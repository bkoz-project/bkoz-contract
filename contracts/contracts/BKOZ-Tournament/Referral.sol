// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract ReferralSystem is ContractMetadata{
    address public deployer;

    // Mapping from user address to referrer address
    mapping(address => address) private referrals;

    // Event to log new referrals
    event ReferralSet(address indexed user, address indexed referrer);
    event DefaultReferrerChanged(address indexed oldReferrer, address indexed newReferrer);

    constructor(string memory _contractURI) {
        deployer = msg.sender;
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    // Function to set a referrer for the caller
    function setReferrer(address _referrer) external {
        require(_referrer != address(0), "Referrer cannot be the zero address");
        require(_referrer != msg.sender, "You cannot refer yourself");
        require(referrals[msg.sender] == address(0), "Referrer already set");

        // Set the referrer
        referrals[msg.sender] = _referrer;

        // Emit the referral set event
        emit ReferralSet(msg.sender, _referrer);
    }

    // Function to set a referrer by backend
    function setReferrerBatch(address [] memory users, address [] memory _referrers) external {
        require(users.length == _referrers.length, "Users and referrers array length must match");
        
        for (uint256 i = 0; i < users.length; i++) {
            require(_referrers[i] != address(0), "Referrer cannot be the zero address");
            require(_referrers[i] != msg.sender, "You cannot refer yourself");
            require(referrals[msg.sender] == address(0), "Referrer already set");
            referrals[users[i]] = _referrers[i];
        }
    }

    // Function to get the referrer of a user
    function getReferrer(address user) public view returns (address) {
        address referrer = referrals[user];
        return referrer;
    }
}
