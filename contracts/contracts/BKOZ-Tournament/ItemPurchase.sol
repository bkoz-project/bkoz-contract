// SPDX-License-Identifier: MIT
// BKOZ inApp item sale V1.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InAppItemPurchase {
    address public admin;
    address public developer;
    uint256 public adminSharePercentage; // in percentage (e.g., 50 for 50%)
    
    struct Item {
        uint256 itemId;
        mapping(address => uint256) prices; // tokenAddress => price
        bool exists;
    }
    
    mapping(uint256 => Item) public items;
    uint256 public itemCount;
    
    event ItemSet(uint256 indexed itemId, address indexed tokenAddress, uint256 price);
    event ItemPurchased(address indexed buyer, uint256 indexed itemId, address indexed tokenAddress, uint256 amountSentToAdmin, uint256 amountSentToDeveloper);
    event AdminSharePercentageChanged(uint256 newAdminSharePercentage);
    event ItemPriceChanged(uint256 indexed itemId, address indexed tokenAddress, uint256 newPrice);
    event ItemRemoved(uint256 indexed itemId);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }
    
    constructor(address _admin, address _developer, uint256 _adminSharePercentage) {
        admin = _admin;
        developer = _developer;
        adminSharePercentage = _adminSharePercentage;
        itemCount = 0;
    }
    
    function setItem(uint256 _itemId, address[] memory _tokenAddresses, uint256[] memory _prices) external onlyAdmin {
        require(_tokenAddresses.length == _prices.length, "Token address and price arrays must have the same length");
        
        Item storage newItem = items[_itemId];
        newItem.itemId = _itemId;
        newItem.exists = true;
        
        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            newItem.prices[_tokenAddresses[i]] = _prices[i];
            emit ItemSet(_itemId, _tokenAddresses[i], _prices[i]);
        }
        
        itemCount++;
    }
    
    function getItemPrice(uint256 _itemId, address _tokenAddress) external view returns (uint256) {
        require(items[_itemId].exists, "Item does not exist");
        return items[_itemId].prices[_tokenAddress];
    }
    
    function changeItemPrice(uint256 _itemId, address _tokenAddress, uint256 _newPrice) external onlyAdmin {
        require(items[_itemId].exists, "Item does not exist");
        items[_itemId].prices[_tokenAddress] = _newPrice;
        emit ItemPriceChanged(_itemId, _tokenAddress, _newPrice);
    }
    
    function removeItem(uint256 _itemId) external onlyAdmin {
        require(items[_itemId].exists, "Item does not exist");
        delete items[_itemId];
        itemCount--;
        emit ItemRemoved(_itemId);
    }
    
    function purchaseItem(uint256 _itemId, address _tokenAddress) external {
        require(items[_itemId].exists, "Item does not exist");
        require(items[_itemId].prices[_tokenAddress] > 0, "Invalid token address");
        
        uint256 itemPrice = items[_itemId].prices[_tokenAddress];
        uint256 adminAmount = itemPrice * adminSharePercentage / 100;
        uint256 developerAmount = itemPrice - adminAmount;
        
        // Transfer tokens to admin and developer
        IERC20(_tokenAddress).transferFrom(msg.sender, admin, adminAmount);
        IERC20(_tokenAddress).transferFrom(msg.sender, developer, developerAmount);
        
        emit ItemPurchased(msg.sender, _itemId, _tokenAddress, adminAmount, developerAmount);
    }
    
    function changeAdminSharePercentage(uint256 _newAdminSharePercentage) external onlyAdmin {
        require(_newAdminSharePercentage >= 0 && _newAdminSharePercentage <= 100, "Invalid percentage");
        adminSharePercentage = _newAdminSharePercentage;
        emit AdminSharePercentageChanged(_newAdminSharePercentage);
    }
}
