# Testing Architecture Analysis

## Key Insight: Strategy vs Vault Interface

Your strategy implementation is correct, but **testing requires understanding the dual-interface pattern:**

### Architecture
```
┌─────────────────────────────────────────┐
│   User deposits USDC                    │
└──────────────┬──────────────────────────┘
               │
        ┌──────▼──────────┐
        │ IStrategyInterface (ERC-4626 Vault)
        │ - deposit()
        │ - withdraw()
        │ - redeem()
        │ - totalAssets()
        │ - balanceOf()
        └──────┬───────────┘
               │ wraps
        ┌──────▼──────────────────────────────┐
        │ SparkMultiAssetYieldOptimizer       │
        │ (Strategy Implementation)           │
        │ - _deployFunds()                    │
        │ - _freeFunds()                      │
        │ - _harvestAndReport()               │
        │ - _tend()                           │
        └──────┬───────────────────────────────┘
               │ allocates to
        ┌──────▼──────────────────────────────┐
        │ Spark Vaults (spUSDC, spUSDT, spETH)│
        │ - IERC4626 interface                │
        │ - Continuous per-second compounding │
        └────────────────────────────────────┘
```

## Testing Pattern (from YieldDonatingOperation.t.sol)

### 1. Cast to IStrategyInterface for deposits/withdrawals

```solidity
// CORRECT: Use IStrategyInterface for user operations
IStrategyInterface strategy = IStrategyInterface(address(yourStrategy));

// Deposit
strategy.deposit(amount, user);

// Withdraw
strategy.redeem(amount, user, user);

// WRONG: Do NOT call these directly on the strategy contract
yourStrategy.deposit(amount, user);  // ❌ This won't compile - strategy doesn't expose it
```

### 2. Helper Functions from Setup

Use the test setup helpers provided:

```solidity
// From SparkStrategySetup.sol

function mintAndDepositIntoStrategy(
    IStrategyInterface _strategy,
    address _user,
    uint256 _amount
) public {
    airdrop(asset, _user, _amount);  // Mint tokens to user
    depositIntoStrategy(_strategy, _user, _amount);  // Deposit them
}

function depositIntoStrategy(
    IStrategyInterface _strategy,
    address _user,
    uint256 _amount
) public {
    vm.prank(_user);
    asset.approve(address(_strategy), _amount);

    vm.prank(_user);
    _strategy.deposit(_amount, _user);  // ✅ Via IStrategyInterface
}

function airdrop(ERC20 _asset, address _to, uint256 _amount) public {
    uint256 balanceBefore = _asset.balanceOf(_to);
    deal(address(_asset), _to, balanceBefore + _amount);
}
```

### 3. Harvesting and Yield Checking

```solidity
// Skip time to allow yield to accrue
skip(7 days);

// Report to harvest
vm.prank(keeper);
(uint256 profit, uint256 loss) = strategy.report();

// Verify profit was donated
uint256 dragonRouterShares = strategy.balanceOf(dragonRouter);
assertGt(dragonRouterShares, 0, "profit should be minted to donation address");

// Convert back to assets to verify amount
uint256 dragonRouterAssets = strategy.convertToAssets(dragonRouterShares);
assertEq(dragonRouterAssets, profit, "shares should equal profit");
```

## Your Fork Test Strategy

For testing on Tenderly fork with real Spark vaults:

### Setup Phase
```solidity
// 1. Deploy YieldDonatingTokenizedStrategy
YieldDonatingTokenizedStrategy tokenizedStrategy = new YieldDonatingTokenizedStrategy();

// 2. Deploy your Spark strategy
SparkMultiAssetYieldOptimizer sparkStrategy = new SparkMultiAssetYieldOptimizer(
    SPARK_USDC, SPARK_USDT, SPARK_ETH,
    USDC, USDT, WETH,
    USDC,  // primary asset
    "Spark USDC Fork Test",
    management, keeper, emergencyAdmin,
    donationAddress,
    false,  // enableBurning
    address(tokenizedStrategy)
);

// 3. Cast to vault interface for user operations
IStrategyInterface vault = IStrategyInterface(address(sparkStrategy));
```

