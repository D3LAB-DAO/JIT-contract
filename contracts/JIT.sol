// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.6.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.1/contracts/GSN/Context.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.1/contracts/ownership/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.1/contracts/token/ERC20/ERC20Pausable.sol";

/** 
 * @title JIT
 * @dev Implements JIT token and its ecosystem.
 * 
 * Features:
 * 
 * - Capped.
 * - Pausable.
 * - Mint JITs frequently (1 week by default).
 * - Stake JITs to distribute new minted one.
 * - Burn JITs to buy NFT such as invitation card(s).
 * - Need the invitation card to join system.
 */
contract JIT is Context, Ownable, ERC20Pausable {
    uint256 private _cap;

    /**
     * @dev Sets the value of the `cap`.
     */
    constructor (uint256 cap) public {
        require(cap > 0, "ERC20Capped: cap is 0");
        _cap = cap;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    /**
     * @dev Sets the value of the `cap`.
     * 
     * TODO:
     * 
     * - Governance.
     */
    function newCap(uint256 cap_) public onlyOwner {
        require(cap_ > 0, "ERC20Capped: cap is 0");
        _cap = cap_;
    }

    /**
     * @dev See {ERC20Mintable-mint}.
     *
     * Requirements:
     *
     * - `value` must not cause the total supply to go over the cap.
     */
    function _mint(address account, uint256 value) internal {
        require(totalSupply().add(value) <= _cap, "ERC20Capped: cap exceeded");
        super._mint(account, value);
    }
}
