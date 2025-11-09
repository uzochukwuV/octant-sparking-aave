# Spark Strategy Deployment Guide

## Quick Reference

### Deployed Addresses (Tenderly Fork Test)

From successful fork test execution on 2025-11-08:

| Component | Address | Network |
|-----------|---------|---------|
| **SparkMultiAssetYieldOptimizer** | `0xfa7E87ab16d74954D821FC3379ADCF660cE78d5B` | Tenderly Fork |
| **YieldDonatingTokenizedStrategy** | `0xdF216d8a65eecAcA7E96D57b8C51cD1713b2dFbA` | Tenderly Fork |
| **Deployer/Manager** | `0x8AaEe2071A400cC60927e46D53f751e521ef4D35` | Tenderly Fork |

### Spark Protocol Addresses (Mainnet)

```
USDC Vault:  0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d (spUSDC)
USDT Vault:  0xe2e7a17dFf93280dec073C995595155283e3C372 (spUSDT)
ETH Vault:   0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f (spETH)

USDC Token:  0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDT Token:  0xdAC17F958D2ee523a2206206994597C13D831ec7
WETH Token:  0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
```

---

## Deployment Steps

### 1. Prerequisites

```bash
# Install dependencies
forge install

# Set up environment
cp .env.example .env
# Edit .env with your values
```

### 2. Environment Configuration

**Required .env values:**

```bash
# Private key for deployment (with 0x prefix)
PRIVATE_KEY=0x...your_private_key...

# RPC URL (mainnet or testnet)
ETH_RPC_URL=https://eth.llamarpc.com

# (Optional) Tenderly fork for testing
TENDERLY_RPC=https://virtual.mainnet.eu.rpc.tenderly.co/...
```

### 3. Compile Contracts

```bash
forge build

# With optimization
forge build --optimize --optimizer-runs 200
```

**Expected output:**
```
Compiling 1 files with Solc 0.8.25
Solc 0.8.25 finished in X.XXs
Compiler run successful!
```

### 4. Deploy to Mainnet

#### Option A: Using Script

```bash
# Deploy with automatic broadcast
forge script script/DeployAndTest.s.sol \
  --rpc-url https://eth.llamarpc.com \
  --broadcast \
  --verify
```

#### Option B: Manual Deployment

```solidity
// Deploy YieldDonatingTokenizedStrategy first
YieldDonatingTokenizedStrategy tokenized = new YieldDonatingTokenizedStrategy();

// Then deploy SparkMultiAssetYieldOptimizer
SparkMultiAssetYieldOptimizer strategy = new SparkMultiAssetYieldOptimizer(
    0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d,  // SPARK_USDC
    0xe2e7a17dFf93280dec073C995595155283e3C372,  // SPARK_USDT
    0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f,  // SPARK_ETH
    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,  // USDC
    0xdAC17F958D2ee523a2206206994597C13D831ec7,  // USDT
    0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,  // WETH
    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,  // primaryAsset (USDC)
    "Spark Multi-Asset USDC Optimizer",            // name
    0x...,                                         // management address
    0x...,                                         // keeper address
    0x...,                                         // emergencyAdmin address
    0x...,                                         // donationAddress (public goods)
    false,                                         // enableBurning
    address(tokenized)                             // tokenizedStrategy
);
```

### 5. Post-Deployment Configuration

#### Initialize Donation Address

```bash
# Set up the donation address that receives 100% of profits
# This is done via Octant registry or directly via management call

cast call 0x<STRATEGY_ADDRESS> "setDragonRouter(address)" <DONATION_ADDRESS> \
  --rpc-url https://eth.llamarpc.com
```

#### Verify Deployment

```bash
# Check strategy asset
cast call 0x<STRATEGY_ADDRESS> "asset()" \
  --rpc-url https://eth.llamarpc.com

# Check total assets
cast call 0x<STRATEGY_ADDRESS> "totalAssets()" \
  --rpc-url https://eth.llamarpc.com

# Check Spark integration
cast call 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d "balanceOf(address)" 0x<STRATEGY_ADDRESS> \
  --rpc-url https://eth.llamarpc.com
```

---

## Testing Before Mainnet

### 1. Fork Test (Integration)

```bash
# Test on Tenderly fork with real Spark vaults
forge script script/ForkTestSimple.s.sol \
  --rpc-url https://virtual.mainnet.eu.rpc.tenderly.co/... \
  --broadcast \
  -vvv
```

**What this verifies:**
- ✓ Deployment succeeds
- ✓ Deposits work and route to Spark
- ✓ Withdrawals function correctly
- ✓ Report mechanism works
- ✓ Donation address setup functional

### 2. Unit Tests (Behavior)

```bash
# Run all Spark strategy tests
forge test --fork-url https://virtual.mainnet.eu.rpc.tenderly.co/... src/test/spark/

# Expected: 12/12 passed
```

