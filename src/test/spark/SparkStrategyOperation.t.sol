// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {SparkStrategySetup as Setup, ERC20, IStrategyInterface, ITokenizedStrategy} from "./SparkStrategySetup.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract SparkStrategyOperationTest is Setup {
    IERC4626 public sparkUSDC;
    IERC4626 public sparkUSDT;
    IERC4626 public sparkETH;

    function setUp() public virtual override {
        super.setUp();
        
        // Initialize Spark vault interfaces
        sparkUSDC = IERC4626(SPARK_USDC);
        sparkUSDT = IERC4626(SPARK_USDT);
        sparkETH = IERC4626(SPARK_ETH);
    }

    function test_setupStrategyOK() public {
        console2.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.management(), management);
        assertEq(ITokenizedStrategy(address(strategy)).dragonRouter(), dragonRouter);
        assertEq(strategy.keeper(), keeper);
    }

    function test_depositToSpark() public {
        uint256 depositAmount = 10_000 * 10 ** decimals; // 10k USDC
        
        // Get initial Spark vault shares
        uint256 initialShares = sparkUSDC.balanceOf(address(strategy));
        
        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, depositAmount);
        
        // Strategy should have deployed funds to Spark
        uint256 sharesAfter = sparkUSDC.balanceOf(address(strategy));
        assertGt(sharesAfter, initialShares, "Strategy should have Spark shares");
        
        // Verify total assets includes deployed amount
        uint256 totalAssets = strategy.totalAssets();
        assertGe(totalAssets, depositAmount, "Total assets should include deposit");
    }

    function test_withdrawFromSpark() public {
        uint256 depositAmount = 10_000 * 10 ** decimals;

        // Deposit
        mintAndDepositIntoStrategy(strategy, user, depositAmount);

        uint256 userShares = strategy.balanceOf(user);
        assertGt(userShares, 0, "User should have shares");

        // Withdraw half
        uint256 withdrawAmount = depositAmount / 2;
        uint256 sharesToRedeem = strategy.convertToShares(withdrawAmount);

        vm.prank(user);
        strategy.approve(address(strategy), sharesToRedeem);

        vm.prank(user);
        strategy.redeem(sharesToRedeem, user, user);

        uint256 userBalance = asset.balanceOf(user);
        assertGe(userBalance, withdrawAmount, "User should receive assets");
    }

    function test_continuousYieldAccrual() public {
        uint256 depositAmount = 100_000 * 10 ** decimals; // 100k USDC
        
        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, depositAmount);
        
        // Get initial assets
        uint256 initialAssets = strategy.totalAssets();
        
        // Fast forward 30 days to simulate yield accrual
        skip(30 days);
        
        // Report to capture yield
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();
        
        // Should have profit from Spark's continuous compounding
        console2.log("Profit after 30 days:", profit);
        console2.log("Loss:", loss);
        
        // Verify profit was minted to dragon router
        uint256 dragonRouterShares = strategy.balanceOf(dragonRouter);
        assertGt(dragonRouterShares, 0, "Dragon router should receive profit shares");
        
        uint256 newTotalAssets = strategy.totalAssets();
        assertGt(newTotalAssets, initialAssets, "Total assets should increase");
    }

    function test_harvestAndReport() public {
        uint256 depositAmount = 50_000 * 10 ** decimals;
        
        // Deposit
        mintAndDepositIntoStrategy(strategy, user, depositAmount);
        
        // Skip time for yield accrual
        skip(7 days);
        
        // Report
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();
        
        assertEq(loss, 0, "Should have no loss");
        
        // Check that profit goes to dragon router
        if (profit > 0) {
            uint256 dragonRouterShares = strategy.balanceOf(dragonRouter);
            assertGt(dragonRouterShares, 0, "Dragon router should have shares");
        }
    }

    function test_tendDeploysIdleFunds() public {
        uint256 depositAmount = 10_000 * 10 ** decimals;
        
        // Deposit
        mintAndDepositIntoStrategy(strategy, user, depositAmount);
        
        // Manually send some idle funds to strategy
        deal(address(asset), address(strategy), 1_000 * 10 ** decimals);
        
        // Check tend trigger
        (bool shouldTend, ) = strategy.tendTrigger();
        
        // Tend should deploy idle funds
        if (shouldTend) {
            vm.prank(keeper);
            strategy.tend();
            
            // Verify idle funds were deployed
            uint256 idleAfter = asset.balanceOf(address(strategy));
            assertLt(idleAfter, 1_000 * 10 ** decimals, "Idle funds should be deployed");
        }
    }

    function test_rebalancing() public {
        // This test would require mocking APY differences
        // For now, we'll test that the rebalance logic exists
        uint256 depositAmount = 100_000 * 10 ** decimals;
        
        mintAndDepositIntoStrategy(strategy, user, depositAmount);
        
        // Get current vault
        (address activeVault, , ) = getStrategyAllocation();
        console2.log("Active vault:", activeVault);
        
        // Fast forward and check if rebalancing triggers
        skip(1 days);
        
        (bool shouldTend, ) = strategy.tendTrigger();
        if (shouldTend) {
            vm.prank(keeper);
            strategy.tend();
        }
    }

    function test_availableDepositLimit() public {
        uint256 limit = strategy.availableDepositLimit(address(0));
        console2.log("Available deposit limit:", limit);
        assertGt(limit, 0, "Should have deposit capacity");
    }

    function test_availableWithdrawLimit() public {
        uint256 depositAmount = 10_000 * 10 ** decimals;
        mintAndDepositIntoStrategy(strategy, user, depositAmount);
        
        uint256 limit = strategy.availableWithdrawLimit(address(0));
        console2.log("Available withdraw limit:", limit);
        assertGt(limit, 0, "Should be able to withdraw");
    }

    function test_getVaultAPYs() public {
        // Test the view function for APY retrieval
        (bool success, bytes memory data) = address(strategy).staticcall(
            abi.encodeWithSignature("getVaultAPYs()")
        );
        require(success, "getVaultAPYs call failed");
        
        (uint256 usdcAPY, uint256 usdtAPY, uint256 ethAPY) = abi.decode(
            data,
            (uint256, uint256, uint256)
        );
        
        console2.log("USDC APY (bps):", usdcAPY);
        console2.log("USDT APY (bps):", usdtAPY);
        console2.log("ETH APY (bps):", ethAPY);
    }

    function test_getAllocation() public {
        uint256 depositAmount = 10_000 * 10 ** decimals;
        mintAndDepositIntoStrategy(strategy, user, depositAmount);
        
        (address activeVault, uint256 deployed, uint256 idle) = getStrategyAllocation();
        
        console2.log("Active vault:", activeVault);
        console2.log("Deployed:", deployed);
        console2.log("Idle:", idle);
        
        assertEq(activeVault, SPARK_USDC, "Should be using USDC vault");
        assertGt(deployed, 0, "Should have deployed funds");
    }

    function test_getSparkVaultState() public {
        uint256 depositAmount = 10_000 * 10 ** decimals;
        mintAndDepositIntoStrategy(strategy, user, depositAmount);
        
        (bool success, bytes memory data) = address(strategy).staticcall(
            abi.encodeWithSignature("getSparkVaultState()")
        );
        require(success, "getSparkVaultState call failed");
        
        (uint256 spTokenBalance, uint256 underlyingValue, uint256 vaultTotalAssets, uint256 vaultLiquidity) = abi.decode(
            data,
            (uint256, uint256, uint256, uint256)
        );
        
        console2.log("spToken balance:", spTokenBalance);
        console2.log("Underlying value:", underlyingValue);
        console2.log("Vault total assets:", vaultTotalAssets);
        console2.log("Vault liquidity:", vaultLiquidity);
        
        assertGt(spTokenBalance, 0, "Should have Spark shares");
        assertGt(underlyingValue, 0, "Should have underlying value");
    }

    // Helper function to get allocation
    function getStrategyAllocation() internal view returns (
        address activeVault,
        uint256 deployed,
        uint256 idle
    ) {
        (bool success, bytes memory data) = address(strategy).staticcall(
            abi.encodeWithSignature("getAllocation()")
        );
        require(success, "getAllocation call failed");
        (activeVault, deployed, idle) = abi.decode(data, (address, uint256, uint256));
    }
}

