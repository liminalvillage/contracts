// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import Foundry’s test utilities.
import "forge-std/Test.sol";
// Import Foundry's console.log utility
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
// ERC20-Holon Base Contract
/////////////////////////////////////////////

// A minimal interface for our TestToken.
interface ITestToken {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
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
        // vm.broadcast(deployer);  // This sets the tx.origin more reliably
        vm.startPrank(deployer);
        // Deploy the token with an initial supply
        token = new TestToken(1000 ether);

        // Deploy the Holons contract (main factory)
        holons = new Holons();

        managedFlavor = new ManagedFactory();
        appreciativeFlavor = new AppreciativeFactory();
        splitterFlavor = new SplitterFactory();
        zonedFlavor = new ZonedFactory();
        // Register flavors in Holons contract
        holons.newFlavor("managed", address(managedFlavor));
        holons.newFlavor("appreciative", address(appreciativeFlavor));
        holons.newFlavor("splitter", address(splitterFlavor));
        holons.newFlavor("zoned", address(zonedFlavor));

        // Create contract instances through Holons
        address managedAddr = holons.newHolon("managed", "Managed", 0);
        address appreciativeAddr = holons.newHolon("appreciative", "Appreciative", 0);
        address splitterAddr = holons.newHolon("splitter", "Splitter", 1);
        address zonedAddr = holons.newHolon("zoned", "Zoned", 5);

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
        console.log("Deployer's zone:", zoned.zone(deployer));
        console.log("Tx origin's zone: ", zoned.zone(tx.origin));
        console.log("tx.origin in setup:", tx.origin);
        console.log("msg.sender in setup:", msg.sender);

        vm.stopPrank();
    }

    function testERC20Distribution() public {

        // Build the holon hierarchy:
        // Managed: members A (EOA) and B (the Appreciative contract)
        vm.prank(deployer); // impersonate the creator
        console.log("Deployer: ", deployer);
        managed.addMember("A");
        vm.prank(deployer); // impersonate the creator
        managed.addMember("B");

        // For the other holons, we simply add members via addMember.
        // Appreciative: members C (EOA) and D (the Splitter contract) 
        vm.prank(deployer); // impersonate the creator
        appreciative.addMember(C, "C");
        vm.prank(deployer); // impersonate the creator
        appreciative.addMember(address(splitter), "D");

        // Splitter: members E (EOA) and F (the Zoned contract)
        vm.prank(deployer);
        splitter.addMember(E, "E");
        vm.prank(deployer); // impersonate the creator
        splitter.addMember(address(zoned), "F");

        // We need to set split in order for Spliter to forward, but it's great test case in case it's not set so we can
        // understand if it is possible to understand that from the logs
        address[] memory members = new address[](2);
        members[0] = E;
        members[1] = address(zoned);
        uint256[] memory percentages = new uint256[](2);
        percentages[0] = 50; // 50% to E
        percentages[1] = 50; // 50% to Zoned
        vm.prank(deployer);
        splitter.setSplit(members, percentages);


        vm.startPrank(deployer, deployer);
        console.log("Deployer zone before addToZone:", zoned.zone(deployer));
        zoned.addToZone(deployer, 5);
        console.log("Deployer zone after addToZone:", zoned.zone(deployer));
        zoned.addToZone(G, 1);
        zoned.addToZone(H, 1);
        vm.stopPrank();

        // Transfer 100 tokens to the Managed holon contract.
        // (Tokens flow from this contract—the deployer of TestToken—to Managed.)
        vm.prank(deployer);
        token.transfer(address(managed), 100 ether);
        // Only Managed requires claim calls.
        // A (EOA) and B (the Appreciative contract) call claim on Managed.
        vm.prank(deployer);
        managed.claim("A", A);
        vm.prank(deployer);
        managed.claim("B", address(appreciative));

        // Now distribute tokens from Managed.
        // Managed divides its 100 tokens between its 2 members:
        // A receives 50 tokens and Appreciative (B) receives 50 tokens.

        // Temporarily
        // Retrieve members from zone 5 (e.g. deployer's zone)
        uint maxZone = 6; // Adjust this value based on contract's zones.
        for (uint zone = 0; zone < maxZone; zone++) {
            address[] memory members = zoned.getZoneMembers(zone);
            if (members.length > 0) {
                console.log("Members in Zone", zone, ":");
                for (uint i = 0; i < members.length; i++) {
                    console.log("  Member", i, ":", members[i]);
                }
            } else {
                console.log("Zone", zone, "has no members.");
            }
        }
        // Temporarily
        vm.prank(deployer);
        // Record deployer's balance before reward distribution
        uint256 deployerInitialBalance = token.balanceOf(deployer);

        console.log("deployer balance before distribution from Zoned", deployerInitialBalance);
        managed.reward(address(token), 100 ether);
        assertEq(token.balanceOf(A), 50 ether);

        // Appreciative divides its 50 tokens equally between C and D (the Splitter contract):
        // C receives 25 tokens and Splitter receives 25 tokens.
        // appreciative.distribute();
        assertEq(token.balanceOf(C), 25 ether);

        // Distribute tokens from Splitter.
        // Splitter divides its 25 tokens equally between E and F (the Zoned contract):
        // E receives 12.5 tokens and Zoned receives 12.5 tokens.
        // splitter.distribute();
        uint256 expectedSplitterShare = 25 ether / 2; // 12.5 tokens
        assertEq(token.balanceOf(E), expectedSplitterShare);
        console.log("Given that splitter didn't distribute the rewards, they must be stored there");
        console.log(token.balanceOf(address(splitter)));

        // Distribute tokens from Zoned.
        // Zoned allocates 2.5 tokens for zone 1, where members G and H reside.
        // It divides the 2.5 tokens equally between them:
        // Each receives 1.25 tokens.
        // zoned.distribute();
        //#TODO: Technical debt - rewards are reserved for zones that have no members, should we distribute whole rewrads instead?
        // For Zone 1 members (G and H)
        uint256 totalZone1Reward = 2.5 ether; // Total reward allocated for zone 1
        uint256 expectedZone1Share = totalZone1Reward / 2; // Divided equally among 2 members

        assertEq(token.balanceOf(G), expectedZone1Share);
        assertEq(token.balanceOf(H), expectedZone1Share);


        // For the Zone 5 member (deployer)
        uint256 expectedZone5Share = 2.5 ether; // All reward for zone 5 goes to its sole member

        // Calculate only the reward change
        uint256 deployerReward = token.balanceOf(deployer) - deployerInitialBalance;
        assertEq(deployerReward, expectedZone5Share);
    }
}
