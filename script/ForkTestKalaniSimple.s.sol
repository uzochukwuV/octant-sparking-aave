// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {KalaniSimpleYieldOptimizer} from "../src/strategies/spark/KalaniSimple.sol";
import {YieldDonatingTokenizedStrategy} from "@octant-core/strategies/yieldDonating/YieldDonatingTokenizedStrategy.sol";
import {ITokenizedStrategy} from "@octant-core/core/interfaces/ITokenizedStrategy.sol";

/**
 * @title Fork Test - Kalani Simple Strategy
 * @notice Deploy and test Kalani strategy on Tenderly fork
 *
 * USAGE:
 *   export PRIVATE_KEY=0x... && forge script script/ForkTestKalaniSimple.s.sol \
 *     --rpc-url https://virtual.mainnet.eu.rpc.tenderly.co/82c86106-662e-4d7f-a974-c311987358ff \
 *     --broadcast \
 *     -vvv
 */
contract ForkTestKalaniSimple is Script {
    // Token addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Kalani USDC Vaults
    address constant KALANI_FLUID_USDC = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
    address constant KALANI_AAVE_USDC = 0x888239Ffa9a0613F9142C808aA9F7d1948a14f75;
    address constant KALANI_MORPHO_USDC = 0x888239Ffa9a0613F9142C808aA9F7d1948a14f75;

    // Test state
    ITokenizedStrategy vault;
    KalaniSimpleYieldOptimizer strategy;
    address deployer;
    address donationAddress = address(0x999);

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerKey);

        console2.log("\n");
        console2.log("=========================================================");
        console2.log("        KALANI STRATEGY - FORK INTEGRATION TEST         ");
        console2.log("=========================================================\n");

        console2.log("Deployer:", deployer);
        console2.log("USDC Balance:", IERC20(USDC).balanceOf(deployer) / 1e6, "USDC\n");

        vm.startBroadcast(deployerKey);

        // Test each Kalani vault
        testKalaniVault("KALANI FLUID USDC", KALANI_FLUID_USDC);
        testKalaniVault("KALANI AAVE USDC", KALANI_AAVE_USDC);
        testKalaniVault("KALANI MORPHO USDC", KALANI_MORPHO_USDC);

        vm.stopBroadcast();

        console2.log("\n=========================================================");
        console2.log("        TEST SUMMARY                                    ");
        console2.log("=========================================================\n");
    }

    function testKalaniVault(string memory vaultName, address kalaniAddress) internal {
        console2.log("---");
        console2.log("Testing:", vaultName);
        console2.log("Vault Address:", kalaniAddress);

        // Deploy TokenizedStrategy wrapper
        YieldDonatingTokenizedStrategy tokenized = new YieldDonatingTokenizedStrategy();

        // Deploy Kalani strategy
        try new KalaniSimpleYieldOptimizer(
            kalaniAddress,
            USDC,
            "Kalani USDC Strategy",
            deployer,
            deployer,
            deployer,
            donationAddress,
            false,
            address(tokenized)
        ) returns (KalaniSimpleYieldOptimizer newStrategy) {
            strategy = newStrategy;
            vault = ITokenizedStrategy(address(strategy));

            console2.log(" Strategy deployed:", address(strategy));

            // Check max deposit
            uint256 maxDeposit = IERC4626(kalaniAddress).maxDeposit(address(this));
            console2.log("  Max deposit:", maxDeposit / 1e6, "USDC");

            if (maxDeposit < 10 * 1e6) {
                console2.log("  ERROR: Max deposit too low");
                console2.log("");
                return;
            }

            // Phase 1: Deposit
            uint256 depositAmount = 10 * 1e6; // 10 USDC
            console2.log("PHASE 1: Deposit", depositAmount / 1e6, "USDC");

            IERC20(USDC).approve(address(vault), depositAmount);
            uint256 sharesReceived = vault.deposit(depositAmount, deployer);

            console2.log(" Deposit successful");
            console2.log("  Shares received:", sharesReceived);
            console2.log("  Total assets:", vault.totalAssets() / 1e6, "USDC");

            // Phase 2: Report (harvest)
            console2.log("PHASE 2: Report (harvest yield)");
            (uint256 profit, uint256 loss) = vault.report();

            console2.log(" Report successful");
            console2.log("  Profit:", profit / 1e6, "USDC");
            console2.log("  Loss:", loss);
            console2.log("  Total assets:", vault.totalAssets() / 1e6, "USDC");

            // Phase 3: Withdraw
            uint256 withdrawAmount = vault.maxWithdraw(address(deployer));
            console2.log("PHASE 3: Withdraw", withdrawAmount / 1e6, "USDC");

            try vault.withdraw(withdrawAmount, deployer, deployer, 2e6) {
                console2.log(" Withdrawal successful");
                console2.log("  Remaining assets:", vault.totalAssets() / 1e6, "USDC");
            } catch Error(string memory reason) {
                console2.log(" Withdrawal failed:", reason);
            } catch {
                console2.log(" Withdrawal failed (unknown)");
            }

            console2.log("");
        } catch Error(string memory reason) {
            console2.log("ERROR deploying strategy:", reason);
            console2.log("");
        } catch {
            console2.log("ERROR deploying strategy (unknown)");
            console2.log("");
        }
    }
}
