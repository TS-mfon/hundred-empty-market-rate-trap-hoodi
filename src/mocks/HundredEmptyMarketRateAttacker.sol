// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./HundredEmptyMarketRateProtocolMock.sol";

contract HundredEmptyMarketRateAttacker {
    HundredEmptyMarketRateProtocolMock public immutable protocol;

    constructor(address target) {
        protocol = HundredEmptyMarketRateProtocolMock(target);
    }

    function stageExploit() external {
        protocol.stageDonationRateInflation();
    }

    function completeExploit() external {
        protocol.borrowAgainstInflatedRate();
    }
}
