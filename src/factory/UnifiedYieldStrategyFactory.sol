// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SparkMultiAssetYieldOptimizer} from "../strategies/spark/SParkOctatnt.sol";
import {AaveV3YieldStrategy} from "../strategies/aave/AaveV3YieldStrategy.sol";
import {YieldDonatingTokenizedStrategy} from "@octant-core/strategies/yieldDonating/YieldDonatingTokenizedStrategy.sol";
import {IStrategyInterface} from "../interfaces/IStrategyInterface.sol";

/**
 * @title Unified Yield Strategy Factory
 * @author Octant DeFi Hackathon 2025
 * @notice Single factory to deploy any yield strategy (Spark, Aave, etc.) with unified configuration
 * @dev Simplifies deployment and management of multi-protocol yield optimization strategies
 *
 * SUPPORTED STRATEGIES:
 * ═══════════════════════════════════════════════════════════════════════════════
 * 1. SPARK (spUSDC, spUSDT, spETH) - Continuous per-second compounding
 * 2. AAVE_V3 (USDC, USDT, ETH) - Supply yields + optional recursive lending
 * 3. AAVE_ERC4626 - Standard ERC-4626 vault wrapper (planned)
 *
 * FACTORY BENEFITS:
 * ═══════════════════════════════════════════════════════════════════════════════
 * ✓ Single entry point for all yield strategies
 * ✓ Unified configuration management
 * ✓ Batch strategy deployments
 * ✓ Consistent naming and versioning
 * ✓ Easy strategy discovery and lookup
 * ✓ Centralized governance
 *
 * DEPLOYMENT FLOW:
 * ═══════════════════════════════════════════════════════════════════════════════
 *
 *   User calls factory.deployStrategy()
 *        ↓
 *   Factory validates parameters
 *        ↓
 *   Creates strategy instance
 *        ↓
 *   Registers deployment
 *        ↓
 *   Returns strategy address
 *        ↓
 *   User interacts with strategy
 */

/// @notice Strategy type enumeration
enum StrategyType {
    SPARK_OPTIMIZER,      // Spark vault yield optimizer
    AAVE_V3_RECURSIVE,    // Aave V3 with optional recursive lending
    AAVE_ERC4626_VAULT    // Standard Aave ERC-4626 wrapper (future)
}

/// @notice Deployment configuration struct
struct DeploymentConfig {
    StrategyType strategyType;
    address asset;
    string name;
    address management;
    address keeper;
    address emergencyAdmin;
    address donationAddress;
    bool enableBurning;
    // Strategy-specific parameters
    bytes strategyParams;  // Encoded parameters (vault addresses, leverage, etc.)
}

