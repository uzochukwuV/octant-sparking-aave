# Fork Testing Guide - Tenderly

Complete guide to deploy and test your Spark strategy on a Tenderly forked mainnet.

## Prerequisites

You have:
- ✅ 1000 USDC on the fork
- ✅ 10 ETH on the fork
- ✅ Private key in `.env` file
- ✅ Tenderly fork RPC: `https://virtual.mainnet.eu.rpc.tenderly.co/82c86106-662e-4d7f-a974-c311987358ff`

## Step 1: Verify Your .env Setup

Your `.env` file should contain:
```bash
PRIVATE_KEY=0x...your_private_key...
```

If not, add it now.

## Step 2: Understand the Test Script

The test script does 4 phases:

### Phase 1: Deployment
- Deploys `YieldDonatingTokenizedStrategy` (Octant wrapper)
- Deploys `SparkMultiAssetYieldOptimizer` strategy
- Primary asset: USDC
- All roles (management, keeper, emergency admin) set to your address

### Phase 2: Basic Functionality (50 USDC)
- Deposits 50 USDC into strategy
- Checks that funds are deployed to Spark (spUSDC)
- Withdraws 25 USDC back
- Verifies everything works

### Phase 3: Yield Accrual (200 USDC)
- Deposits 200 USDC
- Skips 7 days in time
- Calls `report()` to harvest yield
- Verifies profit was minted to donation address
- Shows continuous compounding working

### Phase 4: Emergency Shutdown (100 USDC)
- Deposits 100 USDC
- Triggers emergency shutdown
- Verifies shutdown status

**Total USDC used: 350 USDC (you have 1000, so plenty)**

## Step 3: Run the Test

### Option A: Using Foundry (Recommended)

```bash
# From your project root directory
cd c:\Users\ASUS FX95G\Documents\web3\spark_vault

# Run the test script with your private key from .env
forge script script/DeployAndTest.s.sol \
  --rpc-url https://virtual.mainnet.eu.rpc.tenderly.co/82c86106-662e-4d7f-a974-c311987358ff \
  --broadcast \
  -vvv
```

**Explanation of flags:**
- `--rpc-url` - Tenderly fork endpoint
- `--broadcast` - Actually send transactions (uses PRIVATE_KEY from .env)
- `-vvv` - Very verbose output (shows all console.log outputs)

### Option B: Without Broadcasting (Dry Run)

To see what would happen without actually sending transactions:

```bash
forge script script/DeployAndTest.s.sol \
  --rpc-url https://virtual.mainnet.eu.rpc.tenderly.co/82c86106-662e-4d7f-a974-c311987358ff \
  -vvv
```

(Remove the `--broadcast` flag)

## Step 4: Interpret the Output

### Expected Console Output

```
╔════════════════════════════════════════════════════════════╗
║   SPARK STRATEGY - DEPLOY & TEST ON TENDERLY FORK          ║
╚════════════════════════════════════════════════════════════╝

Your Address: 0x...
USDC Balance: 1000 USDC
...

▶ PHASE 1: DEPLOYING CONTRACTS
════════════════════════════════════════════════════════════
Deploying YieldDonatingTokenizedStrategy...
✓ TokenizedStrategy: 0x...
Deploying SparkMultiAssetYieldOptimizer...
✓ Strategy: 0x...

▶ PHASE 2: BASIC FUNCTIONALITY TEST
════════════════════════════════════════════════════════════
Test: Deposit & Withdraw
Your USDC balance: 1000 USDC
Approving strategy for 50 USDC...
✓ Approved
Depositing 50 USDC...
✓ Deposit successful
Shares received: 50000000
Funds in Spark:
  spUSDC shares: ...
  Value: 50 USDC
Withdrawing 25 USDC...
✓ Withdrawal successful
  Received: 25 USDC

▶ PHASE 3: YIELD ACCRUAL TEST
════════════════════════════════════════════════════════════
Test: Continuous Yield Accrual
Approving for yield test...
Depositing 200 USDC...
✓ Deposit successful
Total assets: 225 USDC
Donation address shares: 0
Skipping 7 days...
✓ Time advanced
Calling report() to harvest yield...
✓ Report successful
  Profit: X USDC
  Loss: 0
After harvest:
  Total assets: 225 USDC
  Donation shares earned: Y
  ✓ Profit successfully donated to public goods!

▶ PHASE 4: EMERGENCY SHUTDOWN TEST
════════════════════════════════════════════════════════════
Test: Emergency Shutdown
...
✓ Emergency shutdown triggered

▶ FINAL SUMMARY
════════════════════════════════════════════════════════════
Deployment Complete!
Contract Addresses:
  Strategy: 0x...
  TokenizedStrategy: 0x...
Strategy State:
  Total Assets: 350 USDC
  Total Shares: ...
  Donation Address Shares: Y
Spark Integration:
  spUSDC Shares: ...
  Value in Spark: 350 USDC
✓ All phases completed successfully!
✓ Spark continuous compounding working!
✓ Yield donation flow operational!
```

