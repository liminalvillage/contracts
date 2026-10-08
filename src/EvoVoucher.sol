// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title EVO voucher — one token is one litre of extra virgin olive oil.
/// @notice The harvest collective's oil as an ERC-20 so a Bundle can divide
///         it: the owner (the mother holon's attester wallet) mints a lot
///         when the oil is back from the press, hands it to the collective's
///         Bundle, and `reward(token, amount)` there cascades it through the
///         split — locations, pickers, cook — exactly as it would ETH.
///         A holder redeems by burning: the oil is handed over in the world
///         and the chain records that it was.
contract EvoVoucher is ERC20, ERC20Burnable, Ownable {
    /// @notice A lot was pressed and its litres minted.
    event Minted(address indexed to, uint256 litres, string memo);
    /// @notice Litres were handed over and the vouchers burned.
    event Redeemed(address indexed holder, uint256 litres, string memo);

    constructor(address _owner) ERC20("EVO olive oil voucher", "EVO") Ownable(_owner) {}

    /// @notice Mint a pressed lot. 18 decimals: 1e18 = one litre.
    function mint(address to, uint256 litres, string calldata memo) external onlyOwner {
        _mint(to, litres);
        emit Minted(to, litres, memo);
    }

    /// @notice Burn vouchers as the oil is handed over.
    function redeem(uint256 litres, string calldata memo) external {
        _burn(msg.sender, litres);
        emit Redeemed(msg.sender, litres, memo);
    }
}
