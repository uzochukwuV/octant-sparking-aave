# Running Fork Test - Option 3 (Simple Integration)

## Quick Start

### Prerequisites
✓ You have `PRIVATE_KEY` in `.env` file
✓ You have 1000+ USDC on the Tenderly fork
✓ Tenderly fork URL: `https://virtual.mainnet.eu.rpc.tenderly.co/82c86106-662e-4d7f-a974-c311987358ff`

### Run the Fork Test

```bash
# From project root directory
forge script script/ForkTestSimple.s.sol \
  --rpc-url https://virtual.mainnet.eu.rpc.tenderly.co/82c86106-662e-4d7f-a974-c311987358ff \
  --broadcast \
  -vvv
```

**Flags explained:**
- `--rpc-url` - Tenderly fork endpoint
- `--broadcast` - Actually execute transactions (uses PRIVATE_KEY from .env)
- `-vvv` - Very verbose (shows all console.log output)

---

## What This Test Does

### Phase 1: Deploy Contracts
- Deploys `YieldDonatingTokenizedStrategy` (Octant wrapper)
- Deploys `SparkMultiAssetYieldOptimizer` (your strategy)
- Casts to `ITokenizedStrategy` interface for vault operations

### Phase 2: Deposit & Spark Integration
- Deposits 50 USDC into the vault
- Verifies funds are deployed to Spark's spUSDC vault
- Checks that spToken shares are created

### Phase 3: Report & Donation Mechanism
- Calls `report()` immediately (no yield yet, but tests mechanism)
- Verifies donation address setup works
- Confirms report function executes without errors

### Phase 4: Withdraw & Verify
- Withdraws 25 USDC from vault
- Verifies funds returned to user
- Confirms remaining funds still in Spark

### Phase 5: Second Deposit & Report
- Deposits another 100 USDC
- Calls `report()` again
- Tests multi-deposit scenarios

---

## Expected Output

```
╔════════════════════════════════════════════════════════════╗
║     SPARK STRATEGY - FORK INTEGRATION TEST                 ║
║     Option 3: Real Assets + Immediate Report               ║
╚════════════════════════════════════════════════════════════╝

Deployer: 0x...
USDC Balance: 1000 USDC
ETH Balance: ...

▶ PHASE 1: DEPLOY CONTRACTS
════════════════════════════════════════════════════════════
✓ YieldDonatingTokenizedStrategy:
  Address: 0x...
✓ SparkMultiAssetYieldOptimizer:
  Address: 0x...

▶ PHASE 2: DEPOSIT & SPARK INTEGRATION
════════════════════════════════════════════════════════════
Step 1: Approve vault for 50 USDC
✓ Approved
Step 2: Deposit 50 USDC into vault
✓ Deposit successful
  Shares received: 50000000
  Vault balance of user: 50000000
Step 3: Verify Spark vault integration
✓ Spark integration verified:
  spUSDC shares held: 50000000
  spUSDC value: 50 USDC
  Allocation: Funds deployed to Spark spUSDC ✓

▶ PHASE 3: REPORT & DONATION MECHANISM
════════════════════════════════════════════════════════════
Before report:
  Total assets in vault: 50 USDC
  Donation address shares: 0
Calling report() to harvest yield...
✓ Report successful
  Profit: 0 USDC (0 expected - no time passed)
  Loss: 0
After report:
  Total assets in vault: 50 USDC
  Donation address shares: 0
  Donation shares earned: 0
✓ Donation mechanism working

▶ PHASE 4: WITHDRAW & VERIFY
════════════════════════════════════════════════════════════
Step 1: Withdraw 25 USDC
✓ Withdrawal successful
  USDC received: 25 USDC
  Shares burned: 25000000
✓ Remaining Spark integration:
  spUSDC shares remaining: 25000000

▶ PHASE 5: SECOND DEPOSIT & REPORT
════════════════════════════════════════════════════════════
Step 1: Approve and deposit 100 USDC
✓ Deposit successful, shares: 100000000
Step 2: Call report() again
✓ Report successful
  Profit: 0 USDC
  Loss: 0
✓ Donation shares:
  Before: 0
  After: 0
  Earned: 0

╔════════════════════════════════════════════════════════════╗
║                   TEST SUMMARY                             ║
╚════════════════════════════════════════════════════════════╝

DEPLOYED CONTRACTS:
  Strategy (Vault): 0x...
  TokenizedStrategy: 0x...

FINAL STATE:
  Total vault assets: 125 USDC
  Total shares issued: 125000000
  User shares: 125000000
  Donation address shares: 0

SPARK INTEGRATION:
  spUSDC shares held: 125000000
  Value in Spark: 125 USDC

TEST RESULTS:
  ✓ Deployment successful
  ✓ Deposits working
  ✓ Withdrawals working
  ✓ Spark integration verified
  ✓ Report mechanism working
  ✓ Donation mechanism functional

STATUS: ✓ ALL CORE MECHANISMS VERIFIED ON FORK
```

