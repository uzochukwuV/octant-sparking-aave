# Spark Multi-Asset Yield Optimizer - Deployment Configuration

## Network: Ethereum Mainnet

### Spark Vault Addresses (Verified on Etherscan)
```
spUSDC: 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d
spUSDT: 0xe2e7a17dFf93280dec073C995595155283e3C372
spETH:  0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f
```

### Underlying Asset Addresses
```
USDC: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDT: 0xdAC17F958D2ee523a2206206994597C13D831ec7
WETH: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
```

### Octant V2 Core Contracts (To be updated)
```
BaseStrategy: [From Octant template]
YieldDonatingTokenizedStrategy: [From Octant template]
```

## Deployment Steps

### 1. Deploy for USDC (Primary Strategy)
```solidity
SparkMultiAssetYieldOptimizer(
    _sparkUSDC: 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d,
    _sparkUSDT: 0xe2e7a17dFf93280dec073C995595155283e3C372,
    _sparkETH:  0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f,
    _usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
    _usdt: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
    _weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
    _primaryAsset: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
    _name: "Spark USDC Yield Optimizer",
    _management: <YOUR_MANAGEMENT_ADDRESS>,
    _keeper: <YOUR_KEEPER_ADDRESS>,
    _emergencyAdmin: <YOUR_EMERGENCY_ADMIN>,
    _donationAddress: <OCTANT_DONATION_ADDRESS>,
    _enableBurning: false,
    _tokenizedStrategyAddress: <OCTANT_TOKENIZED_STRATEGY>
)
```

### 2. Deploy for USDT (Optional)
Same as above but use USDT as `_primaryAsset`

### 3. Deploy for ETH (Optional)
Same as above but use WETH as `_primaryAsset`

## Testing Checklist

### Unit Tests
- [ ] Constructor initialization
- [ ] Deposit funds to Spark
- [ ] Withdraw funds from Spark
- [ ] Harvest and report yield
- [ ] APY estimation
- [ ] Rebalancing logic
- [ ] Emergency withdrawal
- [ ] Deposit/withdraw limits

### Integration Tests (Mainnet Fork)
- [ ] Deploy with real Spark addresses
- [ ] Deposit 10k USDC, verify spUSDC shares
- [ ] Fast-forward time, verify yield accrual
- [ ] Withdraw funds, verify correct amount
- [ ] Test continuous compounding (chi mechanism)
- [ ] Test with low Spark liquidity
- [ ] Test deposit cap limits

### Gas Optimization
- [ ] Measure deployment cost
- [ ] Measure deposit gas
- [ ] Measure withdraw gas
- [ ] Measure rebalance gas
- [ ] Measure harvest gas

## Prize Submission Checklist

### Best Use of Spark ($1,500)
- [ ] Deep integration with Spark VSR mechanism
- [ ] Handles continuous compounding correctly
- [ ] Respects Spark's liquidity layer (TAKER_ROLE)
- [ ] Documentation of Spark integration
- [ ] Demo video showing continuous yield accrual

### Best Yield Donating Strategy ($2,000 x2)
- [ ] 100% of yield goes to donation address
- [ ] Optimal yield routing via auto-rebalancing
- [ ] Clear policy description
- [ ] Tested profit donation flow

### Best Use of Kalani ($2,500)
- [ ] Contract is ERC-4626 compliant
- [ ] Can be deployed on Kalani platform
- [ ] Follows Yearn v3 TokenizedStrategy pattern
- [ ] Documentation for Kalani deployment

### Most Creative ($1,500)
- [ ] Novel continuous compounding for public goods
- [ ] Multi-asset optimization
- [ ] Unique mechanism explanation

### Best Public Goods ($1,500 x2)
- [ ] Maximizes public goods funding
- [ ] Clear impact metrics
- [ ] Sustainable funding model

### Best Tutorial ($1,500)
- [ ] Comprehensive README
- [ ] Architecture diagrams
- [ ] Code walkthrough video
- [ ] Integration guide

## Monitoring & Metrics

### Key Metrics to Track
```
- Total Value Locked (TVL)
- Current APY
- Total Yield Generated
- Yield Donated to Public Goods
- Number of Rebalances
- Gas Costs
- Active Vault
```

### Dashboard Ideas
```
- Real-time APY across all Spark vaults
- Historical yield chart
- Rebalance history
- Public goods funding impact
- Comparison vs single-vault strategies
```

## Security Considerations

### Audited Components
- ✅ Spark Vaults V2 (audited by Spark)
- ✅ OpenZeppelin ERC20/ERC4626 (battle-tested)
- ✅ Octant BaseStrategy (Octant team)

### Custom Logic to Review
- [ ] Rebalancing logic
- [ ] APY estimation
- [ ] Emergency withdrawal
- [ ] Access controls

### Known Limitations
- Spark TAKER_ROLE can deploy liquidity (may cause temporary withdrawal failures)
- Deposit caps may limit strategy capacity
- Cross-asset swaps not implemented (single-asset per deployment)
- APY estimation is simplified (production needs historical tracking)

## Post-Deployment

### Initial Setup
1. Deploy strategy contract
2. Verify on Etherscan
3. Set management roles
4. Fund with initial capital (test with 1k USDC first)
5. Monitor for 24 hours
6. Scale up capital

### Ongoing Maintenance
- Monitor Spark VSR changes
- Check for rebalancing opportunities
- Track public goods funding impact
- Respond to any Spark liquidity constraints

## Resources

- Spark Docs: https://docs.spark.fi/dev/savings/spark-vaults-v2
- Octant Docs: https://docs.v2.octant.build/
- Etherscan: https://etherscan.io/
- GitHub Repo: [To be created]