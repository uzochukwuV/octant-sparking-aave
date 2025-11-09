// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title Individual Vault Test
 * @notice Test each Kalani vault individually to identify which ones work
 *
 * USAGE:
 *   forge script script/VaultIndividualTest.s.sol \
 *     --rpc-url https://virtual.mainnet.eu.rpc.tenderly.co/82c86106-662e-4d7f-a974-c311987358ff \
 *     --broadcast \
 *     -vvv
 */
contract VaultIndividualTest is Script {
    // Vault addresses
    address constant SPARK_USDC = 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d;
    address constant KALANI_FLUID_USDC = 0xBe53A109B494E5c9f97b9Cd39Fe969BE68BF6204; // updated usdcy
    address constant KALANI_AAVE_USDC = 0xF7DE3c70F2db39a188A81052d2f3C8e3e217822a; // super usdc
    address constant KALANI_MORPHO_USDC = 0x888239Ffa9a0613F9142C808aA9F7d1948a14f75;

    // Token address
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Test amount
    uint256 constant TEST_AMOUNT = 10 * 1e6; // 10 USDC

    address deployer;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerKey);

        console2.log("\n=================================================");
        console2.log("        INDIVIDUAL VAULT TESTING                 ");
        console2.log("=================================================\n");

        console2.log("Deployer:", deployer);
        console2.log("USDC Balance:", IERC20(USDC).balanceOf(deployer) / 1e6, "USDC\n");

        vm.startBroadcast(deployerKey);

        // Test each vault
        testVault("SPARK USDC", SPARK_USDC);
        testVault("KALANI FLUID USDC", KALANI_FLUID_USDC);
        testVault("KALANI AAVE USDC", KALANI_AAVE_USDC);
        testVault("KALANI MORPHO USDC", KALANI_MORPHO_USDC);

        vm.stopBroadcast();

        console2.log("\n=================================================");
        console2.log("        TEST SUMMARY                             ");
        console2.log("=================================================\n");
    }

    function testVault(string memory vaultName, address vaultAddress) internal {
        console2.log("---");
        console2.log("Testing:", vaultName);
        console2.log("Vault Address:", vaultAddress);

        IERC4626 vault = IERC4626(vaultAddress);

        // Check max deposit
        uint256 maxDeposit = vault.maxDeposit(address(this));
        console2.log("Max Deposit:", maxDeposit / 1e6, "USDC");

        if (maxDeposit < TEST_AMOUNT) {
            console2.log("ERROR: Max deposit too low, skipping");
            console2.log("");
            return;
        }

        // Step 1: Approve
        console2.log("Step 1: Approving", TEST_AMOUNT / 1e6, "USDC");
        IERC20(USDC).approve(vaultAddress, TEST_AMOUNT);

        // Step 2: Deposit and get shares
        console2.log("Step 2: Depositing");
        uint256 sharesBefore = vault.balanceOf(address(this));
        console2.log("Shares before:", sharesBefore);

        try vault.deposit(TEST_AMOUNT, address(this)) returns (uint256 sharesReceived) {
            console2.log("SUCCESS - Deposit succeeded");
            console2.log("Shares received:", sharesReceived);

            uint256 sharesAfter = vault.balanceOf(address(this));
            console2.log("Shares after:", sharesAfter);
            console2.log("Shares diff:", sharesAfter - sharesBefore);

            // Step 3: Convert to assets
            console2.log("Step 3: Convert shares to assets");
            uint256 assets = vault.convertToAssets(sharesReceived);
            console2.log("Assets from shares:", assets / 1e6, "USDC");

            // Step 4a: Try withdraw (asset-based)
            console2.log("Step 4a: Attempting withdraw (asset-based)");
            uint256 usdcBefore = IERC20(USDC).balanceOf(address(this));

            try vault.withdraw(TEST_AMOUNT, address(this), address(this)) returns (uint256 sharesRedeemed) {
                uint256 usdcAfter = IERC20(USDC).balanceOf(address(this));
                uint256 usdcReceived = usdcAfter - usdcBefore;

                console2.log("SUCCESS - Withdrawal (asset) succeeded");
                console2.log("Shares redeemed:", sharesRedeemed);
                console2.log("USDC received:", usdcReceived / 1e6, "USDC");
                console2.log("Vault WORKS - ALL OPERATIONS SUCCESSFUL");
            } catch Error(string memory reason) {
                console2.log("ERROR in withdraw (asset):", reason);
                console2.log("Step 4b: Attempting redeem (shares-based)");

                // Step 4b: Try redeem (shares-based) as fallback
                uint256 usdcBefore2 = IERC20(USDC).balanceOf(address(this));
                try vault.redeem(sharesReceived, address(this), address(this)) returns (uint256 assetsRedeemed) {
                    uint256 usdcAfter2 = IERC20(USDC).balanceOf(address(this));
                    uint256 usdcReceived2 = usdcAfter2 - usdcBefore2;

                    console2.log("SUCCESS - Redeem (shares) succeeded");
                    console2.log("Assets redeemed:", assetsRedeemed / 1e6, "USDC");
                    console2.log("USDC received:", usdcReceived2 / 1e6, "USDC");
                    console2.log("Vault WORKS - Requires redeem() instead of withdraw()");
                } catch Error(string memory reason2) {
                    console2.log("ERROR in redeem:", reason2);
                } catch {
                    console2.log("ERROR: Redeem also failed");
                }
            } catch {
                console2.log("ERROR: Withdraw failed (unknown reason)");
            }
        } catch Error(string memory reason) {
            console2.log("ERROR in deposit:", reason);
        } catch {
            console2.log("ERROR: Deposit failed (unknown reason)");
        }

        console2.log("");
    }
}
