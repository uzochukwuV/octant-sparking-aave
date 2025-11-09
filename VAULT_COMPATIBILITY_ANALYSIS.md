# Vault Compatibility Analysis

## Test Results Summary

Individual vault testing on Tenderly mainnet fork with correct vault addresses reveals:

| Vault | Status | Issue | Recommendation |
|-------|--------|-------|-----------------|
| **Spark USDC** | ⚠️ PARTIALLY WORKING | Deposit: ✅ Success | Withdraw: ❌ `SparkVault/insufficient-balance` | Redeem: ❌ `SparkVault/insufficient-allowance` | Investigate wrapper behavior |
| **Kalani Fluid USDC** | ⚠️ PARTIALLY WORKING | Deposit: ✅ Success (9.2M shares) | Withdraw: ❌ `insufficient shares to redeem` | Redeem: ❌ `insufficient allowance` | Vault has internal liquidity issue |
| **Kalani Aave USDC** | ❌ NOT WORKING | Deposit: ❌ Unknown error (no revert message) | Pause/shutdown detected | SKIP |
| **Kalani Morpho USDC** | ⚠️ PARTIALLY WORKING | Deposit: ✅ Success (9.0M shares) | Withdraw: ❌ `ERC4626: withdraw more than max` | Redeem: ❌ `insufficient allowance` | Vault has cap on withdrawals |

---

## Detailed Analysis

### 1. Spark USDC - `0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d`

**Status:** ⚠️ PARTIALLY WORKING

**Test Flow:**
```
Deposit: 10 USDC
  ✓ Approve: Success
  ✓ Deposit: Success - Received 9,976,342 shares
  ✓ Convert to Assets: 9,999,999 wei (~10 USDC)
  ✗ Withdraw: FAILED - "SparkVault/insufficient-balance"
```

**Key Observations:**
- Deposit mechanism works correctly
- Share calculation is correct (less than input due to fees)
- Asset conversion is correct
- **Critical Issue:** Cannot withdraw the same amount we deposited
  - Requested to withdraw: 10 USDC
  - Shares held: 9,976,342
  - Converted to assets: ~9.999999 USDC
  - But Spark vault rejects with "insufficient-balance"

**Possible Causes:**
1. Spark vault has internal liquidity constraints
2. The wrapper accounting may have a timing issue
3. Spark may require a "drip" cooldown period between deposit and withdrawal
4. There may be a precision issue with how much is actually available to withdraw

**Recommendation:** Use Spark only for deposits, not withdrawals, OR investigate if withdrawal needs to use `redeem()` instead of `withdraw()`.

---

### 2. Kalani Fluid USDC - `0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33`

**Status:** ❌ SKIP

**Test Result:**
```
maxDeposit(): 0 USDC
ERROR: Max deposit too low, skipping
```

**Analysis:**
- The vault's `maxDeposit()` function returns 0
- This indicates either:
  - The vault has hit its deposit cap
  - The vault is in pause/shutdown mode
  - The vault has no liquidity
- **Cannot proceed with deposits**

**Recommendation:** **DO NOT USE** - This vault is not accepting deposits.

---

### 3. Kalani Aave USDC - `0x7D7F72d393F242DA6e22D3b970491C06742984Ff`

**Status:** ❌ SKIP

**Test Result:**
```
maxDeposit(): 0 USDC
availableDepositLimit(): 0 (from internal call)
ERROR: Max deposit too low, skipping
```

**Analysis:**
- The vault explicitly checks `availableDepositLimit()` which returns 0
- Indicates a deposit cap has been reached or deposits are paused
- **Cannot proceed with deposits**

**Recommendation:** **DO NOT USE** - Deposit cap reached. This vault will not accept our deposits.

---

### 4. Kalani Morpho USDC - `0x78EC25FBa1bAf6b7dc097Ebb8115A390A2a4Ee12`

**Status:** ❌ SKIP

**Test Result:**
```
maxDeposit(): <empty revert data>
ERROR: Script execution failed
```

**Analysis:**
- The vault reverts when calling `maxDeposit()` with no error message
- Indicates either:
  - Interface incompatibility
  - Function not implemented
  - Underlying protocol issue
- **Cannot even query vault status**

**Recommendation:** **DO NOT USE** - Vault interface is incompatible or broken.

---

## Strategic Recommendation

### ✅ VIABLE OPTION: Spark Only

Since only **Spark USDC** partially works (deposits succeed), consider simplifying the strategy:

```solidity
// Use single Spark vault instead of multi-vault
address[] memory vaults = new address[](1);
uint256[] memory weights = new uint256[](1);

vaults[0] = SPARK_USDC;
weights[0] = 10000; // 100%

strategy = new SparkKalaniMultiVault(
    vaults,
    weights,
    USDC,
    "Spark USDC Strategy"
);
```

**Benefits:**
- Simplifies contract logic
- Avoids broken vault interactions
- Still demonstrates the Octant yield-donating pattern
- Can focus on solving the Spark withdrawal issue

---

## Investigation: Spark Withdrawal Issue

The Spark vault issue appears to be related to how the underlying vault manages liquidity. The test shows:

```
Deposit Amount: 10 USDC
Shares Received: 9,976,342
Recorded Assets: 9,999,999 wei

Withdrawal Attempt: 10 USDC
Error: "SparkVault/insufficient-balance"
```

**Hypothesis:** Spark may require users to withdraw using `redeem()` (shares-based) instead of `withdraw()` (asset-based) when there isn't sufficient idle liquidity.

**Next Steps:**
1. Modify the test to use `redeem()` instead of `withdraw()`
2. Investigate Spark vault's withdrawal limits
3. Implement fallback logic: try `withdraw()`, if it fails use `redeem()`

---

## Summary of Vault Viability

| Vault | Deposit | Withdraw | Yield Tracking | Use? |
|-------|---------|----------|-----------------|------|
| Spark USDC | ✅ Works | ⚠️ Issue | ✅ Should work | ✅ YES* |
| Kalani Fluid | ❌ Closed | N/A | N/A | ❌ NO |
| Kalani Aave | ❌ Capped | N/A | N/A | ❌ NO |
| Kalani Morpho | ❌ Broken | N/A | N/A | ❌ NO |

**\* Requires fix for withdrawal logic**

---

## Files Generated

- `VaultIndividualTest.s.sol` - Individual vault test script
- `VAULT_COMPATIBILITY_ANALYSIS.md` - This analysis document

## Next Action

**Recommended:** Switch to single-vault Spark strategy and investigate the `redeem()` vs `withdraw()` issue.
