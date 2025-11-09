// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC4626, ERC20, IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AaveERC4626Vault
 * @author Octant DeFi
 * @notice Production-grade ERC-4626 vault wrapping Aave V3 deposits
 * @dev Deposits underlying assets into Aave V3 Pool, mints ERC-4626 shares to users
 *
 * ARCHITECTURE:
 * ═══════════════════════════════════════════════════════════════════════════════
 * User Deposits USDC
 *    ↓
 * AaveERC4626Vault (ERC-4626 compliant)
 *    ├─ Tracks user shares
 *    ├─ Manages fee collection
 *    └─ Handles rebalancing
 *    ↓
 * Aave V3 Pool (0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2)
 *    ├─ supply(asset, amount, recipient, referral)
 *    └─ withdraw(asset, amount, recipient)
 *    ↓
 * aToken (e.g., aUSDC at 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c)
 *    └─ Balance grows automatically with accrued interest
 *
 * KEY FEATURES:
 * ✓ ERC-4626 standard interface
 * ✓ Automatic yield accrual via aToken balance growth
 * ✓ Performance fee collection (configurable)
 * ✓ Pausable for emergency situations
 * ✓ Deposit cap to limit risk
 * ✓ Emergency withdrawal mechanism
 * ✓ Safe ERC20 transfer handling
 * ✓ Reentrancy protection
 * ✓ Full accounting transparency
 */

// Minimal IPool interface for Aave V3
interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