contract UnifiedYieldStrategyFactory {
    /// @notice Deployment record
    struct DeploymentRecord {
        address strategyAddress;
        StrategyType strategyType;
        address asset;
        uint256 deploymentTime;
        address deployer;
        string name;
    }
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Spark USDC Vault
    address public constant SPARK_USDC = 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d;

    /// @notice Spark USDT Vault
    address public constant SPARK_USDT = 0xe2e7a17dFf93280dec073C995595155283e3C372;

    /// @notice Spark ETH Vault
    address public constant SPARK_ETH = 0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f;

    /// @notice Aave V3 Pool
    address public constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice TokenizedStrategy implementation
    address public tokenizedStrategyAddress;

    /// @notice Management address (can update factory settings)
    address public management;

    /// @notice Donation address (receives yield)
    address public donationAddress;

    /// @notice Keeper address (can call tend/report)
    address public keeper;

    /// @notice Emergency admin address
    address public emergencyAdmin;

    /// @notice Total strategies deployed
    uint256 public deploymentCount;

    /// @notice Deployments by index
    DeploymentRecord[] public deployments;

    /// @notice Deployments by strategy address (for quick lookup)
    mapping(address => uint256) public deploymentIndex;

    /// @notice Deployments by asset (strategy type => asset => deployment records)
    mapping(StrategyType => mapping(address => address[])) public deploymentsByTypeAndAsset;

    /// @notice Version tracking
    string public constant FACTORY_VERSION = "1.0.0";

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event StrategyDeployed(
        address indexed strategyAddress,
        StrategyType indexed strategyType,
        address indexed asset,
        string name,
        uint256 timestamp
    );

    event ConfigurationUpdated(
        address indexed newManagement,
        address indexed newDonationAddress,
        address indexed newKeeper,
        uint256 timestamp
    );

    event FactoryInitialized(
        address indexed management,
        address indexed donationAddress,
        address indexed tokenizedStrategy,
        uint256 timestamp
    );

    event StrategyTypeRegistered(
        StrategyType indexed strategyType,
        string name,
        uint256 timestamp
    );

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidStrategyType();
    error InvalidAsset();
    error InvalidManagement();
    error InvalidDonationAddress();
    error ZeroAddress();
    error OnlyManagement();
    error DeploymentFailed();
    error InvalidSparkVault();
    error InvalidAavePool();
    error StrategyNotFound();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize Unified Yield Strategy Factory
     * @param _management Initial management address
     * @param _donationAddress Initial donation address
     * @param _keeper Initial keeper address
     * @param _emergencyAdmin Initial emergency admin
     */
    constructor(
        address _management,
        address _donationAddress,
        address _keeper,
        address _emergencyAdmin
    ) {
        if (_management == address(0)) revert InvalidManagement();
        if (_donationAddress == address(0)) revert InvalidDonationAddress();
        if (_keeper == address(0)) revert ZeroAddress();
        if (_emergencyAdmin == address(0)) revert ZeroAddress();

        management = _management;
        donationAddress = _donationAddress;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;

        // Deploy the standard TokenizedStrategy implementation
        tokenizedStrategyAddress = address(new YieldDonatingTokenizedStrategy());

        emit FactoryInitialized(_management, _donationAddress, tokenizedStrategyAddress, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        MAIN DEPLOYMENT FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploy a new yield strategy
     * @param _config Deployment configuration struct
     * @return strategyAddress Address of deployed strategy
     *
     * USAGE EXAMPLE - Spark Strategy:
     * ```
     * DeploymentConfig memory config = DeploymentConfig({
     *     strategyType: StrategyType.SPARK_OPTIMIZER,
     *     asset: USDC,
     *     name: "Spark USDC Optimizer",
     *     management: deployer,
     *     keeper: deployer,
     *     emergencyAdmin: deployer,
     *     donationAddress: publicGoodsAddress,
     *     enableBurning: false,
     *     strategyParams: "" // Not needed for Spark
     * });
     * address strategy = factory.deployStrategy(config);
     * ```
     *
     * USAGE EXAMPLE - Aave V3 with 2x Leverage:
     * ```
     * DeploymentConfig memory config = DeploymentConfig({
     *     strategyType: StrategyType.AAVE_V3_RECURSIVE,
     *     asset: USDC,
     *     name: "Aave USDC 2x Leverage",
     *     management: deployer,
     *     keeper: deployer,
     *     emergencyAdmin: deployer,
     *     donationAddress: publicGoodsAddress,
     *     enableBurning: false,
     *     strategyParams: abi.encode(uint256(2e18))  // 2x leverage
     * });
     * address strategy = factory.deployStrategy(config);
     * ```
     */
    function deployStrategy(DeploymentConfig calldata _config)
        external
        returns (address strategyAddress)
    {
        if (_config.asset == address(0)) revert InvalidAsset();

        address newStrategy;

        if (_config.strategyType == StrategyType.SPARK_OPTIMIZER) {
            newStrategy = _deploySpark(_config);
        } else if (_config.strategyType == StrategyType.AAVE_V3_RECURSIVE) {
            newStrategy = _deployAaveV3(_config);
        } else {
            revert InvalidStrategyType();
        }

        if (newStrategy == address(0)) revert DeploymentFailed();

        // Register deployment
        _registerDeployment(newStrategy, _config);

        return newStrategy;
    }

    /*//////////////////////////////////////////////////////////////
                    STRATEGY-SPECIFIC DEPLOYMENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploy Spark Multi-Asset Yield Optimizer
     * @param _config Deployment configuration
     * @return Strategy address
     *
     * Spark Strategy Features:
     * - Continuous per-second VSR compounding
     * - Auto-rebalancing to highest APY vault
     * - Supports spUSDC, spUSDT, spETH
     * - 100% yield donation to publicGoods
     */
    function _deploySpark(DeploymentConfig calldata _config)
        internal
        returns (address)
    {
        // Validate Spark vaults
        if (SPARK_USDC == address(0) || SPARK_USDT == address(0) || SPARK_ETH == address(0)) {
            revert InvalidSparkVault();
        }

        // Determine token addresses based on asset
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        try
            new SparkMultiAssetYieldOptimizer(
                SPARK_USDC,
                SPARK_USDT,
                SPARK_ETH,
                usdc,
                usdt,
                weth,
                _config.asset,
                _config.name,
                _config.management,
                _config.keeper,
                _config.emergencyAdmin,
                _config.donationAddress,
                _config.enableBurning,
                tokenizedStrategyAddress
            )
        returns (SparkMultiAssetYieldOptimizer newStrategy) {
            return address(newStrategy);
        } catch {
            revert DeploymentFailed();
        }
    }

    /**
     * @notice Deploy Aave V3 Yield Strategy (with optional recursive lending)
     * @param _config Deployment configuration
     * @return Strategy address
     *
     * Aave V3 Strategy Features:
     * - Supply yields + liquidity incentives
     * - Optional recursive lending (1x-3x leverage)
     * - Health factor automation
     * - Risk management safeguards
     *
     * strategyParams should encode:
     * - aTokenAddress: Address of aToken for asset
     * - optionalLeverage: Target leverage multiplier (1e18 = 1x, 2e18 = 2x, etc.)
     */
    function _deployAaveV3(DeploymentConfig calldata _config)
        internal
        returns (address)
    {
        if (AAVE_V3_POOL == address(0)) revert InvalidAavePool();

        // Decode strategy parameters
        (address aTokenAddress, uint256 leverage) = _decodeAaveParams(_config.strategyParams);

        if (aTokenAddress == address(0)) {
            // If not provided, use default aToken mapping
            aTokenAddress = _getAaveATokenAddress(_config.asset);
        }

        // Determine debt token (variable rate)
        address debtToken = _getAaveDebtToken(_config.asset);

        try
            new AaveV3YieldStrategy(
                AAVE_V3_POOL,
                aTokenAddress,
                debtToken,
                _config.asset,
                _config.name,
                _config.management,
                _config.keeper,
                _config.emergencyAdmin,
                _config.donationAddress,
                _config.enableBurning,
                tokenizedStrategyAddress
            )
        returns (AaveV3YieldStrategy newStrategy) {
            // Set leverage if provided
            if (leverage > 0 && leverage != 1e18) {
                newStrategy.setLeverageMultiplier(leverage);
                newStrategy.setRecursiveLendingEnabled(true);
            }

            return address(newStrategy);
        } catch {
            revert DeploymentFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                    DEPLOYMENT REGISTRATION & LOOKUP
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register deployment in factory records
     * @param _strategy Strategy address
     * @param _config Deployment configuration
     */
    function _registerDeployment(address _strategy, DeploymentConfig calldata _config) internal {
        DeploymentRecord memory record = DeploymentRecord({
            strategyAddress: _strategy,
            strategyType: _config.strategyType,
            asset: _config.asset,
            deploymentTime: block.timestamp,
            deployer: msg.sender,
            name: _config.name
        });

        deployments.push(record);
        deploymentIndex[_strategy] = deployments.length - 1;
        deploymentsByTypeAndAsset[_config.strategyType][_config.asset].push(_strategy);

        deploymentCount++;

        emit StrategyDeployed(_strategy, _config.strategyType, _config.asset, _config.name, block.timestamp);
    }

    /**
     * @notice Get deployment record by strategy address
     * @param _strategy Strategy address
     * @return Deployment record
     */
    function getDeployment(address _strategy) external view returns (DeploymentRecord memory) {
        uint256 index = deploymentIndex[_strategy];
        return deployments[index];
    }

    /**
     * @notice Get all deployments by type and asset
     * @param _type Strategy type
     * @param _asset Asset address
     * @return Array of strategy addresses
     */
    function getDeploymentsByTypeAndAsset(StrategyType _type, address _asset)
        external
        view
        returns (address[] memory)
    {
        return deploymentsByTypeAndAsset[_type][_asset];
    }

    /**
     * @notice Get recent deployments
     * @param _limit Number of recent deployments to return
     * @return Array of deployment records
     */
    function getRecentDeployments(uint256 _limit)
        external
        view
        returns (DeploymentRecord[] memory)
    {
        uint256 start = deploymentCount > _limit ? deploymentCount - _limit : 0;
        uint256 length = deploymentCount - start;

        DeploymentRecord[] memory records = new DeploymentRecord[](length);
        for (uint256 i = 0; i < length; i++) {
            records[i] = deployments[start + i];
        }

        return records;
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Decode Aave strategy parameters
     * @param _params Encoded parameters
     * @return aTokenAddress Address of aToken
     * @return leverage Target leverage multiplier
     */
    function _decodeAaveParams(bytes calldata _params)
        internal
        pure
        returns (address aTokenAddress, uint256 leverage)
    {
        if (_params.length == 0) {
            return (address(0), 1e18);  // Default: no leverage
        }

        if (_params.length == 20) {
            // Only aToken address provided
            aTokenAddress = abi.decode(_params, (address));
            leverage = 1e18;
        } else if (_params.length == 52) {
            // Both aToken and leverage provided
            (aTokenAddress, leverage) = abi.decode(_params, (address, uint256));
        }
    }

    /**
     * @notice Get aToken address for asset (Aave mainnet)
     * @param _asset Underlying asset
     * @return aToken address
     */
    function _getAaveATokenAddress(address _asset) internal pure returns (address) {
        // USDC
        if (_asset == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) {
            return 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
        }
        // USDT
        if (_asset == 0xdAC17F958D2ee523a2206206994597C13D831ec7) {
            return 0x23878914eFe38D27C36f9B764D3287C137Cedb08;
        }
        // WETH
        if (_asset == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) {
            return 0x4D5F47fa6A74757f35C14Fd3CB47DA0c4D45b1f5;
        }
        revert InvalidAsset();
    }

    /**
     * @notice Get variable debt token for asset (Aave mainnet)
     * @param _asset Underlying asset
     * @return Debt token address
     */
    function _getAaveDebtToken(address _asset) internal pure returns (address) {
        // USDC
        if (_asset == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) {
            return 0x72e95b8931767C79BA4eEE721061b6C7D4f48A6B;
        }
        // USDT
        if (_asset == 0xdAC17F958D2ee523a2206206994597C13D831ec7) {
            return 0x531842cD628F2e7a46BCE428f5480e1D68c5D46d;
        }
        // // WETH
        // if (_asset == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) {
        //     return 0xeA51d6850ae4dcFD03BB802Ce42df5c5b12ede;
        // }
        revert InvalidAsset();
    }

    /*//////////////////////////////////////////////////////////////
                    MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update factory configuration
     * @param _newManagement New management address
     * @param _newDonationAddress New donation address
     * @param _newKeeper New keeper address
     */
    function updateConfiguration(
        address _newManagement,
        address _newDonationAddress,
        address _newKeeper
    ) external {
        if (msg.sender != management) revert OnlyManagement();
        if (_newManagement == address(0)) revert InvalidManagement();
        if (_newDonationAddress == address(0)) revert InvalidDonationAddress();
        if (_newKeeper == address(0)) revert ZeroAddress();

        management = _newManagement;
        donationAddress = _newDonationAddress;
        keeper = _newKeeper;

        emit ConfigurationUpdated(_newManagement, _newDonationAddress, _newKeeper, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get total number of deployments
     * @return Total count
     */
    function getTotalDeployments() external view returns (uint256) {
        return deploymentCount;
    }

    /**
     * @notice Get all deployments
     * @return Array of all deployment records
     */
    function getAllDeployments() external view returns (DeploymentRecord[] memory) {
        return deployments;
    }

    /**
     * @notice Check if address is a registered strategy
     * @param _strategy Strategy address to check
     * @return True if registered
     */
    function isRegisteredStrategy(address _strategy) external view returns (bool) {
        return deploymentIndex[_strategy] < deploymentCount && deployments[deploymentIndex[_strategy]].strategyAddress == _strategy;
    }
}