**Tests cover:**
- Deposit to Spark vaults ✓
- Withdrawal from Spark ✓
- Continuous yield accrual (30 days) ✓
- Harvest and report ✓
- Rebalancing logic ✓
- Deposit/withdraw limits ✓

### 3. Gas Estimation

```bash
# Estimate deployment gas
forge script script/DeployAndTest.s.sol \
  --rpc-url https://eth.llamarpc.com \
  --gas-price 50gwei

# Estimate operation gas
# - Deposit: ~150,000 - 200,000 gas
# - Withdraw: ~120,000 - 180,000 gas
# - Report: ~80,000 - 150,000 gas
# - Tend (rebalance): ~250,000 - 350,000 gas
```

---

## Operating the Strategy

### Keeper Operations

**Daily Report Call** (captures yield):

```bash
# Call report to harvest accumulated yield
cast send 0x<STRATEGY_ADDRESS> "report()" \
  --rpc-url https://eth.llamarpc.com \
  --private-key 0x<KEEPER_PRIVATE_KEY>
```

**Weekly Rebalancing** (if APY spread > 0.1%):

```bash
# Check if rebalancing needed
cast call 0x<STRATEGY_ADDRESS> "tendTrigger()" \
  --rpc-url https://eth.llamarpc.com

# If true, call tend
cast send 0x<STRATEGY_ADDRESS> "tend()" \
  --rpc-url https://eth.llamarpc.com \
  --private-key 0x<KEEPER_PRIVATE_KEY>
```

**Emergency Shutdown** (if needed):

```bash
# Shutdown strategy and withdraw all funds
cast send 0x<STRATEGY_ADDRESS> "shutdownStrategy()" \
  --rpc-url https://eth.llamarpc.com \
  --private-key 0x<EMERGENCY_ADMIN_PRIVATE_KEY>
```

### User Operations

**Deposit:**

```bash
# 1. Approve strategy to spend USDC
cast send 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 \
  "approve(address,uint256)" 0x<STRATEGY_ADDRESS> 10000000000 \
  --rpc-url https://eth.llamarpc.com \
  --private-key 0x<YOUR_PRIVATE_KEY>

# 2. Deposit into strategy (via ERC4626 interface)
cast send 0x<STRATEGY_ADDRESS> \
  "deposit(uint256,address)" 10000000000 0x<YOUR_ADDRESS> \
  --rpc-url https://eth.llamarpc.com \
  --private-key 0x<YOUR_PRIVATE_KEY>
```

**Withdraw:**

```bash
# 1. Get your share balance
cast call 0x<STRATEGY_ADDRESS> "balanceOf(address)" 0x<YOUR_ADDRESS> \
  --rpc-url https://eth.llamarpc.com

# 2. Approve strategy to burn shares
cast send 0x<STRATEGY_ADDRESS> \
  "approve(address,uint256)" 0x<STRATEGY_ADDRESS> <SHARES> \
  --rpc-url https://eth.llamarpc.com \
  --private-key 0x<YOUR_PRIVATE_KEY>

# 3. Redeem shares for assets
cast send 0x<STRATEGY_ADDRESS> \
  "redeem(uint256,address,address)" <SHARES> 0x<YOUR_ADDRESS> 0x<YOUR_ADDRESS> \
  --rpc-url https://eth.llamarpc.com \
  --private-key 0x<YOUR_PRIVATE_KEY>
```

---

## Monitoring & Analytics

### Key Metrics

**1. Total Value Locked (TVL)**

```bash
cast call 0x<STRATEGY_ADDRESS> "totalAssets()" \
  --rpc-url https://eth.llamarpc.com
```

**2. Spark Allocation**

```bash
# Check spUSDC balance
cast call 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d \
  "balanceOf(address)" 0x<STRATEGY_ADDRESS> \
  --rpc-url https://eth.llamarpc.com

# Check spUSDT balance
cast call 0xe2e7a17dFf93280dec073C995595155283e3C372 \
  "balanceOf(address)" 0x<STRATEGY_ADDRESS> \
  --rpc-url https://eth.llamarpc.com

# Check spETH balance
cast call 0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f \
  "balanceOf(address)" 0x<STRATEGY_ADDRESS> \
  --rpc-url https://eth.llamarpc.com
```

**3. Yield Harvested**

```bash
# Get profit shares minted to donation address
cast call 0x<STRATEGY_ADDRESS> "balanceOf(address)" 0x<DONATION_ADDRESS> \
  --rpc-url https://eth.llamarpc.com

# Convert to assets
cast call 0x<STRATEGY_ADDRESS> "convertToAssets(uint256)" <DONATION_SHARES> \
  --rpc-url https://eth.llamarpc.com
```

### Event Tracking

Monitor these events:

```solidity
// Deposit/Withdrawal
event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

// Yield Donation
event Transfer(address indexed from, address indexed to, uint256 value); // Minting to donationAddress

// Strategy Operations
event FundsDeployed(address vault, uint256 assets, uint256 shares, uint256 timestamp);
event FundsFreed(address vault, uint256 assets, uint256 shares, uint256 timestamp);
```

