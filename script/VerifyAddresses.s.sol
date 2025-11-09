// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Verify Addresses and Interfaces
 * @notice Verification script to ensure all addresses have required functions
 * @dev This script verifies that all Spark vaults and tokens implement the expected interfaces
 */
contract VerifyAddresses is Script {
    // Ethereum Mainnet Addresses
    address constant SPARK_USDC = 0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d;
    address constant SPARK_USDT = 0xe2e7a17dFf93280dec073C995595155283e3C372;
    address constant SPARK_ETH = 0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f;
    
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    struct VerificationResult {
        address addr;
        string name;
        bool isValid;
        string[] errors;
        string[] warnings;
    }

    function run() external view {
        console2.log("========================================");
        console2.log("Address Verification Script");
        console2.log("========================================\n");

        VerificationResult[] memory results = new VerificationResult[](6);
        uint256 index = 0;

        // Verify Spark Vaults
        results[index++] = verifySparkVault(SPARK_USDC, "Spark USDC Vault (spUSDC)", USDC);
        results[index++] = verifySparkVault(SPARK_USDT, "Spark USDT Vault (spUSDT)", USDT);
        results[index++] = verifySparkVault(SPARK_ETH, "Spark ETH Vault (spETH)", WETH);

        // Verify Tokens
        results[index++] = verifyERC20Token(USDC, "USDC");
        results[index++] = verifyERC20Token(USDT, "USDT");
        results[index++] = verifyERC20Token(WETH, "WETH");

        // Print summary
        printSummary(results);
    }

    function verifySparkVault(
        address vault,
        string memory name,
        address expectedAsset
    ) internal view returns (VerificationResult memory) {
        VerificationResult memory result = VerificationResult({
            addr: vault,
            name: name,
            isValid: true,
            errors: new string[](0),
            warnings: new string[](0)
        });

        console2.log("Verifying:", name);
        console2.log("Address:", vault);

        // Check if address is zero
        if (vault == address(0)) {
            result.isValid = false;
            result.errors = new string[](1);
            result.errors[0] = "Address is zero";
            console2.log("   ERROR: Address is zero\n");
            return result;
        }

        // Check if contract exists (has code)
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(vault)
        }
        if (codeSize == 0) {
            result.isValid = false;
            result.errors = new string[](1);
            result.errors[0] = "Contract has no code";
            console2.log("   ERROR: Contract has no code\n");
            return result;
        }

        IERC4626 vaultInterface = IERC4626(vault);

        // Verify ERC4626 interface functions
        bool hasAsset = checkFunction(vault, "asset()");
        bool hasTotalAssets = checkFunction(vault, "totalAssets()");
        bool hasTotalSupply = checkFunction(vault, "totalSupply()");
        bool hasConvertToAssets = checkFunction(vault, "convertToAssets(uint256)");
        bool hasConvertToShares = checkFunction(vault, "convertToShares(uint256)");
        bool hasDeposit = checkFunction(vault, "deposit(uint256,address)");
        bool hasWithdraw = checkFunction(vault, "withdraw(uint256,address,address)");
        bool hasRedeem = checkFunction(vault, "redeem(uint256,address,address)");
        bool hasMaxDeposit = checkFunction(vault, "maxDeposit(address)");
        bool hasMaxWithdraw = checkFunction(vault, "maxWithdraw(address)");

        console2.log("  Interface Checks:");
        console2.log("    asset():", hasAsset ? "" : "");
        console2.log("    totalAssets():", hasTotalAssets ? "" : "");
        console2.log("    totalSupply():", hasTotalSupply ? "" : "");
        console2.log("    convertToAssets(uint256):", hasConvertToAssets ? "" : "");
        console2.log("    convertToShares(uint256):", hasConvertToShares ? "" : "");
        console2.log("    deposit(uint256,address):", hasDeposit ? "" : "");
        console2.log("    withdraw(uint256,address,address):", hasWithdraw ? "" : "");
        console2.log("    redeem(uint256,address,address):", hasRedeem ? "" : "");
        console2.log("    maxDeposit(address):", hasMaxDeposit ? "" : "");
        console2.log("    maxWithdraw(address):", hasMaxWithdraw ? "" : "");

        // Verify asset() returns expected token
        if (hasAsset) {
            try vaultInterface.asset() returns (address assetAddress) {
                console2.log("  Asset Address:", assetAddress);
                if (assetAddress == expectedAsset) {
                    console2.log("   Asset matches expected:", expectedAsset);
                } else {
                    result.isValid = false;
                    console2.log("   ERROR: Asset mismatch!");
                    console2.log("    Expected:", expectedAsset);
                    console2.log("    Got:", assetAddress);
                }
            } catch {
                console2.log("   ERROR: Failed to call asset()");
                result.isValid = false;
            }
        }

        // Try to read totalAssets
        if (hasTotalAssets) {
            try vaultInterface.totalAssets() returns (uint256 total) {
                console2.log("  Total Assets:", total);
            } catch {
                console2.log("   WARNING: Failed to call totalAssets()");
            }
        }

        // Try to read totalSupply
        if (hasTotalSupply) {
            try vaultInterface.totalSupply() returns (uint256 supply) {
                console2.log("  Total Supply:", supply);
            } catch {
                console2.log("   WARNING: Failed to call totalSupply()");
            }
        }

        // Verify all required functions exist
        bool allRequired = hasAsset && hasTotalAssets && hasTotalSupply &&
                          hasConvertToAssets && hasConvertToShares &&
                          hasDeposit && hasWithdraw && hasRedeem &&
                          hasMaxDeposit && hasMaxWithdraw;

        if (!allRequired) {
            result.isValid = false;
        }

        console2.log("  Status:", result.isValid ? " VALID" : " INVALID");
        console2.log("");

        return result;
    }

    function verifyERC20Token(
        address token,
        string memory name
    ) internal view returns (VerificationResult memory) {
        VerificationResult memory result = VerificationResult({
            addr: token,
            name: name,
            isValid: true,
            errors: new string[](0),
            warnings: new string[](0)
        });

        console2.log("Verifying Token:", name);
        console2.log("Address:", token);

        // Check if address is zero
        if (token == address(0)) {
            result.isValid = false;
            result.errors = new string[](1);
            result.errors[0] = "Address is zero";
            console2.log("   ERROR: Address is zero\n");
            return result;
        }

        // Check if contract exists
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(token)
        }
        if (codeSize == 0) {
            result.isValid = false;
            result.errors = new string[](1);
            result.errors[0] = "Contract has no code";
            console2.log("   ERROR: Contract has no code\n");
            return result;
        }

        // Verify ERC20 interface functions
        bool hasTotalSupply = checkFunction(token, "totalSupply()");
        bool hasBalanceOf = checkFunction(token, "balanceOf(address)");
        bool hasTransfer = checkFunction(token, "transfer(address,uint256)");
        bool hasTransferFrom = checkFunction(token, "transferFrom(address,address,uint256)");
        bool hasApprove = checkFunction(token, "approve(address,uint256)");
        bool hasAllowance = checkFunction(token, "allowance(address,address)");
        bool hasDecimals = checkFunction(token, "decimals()");
        bool hasSymbol = checkFunction(token, "symbol()");
        bool hasName = checkFunction(token, "name()");

        console2.log("  Interface Checks:");
        console2.log("    totalSupply():", hasTotalSupply ? "" : "");
        console2.log("    balanceOf(address):", hasBalanceOf ? "" : "");
        console2.log("    transfer(address,uint256):", hasTransfer ? "" : "");
        console2.log("    transferFrom(address,address,uint256):", hasTransferFrom ? "" : "");
        console2.log("    approve(address,uint256):", hasApprove ? "" : "");
        console2.log("    allowance(address,address):", hasAllowance ? "" : "");
        console2.log("    decimals():", hasDecimals ? "" : "");
        console2.log("    symbol():", hasSymbol ? "" : "");
        console2.log("    name():", hasName ? "" : "");

        // Try to read token info
        ERC20 tokenInterface = ERC20(token);
        
        try tokenInterface.decimals() returns (uint8 decimals) {
            console2.log("  Decimals:", decimals);
        } catch {
            console2.log("   WARNING: Failed to read decimals");
        }

        try tokenInterface.symbol() returns (string memory symbol) {
            console2.log("  Symbol:", symbol);
        } catch {
            console2.log("   WARNING: Failed to read symbol");
        }

        try tokenInterface.name() returns (string memory tokenName) {
            console2.log("  Name:", tokenName);
        } catch {
            console2.log("   WARNING: Failed to read name");
        }

        try tokenInterface.totalSupply() returns (uint256 supply) {
            console2.log("  Total Supply:", supply);
        } catch {
            console2.log("   WARNING: Failed to read totalSupply");
        }

        // Verify required ERC20 functions exist
        bool allRequired = hasTotalSupply && hasBalanceOf && hasTransfer &&
                          hasTransferFrom && hasApprove && hasAllowance &&
                          hasDecimals;

        if (!allRequired) {
            result.isValid = false;
        }

        console2.log("  Status:", result.isValid ? " VALID" : " INVALID");
        console2.log("");

        return result;
    }

    function checkFunction(address target, string memory sig) internal view returns (bool) {
        bytes4 selector = bytes4(keccak256(bytes(sig)));
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(target)
        }
        if (codeSize == 0) return false;

        // Try to call the function with staticcall
        (bool success, ) = target.staticcall(
            abi.encodeWithSelector(selector)
        );
        return success;
    }

    function printSummary(VerificationResult[] memory results) internal pure {
        console2.log("========================================");
        console2.log("Verification Summary");
        console2.log("========================================");

        uint256 validCount = 0;
        uint256 invalidCount = 0;

        for (uint256 i = 0; i < results.length; i++) {
            if (results[i].isValid) {
                validCount++;
                console2.log("", results[i].name, "- VALID");
            } else {
                invalidCount++;
                console2.log("", results[i].name, "- INVALID");
                for (uint256 j = 0; j < results[i].errors.length; j++) {
                    console2.log("   Error:", results[i].errors[j]);
                }
            }
        }

        console2.log("----------------------------------------");
        console2.log("Total Valid:", validCount);
        console2.log("Total Invalid:", invalidCount);
        console2.log("========================================");

        if (invalidCount > 0) {
            console2.log("\n VERIFICATION FAILED");
            console2.log("Some addresses are invalid or missing required functions.");
        } else {
            console2.log("\n VERIFICATION SUCCESSFUL");
            console2.log("All addresses are valid and have required functions.");
        }
    }
}
