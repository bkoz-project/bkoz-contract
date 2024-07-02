// SPDX-License-Identifier: UNLICENSED
// BKOZ Rebuy Pass V1.1
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract RebuyPass is PermissionsEnumerable, Multicall, ContractMetadata{
    address public deployer;

    struct Pass {
        bool hasRebuyPass;
        uint256 RebuyPassExpiryDate;
    }

    address public admin;
    mapping(address => bool) public supportedTokens;
    mapping(address => mapping(uint256 => uint256)) public passPrices;
    mapping(address => Pass) public passInfo;
    uint256 public constant DURATION = 30 days;

    event PassPriceSet(uint256 indexed passType, address indexed tokenAddress, uint256 price);
    event RebuyPassPurchased(address indexed user, address indexed tokenAddress, uint256 price);
    event RebuyPassRevoked(address indexed user);

    constructor(string memory _contractURI) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        deployer = msg.sender;
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    function setPassPrice(uint256 passType, address tokenAddress, uint256 price) public onlyRole(DEFAULT_ADMIN_ROLE){
        supportedTokens[tokenAddress] = true;
        passPrices[tokenAddress][passType] = price;
        emit PassPriceSet(passType, tokenAddress, price); 
    }

    function withdrawToken(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE){
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(token.transfer(msg.sender, balance), "Transfer failed");
    } 

    // Rebuy Pass
    function getRebuyPassPrice(address tokenAddress) public view returns (uint256) {
        require(supportedTokens[tokenAddress], "Token not supported");
        return passPrices[tokenAddress][1];
    }

    function buyRebuyPass(address _tokenAddress) public {
        require(!hasValidRebuyPass(msg.sender), "Already owns a valid Rebuy Pass");
        require(supportedTokens[_tokenAddress], "Token not supported");
        uint256 price = passPrices[_tokenAddress][1];

        IERC20 token = IERC20(_tokenAddress);
        require(token.transferFrom(msg.sender, address(this), price), "Token Transfer failed");

        _issueRebuyPass(msg.sender);
        emit RebuyPassPurchased(msg.sender, _tokenAddress, price);
    }

    function _issueRebuyPass(address user) internal {
        passInfo[user].hasRebuyPass = true;
        passInfo[user].RebuyPassExpiryDate = block.timestamp + DURATION;
    }

    function hasValidRebuyPass(address user) public view returns (bool) {
        return passInfo[user].hasRebuyPass && block.timestamp <= passInfo[user].RebuyPassExpiryDate;
    }

    function getRemainingRebuyPass(address user) public view returns (uint256) {
        if (passInfo[user].hasRebuyPass && passInfo[user].RebuyPassExpiryDate > block.timestamp) {
            return passInfo[user].RebuyPassExpiryDate - block.timestamp;
        } else {
            return 0;
        }
    }

    function revokeRebuyPass(address user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        passInfo[user].hasRebuyPass = false;
        emit RebuyPassRevoked(user);
    }
}
