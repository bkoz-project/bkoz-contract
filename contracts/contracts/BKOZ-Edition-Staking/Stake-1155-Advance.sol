// SPDX-License-Identifier: MIT
// Kozmo Games
// ERC 1155 Staking Advance v1.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/base/ERC1155Drop.sol";
import "@thirdweb-dev/contracts/external-deps/openzeppelin/utils/ERC1155/ERC1155Holder.sol";
import "@thirdweb-dev/contracts/base/ERC20Base.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

contract ERC1155Staking is ReentrancyGuard, PermissionsEnumerable, ERC1155Holder, ContractMetadata, Multicall{
    address public deployer;
    // ERC1155 token interface, representing the stakable NFTs.
    ERC1155Drop public immutable erc1155Token;
    // ERC20 token interface, representing the rewards token.
    ERC20Base public immutable rewardsToken;
    // The specific ID of the ERC1155 token that is eligible for staking.
    uint256 public stakingTokenId;
    // Percentage of the reward allocated as a fee to agents (if applicable).
    uint256 public AGENT_FEE_PERCENTAGE = 1;
    // Struct to store information about each staking instance.
    struct StakingInfo {
        uint256 amount;     // Amount of tokens staked by the user.
        uint256 reward;     // Reward accumulated by the user.
        uint256 updateTime;  // Timestamp when the user started staking.
    }
    // Mapping from user addresses to their staking information.
    mapping(address => StakingInfo) public stakings;
    // Array of addresses that are currently staking tokens.
    address[] public stakers;
    // Mapping from user addresses to their index in the stakers array.
    mapping(address => uint256) private stakerIndex;
    // Maximum number of NFTs that can be staked in the contract.
    uint256 public MAX_NFT_STAKED;
    // Maximum reward that can be distributed by the contract.
    uint256 public MAX_REWARD;
    // Duration for which the staking is active.
    uint256 public constant STAKING_PERIOD = 1250 days;
    // Timestamp when the reward pool starts.
    uint256 public poolStartTime;
    // Total amount of rewards that have been distributed so far.
    uint256 public totalRewardsDistributed;
    // Staking pool STATUS
    bool public POOL_FINISHED;

    bytes32 private constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    // Event to log deposits
    event RewardDeposit(address indexed user, uint256 amount);
    // Event to log emergency withdrawals
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(address _erc1155Token, uint256 _stakingTokenId, uint256 _nftCount, uint256 _totalReward, uint256 _poolStartTime, uint256 _boforeRewardsDistributed, address _erc20Token, string memory _contractURI) {
        erc1155Token = ERC1155Drop(_erc1155Token);
        stakingTokenId = _stakingTokenId;
        poolStartTime = _poolStartTime;
        totalRewardsDistributed = _boforeRewardsDistributed;
        rewardsToken = ERC20Base(_erc20Token);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, 0x4867D726B9058AcEdbE2080bf2DFAA6782059E43);
        MAX_NFT_STAKED = _nftCount;
        MAX_REWARD = _totalReward;
        deployer = msg.sender;
        POOL_FINISHED = false;
        _setupContractURI(_contractURI);
    }

    // Staking function: Allows a user to stake ERC-1155 tokens.
    function stake(uint256 _amount) external nonReentrant {
        // Chkck pool status.
        require(!POOL_FINISHED, "Pool has finished.");
        // Check if the user has enough ERC-1155 tokens to stake.
        require(erc1155Token.balanceOf(msg.sender, stakingTokenId) >= _amount, "Not enough ERC1155 tokens");
        // Access the user's staking information.
        StakingInfo storage info = stakings[msg.sender];
        // Safely transfer ERC-1155 tokens from the user to this contract.
        erc1155Token.safeTransferFrom(msg.sender, address(this), stakingTokenId, _amount, "");

        // Update the user's staking information.
        if (info.amount > 0) {
            // Claim any rewards before stake the tokens.
            _claimReward(msg.sender, false);
            // Update the staked amount in the user's staking information.
            info.amount = info.amount + _amount;
        } else {
            // If it's the user's first time staking, add them to the list of stakers.
            stakerIndex[msg.sender] = stakers.length;
            stakers.push(msg.sender);
            // Record the staked amount, reward, and start time in the user's staking info.
            stakings[msg.sender] = StakingInfo(_amount, 0, block.timestamp);
        }
    }

    // Withdraw function: Allows a user to withdraw staked ERC-1155 tokens.
    function withdraw(uint256 _amount) external nonReentrant {
        // Access the user's staking information.
        StakingInfo storage info = stakings[msg.sender];
        // Ensure the user has enough staked tokens to withdraw the requested amount.
        require(info.amount >= _amount, "Insufficient staked amount");
        // The requested amount must be greater than 0.
        require(_amount > 0, "Amount must be greater than 0");
        if(!POOL_FINISHED){
            // Claim any rewards before withdrawing the tokens.
            _claimReward(msg.sender, false);
        }
        // Update the staked amount in the user's staking information.
        info.amount = info.amount - _amount;
        // Safely transfer the requested amount of ERC-1155 tokens back to the user.
        erc1155Token.safeTransferFrom(address(this), msg.sender, stakingTokenId, _amount, "");
        // If the user's staked amount reaches 0, remove them from the stakers list.
        if (info.amount == 0) {
            removeStaker(msg.sender);
        }
    }

    // Private function to remove a staker from the stakers list.
    function removeStaker(address _staker) private {
        // Retrieve the index of the staker in the stakers array.
        uint256 index = stakerIndex[_staker];
        // Replace the staker to be removed with the last staker in the array.
        stakers[index] = stakers[stakers.length - 1];
        // Update the index of the staker that was moved.
        stakerIndex[stakers[index]] = index;
        // Remove the last element (now duplicated) from the stakers array.
        stakers.pop();
        // Delete the staking information of the removed staker.
        delete stakings[_staker];
        // Delete the index information of the removed staker.
        delete stakerIndex[_staker];
    }

    // Public function to calculate the reward for a given user.
    function calculateReward(address _user) public view returns (uint256) {
        // Access the staking information of the user.
        StakingInfo storage info = stakings[_user];
        // Check if the staking period has ended or the maximum reward has been distributed.
        // If yes, no more rewards are available.
        if (totalRewardsDistributed >= MAX_REWARD || POOL_FINISHED) {
            return 0;
        }

        // Initialize current block timestamp to 0.
        uint nowBlockTime = 0; 
        if (block.timestamp > poolStartTime + STAKING_PERIOD)
        {
            // If the staking period has ended, set the current block time to the end time of the staking period.
            nowBlockTime = poolStartTime + STAKING_PERIOD; 
        }else{
            // If within the staking period, use the current block timestamp.
            nowBlockTime = block.timestamp; 
        }

        // Calculate the total time the user's tokens have been staked.
        uint256 totalStakingTime = nowBlockTime - info.updateTime;
        // Determine the reward per minute based on the maximum reward and staking period.
        uint256 rewardPerSecond = getRewardPerSec();
        // Calculate the user's reward based on their staked amount and the total staking time.
        uint256 userReward = info.amount * rewardPerSecond * totalStakingTime;
        // Calculate the payable reward, ensuring it does not exceed the maximum reward limit.
        uint256 payableReward = totalRewardsDistributed + userReward > MAX_REWARD ? 
                                MAX_REWARD - totalRewardsDistributed : userReward;
        // Return the calculated payable reward.
        return payableReward;
    }

    function claim() external nonReentrant{
        _claimReward(msg.sender, false);
    }

    function claimAgent(address _user) external onlyRole(FACTORY_ROLE) {
        _claimReward(_user, true);
    }

    // Internal function to handle reward claiming for a user.
    function _claimReward(address _user, bool isAdmin) internal {
        require(!POOL_FINISHED, "Pool has finished.");
        // Calculate the current reward for the user.
        uint256 reward = calculateReward(_user);
        // Ensure there is a reward available to claim.
        require(reward > 0, "No reward available");
        // Access the staking information of the user.
        StakingInfo storage info = stakings[_user];
        // If the claim is made by an admin, calculate the admin fee.
        uint256 adminFee = isAdmin ? (reward * AGENT_FEE_PERCENTAGE) / 100 : 0;

        // Ensure the contract has enough balance to transfer rewards.
        require(rewardsToken.balanceOf(address(this)) >= reward, "Not enough rewards balance");

        // If claimed by an admin, transfer the admin fee to the owner's address if applicable.
        if (isAdmin && adminFee > 0) {
            rewardsToken.transfer(msg.sender, adminFee);
        }

        // Calculate the user's net reward after deducting fees.
        uint256 userReward = reward - adminFee;
        // Transfer the net reward to the user if applicable.
        if (userReward > 0) {
            rewardsToken.transfer(_user, userReward);
        }
        totalRewardsDistributed = totalRewardsDistributed + reward;
        info.updateTime = block.timestamp;
    }

    // Admin functions
    // Administrative function to unstake tokens on behalf of a user.
    function adminUnstakeUser(address _user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // Access the staking information of the specified user.
        StakingInfo storage info = stakings[_user];
        // After the pool is finished, withdrawal is made without paying the reward.
        if(!POOL_FINISHED){
            // Claim any rewards before withdrawing the tokens.
            _claimReward(_user, false);
        }
        // Safely transfer the staked ERC-1155 tokens from this contract back to the user.
        erc1155Token.safeTransferFrom(address(this), _user, stakingTokenId, info.amount, "");
        // Remove the staker from the stakers list.
        removeStaker(_user);
    }

    // Administrative function to unstake all tokens from all users.
    function adminUnstakeAll() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Iterate over all stakers in reverse order to avoid index shifting issues.
        for (uint256 i = stakers.length; i > 0; i--) {
            // Retrieve the address of the current staker.
            address staker = stakers[i - 1];
            // Access the staking information of the current staker.
            uint256 amount = stakings[staker].amount;
            // Check if the staker has a non-zero staked amount.
            if (amount > 0) {
                adminUnstakeUser(staker);
            }
        }
    }

    // Deposit reward tokens into the contract
    function rewardDeposit(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount > 0, "Amount must be greater than zero");
        // Transfer tokens from the user to the contract
        rewardsToken.transferFrom(msg.sender, address(this), amount);
        emit RewardDeposit(msg.sender, amount);
    }

    // Emergency withdraw function from contract
    function rewardEmergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE){
        uint256 balance = rewardsToken.balanceOf(address(this));
        // Transfer tokens from the contract to the user.
        rewardsToken.transfer(msg.sender, balance);
        // Emit the emergency withdrawal event.
        emit EmergencyWithdraw(msg.sender, balance);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    // Function to set the pool start time
    // Only accounts with the admin role can call this function
    function setPoolStartTime(uint256 _poolStartTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        poolStartTime = _poolStartTime;
    }

    // Function to set the pool finished status
    // Only accounts with the admin role can call this function
    function setPoolFinished(bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        POOL_FINISHED = status;
    }

    // Function to get the count of stakers
    // This is a view function that does not modify state
    function getStakersCount() public view returns (uint256) {
        return stakers.length;
    }

    // Function to get the reward per second
    // This is a pure function that does not read from or modify state
    function getRewardPerSec() public view returns (uint256) {
        uint256 max_reward = MAX_REWARD;  // moved from constant to a variable
        uint256 staking_period = STAKING_PERIOD;  // moved from constant to a variable
        
        return (max_reward / staking_period) / MAX_NFT_STAKED;  
    }

    // Function to get the remaining staking time
    // This is a view function that does not modify state
    function getRemainingStakingTime() public view returns (uint256) {
        uint256 endTime = poolStartTime + STAKING_PERIOD; // Calculate the end time of the staking period
        if (block.timestamp >= endTime) { // Check if the current time is past the end time
            return 0; // If yes, return 0 as remaining time
        } else {
            return endTime - block.timestamp; // If no, return the difference between end time and current time
        }
    }
}