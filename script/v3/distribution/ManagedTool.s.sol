// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

/* -------------------- Interfaces -------------------- */

interface IERC20Minimal {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IManaged {
    function getSize() external view returns (uint256);
    function userIds(uint256) external view returns (string memory);
    function hasClaimed(string calldata) external view returns (bool);
    function userIdToAddress(string calldata) external view returns (address);
    function totalDeposited(address token) external view returns (uint256);
    function tokenBalance(string calldata, address token) external view returns (uint256);

    function claim(string calldata userId, address beneficiary) external;
    function reward(address token, uint256 amount) external payable;
}

/* -------------------- Script -------------------- */

contract ManagedTool is Script {
    address public MANAGED = vm.envOr("MANAGED", address(0x63408c5cFF77ee4a720834548DBeb19f1E29E377));
    address public TOKEN   = vm.envOr("TOKEN",   address(0xf11DA4F41899c5E6437cE32061F27C4580A6586F));

    uint256 public constant CHAIN_ID = 11155111; // Sepolia

    IManaged internal managed;
    IERC20Minimal internal token;

    function setUp() public {
        require(MANAGED != address(0), "MANAGED not set");
        require(TOKEN   != address(0), "TOKEN not set");
        managed = IManaged(MANAGED);
        token   = IERC20Minimal(TOKEN);
    }

    /* -------------------- Commands (no broadcast) -------------------- */

    function runInfo() public view {
        console2.log("MANAGED", MANAGED);
        console2.log("TOKEN", TOKEN);
        console2.log("CHAIN", CHAIN_ID);
        _printSizes();
    }

    function runList() public view {
        _listMembers();
    }

    function runFindByAddress(address target) public view {
        uint256 n = managed.getSize();
        bool hit;
        for (uint256 i = 0; i < n; i++) {
            string memory uid = managed.userIds(i);
            address addr = managed.userIdToAddress(uid);
            if (addr == target) {
                bool claimed = managed.hasClaimed(uid);
                console2.log("match");
                console2.log("index", i);
                console2.log("userId", uid);
                console2.log("claimed", claimed);
                console2.log("address", addr);
                hit = true;
            }
        }
        if (!hit) {
            console2.log("no match for address", target);
        }
    }

    function runBalances() public view {
        string memory sym = _safeSymbol(token);
        uint8 dec         = _safeDecimals(token);

        uint256 bal = token.balanceOf(MANAGED);
        uint256 dep = managed.totalDeposited(TOKEN);

        console2.log("Token", sym);
        console2.log("Decimals", dec);
        console2.log("Managed balanceOf", bal);
        console2.log("Managed reserved", dep);
    }

    function runReservedList() public view {
        uint256 n = managed.getSize();
        string memory sym = _safeSymbol(token);
        uint8 dec         = _safeDecimals(token);

        console2.log("Users with reserved", sym);
        console2.log("Decimals", dec);
        for (uint256 i = 0; i < n; i++) {
            string memory uid = managed.userIds(i);
            uint256 amt = managed.tokenBalance(uid, TOKEN);
            if (amt > 0) {
                console2.log("index", i);
                console2.log("userId", uid);
                console2.log("reserved", amt);
            }
        }
    }

    /* -------------------- Commands (require --broadcast) -------------------- */

    function runClaim(string calldata userId, address beneficiary) public {
        setUp();
        vm.startBroadcast();
        managed.claim(userId, beneficiary);
        vm.stopBroadcast();
        console2.log("Claim sent for userId", userId);
        console2.log("beneficiary", beneficiary);
    }

    function runRewardErc20(uint256 amountWei) public {
        setUp();
        vm.startBroadcast();
        managed.reward(TOKEN, amountWei);
        vm.stopBroadcast();
        console2.log("Reward(ERC20) token", TOKEN);
        console2.log("amount", amountWei);
    }

    function runRewardEth(uint256 amountWei) public {
        setUp();
        vm.startBroadcast();
        managed.reward{value: amountWei}(address(0), 0);
        vm.stopBroadcast();
        console2.log("Reward(ETH) value", amountWei);
    }

    /* -------------------- Helpers -------------------- */

    function _printSizes() internal view {
        uint256 n = managed.getSize();
        console2.log("Members in set", n);
    }

    function _listMembers() internal view {
        uint256 n = managed.getSize();
        console2.log("Members in set", n);
        for (uint256 i = 0; i < n; i++) {
            string memory uid = managed.userIds(i);
            bool claimed      = managed.hasClaimed(uid);
            address addr      = managed.userIdToAddress(uid);
            console2.log("index", i);
            console2.log("userId", uid);
            console2.log("claimed", claimed);
            console2.log("address", addr);
        }
    }

    function _safeSymbol(IERC20Minimal t) internal view returns (string memory s) {
        try t.symbol() returns (string memory sym) { s = sym; } catch { s = "UNKNOWN"; }
    }

    function _safeDecimals(IERC20Minimal t) internal view returns (uint8 d) {
        try t.decimals() returns (uint8 dec) { d = dec; } catch { d = 18; }
    }

function run() external view {
    runInfo();
    runList();
    runBalances();
    runReservedList();
}

}