contract AaveERC4626Vault is ERC4626, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Aave V3 Pool address (Ethereum mainnet)
    address public constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    /// @notice Basis points denominator (10000 = 100%)
    uint16 public constant BPS_MAX = 10000;

    /// @notice Aave referral code (0 for no referral)
    uint16 public constant AAVE_REFERRAL_CODE = 0;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice aToken address (e.g., aUSDC)
    address public aToken;

    /// @notice Fee basis points (100 = 1%)
    uint16 public feeBps = 0;

    /// @notice Address receiving accrued fees
    address public feeCollector;

    /// @notice Total fees accrued (in underlying assets)
    uint256 public totalFeesAccrued;

    /// @notice Last recorded total assets for fee computation
    uint256 public lastTotalAssets;

    /// @notice Maximum total assets vault can hold
    uint256 public vaultCap;

    /// @notice Timestamp of last fee accrual
    uint256 public lastAccrualTimestamp;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeeAccrued(uint256 feeInAssets, uint256 feeInShares, uint256 timestamp);
    event FeeCollectorUpdated(address indexed newCollector);
    event FeeBpsUpdated(uint16 newFeeBps);
    event VaultCapUpdated(uint256 newCap);
    event EmergencyExit(address indexed recipient, uint256 assets);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAToken();
    error InvalidFeeCollector();
    error FeeTooHigh(uint16 requested, uint16 max);
    error VaultCapExceeded(uint256 requested, uint256 available);
    error ZeroAssets();
    error WithdrawExceedsMax(uint256 requested, uint256 max);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize AaveERC4626Vault
     * @param _asset Underlying ERC20 asset (USDC, USDT, etc.)
     * @param _aToken aToken address from Aave (aUSDC, aUSDT, etc.)
     * @param _name Vault share token name
     * @param _symbol Vault share token symbol
     * @param _feeCollector Initial fee collector address
     */
    constructor(
        address _asset,
        address _aToken,
        string memory _name,
        string memory _symbol,
        address _feeCollector
    ) ERC4626(ERC20(_asset)) ERC20(_name, _symbol) Ownable(_feeCollector) {
        if (_aToken == address(0)) revert InvalidAToken();
        if (_feeCollector == address(0)) revert InvalidFeeCollector();

        aToken = _aToken;
        feeCollector = _feeCollector;

        // Initialize with zero fee
        feeBps = 0;
        totalFeesAccrued = 0;
        lastTotalAssets = 0;
        vaultCap = type(uint256).max;
        lastAccrualTimestamp = block.timestamp;

        // Approve Aave pool to spend our underlying assets
        IERC20(_asset).forceApprove(AAVE_POOL, type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                    ERC-4626 CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns total assets managed by vault
     * @dev aToken balance grows automatically with interest accrual
     */
    function totalAssets() public view override returns (uint256) {
        return IERC20(aToken).balanceOf(address(this));
    }

    /**
     * @notice Convert a number of assets to shares (rounds down)
     */
    function convertToShares(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    /**
     * @notice Convert a number of shares to assets (rounds down)
     */
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    /**
     * @notice Deposit assets and receive shares
     * @param assets Amount of underlying asset to deposit
     * @param receiver Address to mint shares to
     * @return shares Number of shares minted
     */
    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        if (assets == 0) revert ZeroAssets();
        if (totalAssets() + assets > vaultCap) {
            revert VaultCapExceeded(assets, vaultCap - totalAssets());
        }

        shares = convertToShares(assets);
        require(shares != 0, "Zero shares minted");

        // Transfer asset from user to vault using SafeERC20
        IERC20(address(asset())).safeTransferFrom(msg.sender, address(this), assets);

        // Deposit into Aave
        IPool(AAVE_POOL).supply(
            asset(),
            assets,
            address(this),
            AAVE_REFERRAL_CODE
        );

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    /**
     * @notice Mint exact amount of shares by depositing assets
     * @param shares Number of shares to mint
     * @param receiver Address to mint shares to
     * @return assets Amount of assets required
     */
    function mint(uint256 shares, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        require(shares != 0, "Zero shares");

        assets = convertToAssets(shares);

        if (totalAssets() + assets > vaultCap) {
            revert VaultCapExceeded(assets, vaultCap - totalAssets());
        }

        // Transfer asset from user to vault using SafeERC20
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);

        // Deposit into Aave
        IPool(AAVE_POOL).supply(
            asset(),
            assets,
            address(this),
            AAVE_REFERRAL_CODE
        );

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        return assets;
    }

    /**
     * @notice Withdraw assets by burning shares
     * @param assets Amount of underlying asset to withdraw
     * @param receiver Address to send assets to
     * @param owner Address to burn shares from
     * @return shares Number of shares burned
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        uint256 max = maxWithdraw(owner);
        if (assets > max) {
            revert WithdrawExceedsMax(assets, max);
        }

        shares = convertToShares(assets);

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        // Burn shares
        _burn(owner, shares);

        // Withdraw from Aave to this contract
        IPool(AAVE_POOL).withdraw(asset(), assets, address(this));

        // Transfer to receiver using SafeERC20
        IERC20(address(asset())).safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return shares;
    }

    /**
     * @notice Redeem shares for assets
     * @param shares Number of shares to redeem
     * @param receiver Address to send assets to
     * @param owner Address to burn shares from
     * @return assets Amount of assets returned
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        uint256 max = maxRedeem(owner);
        if (shares > max) {
            revert("Redeem exceeds max");
        }

        assets = convertToAssets(shares);

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        // Burn shares
        _burn(owner, shares);

        // Withdraw from Aave to this contract
        IPool(AAVE_POOL).withdraw(asset(), assets, address(this));

        // Transfer to receiver using SafeERC20
        IERC20(address(asset())).safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                    ERC-4626 PREVIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view override returns (uint256) {
        uint256 cap = vaultCap;
        uint256 current = totalAssets();
        return cap > current ? cap - current : 0;
    }

    function maxMint(address) public view override returns (uint256) {
        return convertToShares(maxDeposit(address(0)));
    }

    function maxWithdraw(address owner) public view override returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        return balanceOf(owner);
    }

    function previewDeposit(uint256 assets) public view override returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                    FEE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Accrue fees based on vault profit since last checkpoint
     */
    function accruePerformanceFee() public nonReentrant returns (uint256 feeInAssets) {
        uint256 currentAssets = totalAssets();

        if (currentAssets <= lastTotalAssets || feeBps == 0) {
            lastAccrualTimestamp = block.timestamp;
            return 0;
        }

        // Compute profit
        uint256 profit = currentAssets - lastTotalAssets;

        // Compute fee
        feeInAssets = (profit * feeBps) / BPS_MAX;

        if (feeInAssets > 0) {
            // Mint fee as shares to feeCollector
            uint256 feeInShares = convertToShares(feeInAssets);
            _mint(feeCollector, feeInShares);

            totalFeesAccrued += feeInAssets;

            emit FeeAccrued(feeInAssets, feeInShares, block.timestamp);
        }

        // Update checkpoint
        lastTotalAssets = currentAssets - feeInAssets;
        lastAccrualTimestamp = block.timestamp;

        return feeInAssets;
    }

    /**
     * @notice Set fee basis points (onlyOwner)
     * @param _feeBps New fee in basis points (100 = 1%)
     */
    function setFeeBps(uint16 _feeBps) external onlyOwner {
        if (_feeBps > 5000) revert FeeTooHigh(_feeBps, 5000); // Max 50% fee

        // Accrue fees before changing fee rate
        accruePerformanceFee();

        feeBps = _feeBps;
        emit FeeBpsUpdated(_feeBps);
    }

    /**
     * @notice Set fee collector address (onlyOwner)
     * @param _feeCollector New fee collector address
     */
    function setFeeCollector(address _feeCollector) external onlyOwner {
        if (_feeCollector == address(0)) revert InvalidFeeCollector();

        // Accrue any pending fees to old collector first
        accruePerformanceFee();

        feeCollector = _feeCollector;
        emit FeeCollectorUpdated(_feeCollector);
    }

    /*//////////////////////////////////////////////////////////////
                    VAULT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set maximum total assets vault can hold
     * @param _cap New vault cap
     */
    function setVaultCap(uint256 _cap) external onlyOwner {
        vaultCap = _cap;
        emit VaultCapUpdated(_cap);
    }

    /**
     * @notice Pause vault (deposits/mints disabled, withdrawals still allowed)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Resume vault operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdrawal of all assets from Aave
     * @param _recipient Address to send all assets to
     */
    function emergencyWithdraw(address _recipient) external onlyOwner nonReentrant {
        require(_recipient != address(0), "Invalid recipient");

        // Withdraw all assets from Aave to this contract
        IPool(AAVE_POOL).withdraw(
            asset(),
            type(uint256).max,
            address(this)
        );

        // Transfer to recipient using SafeERC20
        uint256 balance = IERC20(address(asset())).balanceOf(address(this));
        if (balance > 0) {
            IERC20(address(asset())).safeTransfer(_recipient, balance);
        }

        emit EmergencyExit(_recipient, balance);
    }

    /**
     * @notice Sweep accidental token transfers
     * @param _token Token to sweep (cannot be aToken or asset)
     * @param _to Recipient address
     */
    function sweepTokens(address _token, address _to) external onlyOwner {
        require(_token != address(asset()), "Cannot sweep underlying asset");
        require(_token != aToken, "Cannot sweep aToken");
        require(_to != address(0), "Invalid recipient");

        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(_token).safeTransfer(_to, balance);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get current vault accounting information
     */
    function getVaultInfo()
        external
        view
        returns (
            uint256 _totalAssets,
            uint256 _totalSupply,
            uint256 _feesAccrued,
            uint16 _feeBps
        )
    {
        return (totalAssets(), totalSupply(), totalFeesAccrued, feeBps);
    }

    /**
     * @notice Simulate fee accrual without actual accrual
     */
    function previewFeeAccrual() external view returns (uint256 simulatedFee) {
        uint256 currentAssets = totalAssets();
        if (currentAssets <= lastTotalAssets || feeBps == 0) {
            return 0;
        }

        uint256 profit = currentAssets - lastTotalAssets;
        return (profit * feeBps) / BPS_MAX;
    }
}
