// SPDX-License-Identifier: MIT
// BKOZ Tier Pass V1.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

// Pass Info 
// 1 = Gold / 2 = Diamond
contract TierPass is PermissionsEnumerable, Multicall, ContractMetadata{
    address public deployer;

    struct Pass {
        bool hasDiamond;
        bool hasGold;
        uint256 DiamondExpiryDate;
        uint256 GoldExpiryDate;
    }

    address public admin;
    mapping(address => bool) public supportedTokens; // 지원하는 토큰 목록
    mapping(address => mapping(uint256 => uint256)) public passPrices; // 토큰 주소 -> (패스 타입 -> 가격)
    mapping(address => Pass) public passInfo;
    uint256 public constant DURATION = 30 days;

    // 이벤트 선언
    event PassPriceSet(uint256 indexed passType, address indexed tokenAddress, uint256 price);
    event PassPurchased(address indexed user, uint256 passId, address indexed tokenAddress, uint256 price);
    event PassRevoked(address indexed user, uint256 passId);

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

    // Diamond Pass
    function getDiamondPassPrice(address tokenAddress) public view returns (uint256) {
        require(supportedTokens[tokenAddress], "Token not supported");
        return passPrices[tokenAddress][2];
    }

    function buyDiamondPass(address _tokenAddress) public {
        require(!hasValidDiamondPass(msg.sender), "Already owns a valid Diamond pass");
        require(supportedTokens[_tokenAddress], "Token not supported");
        uint256 price = passPrices[_tokenAddress][2];

        IERC20 token = IERC20(_tokenAddress);
        require(token.transferFrom(msg.sender, address(this), price), "Token Transfer failed");

        _issueDiamondPass(msg.sender);
        emit PassPurchased(msg.sender, 2, _tokenAddress, price); 
    }

    function _issueDiamondPass(address user) internal {
        passInfo[user].hasDiamond = true;
        passInfo[user].DiamondExpiryDate = block.timestamp + DURATION;
    }

    function hasValidDiamondPass(address user) public view returns (bool) {
        return passInfo[user].hasDiamond && block.timestamp <= passInfo[user].DiamondExpiryDate;
    }

    function getRemainingDiamondPass(address user) public view returns (uint256) {
        if (passInfo[user].hasDiamond && passInfo[user].DiamondExpiryDate > block.timestamp) {
            return passInfo[user].DiamondExpiryDate - block.timestamp;
        } else {
            return 0;
        }
    }

    // Gold Pass
    function getGoldPassPrice(address tokenAddress) public view returns (uint256) {
        require(supportedTokens[tokenAddress], "Token not supported");
        return passPrices[tokenAddress][1];
    }

    function buyGoldPass(address _tokenAddress) public {
        require(!hasValidGoldPass(msg.sender), "Already owns a valid Gold pass");
        require(supportedTokens[_tokenAddress], "Token not supported");
        uint256 price = passPrices[_tokenAddress][1];

        IERC20 token = IERC20(_tokenAddress);
        require(token.transferFrom(msg.sender, address(this), price), "Token Transfer failed");

        _issueGoldPass(msg.sender);
        emit PassPurchased(msg.sender, 1, _tokenAddress, price); 
    }

    function _issueGoldPass(address user) internal {
        passInfo[user].hasGold = true;
        passInfo[user].GoldExpiryDate = block.timestamp + DURATION;
    }

    function hasValidGoldPass(address user) public view returns (bool) {
        return passInfo[user].hasGold && block.timestamp <= passInfo[user].GoldExpiryDate;
    }

    function getRemainingGoldPass(address user) public view returns (uint256) {
        if (passInfo[user].hasGold && passInfo[user].GoldExpiryDate > block.timestamp) {
            return passInfo[user].GoldExpiryDate - block.timestamp;
        } else {
            return 0;
        }
    }

    function checkBothPasses(address user) public view returns (bool[] memory) {
        bool[] memory passesStatus = new bool[](2);
        passesStatus[0] = hasValidDiamondPass(user);
        passesStatus[1] = hasValidGoldPass(user);
        return passesStatus;
    }

    function revokeDiamondPass(address user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        passInfo[user].hasDiamond = false;
        emit PassRevoked(user, 2); 
    }

    function revokeGoldPass(address user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        passInfo[user].hasGold = false;
        emit PassRevoked(user, 1); 
    }
}
