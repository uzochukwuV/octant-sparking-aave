// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {SparkMultiAssetYieldOptimizer} from "../src/strategies/spark/SParkOctatnt.sol";
import {YieldDonatingTokenizedStrategy} from "@octant-core/strategies/yieldDonating/YieldDonatingTokenizedStrategy.sol";

/**
 * @title Deploy Spark Multi-Asset Yield Optimizer
 * @notice Deployment script for Spark strategy on Ethereum Mainnet
 * @dev Deploys the strategy with proper configuration for Octant v2
 */
contract DeploySparkStrategy is Script {
    // Ethereum Mainnet Addresses
    address constant SPARK_USDC = 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d;
    address constant SPARK_USDT = 0xe2e7a17dFf93280dec073C995595155283e3C372;
    address constant SPARK_ETH = 0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f;
    
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying Spark Multi-Asset Yield Optimizer...");
        console2.log("Deployer:", deployer);
        
        // Read configuration from environment
        address management = vm.envAddress("MANAGEMENT_ADDRESS");
        address keeper = vm.envAddress("KEEPER_ADDRESS");
        address emergencyAdmin = vm.envAddress("EMERGENCY_ADMIN_ADDRESS");
        address donationAddress = vm.envAddress("DONATION_ADDRESS");
        address tokenizedStrategyAddress = vm.envAddress("TOKENIZED_STRATEGY_ADDRESS");
        
        // Default to USDC if not specified
        address primaryAsset = vm.envOr("PRIMARY_ASSET", USDC);
        string memory name = vm.envOr("STRATEGY_NAME", string("Spark Multi-Asset USDC Optimizer"));
        bool enableBurning = vm.envOr("ENABLE_BURNING", false);
        
        console2.log("Configuration:");
        console2.log("  Management:", management);
        console2.log("  Keeper:", keeper);
        console2.log("  Emergency Admin:", emergencyAdmin);
        console2.log("  Donation Address:", donationAddress);
        console2.log("  Primary Asset:", primaryAsset);
        console2.log("  Enable Burning:", enableBurning);
        
        // If tokenized strategy address not provided, deploy it
        if (tokenizedStrategyAddress == address(0)) {
            console2.log("Deploying YieldDonatingTokenizedStrategy...");
            vm.startBroadcast(deployerPrivateKey);
            YieldDonatingTokenizedStrategy tokenizedStrategy = new YieldDonatingTokenizedStrategy();
            tokenizedStrategyAddress = address(tokenizedStrategy);
            vm.stopBroadcast();
            console2.log("TokenizedStrategy deployed at:", tokenizedStrategyAddress);
        }
        
        // Deploy Spark strategy
        vm.startBroadcast(deployerPrivateKey);
        
        SparkMultiAssetYieldOptimizer strategy = new SparkMultiAssetYieldOptimizer(
            SPARK_USDC,
            SPARK_USDT,
            SPARK_ETH,
            USDC,
            USDT,
            WETH,
            primaryAsset,
            name,
            management,
            keeper,
            emergencyAdmin,
            donationAddress,
            enableBurning,
            tokenizedStrategyAddress
        );
        
        vm.stopBroadcast();
        
        console2.log("==========================================");
        console2.log("Spark Strategy Deployed Successfully!");
        console2.log("==========================================");
        console2.log("Strategy Address:", address(strategy));
        console2.log("Primary Asset:", primaryAsset);
        console2.log("TokenizedStrategy:", tokenizedStrategyAddress);
        console2.log("Spark USDC Vault:", SPARK_USDC);
        console2.log("Spark USDT Vault:", SPARK_USDT);
        console2.log("Spark ETH Vault:", SPARK_ETH);
        console2.log("==========================================");
        
        // Verify deployment
        require(address(strategy) != address(0), "Strategy deployment failed");
        console2.log("Deployment verified successfully!");
    }
}

