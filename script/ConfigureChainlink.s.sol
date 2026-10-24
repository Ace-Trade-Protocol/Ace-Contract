// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ChainlinkAdapter } from "../src/oracles/ChainlinkAdapter.sol";

interface VmScript {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// @notice Deploys Chainlink adapters for the Robinhood AMZN token feed and USDG.
/// Robinhood Chain testnet (46630) does not publish these proxies. The script refuses to
/// invent a feed there. Mainnet proxies are Chainlink's push aggregators, heartbeat 24 hours.
contract ConfigureChainlink {
    VmScript private constant vm =
        VmScript(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant AMZN_FEED = 0xD5a1508ceD74c084eBf3cBe853e2C968fB2a651C;
    address private constant USDG_FEED = 0x61B7e5650328764B076A108EFF5fa7282a1B9aD2;
    uint32 private constant HEARTBEAT = 1 days;

    error TestnetFeedMissing(address feed);

    function run() external returns (ChainlinkAdapter amzn, ChainlinkAdapter usdg) {
        if (block.chainid == 46_630) {
            if (_codeSize(AMZN_FEED) == 0) revert TestnetFeedMissing(AMZN_FEED);
            if (_codeSize(USDG_FEED) == 0) revert TestnetFeedMissing(USDG_FEED);
        }
        vm.startBroadcast();
        amzn = new ChainlinkAdapter(
            AMZN_FEED, address(0), 0, address(0), false, 810, 1_260, HEARTBEAT
        );
        usdg = new ChainlinkAdapter(USDG_FEED, address(0), 0, address(0), true, 0, 0, 0);
        vm.stopBroadcast();
    }

    function _codeSize(address account) private view returns (uint256 size) {
        assembly ("memory-safe") {
            size := extcodesize(account)
        }
    }
}