### What to Look For

✅ **Success Indicators:**
1. All contracts deployed with addresses printed
2. "Deposit successful" messages in Phase 2
3. "Withdrawal successful" in Phase 2
4. Shares deployed to Spark vault (spUSDC)
5. "Profit successfully donated" in Phase 3
6. "Donation shares earned" > 0 in Phase 3
7. Emergency shutdown triggered in Phase 4

❌ **Error Indicators:**
- Transaction reverts with error message
- "Deposit failed" or similar
- Zero donation shares after harvest
- Fund amounts not matching

## Step 5: If Something Goes Wrong

### Common Issues & Fixes

**Issue: "PRIVATE_KEY not set"**
- Check your `.env` file has `PRIVATE_KEY=0x...`
- Make sure you're running from the correct directory

**Issue: "Contract already exists at..."**
- The fork might have leftover state
- Create a fresh fork and try again

**Issue: "Insufficient balance"**
- You should have 1000 USDC on the fork
- Check with: `cast balance 0xYourAddress --rpc-url <RPC>`

**Issue: "spUSDC vault not found"**
- Verify Spark addresses are correct (they're hardcoded in the script)
- Try running on Tenderly's web interface first

### Debugging Commands

Check USDC balance:
```bash
cast balance $(cast sig 'balanceOf(address)' 0xYourAddress) \
  --rpc-url https://virtual.mainnet.eu.rpc.tenderly.co/82c86106-662e-4d7f-a974-c311987358ff
```

Check Spark vault state:
```bash
cast call 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d \
  "totalAssets()" \
  --rpc-url https://virtual.mainnet.eu.rpc.tenderly.co/82c86106-662e-4d7f-a974-c311987358ff
```

## Step 6: Record Your Results

After running, save:

1. **Contract Addresses:**
   - Strategy: `0x...`
   - TokenizedStrategy: `0x...`

2. **Test Results:**
   - Deposits: ✓ Successful
   - Yields: ✓ Accruing
   - Donations: ✓ Being minted
   - Emergency shutdown: ✓ Working

3. **Key Metrics:**
   - Total assets after test
   - Donation shares earned
   - Profit percentage

## Step 7: For Your Submission

Create a file called `FORK_TEST_RESULTS.md` with:

```markdown
# Fork Test Results

## Test Environment
- Fork: Tenderly Mainnet Fork
- Date: [Date you ran test]
- Network: Ethereum Mainnet

## Deployed Contracts
- Strategy: [address]
- TokenizedStrategy: [address]

## Test Results
- Phase 1 (Deployment): ✓ PASSED
- Phase 2 (Basic Functionality): ✓ PASSED
- Phase 3 (Yield Accrual): ✓ PASSED
- Phase 4 (Emergency Shutdown): ✓ PASSED

## Key Findings
- Total assets: X USDC
- Donation shares earned: Y
- Spark integration: Working perfectly
- Continuous compounding: Verified

## Transaction Details
[Include 4 main transaction hashes from broadcast output]
```

## Next Steps

After successful fork testing:

1. ✅ Test passes on fork
2. ⏳ Deploy on testnet (Sepolia) - *optional*
3. ⏳ Create submission documentation
4. ⏳ Prepare demo video (3-5 minutes)
5. ⏳ Submit to hackathon

## Questions?

Refer back to [CONSTRUCTOR_ANALYSIS.md](./CONSTRUCTOR_ANALYSIS.md) for parameter explanations.

---

**Good luck with your fork testing!** 🚀
