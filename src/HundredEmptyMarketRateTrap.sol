// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "./ITrap.sol";
import {TrapAlert} from "./TrapTypes.sol";

interface IHundredEmptyMarketRateTarget {
    function getMetrics() external view returns (uint256 cash, uint256 totalBorrows, uint256 totalReserves, uint256 totalSupply, uint256 exchangeRate, uint256 blockNumber, bool paused);
}

contract HundredEmptyMarketRateTrap is ITrap {
    address public constant TARGET = address(0x0000000000000000000000000000000000001001);
    bytes32 public constant INVARIANT_ID = keccak256("HUNDRED_EMPTY_MARKET_EXCHANGE_RATE");
    uint256 public constant REQUIRED_SAMPLES = 5;

    uint256 internal constant LOW_SUPPLY = 2e18;

    struct CollectOutput {
    address target;
    uint256 cash;
    uint256 totalBorrows;
    uint256 totalReserves;
    uint256 totalSupply;
    uint256 exchangeRate;
    uint256 blockNumber;
    bool paused;
    }

    function collect() external view returns (bytes memory) {
        if (TARGET.code.length == 0) {
            return abi.encode(CollectOutput({
                target: TARGET,
                cash: 100e18,
            totalBorrows: 0,
            totalReserves: 0,
            totalSupply: 10e18,
            exchangeRate: 1e18,
                blockNumber: block.number,
                paused: false
            }));
        }
        try IHundredEmptyMarketRateTarget(TARGET).getMetrics() returns (uint256 cash, uint256 totalBorrows, uint256 totalReserves, uint256 totalSupply, uint256 exchangeRate, uint256 blockNumber, bool paused) {
            return abi.encode(CollectOutput({
                target: TARGET,
                cash: cash,
                totalBorrows: totalBorrows,
                totalReserves: totalReserves,
                totalSupply: totalSupply,
                exchangeRate: exchangeRate,
                blockNumber: blockNumber,
                paused: paused
            }));
        } catch {
            return abi.encode(CollectOutput({
                target: TARGET,
                cash: 100e18,
            totalBorrows: 0,
            totalReserves: 0,
            totalSupply: 10e18,
            exchangeRate: 1e18,
                blockNumber: block.number,
                paused: false
            }));
        }
    }

    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        if (data.length < REQUIRED_SAMPLES) return (false, bytes(""));
        CollectOutput memory latest = abi.decode(data[0], (CollectOutput));
        CollectOutput memory oldest = abi.decode(data[data.length - 1], (CollectOutput));
        if (latest.totalSupply < LOW_SUPPLY && latest.exchangeRate > oldest.exchangeRate * 5 && latest.cash > oldest.cash) {
            TrapAlert memory alert = TrapAlert({
                invariantId: INVARIANT_ID,
                target: latest.target,
                observed: latest.exchangeRate,
                expected: oldest.exchangeRate,
                blockNumber: latest.blockNumber,
                context: abi.encode(latest.cash, latest.totalBorrows, latest.totalReserves, latest.totalSupply, latest.exchangeRate)
            });
            return (true, abi.encode(alert));
        }
        return (false, bytes(""));
    }

}
