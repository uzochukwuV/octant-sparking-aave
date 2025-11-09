# Unified Yield Strategy Factory - Complete Usage Guide

## Overview

The **UnifiedYieldStrategyFactory** is a single entry point for deploying any yield optimization strategy across multiple protocols (Spark, Aave V3, etc.). It eliminates the need to deploy strategies individually and provides centralized discovery, configuration, and governance.

## Why Use the Factory?

### Without Factory (Old Way)
```solidity
// Deploy each strategy manually
SParkOctatnt spark = new SParkOctatnt(
    sparkUSDC, sparkUSDT, sparkETH,
    usdc, usdt, weth,
    USDC, "Spark", mgmt, keeper, admin, donation, false, tokenized
);

AaveV3YieldStrategy aave = new AaveV3YieldStrategy(
    aavePool, aToken, debtToken,
    USDC, "Aave", mgmt, keeper, admin, donation, false, tokenized
);

// Need to track addresses manually
// No discovery mechanism
// No unified governance
```

### With Factory (New Way)
```solidity
// Deploy via factory with minimal configuration
DeploymentConfig memory sparkConfig = DeploymentConfig({
    strategyType: StrategyType.SPARK_OPTIMIZER,
    asset: USDC,
    name: "Spark USDC Optimizer",
    management: mgmt,
    keeper: keeper,
    emergencyAdmin: admin,
    donationAddress: donation,
    enableBurning: false,
    strategyParams: ""
});

address sparkStrategy = factory.deployStrategy(sparkConfig);

// Strategy automatically registered and discoverable
// Centralized governance
// Easy batch deployments
```

## Supported Strategies

### 1. Spark Optimizer (`SPARK_OPTIMIZER`)
**Purpose**: Continuous per-second yield optimization on Spark vaults

**Supported Assets**: USDC, USDT, ETH

**Features**:
- Continuous VSR (Vault Savings Rate) compounding
- Auto-rebalancing to highest APY vault
- Multi-asset support (spUSDC, spUSDT, spETH)
- 100% yield donation to public goods

**Configuration**:
```solidity
DeploymentConfig memory config = DeploymentConfig({
    strategyType: StrategyType.SPARK_OPTIMIZER,
    asset: USDC,  // or USDT, WETH
    name: "Spark USDC Yield Optimizer",
    management: deployer,
    keeper: deployer,
    emergencyAdmin: deployer,
    donationAddress: publicGoods,
    enableBurning: false,
    strategyParams: ""  // Not used for Spark
});

address strategy = factory.deployStrategy(config);
```

### 2. Aave V3 Recursive (`AAVE_V3_RECURSIVE`)
**Purpose**: Supply yield + optional recursive lending for leverage

**Supported Assets**: USDC, USDT, WETH

**Features**:
- Supply yields from lending protocol
- Optional recursive lending (1x-3x leverage)
- Health factor automation
- Auto-rebalancing
- 100% yield donation to public goods

**Configuration - Simple (1x)**:
```solidity
DeploymentConfig memory config = DeploymentConfig({
    strategyType: StrategyType.AAVE_V3_RECURSIVE,
    asset: USDC,
    name: "Aave USDC Simple",
    management: deployer,
    keeper: deployer,
    emergencyAdmin: deployer,
    donationAddress: publicGoods,
    enableBurning: false,
    strategyParams: ""  // Default: 1x (no leverage)
});

address strategy = factory.deployStrategy(config);
```

**Configuration - With Leverage (2x)**:
```solidity
// Encode leverage multiplier: 2e18 = 2x
DeploymentConfig memory config = DeploymentConfig({
    strategyType: StrategyType.AAVE_V3_RECURSIVE,
    asset: USDC,
    name: "Aave USDC 2x Leverage",
    management: deployer,
    keeper: deployer,
    emergencyAdmin: deployer,
    donationAddress: publicGoods,
    enableBurning: false,
    strategyParams: abi.encode(uint256(2e18))
});

address strategy = factory.deployStrategy(config);

// Factory will automatically:
// 1. Deploy strategy
// 2. Set leverage multiplier to 2x
// 3. Enable recursive lending
// 4. Register deployment
```

## Deployment Process

### Step-by-Step Guide

#### 1. Deploy the Factory
```solidity
UnifiedYieldStrategyFactory factory = new UnifiedYieldStrategyFactory(
    management,      // Address controlling factory settings
    donation,        // Default donation address for yields
    keeper,          // Default keeper for tend/report
    emergencyAdmin   // Emergency control address
);
```

#### 2. Create Deployment Configuration
```solidity
DeploymentConfig memory config = DeploymentConfig({
    strategyType: StrategyType.SPARK_OPTIMIZER,
    asset: USDC,
    name: "Spark USDC Optimizer v1",
    management: msg.sender,
    keeper: msg.sender,
    emergencyAdmin: msg.sender,
    donationAddress: publicGoodsAddress,
    enableBurning: false,
    strategyParams: ""
});
```

