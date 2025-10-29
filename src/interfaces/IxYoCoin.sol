// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IxYoCoin {

    error FeeTooHigh();
    error NotAllowed();

    event RewardsDeposited(uint256 amount);

    function depositRewards(uint256 amount) external;
}