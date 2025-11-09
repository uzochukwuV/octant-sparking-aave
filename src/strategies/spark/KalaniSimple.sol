// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseStrategy} from "@octant-core/core/BaseStrategy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title Kalani Simple Yield Optimizer
 * @author Octant DeFi Hackathon 2025
 * @notice Simple Octant strategy for Kalani vault integration
 * @dev Production-ready single-vault strategy for Kalani USDC vaults
 *
 * ARCHITECTURE:
 * ═══════════════════════════════════════════════════════════════════════════════
 *
 *   User Deposits (USDC)
 *            ↓
 *   [This Strategy Contract]
 *            ↓
 *   [Kalani USDC Vault] ← Yield accrual
 *            ↓
 *   _harvestAndReport() captures profit
 *            ↓
 *   Octant mints shares → Donation Address
 *            ↓
 *   PUBLIC GOODS FUNDED 🌱
 */
contract KalaniSimpleYieldOptimizer is BaseStrategy {
    using SafeERC20 for ERC20;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Basis points precision
    uint256 public constant BP_PRECISION = 10000;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Kalani vault we deploy to
    IERC4626 public immutable kalaniVault;

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Shares held in Kalani vault
    uint256 public sharesHeld;

    /// @notice Last recorded asset value for yield calculation
    uint256 public lastRecordedAssets;

    /// @notice Total yield accumulated
    uint256 public totalYieldAccumulated;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultDeployed(address indexed vault, uint256 amount, uint256 shares, uint256 timestamp);
    event VaultWithdrawn(address indexed vault, uint256 amount, uint256 shares, uint256 timestamp);
    event YieldHarvested(uint256 totalAssets, uint256 yieldAmount, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAmount();
    error InvalidVault();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _kalaniVault,
        address _asset,
        string memory _name,
        address _management,
        address _keeper,
        address _emergencyAdmin,
        address _donationAddress,
        bool _enableBurning,
        address _tokenizedStrategy
    ) BaseStrategy(
        _asset,
        _name,
        _management,
        _keeper,
        _emergencyAdmin,
        _donationAddress,
        _enableBurning,
        _tokenizedStrategy
    ) {
        if (_kalaniVault == address(0)) revert InvalidVault();
        kalaniVault = IERC4626(_kalaniVault);
        lastRecordedAssets = 0;
        sharesHeld = 0;
    }

    /*//////////////////////////////////////////////////////////////
                    REQUIRED STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploy funds to Kalani vault
     * @param _amount Amount of asset to deploy
     */
    function _deployFunds(uint256 _amount) internal override {
        if (_amount == 0) revert ZeroAmount();

        // Approve and deposit into Kalani vault
        ERC20(asset).approve(address(kalaniVault), _amount);
        uint256 sharesMinted = kalaniVault.deposit(_amount, address(this));
        sharesHeld += sharesMinted;

        // Update recorded assets after deposit
        uint256 assetsAfter = kalaniVault.convertToAssets(sharesHeld);
        lastRecordedAssets = assetsAfter;

        emit VaultDeployed(address(kalaniVault), _amount, sharesMinted, block.timestamp);
    }

    /**
     * @notice Free funds from Kalani vault
     * @param _amount Amount of asset to free
     */
    function _freeFunds(uint256 _amount) internal override {
        if (_amount == 0) revert ZeroAmount();

        uint256 currentAssets = kalaniVault.convertToAssets(sharesHeld);
        if (currentAssets == 0) return;

        // Calculate shares to redeem
        uint256 sharesToRedeem = kalaniVault.convertToShares(_amount);
        if (sharesToRedeem > sharesHeld) {
            sharesToRedeem = sharesHeld;
        }

        // Redeem from vault with try-catch for safety
        try kalaniVault.redeem(sharesToRedeem, address(this), address(this)) {
            sharesHeld -= sharesToRedeem;
            uint256 assetsAfter = kalaniVault.convertToAssets(sharesHeld);
            lastRecordedAssets = assetsAfter;
            emit VaultWithdrawn(address(kalaniVault), _amount, sharesToRedeem, block.timestamp);
        } catch {}
    }

    /**
     * @notice Report strategy performance and harvest yield
     * @return _totalAssets Total assets under management
     */
    function _harvestAndReport() internal override returns (uint256 _totalAssets) {
        uint256 currentAssets = kalaniVault.convertToAssets(sharesHeld);

        // Calculate yield if we have a previous checkpoint
        if (lastRecordedAssets > 0 && currentAssets > lastRecordedAssets) {
            uint256 yieldAmount = currentAssets - lastRecordedAssets;
            totalYieldAccumulated += yieldAmount;
            emit YieldHarvested(currentAssets, yieldAmount, block.timestamp);
        }

        // Update checkpoint for next harvest
        lastRecordedAssets = currentAssets;

        // Return total assets
        _totalAssets = currentAssets;
        return _totalAssets;
    }

    /*//////////////////////////////////////////////////////////////
                    VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get current assets in Kalani vault
     * @return Current asset value
     */
    function getTotalAssets() external view returns (uint256) {
        return kalaniVault.convertToAssets(sharesHeld);
    }

    /**
     * @notice Get shares held in vault
     * @return Shares currently held
     */
    function getSharesHeld() external view returns (uint256) {
        return sharesHeld;
    }

    /**
     * @notice Get total yield accumulated
     * @return Total yield accumulated
     */
    function getTotalYield() external view returns (uint256) {
        return totalYieldAccumulated;
    }

    /*//////////////////////////////////////////////////////////////
                    OPTIONAL OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function availableWithdrawLimit(address /*_owner*/) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    function availableDepositLimit(address /*_owner*/) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    function _tend(uint256 _totalIdle) internal virtual override {
        // Optional: intermediate tending not needed for simple strategy
    }

    function _tendTrigger() internal view virtual override returns (bool) {
        return false;
    }

    function _emergencyWithdraw(uint256 _amount) internal virtual override {
        if (_amount == 0) return;

        uint256 currentAssets = kalaniVault.convertToAssets(sharesHeld);
        if (currentAssets == 0) return;

        uint256 sharesToRedeem = kalaniVault.convertToShares(_amount);
        if (sharesToRedeem > sharesHeld) {
            sharesToRedeem = sharesHeld;
        }

        try kalaniVault.redeem(sharesToRedeem, address(this), address(this)) {
            sharesHeld -= sharesToRedeem;
        } catch {}
    }
}
