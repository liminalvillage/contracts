// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// /**
//  * @title MembershipStructs
//  * @dev Library defining structs used by the MembershipLib
//  */
// library MembershipStructs {
//     struct MembershipData {
//         mapping(string => bool) isMember;
//         string[] userIds;
//         mapping(string => uint256) etherBalance;
//         mapping(string => mapping(address => uint256)) tokenBalance;
//         mapping(string => address[]) tokensOf;
//         mapping(address => uint256) totalDeposited;
//         mapping(string => bool) hasClaimed;
//         mapping(string => address) userIdToAddress;
//     }
// }

// /**
//  * @title MembershipLib
//  * @dev Library providing membership functionality that can be used via composition
//  */
// library MembershipLib {
//     using MembershipLib for MembershipStructs.MembershipData;
    
//     event MemberAdded(string userId);
//     event EtherDeposited(string userId, uint256 amount);
//     event TokenDeposited(string userId, address tokenAddress, uint256 amount);
//     event Claimed(string userId, address beneficiary, uint256 etherAmount);
//     event TokenClaimed(string userId, address beneficiary, address tokenAddress, uint256 amount);
    
//     function addMember(
//         MembershipStructs.MembershipData storage self,
//         string memory _userId
//     ) public {
//         if (self.isMember[_userId]) return; // Gently fail if user is already added
//         self.isMember[_userId] = true;
//         self.userIds.push(_userId);
//         emit MemberAdded(_userId);
//     }
    
//     function addMembers(
//         MembershipStructs.MembershipData storage self,
//         string[] memory _userIds
//     ) public {
//         for (uint i = 0; i < _userIds.length; i++) {
//             string memory userId = _userIds[i];
//             if (self.isMember[userId]) continue; // Skip if user is already added
//             self.isMember[userId] = true;
//             self.userIds.push(userId);
//             emit MemberAdded(userId);
//         }
//     }
    
//     function depositEtherForUser(
//         MembershipStructs.MembershipData storage self,
//         string memory _userId,
//         uint256 amount
//     ) public {
//         require(self.isMember[_userId], "User is not a member");
//         self.etherBalance[_userId] += amount;
//         emit EtherDeposited(_userId, amount);
//     }
    
//     function depositTokenForUser(
//         MembershipStructs.MembershipData storage self,
//         string memory _userId,
//         address _tokenAddress,
//         uint256 _amount
//     ) public {
//         require(self.isMember[_userId], "User is not a member");
        
//         self.tokenBalance[_userId][_tokenAddress] += _amount;
        
//         // Check if token already exists in user's tokens
//         bool tokenExists = false;
//         for (uint i = 0; i < self.tokensOf[_userId].length; i++) {
//             if (self.tokensOf[_userId][i] == _tokenAddress) {
//                 tokenExists = true;
//                 break;
//             }
//         }
        
//         if (!tokenExists) {
//             self.tokensOf[_userId].push(_tokenAddress);
//         }
        
//         self.totalDeposited[_tokenAddress] += _amount;
//         emit TokenDeposited(_userId, _tokenAddress, _amount);
//     }
    
//     function claim(
//         MembershipStructs.MembershipData storage self,
//         string memory _userId,
//         address _beneficiary
//     ) public {
//         require(self.isMember[_userId], "User is not a member");
//         require(!self.hasClaimed[_userId], "User has already claimed");
        
//         if (self.userIdToAddress[_userId] == address(0)) {
//             self.userIdToAddress[_userId] = _beneficiary; // Associate user ID with address on first claim
//         }
        
//         // Claim Ether
//         uint256 etherAmount = self.etherBalance[_userId];
//         if (etherAmount > 0) {
//             self.etherBalance[_userId] = 0;
//             (bool sent,) = _beneficiary.call{value: etherAmount}("");
//             require(sent, "Claiming Ether failed");
//             emit Claimed(_userId, _beneficiary, etherAmount);
//         }
        
//         // Claim Tokens
//         address[] memory tokens = self.tokensOf[_userId];
//         for (uint i = 0; i < tokens.length; i++) {
//             address tokenAddress = tokens[i];
//             uint256 amount = self.tokenBalance[_userId][tokenAddress];
            
//             if (amount > 0) {
//                 self.tokenBalance[_userId][tokenAddress] = 0;
//                 self.totalDeposited[tokenAddress] -= amount;
                
//                 IERC20 token = IERC20(tokenAddress);
//                 require(token.transfer(_beneficiary, amount), "Token transfer failed");
//                 emit TokenClaimed(_userId, _beneficiary, tokenAddress, amount);
//             }
//         }
        
//         self.hasClaimed[_userId] = true;
//     }
    
//     // View functions
//     function getUserCount(
//         MembershipStructs.MembershipData storage self
//     ) public view returns (uint256) {
//         return self.userIds.length;
//     }
    
//     function getUserTokenBalance(
//         MembershipStructs.MembershipData storage self,
//         string memory _userId,
//         address _tokenAddress
//     ) public view returns (uint256) {
//         return self.tokenBalance[_userId][_tokenAddress];
//     }
    
//     function getUserTokens(
//         MembershipStructs.MembershipData storage self,
//         string memory _userId
//     ) public view returns (address[] memory) {
//         return self.tokensOf[_userId];
//     }
    
//     function isMember(
//         MembershipStructs.MembershipData storage self,
//         string memory _userId
//     ) public view returns (bool) {
//         return self.isMember[_userId];
//     }
// }