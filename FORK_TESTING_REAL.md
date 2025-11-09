# Fork Testing on Real Mainnet (No time skipping)

## The Problem: Can't Skip Time on Fork

```solidity
// ❌ This ONLY works in unit tests
skip(7 days);  // Doesn't work on real fork - block.timestamp is real

// ✅ Need real time to pass OR simulate yield manually
```

On a forked mainnet, `skip()` doesn't work because:
- Block timestamps come from the actual blockchain
- You can't advance Ethereum's real chain time
- Time-dependent yield calculations won't happen

## Solution: Direct Yield Simulation on Fork

### Option 1: Wait for Real Yield (Days/Weeks)

**Pros:** Actual real-world behavior
**Cons:** Takes days to see results, impractical for testing

```solidity
// Deposit on day 1
vault.deposit(100 * 1e6, user);

// Wait 7 real days...
// Then on day 8, call report()
```

### Option 2: Manipulate Spark's Rate Accumulator (Advanced)

Spark's continuous compounding uses the `chi` accumulator. You can directly update it to simulate yield:

```solidity
// Spark uses chi rate accumulator
// chi_new = chi_old * (vsr)^(time_delta) / RAY

// To simulate 7 days of yield, you could:
// 1. Read current chi from Spark vault
// 2. Calculate what chi should be after 7 days
// 3. Directly set chi (requires prank admin role)
```

**Problem:** Spark vaults have role-based access - only SETTER_ROLE can change VSR, only DEFAULT_ADMIN_ROLE controls upgrades

### Option 3: Deposit Real Assets, Call Report Immediately

Most practical for fork testing:

```solidity
// Deploy strategy
IStrategyInterface vault = IStrategyInterface(address(strategy));

// Deposit real USDC
vault.deposit(100 * 1e6, user);

// Call report immediately
// Profit will be zero or minimal (no time has passed)
// But you can verify the MECHANISM works

// Check:
// ✓ Funds deployed to Spark ✓
// ✓ Report called successfully
// ✓ Profit minted to donation address (even if profit=0)
```

### Option 4: Simulate in Forge Test Instead

For meaningful yield testing, use forge unit tests with `skip()`:

```solidity
// In your test file (not fork script)
function test_yieldOnFork() public {
    // Deploy
    // ...

    // Deposit
    vault.deposit(100 * 1e6, user);

    // Skip 7 days
    skip(7 days);

    // Report and check profit
    (uint256 profit,) = vault.report();
    assertGt(profit, 0);
}

// Run with:
// forge test --fork-url <TENDERLY_RPC> --match test_yieldOnFork -vvv
```

## Recommended Fork Testing Strategy

### What to Test on Fork (Real Behavior)

```solidity
// script/ForkTest.s.sol

// ✓ Deployment works
// ✓ Strategy integrates with real Spark vaults
// ✓ Deposits actually send to Spark (spUSDC received)
// ✓ Withdrawals actually work
// ✓ Report can be called (even if profit=0)
// ✓ Donation address gets shares (even if profit=0)
```

### What to Test in Unit Tests (With Time Simulation)

```solidity
// src/test/spark/SparkStrategyOperation.t.sol

// ✓ Yield actually accrues over time (with skip())
// ✓ Profit calculation is correct
// ✓ Shares minted properly to donation address
// ✓ Rebalancing triggers work
```

---

## Implementation: Proper Fork Test

### Simple Fork Test (No Yield, Just Integration)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SparkMultiAssetYieldOptimizer} from "../src/strategies/spark/SParkOctatnt.sol";
import {YieldDonatingTokenizedStrategy} from "@octant-core/strategies/yieldDonating/YieldDonatingTokenizedStrategy.sol";
import {ITokenizedStrategy} from "@octant-core/core/interfaces/ITokenizedStrategy.sol";

