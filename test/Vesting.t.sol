// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {VestingContract} from "src/Vesting.sol";  // Make sure this path is correct

contract MockERC20 is Test, IERC20 {
    string public name = "Mock Token";
    string public symbol = "MTK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        return true;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return balances[account];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowances[msg.sender][spender] = amount;
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return allowances[owner][spender];
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        require(balances[sender] >= amount, "Insufficient balance");
        require(allowances[sender][msg.sender] >= amount, "Allowance exceeded");
        balances[sender] -= amount;
        allowances[sender][msg.sender] -= amount;
        balances[recipient] += amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balances[to] += amount;
        totalSupply += amount;
    }
}

contract VestingContractTest is Test {
    VestingContract public vestingContract;
    MockERC20 public token;
    address public beneficiary = address(0x123);

    function setUp() public {
        token = new MockERC20();
        token.mint(address(this), 1000 ether);

        vestingContract = new VestingContract(address(token));  // Deploy with token address
        token.transfer(address(vestingContract), 1000 ether);    // Transfer tokens to the vesting contract
    }

    function testAddVesting() public {
        vestingContract.addVesting(beneficiary, 100 ether, block.timestamp, block.timestamp + 1 days);
        
        VestingContract.Vesting memory vesting = vestingContract.getVesting(beneficiary);

        assertEq(vesting.amount, 100 ether);
        assertEq(vesting.startTime, block.timestamp);
        assertEq(vesting.endTime, block.timestamp + 1 days);
        assertEq(vesting.isClaimed, false);
    }

    function testClaimTokens() public {
        vestingContract.addVesting(beneficiary, 100 ether, block.timestamp, block.timestamp + 1 days);
        vm.warp(block.timestamp + 1 days);

        vm.prank(beneficiary);
        vestingContract.claimTokens();

        assertEq(token.balanceOf(beneficiary), 100 ether);
    }

    function test_RevertWhen_ClaimBeforeEndTime() public {
        vestingContract.addVesting(beneficiary, 100 ether, block.timestamp, block.timestamp + 1 days);

        vm.prank(beneficiary);
        vm.expectRevert("Vesting period not yet completed");
        vestingContract.claimTokens();
    }

    function test_RevertWhen_DoubleClaim() public {
        vestingContract.addVesting(beneficiary, 100 ether, block.timestamp, block.timestamp + 1 days);
        vm.warp(block.timestamp + 1 days);

        vm.prank(beneficiary);
        vestingContract.claimTokens();

        vm.prank(beneficiary);
        vm.expectRevert("Tokens already claimed");
        vestingContract.claimTokens();
    }

    function test_RevertWhen_InsufficientTokensInContract() public {
        vm.expectRevert("Insufficient tokens in contract");
        vestingContract.addVesting(beneficiary, 2000 ether, block.timestamp, block.timestamp + 1 days);
    }
}
