// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {

    error OracleLib__StalePrice();

    uint256 public constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(AggregatorV3Interface _priceFeed) public view returns (uint80, int256, uint256, uint256, uint80) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = _priceFeed.latestRoundData();
        uint256 timeSinceUpdated = block.timestamp - updatedAt;
        if (timeSinceUpdated > TIMEOUT) {
            revert OracleLib__StalePrice();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}