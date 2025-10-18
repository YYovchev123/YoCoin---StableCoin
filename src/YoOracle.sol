// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IYoOracle} from "./interfaces/IYoOracle.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";

contract YoOracle is IYoOracle {

    /**
     * @param priceFeed The address of the price feed
     * @param priceFeedDecimals The decimal precision of the price feed
     * @param validityPeriod The staleness/validity period
     * @return Returns the fetched price from chainlink in 18 decimal precision
     */
    function getPrice(address priceFeed, uint8 priceFeedDecimals, uint256 validityPeriod) public view returns(uint256) {
        // Fetch latest round data from the oracle
        (,int256 answer,,uint256 updatedAt,) = IPriceFeed(priceFeed).latestRoundData();
        // if validity period is 0, it means that we accept any price > 0
        // othwerwise, we check if the price is updated within the validity period
        if (answer > 0 && (validityPeriod == 0 || (updatedAt >= block.timestamp - validityPeriod))) {
        // scale the value to 18 decimals
            return uint256(answer) * 10 ** (18 - priceFeedDecimals);
        }
        revert InvalidOraclePrice();
    }
}