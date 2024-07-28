// SPDX-License-Identifier: MIT
// Kozmo Games
// ERC 1155 Node v1.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/base/ERC1155Drop.sol";
import "@thirdweb-dev/contracts/external-deps/openzeppelin/utils/ERC1155/ERC1155Holder.sol";
import "@thirdweb-dev/contracts/base/ERC20Base.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

contract ERC1155Node is ReentrancyGuard, PermissionsEnumerable, ERC1155Holder, ContractMetadata, Multicall{
    address public deployer;
    // ERC1155 token interface, representing the nodes.
    ERC1155Drop public immutable erc1155Token;
    // ERC20 token interface, representing the rewards token.
    ERC20Base public immutable rewardsToken;
    // The specific ID of the ERC1155 token that is eligible for nodes.
    uint256 public nodeTokenId;
    // Percentage of the reward allocated as a fee to agents (if applicable).
    uint256 public AGENT_FEE_PERCENTAGE = 1;
    // Struct to store information about each node instance.
    struct NodeInfo {
        uint256 amount;     // Amount of tokens used by the user for nodes.
        uint256 reward;     // Reward accumulated by the user.
        uint256 updateTime;  // Timestamp when the user started nodes.
    }
    // Mapping from user addresses to their node information.
    mapping(address => NodeInfo) public nodes;
    // Array of addresses that are currently using nodes.
    address[] public nodeUsers;
    // Mapping from user addresses to their index in the nodeUsers array.
    mapping(address => uint256) private nodeUserIndex;
    // Maximum number of NFTs that can be used in the contract.
    uint256 public MAX_NFT_USED;
    // Maximum reward that can be distributed by the contract.
    uint256 public MAX_REWARD;
    // Duration for which the nodes are active.
    uint256 public constant NODE_PERIOD = 1250 days;
    // Timestamp when the reward pool starts.
    uint256 public poolStartTime;
    // Total amount of rewards that have been distributed so far.
    uint256 public totalRewardsDistributed;
    // Node pool STATUS
    bool public POOL_FINISHED;

    bytes32 private constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    // Event to log deposits
    event RewardDeposit(address indexed user, uint256 amount);
    // Event to log emergency withdrawals
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(address _erc1155Token, uint256 _nodeTokenId, uint256 _nftCount, uint256 _totalReward, uint256 _poolStartTime, uint256 _boforeRewardsDistributed, address _erc20Token, string memory _contractURI) {
        erc1155Token = ERC1155Drop(_erc1155Token);
        nodeTokenId = _nodeTokenId;
        poolStartTime = _poolStartTime;
        totalRewardsDistributed = _boforeRewardsDistributed;
        rewardsToken = ERC20Base(_erc20Token);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, 0x4867D726B9058AcEdbE2080bf2DFAA6782059E43);
        MAX_NFT_USED = _nftCount;
        MAX_REWARD = _totalReward;
        deployer = msg.sender;
        POOL_FINISHED = false;
        _setupContractURI(_contractURI);
    }

    // Node function: Allows a user to use ERC-1155 tokens as nodes.
    function activateNode(uint256 _amount) external nonReentrant {
        // Check pool status.
        require(!POOL_FINISHED, "Pool has finished.");
        // Check if the user has enough ERC-1155 tokens to use.
        require(erc1155Token.balanceOf(msg.sender, nodeTokenId) >= _amount, "Not enough ERC1155 tokens");
        // Access the user's node information.
        NodeInfo storage info = nodes[msg.sender];
        
        // Prepare data for burnBatch
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = nodeTokenId;
        amounts[0] = _amount;

        // Safely burn ERC-1155 tokens from the user.
        erc1155Token.burnBatch(msg.sender, ids, amounts);

        // Update the user's node information.
        if (info.amount > 0) {
            // Claim any rewards before using the tokens.
            _claimReward(msg.sender, false);
            // Update the used amount in the user's node information.
            info.amount = info.amount + _amount;
        } else {
            // If it's the user's first time using nodes, add them to the list of node users.
            nodeUserIndex[msg.sender] = nodeUsers.length;
            nodeUsers.push(msg.sender);
            // Record the used amount, reward, and start time in the user's node info.
            nodes[msg.sender] = NodeInfo(_amount, 0, block.timestamp);
        }
    }

    // Private function to remove a node user from the nodeUsers list.
    function removeNodeUser(address _nodeUser) private {
        // Retrieve the index of the node user in the nodeUsers array.
        uint256 index = nodeUserIndex[_nodeUser];
        // Replace the node user to be removed with the last node user in the array.
        nodeUsers[index] = nodeUsers[nodeUsers.length - 1];
        // Update the index of the node user that was moved.
        nodeUserIndex[nodeUsers[index]] = index;
        // Remove the last element (now duplicated) from the nodeUsers array.
        nodeUsers.pop();
        // Delete the node information of the removed node user.
        delete nodes[_nodeUser];
        // Delete the index information of the removed node user.
        delete nodeUserIndex[_nodeUser];
    }

    // Public function to calculate the reward for a given user.
    function calculateReward(address _user) public view returns (uint256) {
        // Access the node information of the user.
        NodeInfo storage info = nodes[_user];
        // Check if the node period has ended or the maximum reward has been distributed.
        // If yes, no more rewards are available.
        if (totalRewardsDistributed >= MAX_REWARD || POOL_FINISHED) {
            return 0;
        }

        // Initialize current block timestamp to 0.
        uint nowBlockTime = 0; 
        if (block.timestamp > poolStartTime + NODE_PERIOD)
        {
            // If the node period has ended, set the current block time to the end time of the node period.
            nowBlockTime = poolStartTime + NODE_PERIOD; 
        }else{
            // If within the node period, use the current block timestamp.
            nowBlockTime = block.timestamp; 
        }

        // Calculate the total time the user's tokens have been used.
        uint256 totalNodeTime = nowBlockTime - info.updateTime;
        // Determine the reward per second based on the maximum reward and node period.
        uint256 rewardPerSecond = getRewardPerSec();
        // Calculate the user's reward based on their used amount and the total node time.
        uint256 userReward = info.amount * rewardPerSecond * totalNodeTime;
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
        // Access the node information of the user.
        NodeInfo storage info = nodes[_user];
        // If the claim is made by an admin, calculate the admin fee.
        uint256 adminFee = isAdmin ? (reward * AGENT_FEE_PERCENTAGE) / 100 : 0;

        // If claimed by an admin, mintTo the admin fee to the owner's address if applicable.
        if (isAdmin && adminFee > 0) {
            rewardsToken.mintTo(msg.sender, adminFee);
        }

        // Calculate the user's net reward after deducting fees.
        uint256 userReward = reward - adminFee;
        // mintTo the net reward to the user if applicable.
        if (userReward > 0) {
            rewardsToken.mintTo(_user, userReward);
        }
        totalRewardsDistributed = totalRewardsDistributed + reward;
        info.updateTime = block.timestamp;
    }

    // Admin functions

    // Remove nodes - Removes all nodes of a specific user.
    function adminRemoveNode(address _user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Access the user's node information.
        NodeInfo storage info = nodes[_user];
        // Ensure the user has nodes.
        require(info.amount > 0, "User has no nodes");
        // Claim rewards before removing nodes.
        _claimReward(_user, false);
        // Remove the user's node information.
        removeNodeUser(_user);
    }

    // Add nodes - Adds nodes to a new user.
    function adminAddNode(address _user, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Ensure the amount is greater than 0.
        require(_amount > 0, "Amount must be greater than 0");
        // Access the user's node information.
        NodeInfo storage info = nodes[_user];
        
        // If the user already has nodes
        if (info.amount > 0) {
            // Claim rewards before adding nodes.
            _claimReward(_user, false);
            // Update the user's node amount.
            info.amount += _amount;
        } else {
            // If it's the user's first time adding nodes
            // Add the user to the node user list.
            nodeUserIndex[_user] = nodeUsers.length;
            nodeUsers.push(_user);
            // Record the user's node information.
            nodes[_user] = NodeInfo(_amount, 0, block.timestamp);
        }
    }

    // Modify nodes - Modifies the node quantity of a specific user.
    function adminModifyNode(address _user, uint256 _newAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Ensure the new amount is greater than 0.
        require(_newAmount > 0, "New amount must be greater than 0");
        // Access the user's node information.
        NodeInfo storage info = nodes[_user];
        // Ensure the user has nodes.
        require(info.amount > 0, "User has no nodes");
        // Claim rewards before modifying nodes.
        _claimReward(_user, false);
        // Update the user's node amount to the new quantity.
        info.amount = _newAmount;
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

    // Function to get the count of node users
    // This is a view function that does not modify state
    function getNodeUsersCount() public view returns (uint256) {
        return nodeUsers.length;
    }

    // Function to get the reward per second
    // This is a pure function that does not read from or modify state
    function getRewardPerSec() public view returns (uint256) {
        uint256 max_reward = MAX_REWARD;  // moved from constant to a variable
        uint256 node_period = NODE_PERIOD;  // moved from constant to a variable
        
        return (max_reward / node_period) / MAX_NFT_USED;  
    }

    // Function to get the remaining node time
    // This is a view function that does not modify state
    function getRemainingNodeTime() public view returns (uint256) {
        uint256 endTime = poolStartTime + NODE_PERIOD; // Calculate the end time of the node period
        if (block.timestamp >= endTime) { // Check if the current time is past the end time
            return 0; // If yes, return 0 as remaining time
        } else {
            return endTime - block.timestamp; // If no, return the difference between end time and current time
        }
    }
}
