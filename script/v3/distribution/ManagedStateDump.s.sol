// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

interface IERC20Minimal {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface IManaged {
    // core view
    function name() external view returns (string memory);
    function flavor() external view returns (string memory);
    function creator() external view returns (address);

    function getSize() external view returns (uint256);
    function userIds(uint256) external view returns (string memory);
    function hasClaimed(string calldata) external view returns (bool);
    function userIdToAddress(string calldata) external view returns (address);

    function appreciation(string calldata) external view returns (uint256);
    function totalappreciation() external view returns (uint256);
    function maxAppreciation() external view returns (uint256);

    function etherBalance(string calldata) external view returns (uint256);

    function getTokensOf(string calldata) external view returns (address[] memory);
    function tokenBalance(string calldata, address) external view returns (uint256);

    function totalDeposited(address) external view returns (uint256);
}

contract ManagedStateDump is Script {
    // ===== Config via env =====
    address public MANAGED = vm.envOr("MANAGED", address(0x63408c5cFF77ee4a720834548DBeb19f1E29E377));
    address public PRIMARY_TOKEN = vm.envOr("TOKEN", address(0xf11DA4F41899c5E6437cE32061F27C4580A6586F));
    string  public OUT_PATH = vm.envOr("OUT_JSON", string(""));

    IManaged internal managed;

    function setUp() public {
        require(MANAGED != address(0), "MANAGED not set");
        managed = IManaged(MANAGED);
    }

    function run() external { dump(); }

    /* ------------------------- Helpers ------------------------- */

    /// @dev append tokenAddr to seen[0:count) if not present; return new count
    function _pushIfNew(address[] memory seen, uint256 count, address tokenAddr)
        internal
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < count; i++) {
            if (seen[i] == tokenAddr) return count;
        }
        seen[count] = tokenAddr;
        return count + 1;
    }

    /// @dev serialize one token rollup and print to console; returns updated toksArr json blob
    function _serializeTokenRollup(
        address tokenAddr,
        uint256 memberCount,
        string memory toksKey,
        uint256 idx
    ) internal returns (string memory newToksArr) {
        IERC20Minimal erc = IERC20Minimal(tokenAddr);

        // Roll up per-user reserved for this token
        uint256 totalPerUserReserved = 0;
        for (uint256 u = 0; u < memberCount; u++) {
            string memory uid = managed.userIds(u);
            totalPerUserReserved += managed.tokenBalance(uid, tokenAddr);
        }

        uint256 bal = erc.balanceOf(address(managed));
        uint256 dep = managed.totalDeposited(tokenAddr);

        string memory sym;
        uint8 dec;
        // best-effort metadata (don't fail script)
        try erc.symbol() returns (string memory s) { sym = s; } catch { sym = "UNKNOWN"; }
        try erc.decimals() returns (uint8 d) { dec = d; } catch { dec = 18; }

        // Console
        console2.log("== Token rollup ==");
        console2.log("token", tokenAddr);
        console2.log("symbol", sym);
        console2.log("decimals", dec);
        console2.log("contractBalance", bal);
        console2.log("totalDeposited_slot", dep);
        console2.log("sumPerUserReserved", totalPerUserReserved);
        console2.log("available(balance - totalDeposited)", bal > dep ? bal - dep : 0);

        // JSON
        string memory tk = string.concat("t_", vm.toString(idx));
        vm.serializeAddress(tk, "token", tokenAddr);
        vm.serializeString(tk, "symbol", sym);
        vm.serializeUint(tk, "decimals", dec);
        vm.serializeUint(tk, "contractBalance", bal);
        vm.serializeUint(tk, "totalDeposited_slot", dep);
        vm.serializeUint(tk, "sumPerUserReserved", totalPerUserReserved);
        vm.serializeUint(tk, "available", bal > dep ? bal - dep : 0);
        string memory tokJson = vm.serializeString(tk, "note", "rollup across users");

        // IMPORTANT: vm.serialize* builds arrays by returning accumulated JSON; capture it
        newToksArr = vm.serializeString(toksKey, vm.toString(idx), tokJson);
    }

    /* -------------------------- Main -------------------------- */

    function dump() public {
        console2.log("=== Managed State Snapshot ===");
        console2.log("Managed", MANAGED);

        // header values in locals to shorten lifetimes
        string memory _name   = managed.name();
        string memory _flavor = managed.flavor();
        address _creator      = managed.creator();

        console2.log("Name", _name);
        console2.log("Flavor", _flavor);
        console2.log("Creator", _creator);

        uint256 size = managed.getSize();
        console2.log("Members", size);

        uint256 storedTotal = managed.totalappreciation();
        uint256 maxApp      = managed.maxAppreciation();

        // JSON root
        string memory root = "state";
        vm.serializeAddress(root, "managed", MANAGED);
        vm.serializeString(root, "name", _name);
        vm.serializeString(root, "flavor", _flavor);
        vm.serializeAddress(root, "creator", _creator);
        vm.serializeUint(root, "members", size);
        vm.serializeUint(root, "totalappreciation_stored", storedTotal);
        vm.serializeUint(root, "maxAppreciation", maxApp);

        uint256 sumCurrentAppreciation = 0;

        // We'll track tokens we see to roll up later
        address[] memory seenTokens = new address[](size * 4);
        uint256 seenCount = 0;

        // Per-user dump (narrow scopes inside the loop)
        string memory usersKey = "users";
        string memory usersObj;

        for (uint256 i = 0; i < size; i++) {
            string memory uid = managed.userIds(i);
            bool claimed      = managed.hasClaimed(uid);
            address addr      = managed.userIdToAddress(uid);
            uint256 appr      = managed.appreciation(uid);
            uint256 ethRes    = managed.etherBalance(uid);
            sumCurrentAppreciation += appr;

            // JSON object for this user
            string memory userKey = string.concat("user_", vm.toString(i));
            vm.serializeString(userKey, "userId", uid);
            vm.serializeBool(userKey, "claimed", claimed);
            vm.serializeAddress(userKey, "address", addr);
            vm.serializeUint(userKey, "appreciation", appr);
            vm.serializeUint(userKey, "etherReserved", ethRes);

            // tokens for this user in a short-lived scope
            {
                address[] memory toks = managed.getTokensOf(uid);
                string memory tarr    = "tokens";
                string memory tarrJson;

                for (uint256 j = 0; j < toks.length; j++) {
                    address tokenAddr = toks[j];
                    uint256 r = managed.tokenBalance(uid, tokenAddr);

                    // serialize per-user token reservation
                    string memory tokKey = string.concat("tok_", vm.toString(j));
                    vm.serializeAddress(tokKey, "token", tokenAddr);
                    vm.serializeUint(tokKey, "reserved", r);
                    string memory oneTok = vm.serializeString(tokKey, "note", "per-user reserved");
                    tarrJson = vm.serializeString(tarr, vm.toString(j), oneTok);

                    // remember this token for rollup
                    seenCount = _pushIfNew(seenTokens, seenCount, tokenAddr);
                }

                // attach per-user tokens json
                string memory userJson = vm.serializeString(userKey, "tokens", tarrJson);
                usersObj = vm.serializeString(usersKey, vm.toString(i), userJson);
            }

            // Console for this user
            console2.log("---");
            console2.log("index", i);
            console2.log("userId", uid);
            console2.log("claimed", claimed);
            console2.log("address", addr);
            console2.log("appreciation", appr);
            console2.log("etherReserved", ethRes);

            // (Optional) echo per-user tokens to console
            {
                address[] memory toks2 = managed.getTokensOf(uid);
                for (uint256 j2 = 0; j2 < toks2.length; j2++) {
                    address t2 = toks2[j2];
                    uint256 r2 = managed.tokenBalance(uid, t2);
                    console2.log("token", t2);
                    console2.log("reserved", r2);
                }
            }
        }

        // Appreciation summary
        console2.log("== Appreciation ==");
        console2.log("stored totalappreciation", storedTotal);
        console2.log("sum(current appreciation)", sumCurrentAppreciation);
        vm.serializeString(root, "users", usersObj);
        vm.serializeUint(root, "sumCurrentAppreciation", sumCurrentAppreciation);

        // Per-token rollups (now in a separate helper to keep stack shallow)
        {
            string memory toksKey = "tokens";
            string memory toksArr;
            for (uint256 idx = 0; idx < seenCount; idx++) {
                address tkn = seenTokens[idx];
                toksArr = _serializeTokenRollup(tkn, size, toksKey, idx);
            }
            vm.serializeString(root, "tokens", toksArr);
        }

        // Primary quick stats (optional)
        if (PRIMARY_TOKEN != address(0)) {
            IERC20Minimal pt = IERC20Minimal(PRIMARY_TOKEN);
            uint256 balPT = pt.balanceOf(address(managed));
            uint256 depPT = managed.totalDeposited(PRIMARY_TOKEN);
            console2.log("== Primary token quick ==");
            console2.log("token", PRIMARY_TOKEN);
            console2.log("balance", balPT);
            console2.log("totalDeposited", depPT);
            vm.serializeAddress(root, "primaryToken", PRIMARY_TOKEN);
            vm.serializeUint(root, "primary_balance", balPT);
            vm.serializeUint(root, "primary_totalDeposited", depPT);
        }

        // finalize JSON
        string memory jsonOut = vm.serializeString(root, "note", "Managed state snapshot");
        if (bytes(OUT_PATH).length > 0) {
            vm.writeJson(jsonOut, OUT_PATH);
            console2.log("JSON written to", OUT_PATH);
        }
    }
}
