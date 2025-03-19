// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract VestingContract {
    struct Vesting {
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool isClaimed;
    }

    IERC20 public immutable token;
    mapping(address => Vesting) public vestings;

    event TokensVested(address indexed beneficiary, uint256 amount, uint256 startTime, uint256 endTime);
    event TokensClaimed(address indexed beneficiary, uint256 amount);

    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token address");
        token = IERC20(_tokenAddress);  // Use the token address provided during deployment
    }

    function addVesting(
        address _beneficiary,
        uint256 _amount,
        uint256 _startTime,
        uint256 _endTime
    ) external {
        require(_startTime < _endTime, "Start time must be before end time");
        require(_amount > 0, "Amount must be greater than zero");
        require(token.balanceOf(address(this)) >= _amount, "Insufficient tokens in contract");

        Vesting storage existingVesting = vestings[_beneficiary];
        require(
            existingVesting.amount == 0 || existingVesting.isClaimed,
            "Active vesting already exists for this beneficiary"
        );

        vestings[_beneficiary] = Vesting({
            amount: _amount,
            startTime: _startTime,
            endTime: _endTime,
            isClaimed: false
        });

        emit TokensVested(_beneficiary, _amount, _startTime, _endTime);
    }

    function claimTokens() external {
        Vesting storage vesting = vestings[msg.sender];

        require(block.timestamp >= vesting.endTime, "Vesting period not yet completed");
        require(!vesting.isClaimed, "Tokens already claimed");

        uint256 amount = vesting.amount;
        vesting.isClaimed = true;

        emit TokensClaimed(msg.sender, amount);

        require(token.transfer(msg.sender, amount), "Token transfer failed");
    }

    function getVesting(address _beneficiary) external view returns (Vesting memory) {
        return vestings[_beneficiary];
    }
}