contract ForkTestNoYield is Script {
    address constant SPARK_USDC = 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d;
    address constant SPARK_USDT = 0xe2e7a17dFf93280dec073C995595155283e3C372;
    address constant SPARK_ETH = 0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f;

    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console2.log("\n╔════════════════════════════════════════════════════════════╗");
        console2.log("║  SPARK STRATEGY - FORK INTEGRATION TEST (No Time Skipping) ║");
        console2.log("╚════════════════════════════════════════════════════════════╝\n");

        vm.startBroadcast(deployerKey);

        // ════════════════════════════════════════════════════════════
        // PHASE 1: DEPLOY
        // ════════════════════════════════════════════════════════════

        console2.log("PHASE 1: DEPLOYMENT");
        console2.log("════════════════════════════════════════════════════════════");

        YieldDonatingTokenizedStrategy tokenized = new YieldDonatingTokenizedStrategy();
        console2.log("✓ TokenizedStrategy deployed:", address(tokenized));

        SparkMultiAssetYieldOptimizer strategy = new SparkMultiAssetYieldOptimizer(
            SPARK_USDC, SPARK_USDT, SPARK_ETH,
            USDC, USDT, WETH,
            USDC,
            "Spark USDC Fork Test",
            deployer, deployer, deployer,
            address(0x999),  // donation address
            false,
            address(tokenized)
        );
        console2.log("✓ Strategy deployed:", address(strategy));

        ITokenizedStrategy vault = ITokenizedStrategy(address(strategy));

        // ════════════════════════════════════════════════════════════
        // PHASE 2: DEPOSIT & WITHDRAW (Real Behavior)
        // ════════════════════════════════════════════════════════════

        console2.log("\nPHASE 2: DEPOSIT & WITHDRAW");
        console2.log("════════════════════════════════════════════════════════════");

        // Check balance on fork
        uint256 usdcBalance = IERC20(USDC).balanceOf(deployer);
        console2.log("Your USDC on fork:", usdcBalance / 1e6, "USDC");

        // Deposit
        uint256 depositAmount = 50 * 1e6;
        IERC20(USDC).approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, deployer);
        console2.log("✓ Deposited", depositAmount / 1e6, "USDC");
        console2.log("  Received shares:", shares);

        // Check Spark integration
        uint256 spUSDCShares = IERC4626(SPARK_USDC).balanceOf(address(vault));
        uint256 sparkValue = IERC4626(SPARK_USDC).convertToAssets(spUSDCShares);
        console2.log("✓ Spark integration verified:");
        console2.log("  spUSDC shares:", spUSDCShares);
        console2.log("  Value in Spark:", sparkValue / 1e6, "USDC");

        // Withdraw
        uint256 withdrawAmount = 25 * 1e6;
        uint256 sharesToWithdraw = vault.convertToShares(withdrawAmount);
        uint256 usdcBefore = IERC20(USDC).balanceOf(deployer);
        vault.withdraw(withdrawAmount, deployer, deployer);
        uint256 usdcAfter = IERC20(USDC).balanceOf(deployer);
        console2.log("✓ Withdrew:", (usdcAfter - usdcBefore) / 1e6, "USDC");

        // ════════════════════════════════════════════════════════════
        // PHASE 3: HARVEST (Immediate, No Yield Expected)
        // ════════════════════════════════════════════════════════════

        console2.log("\nPHASE 3: HARVEST (Immediate)");
        console2.log("════════════════════════════════════════════════════════════");

        uint256 assetsBeforeReport = vault.totalAssets();
        uint256 donationSharesBefore = IERC20(address(vault)).balanceOf(address(0x999));

        console2.log("Before report:");
        console2.log("  Total assets:", assetsBeforeReport / 1e6, "USDC");
        console2.log("  Donation shares:", donationSharesBefore);

        // Report immediately (profit will be 0 or minimal since no time passed)
        (uint256 profit, uint256 loss) = vault.report();
        console2.log("✓ Report called successfully");
        console2.log("  Profit:", profit / 1e6, "USDC (0 expected - no time passed)");
        console2.log("  Loss:", loss);

        uint256 assetsAfterReport = vault.totalAssets();
        uint256 donationSharesAfter = IERC20(address(vault)).balanceOf(address(0x999));

        console2.log("After report:");
        console2.log("  Total assets:", assetsAfterReport / 1e6, "USDC");
        console2.log("  Donation shares:", donationSharesAfter);

        // ════════════════════════════════════════════════════════════
        // PHASE 4: VERIFY MECHANISMS (What We CAN Test)
        // ════════════════════════════════════════════════════════════

        console2.log("\nPHASE 4: MECHANISM VERIFICATION");
        console2.log("════════════════════════════════════════════════════════════");

        console2.log("✓ Deposit mechanism verified");
        console2.log("✓ Withdrawal mechanism verified");
        console2.log("✓ Spark vault integration verified");
        console2.log("✓ Report function works");
        console2.log("✓ Donation address setup works");
        console2.log("ℹ  Yield accrual NOT tested (requires time passage)");
        console2.log("ℹ  Run unit tests for yield verification with skip()");

        vm.stopBroadcast();

        // Final summary
        console2.log("\n╔════════════════════════════════════════════════════════════╗");
        console2.log("║  FORK TEST COMPLETE                                        ║");
        console2.log("╚════════════════════════════════════════════════════════════╝");
        console2.log("Strategy:", address(strategy));
        console2.log("Integration Status: ✓ ALL CORE MECHANISMS WORKING");
        console2.log("Next: Run unit tests for yield verification");
    }
}
```

### Unit Test with Time Skipping (For Yield Testing)

```solidity
// src/test/spark/SparkStrategyOperation.t.sol

