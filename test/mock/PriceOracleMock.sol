// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";

contract PriceOracleMock {

    function getPrice(address priceFeed, uint8 priceFeedDecimals, uint256 validityPeriod) external view returns (uint256) {
        return 1e18;
    }
}