---

## Troubleshooting Deployment

### Issue: "Constructor parameter mismatch"

**Solution:** Ensure all 15 parameters are in correct order and types:

```solidity
new SparkMultiAssetYieldOptimizer(
    address _sparkUSDC,          // 1. Spark vault address
    address _sparkUSDT,          // 2. Spark vault address
    address _sparkETH,           // 3. Spark vault address
    address _usdc,               // 4. Token address
    address _usdt,               // 5. Token address
    address _weth,               // 6. Token address
    address _primaryAsset,       // 7. Primary deposit asset (USDC)
    string memory _name,         // 8. Vault name
    address _management,         // 9. Management role
    address _keeper,             // 10. Keeper role
    address _emergencyAdmin,     // 11. Emergency role
    address _donationAddress,    // 12. Yield donation address
    bool _enableBurning,         // 13. Burn flag
    address _tokenizedStrategyAddress  // 14. TokenizedStrategy impl
);
```

### Issue: "Insufficient balance for deployment"

**Solution:** Ensure sender has enough ETH for gas:

```bash
# Check balance
cast balance 0x<YOUR_ADDRESS> --rpc-url https://eth.llamarpc.com

# Need minimum: ~5 ETH for safe deployment + testing
```

### Issue: "maxDeposit exceeded" error

**Solution:** Spark vaults have deposit caps. Check current limits:

```bash
# Check max deposit for spUSDC
cast call 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d \
  "maxDeposit(address)" 0x<STRATEGY_ADDRESS> \
  --rpc-url https://eth.llamarpc.com
```

---

## Verification Checklist

- [ ] Code compiles without warnings
- [ ] Fork test passes (12/12 tests)
- [ ] Unit tests pass (all Spark strategy tests)
- [ ] Deployment addresses recorded
- [ ] Donation address configured
- [ ] Mainnet fork test completed
- [ ] Gas estimates reviewed
- [ ] Security audit completed (if required)
- [ ] Liquidity provider incentives configured
- [ ] Monitoring/alerting set up
- [ ] Documentation complete
- [ ] Contract verified on Etherscan

---

## Mainnet Safety Checklist

Before deploying to mainnet:

1. **Code Review**
   - [ ] All 15 constructor parameters verified
   - [ ] Spark vault integrations reviewed
   - [ ] Yield harvesting logic validated
   - [ ] Rebalancing thresholds checked

2. **Testing**
   - [ ] Fork test passed (all phases)
   - [ ] Unit tests passed (12/12)
   - [ ] Gas optimizations reviewed
   - [ ] Edge cases tested

3. **Security**
   - [ ] No hardcoded values in production
   - [ ] Donation address validation
   - [ ] Emergency shutdown tested
   - [ ] Access control verified

4. **Operations**
   - [ ] Keeper setup confirmed
   - [ ] Monitoring configured
   - [ ] Runbooks prepared
   - [ ] Team training completed

5. **Documentation**
   - [ ] Deployment addresses documented
   - [ ] Operation procedures documented
   - [ ] Troubleshooting guide complete
   - [ ] User documentation prepared

---

## Support Resources

- **Technical Docs:** [SPARK_INTEGRATION_GUIDE.md](SPARK_INTEGRATION_GUIDE.md)
- **Testing Guide:** [RUN_FORK_TEST.md](RUN_FORK_TEST.md)
- **Constructor Details:** [CONSTRUCTOR_ANALYSIS.md](CONSTRUCTOR_ANALYSIS.md)
- **Test Architecture:** [TESTING_ANALYSIS.md](TESTING_ANALYSIS.md)
- **Spark Protocol:** https://docs.spark.fi
- **ERC-4626 Spec:** https://eips.ethereum.org/EIPS/eip-4626

---

## Test Results Summary

### Fork Test (Tenderly)
```
✓ Deployment successful
✓ Deposits working (50→124 USDC across 3 phases)
✓ Spark integration verified (124.7M spUSDC held)
✓ Withdrawals working (25 USDC withdrawn)
✓ Report mechanism working (0 profit expected - no time passed)
✓ Donation mechanism functional
```

### Unit Tests (12/12 Passed)
```
✓ test_setupStrategyOK
✓ test_depositToSpark
✓ test_withdrawFromSpark (FIXED: Added approval)
✓ test_continuousYieldAccrual (30 days)
✓ test_harvestAndReport
✓ test_tendDeploysIdleFunds
✓ test_rebalancing
✓ test_availableDepositLimit
✓ test_availableWithdrawLimit
✓ test_getVaultAPYs
✓ test_getAllocation
✓ test_getSparkVaultState
```

---

## Contact & Support

For questions about deployment or operation:

1. Review the [SPARK_INTEGRATION_GUIDE.md](SPARK_INTEGRATION_GUIDE.md)
2. Check test files for working examples
3. Review RUN_FORK_TEST.md for fork testing details
4. Consult CONSTRUCTOR_ANALYSIS.md for parameter details

