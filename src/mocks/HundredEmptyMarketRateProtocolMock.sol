// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMockToken {
    function mint(address to, uint256 amount) external;
    function balanceOf(address owner) external view returns (uint256);
}

contract HundredEmptyMarketRateProtocolMock {
    address public owner;
    address public emergencyModule;
    address public token;
    address public attacker;
    bool public paused;
    bool public staged;
    uint256 public cash;
    uint256 public totalBorrows;
    uint256 public totalReserves;
    uint256 public totalSupply;
    uint256 public exchangeRate;

    error NotOwner();
    error NotEmergencyModule();
    error ProtocolPaused();

    constructor(address token_) {
        owner = msg.sender;
        token = token_;
    }

    function setEmergencyModule(address emergencyModule_) external {
        _claimOwnerIfNeeded();
        if (msg.sender != owner) revert NotOwner();
        emergencyModule = emergencyModule_;
    }

    function setToken(address token_) external {
        _claimOwnerIfNeeded();
        if (msg.sender != owner) revert NotOwner();
        token = token_;
    }

    function seedHealthy(address attacker_) external {
        _claimOwnerIfNeeded();
        if (msg.sender != owner) revert NotOwner();
        attacker = attacker_;
        paused = false;
        staged = false;
        cash = 100e18;
        totalBorrows = 0;
        totalReserves = 0;
        totalSupply = 10e18;
        exchangeRate = 1e18;
    }

    function stageDonationRateInflation() external {
        if (paused) revert ProtocolPaused();
        cash = 10_000e18;
        totalBorrows = 0;
        totalReserves = 0;
        totalSupply = 1e18;
        exchangeRate = 10_000e18;
        staged = true;
    }

    function borrowAgainstInflatedRate() external {
        if (paused) revert ProtocolPaused();
        require(staged, "EXPLOIT_NOT_STAGED");
        IMockToken(token).mint(attacker, 100e18);
    }

    function emergencyPause() external {
        if (msg.sender != emergencyModule) revert NotEmergencyModule();
        paused = true;
    }

    function attackerBalance() external view returns (uint256) {
        return IMockToken(token).balanceOf(attacker);
    }

    function getMetrics() external view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool) {
        return (cash, totalBorrows, totalReserves, totalSupply, exchangeRate, block.number, paused);
    }

    function _claimOwnerIfNeeded() internal {
        if (owner == address(0)) owner = msg.sender;
    }
}
