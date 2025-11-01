# YieldDonating Strategy Development Guide for Octant

This repository provides a template for creating **YieldDonating strategies** compatible with Octant's ecosystem using [Foundry](https://book.getfoundry.sh/). YieldDonating strategies donate all generated yield to a donation address.

## What is a YieldDonating Strategy?

YieldDonating strategies are designed to:
- Deploy assets into external yield sources (Aave, Compound, Yearn vaults, etc.)
- Harvest yield and donate 100% of profits to public goods funding
- Optionally protect users from losses by burning dragonRouter shares
- Charge NO performance fees to users

## Getting Started

### Prerequisites

1. Install [Foundry](https://book.getfoundry.sh/getting-started/installation) (WSL recommended for Windows)
2. Install [Node.js](https://nodejs.org/en/download/package-manager/)
3. Clone this repository:
```sh
git clone --recursive https://github.com/golemfoundation/octant-v2-tokenized-strategy-foundry-mix
cd octant-v2-tokenized-strategy-foundry-mix

# TEMPORARY: Install octant-v2-core dependencies (needed until remapping issue with forge is resolved)
cd lib/octant-v2-core && forge soldeer install && cd ../..

forge install
```

### Environment Setup

1. Copy `.env.example` to `.env`
2. Set the required environment variables:
```env
# Required for testing
TEST_ASSET_ADDRESS=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48  # USDC on mainnet
TEST_YIELD_SOURCE=0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2   # Your yield source address

# RPC URLs
ETH_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_API_KEY  # Get your key from infura.io
```

## Strategy Development Step-by-Step

### 1. Understanding the Template Structure

The YieldDonating strategy template (`src/strategies/yieldDonating/YieldDonatingStrategy.sol`) contains:
- **Constructor parameters** you need to provide
- **Mandatory functions** (marked with TODO) you MUST implement
- **Optional functions** you can override if needed
- **Built-in functionality** for profit donation and loss protection

### 2. Define Your Yield Source Interface

First, implement the `IYieldSource` interface for your specific protocol:

```solidity
// TODO: Replace with your yield source interface
interface IYieldSource {
    // Example for Aave V3:
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    
    // Example for ERC4626 vaults:
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
}
```

### 3. Implement Mandatory Functions

You MUST implement these three core functions:

#### A. `_deployFunds(uint256 _amount)`
Deploy assets into your yield source:
```solidity
function _deployFunds(uint256 _amount) internal override {
    // Example for Aave:
    yieldSource.supply(address(asset), _amount, address(this), 0);
    
    // Example for ERC4626:
    // IERC4626(address(yieldSource)).deposit(_amount, address(this));
}
```

#### B. `_freeFunds(uint256 _amount)`
Withdraw assets from your yield source:
```solidity
function _freeFunds(uint256 _amount) internal override {
    // Example for Aave:
    yieldSource.withdraw(address(asset), _amount, address(this));
    
    // Example for ERC4626:
    // uint256 shares = IERC4626(address(yieldSource)).convertToShares(_amount);
    // IERC4626(address(yieldSource)).redeem(shares, address(this), address(this));
}
```

#### C. `_harvestAndReport()`
Calculate total assets held by the strategy:
```solidity
function _harvestAndReport() internal override returns (uint256 _totalAssets) {
    // 1. Get assets deployed in yield source
    uint256 deployedAssets = yieldSource.balanceOf(address(this));
    
    // 2. Get idle assets in strategy
    uint256 idleAssets = asset.balanceOf(address(this));
    
    // 3. Return total (MUST include both deployed and idle)
    _totalAssets = deployedAssets + idleAssets;
    
    // Note: Profit/loss is calculated automatically by comparing
    // with previous totalAssets. Profits are minted to dragonRouter.
}
```

### 4. Optional Functions

Override these functions based on your strategy's needs:

#### `availableDepositLimit(address _owner)`
Implement deposit limits if needed:
```solidity
function availableDepositLimit(address) public view override returns (uint256) {
    // Example: Cap at protocol's lending capacity
    uint256 protocolCapacity = yieldSource.availableCapacity();
    return protocolCapacity;
}
```

#### `availableWithdrawLimit(address _owner)`
Implement withdrawal limits:
```solidity
function availableWithdrawLimit(address) public view override returns (uint256) {
    // Example: Limited by protocol's available liquidity
    return yieldSource.availableLiquidity();
}
```

#### `_emergencyWithdraw(uint256 _amount)`
Emergency withdrawal logic when strategy is shutdown:
```solidity
function _emergencyWithdraw(uint256 _amount) internal override {
    // Force withdraw from yield source
    yieldSource.emergencyWithdraw(_amount);
}
```

#### `_tend(uint256 _totalIdle)` and `_tendTrigger()`
For maintenance between reports:
```solidity
function _tend(uint256 _totalIdle) internal override {
    // Example: Deploy idle funds if above threshold
    if (_totalIdle > minDeployAmount) {
        _deployFunds(_totalIdle);
    }
}

function _tendTrigger() internal view override returns (bool) {
    // Return true when tend should be called
    return asset.balanceOf(address(this)) > minDeployAmount;
}
```

### 5. Constructor Parameters

When deploying your strategy, provide these parameters:
- `_yieldSource`: Address of your yield protocol (Aave, Compound, etc.)
- `_asset`: The token to be managed (USDC, DAI, etc.)
- `_name`: Your strategy name (e.g., "USDC Aave YieldDonating")
- `_management`: Address that can configure the strategy
- `_keeper`: Address that can call report() and tend()
- `_emergencyAdmin`: Address that can shutdown the strategy
- `_donationAddress`: The dragonRouter address (receives minted profit shares)
- `_enableBurning`: Whether to enable loss protection via share burning
- `_tokenizedStrategyAddress`: YieldDonatingTokenizedStrategy implementation

## Testing Your Strategy

### 1. Update Test Configuration

Modify `src/test/yieldDonating/YieldDonatingSetup.sol`:
- Set your yield source interface and mock
- Adjust test parameters as needed

### 2. Run Tests

```sh
# Run all YieldDonating tests
make test

# Run specific test file
make test-contract contract=YieldDonatingOperation

# Run with traces for debugging
make trace
```

### 3. Key Test Scenarios

Your tests should verify:
- ✅ Assets are correctly deployed to yield source
- ✅ Withdrawals work for various amounts
- ✅ Profits are minted to dragonRouter (not kept by strategy)
- ✅ Losses trigger dragonRouter share burning (if enabled)
- ✅ Emergency withdrawals work when shutdown
- ✅ Deposit/withdraw limits are enforced

## Common Implementation Examples


### ERC4626 Vault Strategy
```solidity
function _deployFunds(uint256 _amount) internal override {
    IERC4626(address(yieldSource)).deposit(_amount, address(this));
}

function _harvestAndReport() internal override returns (uint256 _totalAssets) {
    uint256 shares = IERC4626(address(yieldSource)).balanceOf(address(this));
    uint256 vaultAssets = IERC4626(address(yieldSource)).convertToAssets(shares);
    uint256 idleAssets = asset.balanceOf(address(this));
    
    _totalAssets = vaultAssets + idleAssets;
}
```

## Deployment Checklist

- [ ] Implement all TODO functions in the strategy
- [ ] Update IYieldSource interface for your protocol
- [ ] Set up proper token approvals in constructor
- [ ] Test all core functionality
- [ ] Test profit donation to dragonRouter
- [ ] Test loss protection if enabled
- [ ] Verify emergency shutdown procedures


## Key Differences from Standard Tokenized Strategies

| Feature | Standard Strategy | YieldDonating Strategy |
|---------|------------------|----------------------|
| Performance Fees | Charges fees to LPs | NO fees - all yield donated |
| Profit Distribution | Kept by strategy/fees | Minted as shares to dragonRouter |
| Loss Protection | Users bear losses | Optional burning of dragon shares |
| Use Case | Maximize LP returns | Public goods funding |