#### 3. Deploy Strategy via Factory
```solidity
address strategyAddress = factory.deployStrategy(config);
```

#### 4. Verify Deployment
```solidity
// Check registration
bool isRegistered = factory.isRegisteredStrategy(strategyAddress);

// Get deployment details
UnifiedYieldStrategyFactory.DeploymentRecord memory record =
    factory.getDeployment(strategyAddress);

console.log("Strategy Name:", record.name);
console.log("Asset:", record.asset);
console.log("Deployed by:", record.deployer);
console.log("Deployment time:", record.deploymentTime);
```

## Usage Examples

### Example 1: Deploy Spark + Aave Bundle

```solidity
// Initialize factory with common settings
UnifiedYieldStrategyFactory factory = new UnifiedYieldStrategyFactory(
    management, donation, keeper, admin
);

// Deploy Spark strategy
DeploymentConfig memory sparkConfig = DeploymentConfig({
    strategyType: StrategyType.SPARK_OPTIMIZER,
    asset: USDC,
    name: "Multi-Protocol USDC - Spark",
    management: management,
    keeper: keeper,
    emergencyAdmin: admin,
    donationAddress: donation,
    enableBurning: false,
    strategyParams: ""
});
address sparkStrategy = factory.deployStrategy(sparkConfig);

// Deploy Aave V3 simple strategy
DeploymentConfig memory aaveConfig = DeploymentConfig({
    strategyType: StrategyType.AAVE_V3_RECURSIVE,
    asset: USDC,
    name: "Multi-Protocol USDC - Aave Simple",
    management: management,
    keeper: keeper,
    emergencyAdmin: admin,
    donationAddress: donation,
    enableBurning: false,
    strategyParams: ""
});
address aaveStrategy = factory.deployStrategy(aaveConfig);

// Both registered and discoverable
assert(factory.isRegisteredStrategy(sparkStrategy));
assert(factory.isRegisteredStrategy(aaveStrategy));
```

### Example 2: Leverage Comparison

```solidity
// Deploy three leverage tiers for Aave
uint256[] memory leverages = new uint256[](3);
leverages[0] = 1e18;  // 1x (simple)
leverages[1] = 2e18;  // 2x (conservative)
leverages[2] = 3e18;  // 3x (aggressive)

address[] memory strategies = new address[](3);

for (uint256 i = 0; i < leverages.length; i++) {
    bytes memory params = abi.encode(leverages[i]);

    DeploymentConfig memory config = DeploymentConfig({
        strategyType: StrategyType.AAVE_V3_RECURSIVE,
        asset: USDC,
        name: string.concat(
            "Aave USDC ",
            _toString(leverages[i] / 1e18),
            "x Leverage"
        ),
        management: management,
        keeper: keeper,
        emergencyAdmin: admin,
        donationAddress: donation,
        enableBurning: false,
        strategyParams: params
    });

    strategies[i] = factory.deployStrategy(config);
}

// All three deployed with different risk profiles
```

### Example 3: Query Deployments

```solidity
// Get all Spark strategies for USDC
address[] memory sparkUSDCStrategies = factory.getDeploymentsByTypeAndAsset(
    StrategyType.SPARK_OPTIMIZER,
    USDC
);

console.log("Spark USDC strategies:", sparkUSDCStrategies.length);
for (uint256 i = 0; i < sparkUSDCStrategies.length; i++) {
    UnifiedYieldStrategyFactory.DeploymentRecord memory record =
        factory.getDeployment(sparkUSDCStrategies[i]);
    console.log(record.name);
}

// Get recent deployments (last 10)
UnifiedYieldStrategyFactory.DeploymentRecord[] memory recent =
    factory.getRecentDeployments(10);

for (uint256 i = 0; i < recent.length; i++) {
    console.log("Deployment", i, ":", recent[i].name);
}
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│   UnifiedYieldStrategyFactory                       │
│                                                     │
│  ┌──────────────┐      ┌──────────────┐            │
│  │ Management   │      │ Donation     │            │
│  │ Address      │      │ Address      │            │
│  └──────────────┘      └──────────────┘            │
│         ↓                     ↓                     │
│  ┌─────────────────────────────────────────┐       │
│  │  deployStrategy(config)                 │       │
│  │  - Validates configuration              │       │
│  │  - Deploys appropriate strategy         │       │
│  │  - Registers deployment                 │       │
│  │  - Emits events                         │       │
│  └─────────────────────────────────────────┘       │
│         ↓                     ↓        ↓            │
│  ┌──────────────┐  ┌──────────────┐ ┌─────────┐   │
│  │   Spark      │  │   Aave V3    │ │ Future  │   │
│  │  Optimizer   │  │  Recursive   │ │ Strats  │   │
│  └──────────────┘  └──────────────┘ └─────────┘   │
│         ↓                  ↓                       │
│  ┌─────────────────────────────────────────┐       │
│  │  Deployment Registry                   │       │
│  │  - By strategy address                 │       │
│  │  - By type + asset                     │       │
│  │  - Recent deployments                  │       │
│  └─────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘
                         ↓
        ┌────────────────┴────────────────┐
        ↓                                 ↓
   ┌──────────────┐              ┌──────────────┐
   │ Spark Pool   │              │ Aave V3 Pool │
   │ (Mainnet)    │              │ (Mainnet)    │
   └──────────────┘              └──────────────┘
```

