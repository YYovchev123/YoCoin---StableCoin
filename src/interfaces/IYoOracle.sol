// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IYoOracle {
    event YoCoinMinted(address to, uint256 amount);

    error InvalidOraclePrice();

    function getPrice(address priceFeed, uint8 priceFeedDecimals, uint256 validityPeriod) external returns (uint256);
}
