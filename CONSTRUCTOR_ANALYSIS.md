# Constructor Parameter Analysis & Deployment Guide

## Constructor Overview

Your `SparkMultiAssetYieldOptimizer` constructor has 15 parameters. Here's a breakdown of each:

```solidity
constructor(
    address _sparkUSDC,           // [1] Spark USDC vault
    address _sparkUSDT,           // [2] Spark USDT vault
    address _sparkETH,            // [3] Spark ETH vault
    address _usdc,                // [4] USDC token
    address _usdt,                // [5] USDT token
    address _weth,                // [6] WETH token
    address _primaryAsset,        // [7] Primary asset (determines yield source)
    string memory _name,          // [8] Strategy name
    address _management,          // [9] Can manage strategy config
    address _keeper,              // [10] Can call harvest/tend
    address _emergencyAdmin,      // [11] Can emergency shutdown
    address _donationAddress,     // [12] Receives minted yield shares
    bool _enableBurning,          // [13] Loss protection via burning
    address _tokenizedStrategyAddress  // [14] Octant wrapper contract
)
```

---

## Parameter Breakdown

### Category 1: SPARK VAULT ADDRESSES (IMMUTABLE, REQUIRED)

| Param | Type | Value | Purpose | Necessary |
|-------|------|-------|---------|-----------|
| `_sparkUSDC` | address | `0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d` | Spark USDC vault | ✅ YES |
| `_sparkUSDT` | address | `0xe2e7a17dFf93280dec073C995595155283e3C372` | Spark USDT vault | ✅ YES |
| `_sparkETH` | address | `0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f` | Spark ETH vault | ✅ YES |

**Why necessary:** Your strategy can rebalance between these vaults. The contract validates that the vault's asset matches the token you're trying to deposit.