### Deposit Phase
```solidity
// Mint USDC to user (fork has 1000 USDC available)
deal(USDC, user, 50 * 1e6);

// Approve and deposit
IERC20(USDC).approve(address(vault), 50 * 1e6);
uint256 sharesReceived = vault.deposit(50 * 1e6, user);

// Verify deployment to Spark
uint256 spUSDCShares = IERC4626(SPARK_USDC).balanceOf(address(vault));
uint256 sparkValue = IERC4626(SPARK_USDC).convertToAssets(spUSDCShares);
```

### Yield Testing Phase
```solidity
// Skip 7 days for Spark's continuous compounding
skip(7 days);

// Harvest
vm.prank(keeper);
(uint256 profit, uint256 loss) = ITokenizedStrategy(address(vault)).report();

// Check donation
uint256 donationShares = IERC20(address(vault)).balanceOf(donationAddress);
assertGt(donationShares, 0, "profit should be minted");

if (profit > 0) {
    console.log("Profit harvested:", profit / 1e6, "USDC");
    console.log("Donation shares:", donationShares);
}
```

### Withdrawal Phase
```solidity
// User redeems shares
uint256 userShares = vault.balanceOf(user);
vault.redeem(userShares, user, user);

// Verify user got funds back
assertGe(IERC20(USDC).balanceOf(user), 50 * 1e6);
```

## Key Differences: Your Tests vs YieldDonating Pattern

| Aspect | Your Current Tests | Correct Pattern |
|--------|-------------------|-----------------|
| **Deposit** | `strategy.deposit()` ❌ | `IStrategyInterface(strategy).deposit()` ✅ |
| **Withdraw** | `strategy.redeem()` ❌ | `IStrategyInterface(strategy).redeem()` ✅ |
| **Setup** | Custom helpers | Use `mintAndDepositIntoStrategy()` ✅ |
| **Profit Check** | Not implemented | `strategy.balanceOf(dragonRouter)` ✅ |
| **Harvest** | Uses `report()` ✅ | Same ✅ |

## Why This Architecture?

The split exists because:

1. **Strategy** = yield logic (`_deployFunds`, `_freeFunds`, `_harvestAndReport`)
   - Complex, domain-specific
   - Reused across multiple vaults
   - Doesn't expose user-facing methods

2. **Vault (IStrategyInterface)** = ERC-4626 interface
   - User-facing: deposit, withdraw, redeem
   - Share accounting
   - Handles profit minting to donation address
   - Wraps the strategy implementation

3. **Yield Source** (Spark vaults) = actual yield generation
   - IERC4626 compatible
   - Provides the `convertToAssets()` for continuous compounding

## Testing Pattern Summary

```solidity
// Setup
IStrategyInterface vault = IStrategyInterface(address(strategy));

// User operations (via vault interface)
vault.deposit(amount, user);
vault.redeem(amount, user, user);
vault.balanceOf(user);

// Harvest (via TokenizedStrategy interface)
ITokenizedStrategy(address(vault)).report();

// Profit tracking
vault.balanceOf(donationAddress);  // Shares minted to donation address
```

This is exactly what your `SparkStrategyOperation.t.sol` test file does - and it's correct!

## Your Current Test File: SparkStrategyOperation.t.sol

This file **already follows the correct pattern**:
- ✅ Uses `IStrategyInterface` interface (via `Strategy as IStrategyInterface`)
- ✅ Uses `mintAndDepositIntoStrategy()` helper
- ✅ Calls `strategy.report()` for harvest
- ✅ Checks `dragonRouter` for profit shares

**For fork testing, just run your existing tests with:**
```bash
forge test --fork-url <TENDERLY_RPC> -vvv
```

The tests are already correct! No need to modify them.