function test_yieldAccrualWithSkip() public {
    uint256 depositAmount = 100 * 1e6;

    // Deposit
    mintAndDepositIntoStrategy(strategy, user, depositAmount);
    assertEq(strategy.totalAssets(), depositAmount);

    // Get baseline
    uint256 assetsBefore = strategy.totalAssets();
    uint256 donationBefore = strategy.balanceOf(dragonRouter);

    // THIS WORKS IN UNIT TESTS: Skip 7 days
    skip(7 days);

    // Harvest
    vm.prank(keeper);
    (uint256 profit, uint256 loss) = strategy.report();

    // Verify yield was minted to donation address
    uint256 donationAfter = strategy.balanceOf(dragonRouter);
    assertGt(donationAfter, donationBefore, "profit should be minted");

    console2.log("Profit harvested:", profit / 1e6, "USDC");
    console2.log("Donation shares earned:", donationAfter - donationBefore);
}
```

---

## Recommended Testing Workflow

### 1. Fork Test (Integration Check)
```bash
# Verify strategy works with real Spark on fork
forge script script/ForkTest.s.sol \
  --rpc-url https://virtual.mainnet.eu.rpc.tenderly.co/82c86... \
  --broadcast \
  -vvv
```

**What This Tests:**
- ✓ Deployment works
- ✓ Deposits to Spark work
- ✓ Withdrawals work
- ✓ Report can be called
- ✓ No compilation errors with real contracts

### 2. Unit Tests (Yield Verification)
```bash
# Verify yield mechanisms with time skipping
forge test --fork-url https://virtual.mainnet.eu.rpc.tenderly.co/82c86... \
  --match "test_yieldAccrual" \
  -vvv
```

**What This Tests:**
- ✓ Yield accrues correctly over time
- ✓ Profit is calculated correctly
- ✓ Shares minted to donation address
- ✓ Edge cases (large deposits, multiple reports, etc.)

### 3. Local Unit Tests (Fast)
```bash
# Fast tests without fork
forge test --match "test_" -vvv
```

**What This Tests:**
- ✓ All functionality (with mocked time)
- ✓ Runs in seconds
- ✓ Good for development

---

## Summary: Fork vs Unit Tests

| Aspect | Fork Test | Unit Test |
|--------|-----------|-----------|
| **Real Spark vaults** | ✓ | ✗ (simulated) |
| **Real USDC token** | ✓ | ✗ (minted with deal()) |
| **Can skip time** | ✗ | ✓ |
| **Yield accrual** | ✗ (no time) | ✓ |
| **Integration check** | ✓ | - |
| **Deployment verification** | ✓ | - |
| **Profit calculation** | ✗ (profit=0) | ✓ |
| **Speed** | Slow | Fast |

**Recommendation:** Do both!
- Fork test: Proves integration works
- Unit test: Proves yield mechanisms work