**For your test:** Use exact mainnet addresses (they're already correct in your deployment script).

---

### Category 2: UNDERLYING TOKEN ADDRESSES (IMMUTABLE, REQUIRED)

| Param | Type | Value | Purpose | Necessary |
|-------|------|-------|---------|-----------|
| `_usdc` | address | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | USDC token | ✅ YES |
| `_usdt` | address | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | USDT token | ✅ YES |
| `_weth` | address | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | WETH token | ✅ YES |

**Why necessary:** Needed to check which token each vault accepts and for token transfers.

**For your test:** Use exact mainnet addresses (already correct).

---

### Category 3: STRATEGY CONFIGURATION (MUTABLE, REQUIRED)

| Param | Type | Value | Purpose | Necessary |
|-------|------|-------|---------|-----------|
| `_primaryAsset` | address | USDC (0xA0b86...) | Which asset this deployment handles | ✅ YES |
| `_name` | string | "Spark Multi-Asset USDC Optimizer" | Strategy name (for display) | ✅ YES |

**Why necessary:**
- `_primaryAsset` determines which Spark vault receives deposits (USDC → spUSDC, USDT → spUSDT, ETH → spETH)
- `_name` is used in the ERC-4626 vault name property

**For your test:**
- Use `USDC` address since you have 1000 USDC to test
- Name can be anything descriptive

---

### Category 4: ROLE-BASED ACCESS CONTROL (CRITICAL, REQUIRED)

| Param | Type | Value | Purpose | Necessary | Your Test Value |
|-------|------|-------|---------|-----------|-----------------|
| `_management` | address | Your address | Can change strategy config | ✅ YES | Your deployer address |
| `_keeper` | address | Keeper bot address | Calls `harvest()` and `tend()` | ✅ YES | Can be your address for testing |
| `_emergencyAdmin` | address | Emergency multisig | Can trigger `emergencyShutdown()` | ✅ YES | Can be your address for testing |

**Why necessary:**
- These are inherited from `BaseStrategy` (Octant framework requirement)
- **Management**: Controls strategy parameters (fees, limits, etc.)
- **Keeper**: Automated bot that harvests yield periodically (in production, this is a centralized keeper)
- **Emergency Admin**: Can pause/shut down strategy if something breaks

**For your test:**
```solidity
management = msg.sender        // Your address
keeper = msg.sender            // Your address (you'll manually call harvest)
emergencyAdmin = msg.sender    // Your address (you can trigger emergency shutdown)
```

---

### Category 5: YIELD DONATION (CRITICAL, REQUIRED)

| Param | Type | Value | Purpose | Necessary | Your Test Value |
|-------|------|-------|---------|-----------|-----------------|
| `_donationAddress` | address | Octant Dragon Router | Receives minted yield shares | ✅ YES | Any address (e.g., `address(0x123)`) |

**Why necessary:**
- This is **the whole point** of your strategy
- When profits are harvested, new shares are minted directly to this address
- In production: points to Octant's Dragon Router (allocates yield to public goods)
- In your test: can be any address (even `address(0x3)` for simplicity)

**For your test:**
```solidity
donationAddress = address(3)  // Simple test address for tracking donations
```

---

### Category 6: OPTIONAL CONFIGURATION (TUNABLE, REQUIRED)

| Param | Type | Value | Purpose | Necessary | Your Test Value |
|-------|------|-------|---------|-----------|-----------------|
| `_enableBurning` | bool | false | Burn shares on losses for protection | ✅ YES (but can be false) | `false` (simpler for testing) |

**Why necessary:**
- Inherited from `YieldDonatingTokenizedStrategy`
- If `true`: When losses occur, shares are burned from donation address
- If `false`: Losses just reduce total assets (no burning)

**For your test:** Set to `false` (simpler, and you won't have losses with Spark)

---

### Category 7: OCTANT INTEGRATION (CRITICAL, REQUIRED)

| Param | Type | Value | Purpose | Necessary | Your Test Value |
|-------|------|-------|---------|-----------|-----------------|
| `_tokenizedStrategyAddress` | address | YieldDonatingTokenizedStrategy contract | Octant wrapper | ✅ YES | Deploy a new one |

**Why necessary:**
- This is the Octant framework's wrapper that handles:
  - Profit minting to donation address
  - Loss handling
  - Reporting to Octant
  - Dragon Router management

**For your test:**
```solidity
YieldDonatingTokenizedStrategy tokenizedStrategy = new YieldDonatingTokenizedStrategy();
address tokenizedStrategyAddress = address(tokenizedStrategy);
```

---

## Deployment Checklist for Your Forked Mainnet Test

### ✅ Immutable Addresses (Copy from Mainnet)
```solidity
address sparkUSDC = 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d;
address sparkUSDT = 0xe2e7a17dFf93280dec073C995595155283e3C372;
address sparkETH = 0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f;

address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
```

### ✅ Configuration (Your Choices)
```solidity
address primaryAsset = usdc;  // Since you have 1000 USDC
string memory name = "Spark USDC Optimizer - Test";

// Your test addresses (can all be the same)
address management = msg.sender;
address keeper = msg.sender;
address emergencyAdmin = msg.sender;
address donationAddress = address(0x999);  // Track donations here

bool enableBurning = false;  // Simpler for testing
```

### ✅ Deploy Octant Wrapper
```solidity
YieldDonatingTokenizedStrategy tokenizedStrategy = new YieldDonatingTokenizedStrategy();
address tokenizedStrategyAddress = address(tokenizedStrategy);
```

### ✅ Deploy Your Strategy
```solidity
SparkMultiAssetYieldOptimizer strategy = new SparkMultiAssetYieldOptimizer(
    sparkUSDC,
    sparkUSDT,
    sparkETH,
    usdc,
    usdt,
    weth,
    primaryAsset,
    name,
    management,
    keeper,
    emergencyAdmin,
    donationAddress,
    enableBurning,
    tokenizedStrategyAddress
);
```

---

## Testing Strategy (With Your 1000 USDC + 10 ETH)

### Phase 1: Basic Functionality (50 USDC)
```
1. Deploy strategy
2. Approve 50 USDC to strategy
3. Deposit 50 USDC → Check spUSDC shares received
4. Wait 1 day (skip time in test)
5. Call harvest() → Check yield accrued
6. Verify donation address got shares
7. Withdraw 25 USDC → Check redemption works
```

### Phase 2: Yield Accrual (200 USDC)
```
1. Deposit 200 USDC
2. Skip 7 days
3. Call report() from keeper
4. Verify profit was calculated correctly
5. Check donation address share balance increased
```

### Phase 3: Multi-Asset (Use your ETH)
```
1. Deploy another strategy with WETH as primaryAsset
2. Wrap 1 ETH → WETH
3. Deposit WETH
4. Skip 7 days
5. Harvest and verify Spark ETH vault yield
```

### Phase 4: Emergency Scenario (500 USDC)
```
1. Deposit 500 USDC
2. Call emergencyWithdraw() from emergencyAdmin
3. Verify funds returned (or graceful failure if liquidity unavailable)
```

---

## Quick Reference: Parameter Necessity Matrix

```
┌─────────────────────────┬──────────┬────────────┬──────────────────┐
│ Parameter               │ Required │ Immutable  │ Typical Value    │
├─────────────────────────┼──────────┼────────────┼──────────────────┤
│ _sparkUSDC              │ ✅ YES   │ ✅ YES     │ spUSDC address   │
│ _sparkUSDT              │ ✅ YES   │ ✅ YES     │ spUSDT address   │
│ _sparkETH               │ ✅ YES   │ ✅ YES     │ spETH address    │
│ _usdc                   │ ✅ YES   │ ✅ YES     │ USDC address     │
│ _usdt                   │ ✅ YES   │ ✅ YES     │ USDT address     │
│ _weth                   │ ✅ YES   │ ✅ YES     │ WETH address     │
│ _primaryAsset           │ ✅ YES   │ ❌ NO      │ USDC/USDT/WETH   │
│ _name                   │ ✅ YES   │ ❌ NO      │ "Spark USDC..."  │
│ _management             │ ✅ YES   │ ❌ NO      │ Your address     │
│ _keeper                 │ ✅ YES   │ ❌ NO      │ Your address     │
│ _emergencyAdmin         │ ✅ YES   │ ❌ NO      │ Your address     │
│ _donationAddress        │ ✅ YES   │ ❌ NO      │ Tracking address │
│ _enableBurning          │ ✅ YES   │ ❌ NO      │ false            │
│ _tokenizedStrategyAddr  │ ✅ YES   │ ❌ NO      │ Deployed contract│
└─────────────────────────┴──────────┴────────────┴──────────────────┘
```

---

## Key Insights

1. **All parameters are necessary** - The constructor doesn't have optional parameters
2. **6 are hardcoded immutables** - Copy these from mainnet addresses
3. **2 are configuration** - Choose based on what you're testing
4. **3 are roles** - Can all be `msg.sender` for testing
5. **1 is critical** - `_donationAddress` is where yield magic happens
6. **1 is optional** - `_enableBurning` can be false for simpler testing
7. **1 is framework requirement** - `_tokenizedStrategyAddress` handles Octant integration

---

## Recommended Test Deployment Values

```solidity
// Copy these from mainnet (do NOT change)
address constant SPARK_USDC = 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d;
address constant SPARK_USDT = 0xe2e7a17dFf93280dec073C995595155283e3C372;
address constant SPARK_ETH = 0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

// Configure for your test
address primaryAsset = USDC;                          // What you have
string memory name = "Spark USDC Test Strategy";      // Descriptive
address management = msg.sender;                      // You control
address keeper = msg.sender;                          // You harvest
address emergencyAdmin = msg.sender;                  // You can shutdown
address donationAddress = address(0x999);             // Track donations
bool enableBurning = false;                           // Simpler

// Deploy Octant wrapper
YieldDonatingTokenizedStrategy ts = new YieldDonatingTokenizedStrategy();

// Deploy your strategy with all these values
SparkMultiAssetYieldOptimizer strategy = new SparkMultiAssetYieldOptimizer(
    SPARK_USDC, SPARK_USDT, SPARK_ETH,
    USDC, USDT, WETH,
    primaryAsset, name,
    management, keeper, emergencyAdmin,
    donationAddress, enableBurning,
    address(ts)
);
```

---

**Next Step:** Ready to write a test script that deploys this and runs the testing phases?
