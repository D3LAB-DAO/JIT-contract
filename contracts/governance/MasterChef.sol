// SPDX-License-Identifier: MIT
// Reference: https://github.com/repuswap

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "./REPU.sol";

interface IRewarder { 
    function onRepuReward(uint256 pid, address user, address recipient, uint256 repuAmount, uint256 newLpAmount) external;
    function pendingTokens(uint256 pid, address user, uint256 repuAmount) external view returns (IERC20[] memory, uint256[] memory);
}

contract MasterChef is Ownable {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of REPU entitled to the user.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }
    /// @notice Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of REPU to distribute per block.
    struct PoolInfo {
        uint128 accRepuPerShare;
        uint64 lastRewardBlock;
        uint64 allocPoint;
    }
    /// @notice Info of each MCV2 pool.
    PoolInfo[] public poolInfo;
    /// @notice Address of the LP token for each MCV2 pool.
    IERC20[] public lpToken;
    /// @notice Address of each `IRewarder` contract in MCV2.
    IRewarder[] public rewarder;

    /// @notice REPU contract.
    REPU public repu;

    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    uint256 private constant ACC_REPU_PRECISION = 1e12;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken, IRewarder indexed rewarder);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint, IRewarder indexed rewarder, bool overwrite);
    event LogUpdatePool(uint256 indexed pid, uint64 lastRewardBlock, uint256 lpSupply, uint256 accRepuPerShare);

    constructor() {
        address msgSender = _msgSender();
        
        bytes memory bytecode = type(REPU).creationCode;
        bytecode = abi.encodePacked(bytecode);
        bytes32 salt = keccak256(abi.encodePacked(msgSender));
        address repu_;
        assembly {
            repu_ := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        repu = REPU(repu_);

        repu.initialize();
    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _lpToken Address of the LP ERC-20 token.
    /// @param _rewarder Address of the rewarder delegate.
    function add(uint256 allocPoint, IERC20 _lpToken, IRewarder _rewarder) public onlyOwner {
        uint256 lastRewardBlock = block.number;
        totalAllocPoint += allocPoint;
        lpToken.push(_lpToken);
        rewarder.push(_rewarder);

        poolInfo.push(PoolInfo({
            allocPoint: uint64(allocPoint),
            lastRewardBlock: uint64(lastRewardBlock),
            accRepuPerShare: 0
        }));
        emit LogPoolAddition(lpToken.length - 1, allocPoint, _lpToken, _rewarder);
    }

    /// @notice Update the given pool's REPU allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    /// @param _rewarder Address of the rewarder delegate.
    /// @param overwrite True if _rewarder should be `set`. Otherwise `_rewarder` is ignored.
    function set(uint256 _pid, uint256 _allocPoint, IRewarder _rewarder, bool overwrite) public onlyOwner {
        totalAllocPoint -= poolInfo[_pid].allocPoint;
        totalAllocPoint += _allocPoint;
        poolInfo[_pid].allocPoint = uint64(_allocPoint);
        if (overwrite) { rewarder[_pid] = _rewarder; }
        emit LogSetPool(_pid, _allocPoint, overwrite ? _rewarder : rewarder[_pid], overwrite);
    }

    /// @notice View function to see pending REPU on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending REPU reward for a given user.
    function pendingRepu(uint256 _pid, address _user) external view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRepuPerShare = pool.accRepuPerShare;
        uint256 lpSupply = lpToken[_pid].balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 repuReward = calRepuAmount(pool.lastRewardBlock, block.number) * pool.allocPoint / totalAllocPoint;
            accRepuPerShare += repuReward * ACC_REPU_PRECISION / lpSupply;
        }
        pending = uint256((user.amount * accRepuPerShare / ACC_REPU_PRECISION).toInt256() - user.rewardDebt);
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Calculates and returns the `amount` of REPU over the given _from to _to block.
    function calRepuAmount(uint256 _from, uint256 _to) public view returns (uint256 amount) {
        // TODO: Distribution
        // max cap

        // if (_to <= bonusEndBlock) {
        //     return _to.sub(_from).mul(BONUS_MULTIPLIER);
        // } else if (_from >= bonusEndBlock) {
        //     return _to.sub(_from);
        // } else {
        //     return bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
        //         _to.sub(bonusEndBlock)
        //     );
        // }

        return _to - _from;
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.number > pool.lastRewardBlock) {
            uint256 lpSupply = lpToken[pid].balanceOf(address(this));
            if (lpSupply > 0) {
                uint256 repuReward = calRepuAmount(pool.lastRewardBlock, block.number) * pool.allocPoint / totalAllocPoint;
                pool.accRepuPerShare += (repuReward * ACC_REPU_PRECISION / lpSupply).toUint128();
            }
            pool.lastRewardBlock = block.number.toUint64();
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardBlock, lpSupply, pool.accRepuPerShare);
        }
    }

    /// @notice Deposit LP tokens to MCV2 for REPU allocation.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function deposit(uint256 pid, uint256 amount, address to) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][to];

        // Effects
        user.amount += amount;
        user.rewardDebt += int256(amount * pool.accRepuPerShare / ACC_REPU_PRECISION);

        // Interactions
        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onRepuReward(pid, to, to, 0, user.amount);
        }

        lpToken[pid].safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, pid, amount, to);
    }

    /// @notice Withdraw LP tokens from MCV2.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens.
    function withdraw(uint256 pid, uint256 amount, address to) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];

        // Effects
        user.rewardDebt -= int256(amount * pool.accRepuPerShare / ACC_REPU_PRECISION);
        user.amount -= amount;

        // Interactions
        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onRepuReward(pid, msg.sender, to, 0, user.amount);
        }
        
        lpToken[pid].safeTransfer(to, amount);

        emit Withdraw(msg.sender, pid, amount, to);
    }

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of REPU rewards.
    function harvest(uint256 pid, address to) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];
        int256 accumulatedRepu = int256(user.amount * pool.accRepuPerShare / ACC_REPU_PRECISION);
        uint256 _pendingRepu = uint256(accumulatedRepu - user.rewardDebt);

        // Effects
        user.rewardDebt = accumulatedRepu;

        // Interactions
        if (_pendingRepu != 0) {
            repu.mint(to, _pendingRepu);
        }
        
        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onRepuReward( pid, msg.sender, to, _pendingRepu, user.amount);
        }

        emit Harvest(msg.sender, pid, _pendingRepu);
    }
    
    /// @notice Withdraw LP tokens from MCV2 and harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens and REPU rewards.
    function withdrawAndHarvest(uint256 pid, uint256 amount, address to) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];
        int256 accumulatedRepu = int256(user.amount * pool.accRepuPerShare / ACC_REPU_PRECISION);
        uint256 _pendingRepu = uint256(accumulatedRepu - user.rewardDebt);

        // Effects
        user.rewardDebt = accumulatedRepu - int256(amount * pool.accRepuPerShare / ACC_REPU_PRECISION);
        user.amount -= amount;
        
        // Interactions
        repu.mint(to, _pendingRepu);

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onRepuReward(pid, msg.sender, to, _pendingRepu, user.amount);
        }

        lpToken[pid].safeTransfer(to, amount);

        emit Withdraw(msg.sender, pid, amount, to);
        emit Harvest(msg.sender, pid, _pendingRepu);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of the LP tokens.
    function emergencyWithdraw(uint256 pid, address to) public {
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onRepuReward(pid, msg.sender, to, 0, 0);
        }

        // Note: transfer can fail or succeed if `amount` is zero.
        lpToken[pid].safeTransfer(to, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount, to);
    }
}
