// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/utils/Context.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/ERC20.sol";

interface IERC20Govern {
    // TODO
}

/** 
 * @title ERC20Govern
 * @dev Implements extended ERC20 token format with vote (govern).
 * 
 * Features:
 * 
 * - AntiWhale
 * - Owner (or delegated one) earns fees per txs
 * - Votes
 * 
 * References:
 * 
 * - Openzeppelin
 * - Compound
 * - Yam
 * - GoCerberus
 */
contract ERC20Govern is Context, Ownable, ERC20, IERC20Govern {

    /* Owner-friendly features */
    
    /// Transfer tax rate in basis points. (default 9%)
    uint16 public transferTaxRate = 900;
    
    /// Burn rate % of transfer tax. (default 88% x 9% = 7.92% ~= 8% of total amount)
    uint16 public burnRate = 88;
    
    /// Max transfer tax rate: 10%.
    uint16 public constant MAXIMUM_TRANSFER_TAX_RATE = 1000;
    
    /// Burn address
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /// Earn address who earns tx fees
    address public earnAddress;

    /**
     * @dev Update the transfer tax rate.
     * Can only be called by the current operator.
     */
    function updateTransferTaxRate(uint16 transferTaxRate_) public onlyOwner {
        require(
            transferTaxRate_ <= MAXIMUM_TRANSFER_TAX_RATE,
            "ERC20Govern::updateTransferTaxRate: Transfer tax rate must not exceed the maximum rate."
        );
        transferTaxRate = transferTaxRate_;
    }

    /**
     * @dev Update the burn rate.
     * Can only be called by the current operator.
     */
    function updateBurnRate(uint16 burnRate_) public onlyOwner {
        require(
            burnRate_ <= 100,
            "ERC20Govern::updateBurnRate: Burn rate must not exceed the maximum rate."
        );
        burnRate = burnRate_;
    }

    /**
     * @dev Update the `earnAddress`.
     * Can only be called by the current operator.
     */
    function updateEarnAddress(address earnAddress_) public onlyOwner {
        require(
            earnAddress_ != earnAddress && earnAddress_ != address(0) && earnAddress_ != BURN_ADDRESS,
            "ERC20Govern::updateEarnAddress: Earn address must not be the original one, zero, and burn address."
        );
        earnAddress = earnAddress_;
    }

    /* Anti Whale */

    /// Max transfer amount rate in basis points. (default is 0.5% of total supply)
    uint16 public maxTransferAmountRate = 50;
    
    /// Addresses that excluded from antiWhale
    mapping(address => bool) private _excludedFromAntiWhale;

    /**
     * @dev Returns the max transfer amount.
     */
    function maxTransferAmount() public view returns (uint256) {
        return totalSupply() * maxTransferAmountRate / 10000;
    }

    /**
     * @dev Returns the address is excluded from antiWhale or not.
     */
    function isExcludedFromAntiWhale(address account_) public view returns (bool) {
        return _excludedFromAntiWhale[account_];
    }

    /**
     * @dev Update the max transfer amount rate.
     * Can only be called by the current operator.
     */
    function updateMaxTransferAmountRate(uint16 maxTransferAmountRate_) public onlyOwner {
        require(
            maxTransferAmountRate_ <= 10000,
            "ERC20Govern::updateMaxTransferAmountRate: Max transfer amount rate must not exceed the maximum rate."
        );
        maxTransferAmountRate = maxTransferAmountRate_;
    }

    /**
     * @dev Exclude or include an address from antiWhale.
     * Can only be called by the current operator.
     */
    function setExcludedFromAntiWhale(address account_, bool excluded_) public onlyOwner {
        _excludedFromAntiWhale[account_] = excluded_;
    }

    modifier antiWhale(address sender, address recipient, uint256 amount) {
        if (maxTransferAmount() > 0) {
            if (
                _excludedFromAntiWhale[sender] == false && _excludedFromAntiWhale[recipient] == false
            ) {
                require(
                    amount <= maxTransferAmount(),
                    "ERC20Govern::antiWhale: Transfer amount exceeds the maxTransferAmount"
                );
            }
        }
        _;
    }

    /* ERC20-like */

    /**
     * @notice Constructs the ERC20Govern contract.
     */
    constructor(string memory name_, string memory symbol_)
        /* public */
        ERC20(name_, symbol_)
        Ownable()
    {
        address msgSender = _msgSender();

        earnAddress = msgSender;
        
        _excludedFromAntiWhale[msgSender] = true;
        _excludedFromAntiWhale[address(0)] = true;
        _excludedFromAntiWhale[address(this)] = true; // TODO: Is this possible?
        _excludedFromAntiWhale[BURN_ADDRESS] = true;
    }

    /**
     * @notice Creates `amount_` token to `to_`.
     * Must only be called by the owner.
     */
    function mint(address to_, uint256 amount_) public onlyOwner {
        _mint(to_, amount_);
        _moveDelegates(address(0), _delegates[to_], amount_);
    }

    /**
     * @dev Overrides transfer function to meet Tokenomics.
     */
    function _transfer(address sender, address recipient, uint256 amount)
        internal
        virtual
        override
        antiWhale(sender, recipient, amount)
    {
        if (recipient == BURN_ADDRESS || transferTaxRate == 0) {
            super._transfer(sender, recipient, amount);
        }
        else {
            // default tax is 9% of every transfer
            uint256 taxAmount = amount * transferTaxRate / 10000;
            uint256 burnAmount = taxAmount * burnRate / 100;
            uint256 rewardAmount = taxAmount - burnAmount;
            // require(taxAmount == burnAmount + rewardAmount, "ERC20Govern::transfer: Burn value invalid"); // No overflow

            // default 91% of transfer sent to recipient
            uint256 sendAmount = amount - taxAmount;
            // require(amount == sendAmount + taxAmount, "ERC20Govern::transfer: Tax value invalid"); // No overflow

            super._transfer(sender, BURN_ADDRESS, burnAmount);
            super._transfer(sender, earnAddress, rewardAmount);
            super._transfer(sender, recipient, sendAmount);
            amount = sendAmount;
        }
    }

    /* Governance */
    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    /// @dev A record of each accounts delegate
    mapping (address => address) internal _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegator The address to get delegatee for
     */
    function delegates(address delegator)
    external
    view
    returns (address)
    {
        return _delegates[delegator];
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
    external
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "ERC20Govern::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "ERC20Govern::delegateBySig: invalid nonce");
        require(block.timestamp <= expiry, "ERC20Govern::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account)
    external
    view
    returns (uint256)
    {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber)
    external
    view
    returns (uint256)
    {
        require(blockNumber < block.number, "ERC20Govern::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee)
    internal
    {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying ERC20Govern (not scaled);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld - amount;
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld + amount;
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
    internal
    {
        uint32 blockNumber = safe32(block.number, "ERC20Govern::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal view returns (uint) {
        return block.chainid;
    }
}
