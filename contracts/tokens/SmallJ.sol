// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20Govern.sol";

interface ISmallJ {
    // TODO
}

/** 
 * @title SmallJ
 * @dev Governance token at Small-J system.
 * 
 * Features:
 * 
 * - AntiWhale
 * - Owner (or delegated one) earns fees per txs
 * - Votes
 * - Capped by 30000 * 10 ** 18
 * 
 * References
 * 
 * - Openzeppelin
 */
contract SmallJ is ERC20Govern, ISmallJ {
    uint256 immutable private _cap = 30000 * 10 ** 18;

    /**
     * @notice Constructs the JIT contract.
     */
    constructor(string memory name_, string memory symbol_)
        /* public */
        ERC20Govern(name_, symbol_)
    {

    }
    
    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    /**
     * @dev See {ERC20-_mint}.
     */
    function _mint(address account, uint256 amount) internal virtual override {
        require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }
}