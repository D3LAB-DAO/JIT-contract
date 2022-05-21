// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract REPU is ERC20Capped, Ownable {
    constructor()
        ERC20Capped(1000000000 * 10e18)
        ERC20("Reputation", "REPU")
    {}

    // called once by the MasterChef at time of deployment
    function initialize() public onlyOwner {
        // TODO: genesis distribution
        // airdrop
        // community fund
        // liqudity providing
    }

    //==================== Functions ====================//

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }
}
