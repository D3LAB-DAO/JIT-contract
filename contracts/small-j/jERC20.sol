// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/Ownable.sol";
import "./interfaces/IMinter.sol";
import "./interfaces/IBurner.sol";

/**
 * References
 * 
 * - https://github.com/OpenZeppelin/openzeppelin-contracts
 * 
 * TODO
 * 
 * - Prevent reentrancy attack.
 * - | https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/security/ReentrancyGuard.sol
 * - | nonReentrant
 */
contract jERC20 is ERC20Capped, Ownable, IMinter, IBurner {
    //==== Constructor ====//
    
    /**
     * @dev Initializes the contract.
     */
    constructor (string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC20Capped(30000000000000000000000)  // TODO: 30000 * (10 ** 18)
        Ownable()
    {
        require(bytes(symbol_)[0] == 0x6a); // 'j' + BLAHBLAH
    }

    /**
     * @dev Approves token to max value.
     */
    function approve(address spender) public virtual returns (bool) {
        _approve(_msgSender(), spender, type(uint256).max);
        return true;
    }

    //==== ERC20 ====//

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function mint(address account, uint256 amount) public virtual override onlyOwner {
        _mint(account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function burn(uint256 amount) public virtual override {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }
}
