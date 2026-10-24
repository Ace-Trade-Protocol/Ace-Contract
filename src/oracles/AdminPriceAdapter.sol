// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Ownable2Step } from "../access/Ownable2Step.sol";
import { IPriceAdapter, PriceData } from "../interfaces/IPriceAdapter.sol";

/// @notice Admin-owned USD price. A publisher key calls `setBidAsk`. Until a publisher is set,
/// the owner can publish, which keeps an adapter usable before roles are split.
contract AdminPriceAdapter is Ownable2Step, IPriceAdapter {
    error InvalidPrice();
    error StalePrice();

    uint256 public minPrice;
    uint256 public maxPrice;
    uint256 public updatedAt;
    bool public marketOpen;
    address public publisher;
    event PublisherUpdated(address indexed publisher);

    constructor(address initialOwner, uint256 price) Ownable2Step(initialOwner) {
        _set(price, price, true);
    }

    function setPublisher(address value) external onlyOwner {
        publisher = value;
        emit PublisherUpdated(value);
    }

    function setPrice(uint256 price, bool open) external {
        _publisher();
        _set(price, price, open);
    }

    function setBidAsk(uint256 min_, uint256 max_, bool open) external {
        _publisher();
        _set(min_, max_, open);
    }

    function _publisher() private view {
        if (publisher == address(0)) {
            if (msg.sender != owner) revert Unauthorized();
            return;
        }
        if (msg.sender != publisher) revert Unauthorized();
    }

    function getPrice(uint256 maxAge) external view returns (PriceData memory) {
        if (updatedAt == 0 || updatedAt > block.timestamp || block.timestamp - updatedAt > maxAge) {
            revert StalePrice();
        }
        return PriceData(minPrice, maxPrice, updatedAt, marketOpen);
    }

    function _set(uint256 min_, uint256 max_, bool open) private {
        if (min_ == 0 || max_ < min_) revert InvalidPrice();
        minPrice = min_;
        maxPrice = max_;
        updatedAt = block.timestamp;
        marketOpen = open;
    }
}
