// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20Govern.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/security/Pausable.sol";

interface IJIT {
    // TODO
}

/** 
 * @title JIT
 * @dev Governance token at JIT system.
 * 
 * Features:
 * 
 * - AntiWhale
 * - Owner (or delegated one) earns fees per txs
 * - Votes
 * - TODO: Initial minted tokens for merkle distributor
 * - Pausable
 * - Cap-less but "burn like a hell"
 */
contract JIT is ERC20Govern, Pausable, IJIT {
    /**
     * @notice Constructs the JIT contract.
     */
    constructor()
        /* public */
        ERC20Govern("Just In Time", "JIT")
        Pausable()
    {

    }
}