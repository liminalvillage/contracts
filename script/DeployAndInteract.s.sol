// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import your contracts
import "../src/Managed.sol";
import "../src/ManagedFactory.sol";
import "../src/AppreciativeFactory.sol";
import "../src/Appreciative.sol";
import "../src/SplitterFactory.sol";
import "../src/Splitter.sol";
import "../src/ZonedFactory.sol";
import "../src/Zoned.sol";
import "../src/Holons.sol";

/////////////////////////////////////////////
// Minimal ERC20 Token Implementation
/////////////////////////////////////////////
contract TestToken {
    string public name = "TestToken";
    string public symbol = "TTK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
    }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        balanceOf[from] -= amount;
        allowance[from][msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/////////////////////////////////////////////
// Broadcast Script (Refactored)
/////////////////////////////////////////////
contract DeployAndInteract is Script {
    // Group deployed contracts into a struct to pass them between functions.
    struct DeployedContracts {
        TestToken token;
        Holons holons;
        ManagedFactory managedFlavor;
        AppreciativeFactory appreciativeFlavor;
        SplitterFactory splitterFlavor;
        ZonedFactory zonedFlavor;
        Managed managed;
        Appreciative appreciative;
        Splitter splitter;
        Zoned zoned;
    }

    /// @notice Deploy contracts and return the struct with references.
    function deployContracts() internal returns (DeployedContracts memory dc) {
        dc.token = new TestToken(1000 ether);
        dc.holons = new Holons();

        dc.managedFlavor = new ManagedFactory();
        dc.appreciativeFlavor = new AppreciativeFactory();
        dc.splitterFlavor = new SplitterFactory();
        dc.zonedFlavor = new ZonedFactory();

        // Register flavors
        dc.holons.newFlavor("managed", address(dc.managedFlavor));
        dc.holons.newFlavor("appreciative", address(dc.appreciativeFlavor));
        dc.holons.newFlavor("splitter", address(dc.splitterFlavor));
        dc.holons.newFlavor("zoned", address(dc.zonedFlavor));

        // Create holon instances
        address managedAddr = dc.holons.newHolon("managed", "Managed", 0);
        address appreciativeAddr = dc.holons.newHolon("appreciative", "Appreciative", 0);
        address splitterAddr = dc.holons.newHolon("splitter", "Splitter", 1);
        address zonedAddr = dc.holons.newHolon("zoned", "Zoned", 5);

        dc.managed = Managed(payable(managedAddr));
        dc.appreciative = Appreciative(payable(appreciativeAddr));
        dc.splitter = Splitter(payable(splitterAddr));
        dc.zoned = Zoned(payable(zonedAddr));

        console.log("Holons deployed at:", address(dc.holons));
        console.log("Managed deployed at:", address(dc.managed));
        console.log("Appreciative deployed at:", address(dc.appreciative));
        console.log("Splitter deployed at:", address(dc.splitter));
        console.log("Zoned deployed at:", address(dc.zoned));

        return dc;
    }

    /// @notice Build the holon hierarchy and adjust zones.
    function buildHierarchy(DeployedContracts memory dc, address deployer) internal {
        // Predefined addresses representing EOAs.
        address A = address(0x10);
        address C = address(0x11);
        address E = address(0x12);
        address G = address(0x13);
        address H = address(0x14);

        // Managed: add members "A" and "B"
        dc.managed.addMember("A");
        dc.managed.addMember("B");

        // Appreciative: add members C and the Splitter contract (as "D")
        dc.appreciative.addMember(C, "C");
        dc.appreciative.addMember(address(dc.splitter), "D");

        // Splitter: add members E and the Zoned contract (as "F")
        dc.splitter.addMember(E, "E");
        dc.splitter.addMember(address(dc.zoned), "F");

        // Set split for Splitter (E and Zoned share equally)
        {
            address[] memory splitMembers = new address[](2);
            splitMembers[0] = E;
            splitMembers[1] = address(dc.zoned);
            uint256[] memory percentages = new uint256[](2);
            percentages[0] = 50;
            percentages[1] = 50;
            dc.splitter.setSplit(splitMembers, percentages);
        }

        // Adjust zone settings
        dc.zoned.addToZone(deployer, 5);
        dc.zoned.addToZone(G, 1);
        dc.zoned.addToZone(H, 1);
    }

    /// @notice Interact with deployed contracts (token transfers, reward distribution, etc.)
    function interactWithContracts(DeployedContracts memory dc, address deployer) internal {
        // Predefined address for member A (as an example)
        address A = address(0x10);
        // Transfer 100 tokens to the Managed holon contract.
        dc.token.transfer(address(dc.managed), 100 ether);

        // Claim rewards for Managed: "A" and "B" (here, "B" is represented by the Appreciative contract).
        dc.managed.claim("A", A);
        dc.managed.claim("B", address(dc.appreciative));

        // Record deployer's token balance before distribution.
        uint256 deployerInitialBalance = dc.token.balanceOf(deployer);

        // Distribute tokens from Managed (splitting 100 tokens between its 2 members).
        dc.managed.reward(address(dc.token), 100 ether);

        // Log balances.
        uint256 balanceA = dc.token.balanceOf(A);
        uint256 balanceC = dc.token.balanceOf(address(0x11)); // member C
        uint256 balanceE = dc.token.balanceOf(address(0x12)); // member E
        uint256 splitterBalance = dc.token.balanceOf(address(dc.splitter));
        uint256 balanceG = dc.token.balanceOf(address(0x13)); // member G
        uint256 balanceH = dc.token.balanceOf(address(0x14)); // member H
        uint256 deployerReward = dc.token.balanceOf(deployer) - deployerInitialBalance;

        // console.log("Balance of A (~50 tokens):", balanceA);
        // console.log("Balance of C (~25 tokens):", balanceC);
        // console.log("Balance of E (~12.5 tokens):", balanceE);
        // console.log("Undistributed balance in Splitter (~12.5 tokens):", splitterBalance);
        // console.log("Balance of G (zone 1 share):", balanceG);
        // console.log("Balance of H (zone 1 share):", balanceH);
        // console.log("Deployer's reward from Zoned (zone 5):", deployerReward);
    }

    function run() public {
        // Get deployer private key from env variable and derive address.
        uint256 deployerPrivateKeyHex = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = uint256(bytes32(abi.encodePacked(deployerPrivateKeyHex)));
        address deployer = vm.addr(deployerPrivateKey);

        // Start broadcasting transactions.
        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts.
        DeployedContracts memory dc = deployContracts();

        // Build the holon hierarchy.
        buildHierarchy(dc, deployer);

        // Interact with contracts (transfer tokens, claim rewards, etc.).
        interactWithContracts(dc, deployer);

        vm.stopBroadcast();
    }
}
