// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IPriceAdapter, PriceData } from "../interfaces/IPriceAdapter.sol";
import { IAggregatorV3Like, OracleChecks } from "./OracleChecks.sol";

interface IChainlinkAggregatorV3 is IAggregatorV3Like { }

/// @notice Chainlink Data Feed adapter with L2 sequencer and RWA market-status checks.
contract ChainlinkAdapter is IPriceAdapter {
    error InvalidFeed();
    error InvalidPrice();
    error StalePrice();
    IAggregatorV3Like public immutable feed;
    uint8 public immutable feedDecimals;
    address public immutable sequencerFeed;
    uint32 public immutable sequencerGracePeriod;
    address public immutable marketStatusFeed;
    bool public immutable alwaysOpen;
    /// @notice Inclusive start and exclusive end, as minutes from 00:00 UTC. Both zero disables the clock.
    uint16 public immutable sessionOpenMinute;
    uint16 public immutable sessionCloseMinute;
    /// @notice Price older than this is outside the session even when the clock says open. Zero skips it.
    uint32 public immutable sessionHeartbeat;
    /// @notice 13:30 UTC. Covers the US cash open in both daylight-saving schedules.
    uint16 public constant US_CASH_OPEN_MINUTE = 810;
    /// @notice 21:00 UTC. Covers the US cash close in both daylight-saving schedules.
    uint16 public constant US_CASH_CLOSE_MINUTE = 1260;

    constructor(
        address feed_,
        address sequencerFeed_,
        uint32 grace_,
        address status_,
        bool alwaysOpen_,
        uint16 sessionOpenMinute_,
        uint16 sessionCloseMinute_,
        uint32 sessionHeartbeat_
    ) {
        if (feed_ == address(0) || feed_.code.length == 0) {
            revert InvalidFeed();
        }
        if (sessionOpenMinute_ > 1_440 || sessionCloseMinute_ > 1_440) revert InvalidFeed();
        if (sessionOpenMinute_ == sessionCloseMinute_ && sessionOpenMinute_ != 0) {
            revert InvalidFeed();
        }
        feed = IAggregatorV3Like(feed_);
        uint8 decimals_ = feed.decimals();
        if (decimals_ > 18) revert InvalidFeed();
        feedDecimals = decimals_;
        sequencerFeed = sequencerFeed_;
        sequencerGracePeriod = grace_;
        marketStatusFeed = status_;
        alwaysOpen = alwaysOpen_;
        sessionOpenMinute = sessionOpenMinute_;
        sessionCloseMinute = sessionCloseMinute_;
        sessionHeartbeat = sessionHeartbeat_;
    }

    function getPrice(uint256 maxAge) external view returns (PriceData memory data) {
        OracleChecks.validateSequencer(sequencerFeed, sequencerGracePeriod);
        (uint80 roundId, int256 answer,, uint256 timestamp, uint80 answeredInRound) =
            feed.latestRoundData();
        if (answer <= 0 || timestamp == 0 || answeredInRound < roundId) revert InvalidPrice();
        if (timestamp > block.timestamp || block.timestamp - timestamp > maxAge) {
            revert StalePrice();
        }
        uint256 price = uint256(answer) * 10 ** (18 - feedDecimals);
        data = PriceData(
            price,
            price,
            timestamp,
            OracleChecks.sessionOpen(
                marketStatusFeed,
                alwaysOpen,
                sessionOpenMinute,
                sessionCloseMinute,
                sessionHeartbeat,
                timestamp
            )
        );
    }
}
