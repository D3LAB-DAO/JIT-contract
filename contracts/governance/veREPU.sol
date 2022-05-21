// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// TODO
contract veREPU is ERC20VotesComp, Ownable {
    constructor()
        ERC20("vote-escrowed Reputation", "veREPU")
        ERC20Permit("vote-escrowed Reputation")
    {}
}