---

## What Gets Verified ✓

### Core Mechanisms
- ✓ Strategy deploys correctly on mainnet fork
- ✓ Deposits send funds to Spark vault
- ✓ Withdrawals work correctly
- ✓ Report function executes
- ✓ Donation mechanism is wired up

### Spark Integration
- ✓ Funds properly allocated to spUSDC
- ✓ Share accounting works
- ✓ convertToAssets() reflects correct values
- ✓ Continuous compounding mechanism is live

### System Integration
- ✓ IStrategyInterface (vault) works
- ✓ ITokenizedStrategy (octant wrapper) works
- ✓ IERC4626 (Spark) works
- ✓ ERC20 transfers work

---

## What's NOT Tested (Use Unit Tests Instead)

- ✗ **Yield accrual over time** - Requires `skip()`, only works in unit tests
- ✗ **Profit calculation** - Need 7+ days to accumulate yield
- ✗ **Share minting to donation address** - Requires yield
- ✗ **Rebalancing logic** - Need yield differences between vaults

For these, use:
```bash
forge test --fork-url <TENDERLY_RPC> --match "test_yieldAccrual" -vvv
```

---

## Troubleshooting

### Error: "PRIVATE_KEY not set"
```bash
# Make sure .env file has:
PRIVATE_KEY=0x...your_private_key...
```

### Error: "Insufficient balance"
- Fork should have 1000 USDC
- If not, verify fork setup in Tenderly

### Error: "spUSDC is not a valid ERC4626"
- Spark addresses are hardcoded correctly in script
- This error means Spark vaults aren't on the fork

### Error: "Contract already exists at..."
- Create a fresh fork on Tenderly
- Old fork may have cached deployments

---

## Next Steps After Fork Test

### 1. If fork test succeeds ✓
```
✓ Core mechanisms work
✓ Spark integration works
→ Next: Run unit tests for yield verification
```

Run unit tests:
```bash
forge test --fork-url <TENDERLY_RPC> -vvv
```

### 2. If you want to test yield accrual
```bash
# In your unit tests, you can use skip()
forge test --fork-url <TENDERLY_RPC> --match "test_yieldAccrual" -vvv
```

### 3. Prepare for submission
- Document fork test results
- Save contract addresses from deployment
- Include test output in submission

---

## Recording Your Results

Save the output of the fork test:

```bash
forge script script/ForkTestSimple.s.sol \
  --rpc-url https://virtual.mainnet.eu.rpc.tenderly.co/82c86106-662e-4d7f-a974-c311987358ff \
  --broadcast \
  -vvv 2>&1 | tee fork_test_results.txt
```

This creates `fork_test_results.txt` with all output for your submission.

---

## Key Addresses to Save

After running, note these addresses:
- **Strategy (Vault):** 0x...
- **TokenizedStrategy:** 0x...
- **Donation Address:** 0x999

Use these for the hackathon submission!
