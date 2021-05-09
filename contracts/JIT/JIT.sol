// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/security/Pausable.sol";
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
contract JIT is ERC20Capped, Ownable, Pausable, IMinter, IBurner {
    //==== Constructor ====//
    
    /**
     * @dev Initializes the contract.
     * 
     * - Set `cap`.
     * - Token distribution.
     */
    constructor (uint256 cap_, address[] memory members_, uint256[] memory amounts_)
        ERC20("Just In Time", "JIT")
        ERC20Capped(cap_)
        Ownable()
        Pausable()
    {
        for(uint256 i=0; i<members_.length; i++) {
            ERC20._mint(members_[i], amounts_[i]);
        }
    }

    /**
     * @dev Approves token to max value.
     */
    function approve(address spender) public virtual returns (bool) {
        _approve(_msgSender(), spender, type(uint256).max);
        return true;
    }

    //==== ERC20 ====//

    // function cap() public view virtual override(ERC20Capped, IJIT) returns (uint256) {
    //     return ERC20Capped.cap();
    // }

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

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        require(!paused(), "ERC20Pausable: token transfer while paused");
    }

    //==== Pausable ====//

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() public virtual onlyOwner {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() public virtual onlyOwner {
        _unpause();
    }
}
