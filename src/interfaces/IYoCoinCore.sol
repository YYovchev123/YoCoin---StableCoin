// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IYoCoinCore {

  /// @notice Information about each allowed collateral token.
    struct CollateralInfo {
        address priceFeed;               // Primary oracle address
        uint8 tokenDecimals;             // Collateral token decimals (e.g., 6 for USDC, 18 for DAI)
        uint8 priceFeedDecimals;         // Primary oracle decimals (e.g., 8 for many Chainlink feeds)
        uint256 validityPeriod;           // Validity period in seconds
    }

    struct RedeemRequest {
        address collateralToken; // Address of the collateral token
        uint256 amount; // Amount of collateral token
        address receiver; // The address to which to send the collateral token to
        uint256 startTimestamp; // Starting time of redeemRequest
        uint256 endTimestamp; // Ending time of redeemRequest
    }

    error NotWhitelistedToken();
    error ZeroAmount();
    error ZeroAddress();
    error CollateralPriceBelowThreshold();
    error CollateralTokenAlreadyAdded();
    error CollateralTokenNotAdded();
    error InvalidRedeemRequest();
    error RequestNotFinalized();

    event YoCoinMinted(address to, uint256 amount);
}