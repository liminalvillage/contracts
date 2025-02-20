// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import your contracts
import "../../src/Managed.sol";
import "../../src/ManagedFactory.sol";
import "../../src/AppreciativeFactory.sol";
import "../../src/Appreciative.sol";
import "../../src/SplitterFactory.sol";
import "../../src/Splitter.sol";
import "../../src/ZonedFactory.sol";
import "../../src/Zoned.sol";
import "../../src/Holons.sol";

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
    /// @dev In the updated contracts, member management uses string userIds.
    function buildHierarchy(DeployedContracts memory dc, address deployer) internal {
        // Predefined addresses for claim later (EOA beneficiaries)
        address A = address(0x10);
        address C = address(0x11);
        address E = address(0x12);
        address G = address(0x13);
        address H = address(0x14);

        // Managed holon: add members "A" and "B"
        dc.managed.addMember("A");
        dc.managed.addMember("B");

        // Appreciative holon: add members "C" and "D"
        dc.appreciative.addMember("C");
        dc.appreciative.addMember("D");

        // Splitter holon: add members "E" and "F"
        dc.splitter.addMember("E");
        dc.splitter.addMember("F");

        // Zoned holon: add members "deployer", "G", and "H"
        dc.zoned.addMember("deployer");
        dc.zoned.addMember("G");
        dc.zoned.addMember("H");

        // Set split for Splitter: "E" and "F" share equally
        {
            string[] memory splitMembers = new string[](2);
            splitMembers[0] = "E";
            splitMembers[1] = "F";
            uint[] memory percentages = new uint[](2);
            percentages[0] = 50;
            percentages[1] = 50;
            dc.splitter.setSplit(splitMembers, percentages);
        }

        // Adjust zone settings in Zoned holon
        dc.zoned.addToZone("deployer", 5);
        dc.zoned.addToZone("G", 1);
        dc.zoned.addToZone("H", 1);

        // Note: The hierarchy linking is achieved by making Managed’s second member
        // be the Appreciative holon, Appreciative’s second member be the Splitter, and so on.
    }

    /// @notice Interact with deployed contracts (simulate token flow through the hierarchy).
    /// @dev This function shows one possible reward cascade.
    function interactWithContracts(DeployedContracts memory dc, address deployer) internal {
        // Predefined addresses for claim calls
        address A = address(0x10);
        address C = address(0x11);
        address E = address(0x12);
        
        // Transfer 100 tokens to the Managed holon.
        dc.token.transfer(address(dc.managed), 100 ether);

        // Managed holon: "A" claims directly and "B" (represented by Appreciative) claims.
        dc.managed.claim("A", A);
        dc.managed.claim("B", address(dc.appreciative));

        // Distribute tokens from Managed.
        // For example, this might split 100 tokens between "A" and the Appreciative holon.
        dc.managed.reward(address(dc.token), 100 ether);

        // Now, the Appreciative holon (member "B" of Managed) should distribute its tokens.
        // Let "C" claim directly and "D" (represented by the Splitter) claim.
        dc.appreciative.claim("C", C);
        dc.appreciative.claim("D", address(dc.splitter));

        // Distribute tokens from Appreciative.
        // Assuming it received 50 tokens from Managed.
        uint256 appreciatedTokenAmount = 50 ether;
        dc.appreciative.reward(address(dc.token), appreciatedTokenAmount);

        // Next, the Splitter holon (member "D" of Appreciative) does its distribution.
        // Let "E" claim directly and "F" (represented by Zoned) claim.
        dc.splitter.claim("E", E);
        dc.splitter.claim("F", address(dc.zoned));

        // Distribute tokens from Splitter.
        // Assuming it received 50 tokens.
        uint256 splitterTokenAmount = 50 ether;
        dc.splitter.reward(address(dc.token), splitterTokenAmount);

        // Finally, the Zoned holon (member "F" of Splitter) distributes rewards.
        // Its members are "deployer", "G", and "H".
        dc.zoned.claim("deployer", deployer);
        dc.zoned.claim("G", address(0x13));
        dc.zoned.claim("H", address(0x14));

        // Distribute tokens from Zoned.
        // Assuming it received 50 tokens.
        uint256 zonedTokenAmount = 50 ether;
        dc.zoned.reward(address(dc.token), zonedTokenAmount);

        // (Optional) Log final balances for verification.
        uint256 balanceA = dc.token.balanceOf(A);
        uint256 balanceC = dc.token.balanceOf(C);
        uint256 balanceE = dc.token.balanceOf(E);
        uint256 splitterBalance = dc.token.balanceOf(address(dc.splitter));
        uint256 balanceG = dc.token.balanceOf(address(0x13));
        uint256 balanceH = dc.token.balanceOf(address(0x14));
        uint256 deployerReward = dc.token.balanceOf(deployer);

        console.log("Balance of A:", balanceA);
        console.log("Balance of C:", balanceC);
        console.log("Balance of E:", balanceE);
        console.log("Undistributed balance in Splitter:", splitterBalance);
        console.log("Balance of G:", balanceG);
        console.log("Balance of H:", balanceH);
        console.log("Deployer's reward from Zoned:", deployerReward);
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

        // Interact with contracts (simulate token transfers and reward distribution).
        interactWithContracts(dc, deployer);

        vm.stopBroadcast();
    }
}
