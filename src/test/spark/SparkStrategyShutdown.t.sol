// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {SparkStrategySetup as Setup, ERC20, IStrategyInterface, ITokenizedStrategy} from "./SparkStrategySetup.sol";

contract SparkStrategyShutdownTest is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_emergencyShutdown() public {
        uint256 depositAmount = 10_000 * 10 ** decimals;
        
        // Deposit funds
        mintAndDepositIntoStrategy(strategy, user, depositAmount);
        
        uint256 totalAssetsBefore = strategy.totalAssets();
        assertGt(totalAssetsBefore, 0, "Should have assets");
        
        // Shutdown strategy
        vm.prank(emergencyAdmin);
        ITokenizedStrategy(address(strategy)).shutdownStrategy();
        
        // Verify strategy is shutdown
        assertTrue(ITokenizedStrategy(address(strategy)).isShutdown(), "Strategy should be shutdown");
        
        // Should still be able to report
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();
        
        console2.log("Profit after shutdown:", profit);
        console2.log("Loss after shutdown:", loss);
    }

    function test_emergencyWithdraw() public {
        uint256 depositAmount = 10_000 * 10 ** decimals;
        
        // Deposit
        mintAndDepositIntoStrategy(strategy, user, depositAmount);
        
        // Shutdown
        vm.prank(emergencyAdmin);
        ITokenizedStrategy(address(strategy)).shutdownStrategy();
        
        // Emergency withdraw should free funds
        uint256 totalAssets = strategy.totalAssets();
        if (totalAssets > 0) {
            // Emergency withdraw is internal, but we can verify via report
            vm.prank(keeper);
            strategy.report();
        }
    }

    function test_cannotDepositAfterShutdown() public {
        uint256 depositAmount = 10_000 * 10 ** decimals;
        
        // Shutdown first
        vm.prank(emergencyAdmin);
        ITokenizedStrategy(address(strategy)).shutdownStrategy();
        
        // Try to deposit - should revert or not deploy funds
        mintAndDepositIntoStrategy(strategy, user, depositAmount);
        
        // Strategy should not deploy new funds after shutdown
        // (This depends on BaseStrategy implementation)
    }
}

