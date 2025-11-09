// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {UnifiedYieldStrategyFactory, DeploymentConfig, StrategyType} from "../src/factory/UnifiedYieldStrategyFactory.sol";

/**
 * @title Factory Deployment Demo
 * @notice Demonstrates how to use the UnifiedYieldStrategyFactory to deploy strategies
 *
 * USAGE:
 *   export PRIVATE_KEY=0x... && forge script script/FactoryDeploymentDemo.s.sol \
 *     --rpc-url https://virtual.mainnet.eu.rpc.tenderly.co/[TENDERLY_RPC] \
 *     --broadcast \
 *     -vvv
 */
contract FactoryDeploymentDemo is Script {
    // Token addresses (Ethereum mainnet)
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Factory state
    UnifiedYieldStrategyFactory factory;
    address deployer;
    address donationAddress = address(0x999);

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerKey);

        console2.log("\n");
        console2.log("==================================================");
        console2.log("   UNIFIED YIELD STRATEGY FACTORY - DEMO           ");
        console2.log("==================================================");
        console2.log("");

        console2.log(" Deployer:", deployer);
        console2.log(" Donation Address:", donationAddress);
        console2.log("");

        vm.startBroadcast(deployerKey);

        // Step 1: Deploy the factory
        phase1_DeployFactory();

        // Step 2: Deploy Spark strategy
        phase2_DeploySpark();

        // Step 3: Deploy Aave V3 strategy (simple, no leverage)
        phase3_DeployAaveSimple();

        // Step 4: Deploy Aave V3 strategy with leverage
        phase4_DeployAaveWithLeverage();

        // Step 5: Query deployments
        phase5_QueryDeployments();

        vm.stopBroadcast();

        console2.log("");
        console2.log("==================================================");
        console2.log("   DEPLOYMENT COMPLETE - FACTORY READY            ");
        console2.log("==================================================");
        console2.log("");
    }

    /*//////////////////////////////////////////////////////////////
                        PHASE 1: DEPLOY FACTORY
    //////////////////////////////////////////////////////////////*/

    function phase1_DeployFactory() internal {
        console2.log("...................................................");
        console2.log(" PHASE 1: DEPLOY UNIFIED FACTORY");
        console2.log("...................................................");
        console2.log("");

        factory = new UnifiedYieldStrategyFactory(
            deployer,
            donationAddress,
            deployer,
            deployer
        );

        console2.log(" Factory deployed!");
        console2.log("  Address:", address(factory));
        console2.log("  Version:", factory.FACTORY_VERSION());
        console2.log("  TokenizedStrategy:", factory.tokenizedStrategyAddress());
        console2.log("");
    }

    /*//////////////////////////////////////////////////////////////
                    PHASE 2: DEPLOY SPARK STRATEGY
    //////////////////////////////////////////////////////////////*/

    function phase2_DeploySpark() internal {
        console2.log("...................................................");
        console2.log(" PHASE 2: DEPLOY SPARK USDC OPTIMIZER");
        console2.log("...................................................");
        console2.log("");

        // Create deployment config
        DeploymentConfig memory config = DeploymentConfig({
            strategyType: StrategyType.SPARK_OPTIMIZER,
            asset: USDC,
            name: "Spark USDC Yield Optimizer",
            management: deployer,
            keeper: deployer,
            emergencyAdmin: deployer,
            donationAddress: donationAddress,
            enableBurning: false,
            strategyParams: ""  // Not needed for Spark
        });

        // Deploy via factory
        address sparkStrategy = factory.deployStrategy(config);

        console2.log(" Spark strategy deployed!");
        console2.log("  Address:", sparkStrategy);
        console2.log("  Type: SPARK_OPTIMIZER");
        console2.log("  Asset: USDC");
        console2.log("");

        // Verify registration
        UnifiedYieldStrategyFactory.DeploymentRecord memory record = factory.getDeployment(sparkStrategy);
        console2.log(" Deployment verified:");
        console2.log("  Name:", record.name);
        console2.log("  Deployed at:", record.deploymentTime);
        console2.log("  By:", record.deployer);
        console2.log("");
    }

    /*//////////////////////////////////////////////////////////////
                PHASE 3: DEPLOY AAVE SIMPLE (NO LEVERAGE)
    //////////////////////////////////////////////////////////////*/

    function phase3_DeployAaveSimple() internal {
        console2.log("...................................................");
        console2.log(" PHASE 3: DEPLOY AAVE V3 SIMPLE (1x, NO LEVERAGE)");
        console2.log("...................................................");
        console2.log("");

        // Create deployment config for simple supply (no leverage)
        DeploymentConfig memory config = DeploymentConfig({
            strategyType: StrategyType.AAVE_V3_RECURSIVE,
            asset: USDC,
            name: "Aave USDC Simple Supply",
            management: deployer,
            keeper: deployer,
            emergencyAdmin: deployer,
            donationAddress: donationAddress,
            enableBurning: false,
            strategyParams: ""  // Default: 1x leverage
        });

        // Deploy via factory
        address aaveSimple = factory.deployStrategy(config);

        console2.log(" Aave simple strategy deployed!");
        console2.log("  Address:", aaveSimple);
        console2.log("  Type: AAVE_V3_RECURSIVE");
        console2.log("  Leverage: 1x (simple supply)");
        console2.log("  Asset: USDC");
        console2.log("");
    }

    /*//////////////////////////////////////////////////////////////
            PHASE 4: DEPLOY AAVE WITH LEVERAGE (2x LEVERAGE)
    //////////////////////////////////////////////////////////////*/

    function phase4_DeployAaveWithLeverage() internal {
        console2.log("...................................................");
        console2.log(" PHASE 4: DEPLOY AAVE V3 WITH 2x LEVERAGE");
        console2.log("...................................................");
        console2.log("");

        // Create deployment config with 2x leverage
        // Encode: (aTokenAddress=0, leverage=2e18)
        bytes memory params = abi.encode(uint256(2e18));

        DeploymentConfig memory config = DeploymentConfig({
            strategyType: StrategyType.AAVE_V3_RECURSIVE,
            asset: USDC,
            name: "Aave USDC 2x Leverage",
            management: deployer,
            keeper: deployer,
            emergencyAdmin: deployer,
            donationAddress: donationAddress,
            enableBurning: false,
            strategyParams: params
        });

        // Deploy via factory
        address aaveLeverage = factory.deployStrategy(config);

        console2.log(" Aave 2x leverage strategy deployed!");
        console2.log("  Address:", aaveLeverage);
        console2.log("  Type: AAVE_V3_RECURSIVE");
        console2.log("  Leverage: 2x (recursive lending enabled)");
        console2.log("  Asset: USDC");
        console2.log("");
    }

    /*//////////////////////////////////////////////////////////////
                    PHASE 5: QUERY DEPLOYMENTS
    //////////////////////////////////////////////////////////////*/

    function phase5_QueryDeployments() internal {
        console2.log("...................................................");
        console2.log(" PHASE 5: QUERY FACTORY DEPLOYMENTS");
        console2.log("...................................................");
        console2.log("");

        // Get total deployments
        uint256 totalCount = factory.getTotalDeployments();
        console2.log(" Total strategies deployed:", totalCount);
        console2.log("");

        // Get recent deployments
        UnifiedYieldStrategyFactory.DeploymentRecord[] memory recent = factory.getRecentDeployments(10);
        console2.log(" Recent deployments:");

        for (uint256 i = 0; i < recent.length; i++) {
            console2.log("");
            console2.log("  Strategy", i + 1);
            console2.log("    Address:", recent[i].strategyAddress);
            console2.log("    Name:", recent[i].name);
            console2.log("    Asset:", recent[i].asset);
            console2.log("    Deployed by:", recent[i].deployer);
            console2.log("    Time:", recent[i].deploymentTime);
        }

        console2.log("");
    }
}
