// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IAggregatorV3Like {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

library OracleChecks {
    error SequencerDown();
    error SequencerGracePeriod();
    error MarketClosed();

    function validateSequencer(address sequencerFeed, uint256 gracePeriod) internal view {
        if (sequencerFeed == address(0)) return;
        (, int256 answer, uint256 startedAt,,) = IAggregatorV3Like(sequencerFeed).latestRoundData();
        if (answer != 0) revert SequencerDown();
        if (startedAt == 0 || block.timestamp <= startedAt + gracePeriod) {
            revert SequencerGracePeriod();
        }
    }

    function marketOpen(address statusFeed, bool alwaysOpen) internal view returns (bool) {
        if (alwaysOpen) return true;
        if (statusFeed == address(0)) return false;
        (, int256 answer,, uint256 updatedAt,) = IAggregatorV3Like(statusFeed).latestRoundData();
        return answer > 0 && updatedAt != 0 && updatedAt <= block.timestamp;
    }

    /// @notice Weekday UTC window. `openMinute` and `closeMinute` of zero means the clock is unused.
    /// Unix day zero is Thursday, so Saturday is 2 and Sunday is 3.
    function inWeekdaySession(uint16 openMinute, uint16 closeMinute) internal view returns (bool) {
        if (openMinute == 0 && closeMinute == 0) return true;
        uint256 dow = (block.timestamp / 1 days) % 7;
        if (dow == 2 || dow == 3) return false;
        uint256 minuteOfDay = (block.timestamp % 1 days) / 60;
        if (openMinute < closeMinute) {
            return minuteOfDay >= openMinute && minuteOfDay < closeMinute;
        }
        return minuteOfDay >= openMinute || minuteOfDay < closeMinute;
    }

    /// @dev A feed with no status feed and no session is closed unless `alwaysOpen` is set.
    /// `heartbeat` of zero does not add a freshness limit beyond the caller's max age.
    function sessionOpen(
        address statusFeed,
        bool alwaysOpen,
        uint16 openMinute,
        uint16 closeMinute,
        uint32 heartbeat,
        uint256 updatedAt
    ) internal view returns (bool) {
        if (alwaysOpen) return true;
        if (statusFeed != address(0) && !marketOpen(statusFeed, false)) return false;
        if (statusFeed == address(0) && openMinute == 0 && closeMinute == 0) return false;
        if (!inWeekdaySession(openMinute, closeMinute)) return false;
        if (
            heartbeat != 0
                && (updatedAt > block.timestamp || block.timestamp - updatedAt > heartbeat)
        ) {
            return false;
        }
        return true;
    }
}
