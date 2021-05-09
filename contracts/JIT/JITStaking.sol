// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/utils/Context.sol";
import "./interfaces/IMinter.sol";

contract JITStaking is Context {
    using SafeERC20 for IERC20;

    address private _JIT;
    uint256 private _JITPerBlock;

    address[] internal _stakerHolders;
    
    struct Stake {
        uint256 amount;
        uint256 latestUpdateBlock;
    }
    
    uint256 private _totalAmount;
    
    mapping(address => Stake) private _stakes;

    //==== Constructor ====//
    
    /**
     * @dev Initializes the contract.
     */
    constructor (address JITAddr_, uint256 JITPerBlock_)
    {
        _JIT = JITAddr_;
        _JITPerBlock = JITPerBlock_;
    }

    /**
     * @dev Stakes JIT to this contract.
     * 
     * Requirements:
     * 
     * - Do `approve` first.
     */
    function deposit(uint256 amount_)
        public
    {
        require(amount_ > 0, "amount SHOULD be bigger than zero");

        // from _msgSender(), to address(this)
        IERC20(_JIT).safeTransferFrom(_msgSender(), address(this), amount_);

        Stake storage stake = _stakes[_msgSender()];

        if (stake.amount == 0) { // new user
            _stakerHolders.push(_msgSender());
            stake.latestUpdateBlock = block.timestamp;
        }
        else {
            updateReward(_msgSender()); // automatically updated
        }

        stake.amount += amount_;
        _totalAmount += amount_;
    }
    
    function withdraw(uint256 amount_)
        public
    {
        require(amount_ > 0, "amount SHOULD be bigger than zero");

        Stake storage stake = _stakes[_msgSender()];

        require(stake.amount != 0, "cannot withdraw, run updateReward() first");
        
        // updateReward(_msgSender());
        stake.amount -= amount_;
        _totalAmount -= amount_;
        
        // from address(this), to _msgSender()
        IERC20(_JIT).safeTransfer(_msgSender(), amount_);
    }
    
    function updateReward(address who_)
        public
    {
        Stake storage stake = _stakes[who_];
        uint256 reward = estimatedReward(who_);
        
        stake.latestUpdateBlock = block.timestamp;

        IMinter(_JIT).mint(address(this), reward); // cannot exceed cap
        
        stake.amount += reward;
        _totalAmount += reward;
    }
    
    function estimatedReward(address who_)
        public
        view
        returns (uint256)
    {
        Stake storage stake = _stakes[who_];
        
        if (stake.amount == 0) { return 0; } // early exit

        uint256 elapsedTime = block.timestamp - stake.latestUpdateBlock;
        
        if (elapsedTime == 0) { return 0; } // early exit
        
        uint256 reward = elapsedTime * _JITPerBlock * stake.amount / _totalAmount;

        // `mint` do the below check:
        // uint256 capped = IJIT(_JIT).cap();
        // uint256 supplied = IERC20(_JIT).totalSupply();
        // if (supplied + reward > capped ) { return capped - supplied; } // cannot exceed cap

        return reward;
    }
    
    function stakeHolders()
        public
        view
        returns (address[] memory holders)
    {
        uint256 cnt;
        for(uint256 i=0; i < _stakerHolders.length; i++) {
            if(_stakes[_stakerHolders[i]].amount != 0) {
                holders[cnt++] = _stakerHolders[i];
            }   
        }
    }
}
