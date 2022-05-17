// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RepuERC20 is ERC20Capped, ERC20Burnable, ERC20VotesComp, Ownable, ReentrancyGuard {
    address public factory;

    //==================== Initialization ====================//

    constructor(
        string memory symbol
    )
        ERC20Capped(1000000000 * 10e18)
        ERC20(symbol, string(abi.encodePacked('r', symbol)))
        ERC20Permit(string(abi.encodePacked('r', symbol)))
    {
        factory = _msgSender();
    }
    
    // called once by the factory at time of deployment
    function initialize(address origin) public {
        require(msg.sender == factory, "Repusitory: FORBIDDEN"); // sufficient check
        transferOwnership(origin);
        _mint(origin, 1000000000 * 10e18);
    }

    //==================== Inherited Functions ====================//

    /**
     * @dev Snapshots the totalSupply after it has been increased.
     * 
     * See {ERC20-_mint}.
     */
    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped, ERC20Votes) {
        require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        ERC20Votes._mint(account, amount);
    }

    /**
     * @dev Snapshots the totalSupply after it has been decreased.
     * Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function _burn(address account, uint256 amount) internal virtual override(ERC20, ERC20Votes) {
        ERC20Votes._burn(account, amount);
    }

    /**
     * @dev Move voting power when tokens are transferred.
     *
     * Emits a {DelegateVotesChanged} event.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Votes) {
        ERC20Votes._afterTokenTransfer(from, to, amount);
    }
}
