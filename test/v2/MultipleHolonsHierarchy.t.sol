// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
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
// Foundry Test Contract
/////////////////////////////////////////////

contract MultipleHolonsHierarchy is Test {
    // Predefined addresses to represent EOAs.
    address A = address(0x10);
    address C = address(0x11);
    address E = address(0x12);
    address G = address(0x13);
    address H = address(0x14);
    address deployer = address(0x15);

    TestToken token;
    ManagedFactory managedFlavor;
    Managed managed;
    AppreciativeFactory appreciativeFlavor;
    Appreciative appreciative;
    SplitterFactory splitterFlavor;
    Splitter splitter;
    ZonedFactory zonedFlavor;
    Zoned zoned;
    Holons holons;

    function setUp() public {
        vm.label(deployer, "Deployer");
        vm.startPrank(deployer);
        
        console.log("Deploying TestToken...");
        token = new TestToken(1000 ether);
        console.log("TestToken deployed at:", address(token));

        console.log("Deploying Holons (main factory)...");
        holons = new Holons();
        console.log("Holons deployed at:", address(holons));

        console.log("Deploying flavor factories...");
        managedFlavor = new ManagedFactory();
        appreciativeFlavor = new AppreciativeFactory();
        splitterFlavor = new SplitterFactory();
        zonedFlavor = new ZonedFactory();
        console.log("ManagedFactory deployed at:", address(managedFlavor));
        console.log("AppreciativeFactory deployed at:", address(appreciativeFlavor));
        console.log("SplitterFactory deployed at:", address(splitterFlavor));
        console.log("ZonedFactory deployed at:", address(zonedFlavor));

        console.log("Registering flavors in Holons contract...");
        holons.newFlavor("managed", address(managedFlavor));
        console.log("Registered flavor: managed");
        holons.newFlavor("appreciative", address(appreciativeFlavor));
        console.log("Registered flavor: appreciative");
        holons.newFlavor("splitter", address(splitterFlavor));
        console.log("Registered flavor: splitter");
        holons.newFlavor("zoned", address(zonedFlavor));
        console.log("Registered flavor: zoned");

        console.log("Creating holon instances via Holons contract...");
        console.log("Creating Managed holon...");
        address managedAddr = holons.newHolon("managed", "test_creator", "Managed", 0);
        console.log("Managed holon created at:", managedAddr);

        console.log("Creating Appreciative holon...");
        address appreciativeAddr = holons.newHolon("appreciative", "test_creator", "Appreciative", 0);
        console.log("Appreciative holon created at:", appreciativeAddr);

        console.log("Creating Splitter holon...");
        address splitterAddr = holons.newHolon("splitter", "test_creator", "Splitter", 1);
        console.log("Splitter holon created at:", splitterAddr);

        console.log("Creating Zoned holon...");
        address zonedAddr = holons.newHolon("zoned", "test_creator", "Zoned", 5);
        console.log("Zoned holon created at:", zonedAddr);

        // Cast addresses to their respective contract types
        managed = Managed(payable(managedAddr));
        appreciative = Appreciative(payable(appreciativeAddr));
        splitter = Splitter(payable(splitterAddr));
        zoned = Zoned(payable(zonedAddr));

        console.log("Holons address:", address(holons));
        console.log("Managed address:", address(managed));
        console.log("Appreciative address:", address(appreciative));
        console.log("Splitter address:", address(splitter));
        console.log("Zoned address:", address(zoned));
        console.log("Deployer address:", deployer);

        console.log("Adding members to Zoned contract...");
        zoned.addMember("test_creator","deployer");
        console.log("Added member 'deployer'");
        zoned.addMember("test_creator","G");
        console.log("Added member 'G'");
        zoned.addMember("test_creator","H");
        console.log("Added member 'H'");

        vm.stopPrank();
    }

    function testERC20Distribution() public {
        // Build the holon hierarchy:

        // Managed holon: add members "A" and "B" 
        // (where "B" will be the Appreciative contract)
        vm.prank(deployer);
        managed.addMember("A");
        vm.prank(deployer);
        managed.addMember("B");

        // Appreciative holon: add members "C" and "D" 
        // (where "D" will be the Splitter contract)
        vm.prank(deployer);
        appreciative.addMember("C");
        vm.prank(deployer);
        appreciative.addMember("D");

        // Splitter holon: add members "E" and "F" 
        // (where "F" will be the Zoned contract)
        vm.prank(deployer);
        splitter.addMember("E");
        vm.prank(deployer);
        splitter.addMember("F");

        // Set Splitter's split percentages using user IDs.
        string[] memory splitterMembers = new string[](2);
        splitterMembers[0] = "E";
        splitterMembers[1] = "F";
        uint[] memory splitterPercentages = new uint[](2);
        splitterPercentages[0] = 50; // 50% to E
        splitterPercentages[1] = 50; // 50% to F
        vm.prank(deployer);
        splitter.setSplit(splitterMembers, splitterPercentages);

        // For Zoned, adjust zones for members.
        vm.startPrank(deployer, deployer);
        console.log("Deployer zone before addToZone:", zoned.zone("deployer"));
        zoned.addToZone("deployer_id", "deployer", 5);
        console.log("Deployer zone after addToZone:", zoned.zone("deployer"));
        zoned.addToZone("deployer_id", "G", 1);
        zoned.addToZone("deployer_id", "H", 1);
        vm.stopPrank();

        // Transfer 100 tokens to the Managed holon contract.
        vm.prank(deployer);
        token.transfer(address(managed), 100 ether);

        // Only Managed requires claim calls.
        // Members "A" and "B" claim their rewards.
        vm.prank(deployer);
        managed.claim("A", A);
        vm.prank(deployer);
        managed.claim("B", address(appreciative));

        // Now distribute tokens from Managed.
        // Managed divides its 100 tokens between its 2 members:
        // "A" receives 50 tokens and Appreciative ("B") receives 50 tokens.
        uint256 deployerInitialBalance = token.balanceOf(deployer);
        // Appreciative distributes its 50 tokens equally between its members.
        // Members "C" and "D" claim their rewards.
        vm.prank(deployer);
        appreciative.claim("C", C);
        vm.prank(deployer);
        appreciative.claim("D", address(splitter));

        // Splitter distributes its 25 tokens equally between its members.
        // For immediate transfers, at least one member (here "E") claims.
        vm.prank(deployer);
        splitter.claim("E", E);
        vm.prank(deployer);
        splitter.claim("F", address(zoned));

        uint256 expectedSplitterShare = 25 ether / 2; // 12.5 tokens
        console.log("Splitter stored tokens:", token.balanceOf(address(splitter)));

        // Zoned receives its 12.5 tokens from Splitter.
        // Now, Zoned will distribute its rewards according to zones.
        // In this test, we assume:
        // - Zone 1 (members "G" and "H") gets a total of 2.5 tokens (each 1.25 tokens).
        // - Zone 5 (member "deployer") gets 2.5 tokens.
        vm.prank(deployer);
        zoned.claim("deployer", deployer);
        vm.prank(deployer);
        zoned.claim("G", G);
        vm.prank(deployer);
        zoned.claim("H", H);

        managed.reward(address(token), 100 ether);

        uint256 totalZone1Reward = 2.5 ether;
        uint256 expectedZone1Share = totalZone1Reward / 2; // 1.25 tokens each
        assertEq(token.balanceOf(G), expectedZone1Share);
        assertEq(token.balanceOf(H), expectedZone1Share);

        uint256 expectedZone5Share = 2.5 ether;
        console.log("Here is where the contract fails!");
        uint256 deployerReward = token.balanceOf(deployer) - deployerInitialBalance;
        console.log("I was wrong!");
        console.log("deployerReward", deployerReward);
        console.log("expectedZone5Share", expectedZone5Share);
        assertEq(deployerReward, expectedZone5Share);

        assertEq(token.balanceOf(A), 50 ether);
        assertEq(token.balanceOf(C), 25 ether);
        assertEq(token.balanceOf(E), expectedSplitterShare);

    }
}