## Factory Functions Reference

### Deployment Functions

```solidity
// Main deployment function
function deployStrategy(DeploymentConfig calldata _config)
    external
    returns (address strategyAddress)
```

### Query Functions

```solidity
// Get deployment details
function getDeployment(address _strategy)
    external view
    returns (DeploymentRecord memory)

// Get strategies by type and asset
function getDeploymentsByTypeAndAsset(StrategyType _type, address _asset)
    external view
    returns (address[] memory)

// Get recent deployments
function getRecentDeployments(uint256 _limit)
    external view
    returns (DeploymentRecord[] memory)

// Check if strategy is registered
function isRegisteredStrategy(address _strategy)
    external view
    returns (bool)

// Get total deployment count
function getTotalDeployments()
    external view
    returns (uint256)

// Get all deployments
function getAllDeployments()
    external view
    returns (DeploymentRecord[] memory)
```

### Management Functions

```solidity
// Update factory configuration
function updateConfiguration(
    address _newManagement,
    address _newDonationAddress,
    address _newKeeper
) external
```

## Integration with Tests

### Test Script Template

```solidity
import {UnifiedYieldStrategyFactory, DeploymentConfig, StrategyType} from "src/factory/UnifiedYieldStrategyFactory.sol";

contract FactoryIntegrationTest {
    UnifiedYieldStrategyFactory factory;
    address deployer;

    function setUp() public {
        deployer = address(this);
        factory = new UnifiedYieldStrategyFactory(
            deployer,
            address(0x999),  // donation
            deployer,        // keeper
            deployer         // admin
        );
    }

    function testDeploySparkStrategy() public {
        DeploymentConfig memory config = DeploymentConfig({
            strategyType: StrategyType.SPARK_OPTIMIZER,
            asset: USDC,
            name: "Test Spark",
            management: deployer,
            keeper: deployer,
            emergencyAdmin: deployer,
            donationAddress: address(0x999),
            enableBurning: false,
            strategyParams: ""
        });

        address strategy = factory.deployStrategy(config);
        assertTrue(factory.isRegisteredStrategy(strategy));
    }

    function testDeployAaveWithLeverage() public {
        bytes memory params = abi.encode(uint256(2e18));

        DeploymentConfig memory config = DeploymentConfig({
            strategyType: StrategyType.AAVE_V3_RECURSIVE,
            asset: USDC,
            name: "Test Aave 2x",
            management: deployer,
            keeper: deployer,
            emergencyAdmin: deployer,
            donationAddress: address(0x999),
            enableBurning: false,
            strategyParams: params
        });

        address strategy = factory.deployStrategy(config);
        assertTrue(factory.isRegisteredStrategy(strategy));
    }
}
```

## Gas Optimization Tips

1. **Batch Deployments**: Deploy multiple strategies in one transaction to save gas on setup
2. **Reuse Configuration**: Use same management/keeper/admin for multiple strategies
3. **Strategic Params**: Only include necessary strategy parameters
4. **Query Efficiently**: Use `getDeploymentsByTypeAndAsset` instead of iterating all deployments

## Security Considerations

1. **Access Control**: Only management address can update factory configuration
2. **Parameter Validation**: All inputs validated before deployment
3. **Strategy Isolation**: Each strategy is independent and cannot affect others
4. **Emergency Controls**: Emergency admin can handle critical issues
5. **Deposit Caps**: Each strategy respects underlying protocol limits

## Deployment Checklist

- [ ] Factory deployed with correct addresses
- [ ] TokenizedStrategy implementation verified
- [ ] Spark vault addresses confirmed (spUSDC, spUSDT, spETH)
- [ ] Aave V3 pool and aToken addresses verified
- [ ] Donation address set correctly
- [ ] Management address has appropriate permissions
- [ ] Emergency admin address configured
- [ ] Keeper address can execute tend/report
- [ ] Strategies tested on testnet
- [ ] Factory registered with governance
- [ ] Deployment events logged and verified

## Next Steps

1. Deploy factory to target network (Ethereum mainnet or testnet)
2. Create configuration templates for common use cases
3. Document custom strategy parameters for your use case
4. Set up monitoring for deployed strategies
5. Integrate with governance for strategy lifecycle management
