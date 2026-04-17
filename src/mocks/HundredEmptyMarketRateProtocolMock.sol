// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMockToken {
    function mint(address to, uint256 amount) external;
    function balanceOf(address owner) external view returns (uint256);
}

contract HundredEmptyMarketRateProtocolMock {
    address public constant DEFAULT_TOKEN = address(0x0000000000000000000000000000000000002002);
    address public token = DEFAULT_TOKEN;
    address public attacker;
    bool public paused;
    bool public staged;
    uint256 public cash;
    uint256 public totalBorrows;
    uint256 public totalReserves;
    uint256 public totalSupply;
    uint256 public exchangeRate;

    function seedHealthy(address attacker_) external {
        attacker = attacker_;
        if (token == address(0)) token = DEFAULT_TOKEN;
        paused = false;
        staged = false;
        cash = 100e18;
        totalBorrows = 0;
        totalReserves = 0;
        totalSupply = 10e18;
        exchangeRate = 1e18;
    }

    function setToken(address token_) external {
        token = token_;
    }

    function stageDonationRateInflation() external {
        cash = 10_000e18;
        totalBorrows = 0;
        totalReserves = 0;
        totalSupply = 1e18;
        exchangeRate = 10_000e18;
        staged = true;
    }

    function borrowAgainstInflatedRate() external {
        require(!paused, "PROTOCOL_PAUSED");
        require(staged, "EXPLOIT_NOT_STAGED");
        IMockToken(token).mint(attacker, 100e18);
    }

    function pauseAll() external {
        paused = true;
    }

    function attackerBalance() external view returns (uint256) {
        return IMockToken(token).balanceOf(attacker);
    }

    function getMetrics() external view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool) {
        return (cash, totalBorrows, totalReserves, totalSupply, exchangeRate, block.number, paused);
    }
}
