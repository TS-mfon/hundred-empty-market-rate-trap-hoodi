// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "./ITrap.sol";
import {TrapAlert} from "./TrapTypes.sol";

interface IHundredEmptyMarketRateEnvironmentRegistryView {
    function environmentId() external view returns (bytes32);
    function monitoredTarget() external view returns (address);
    function active() external view returns (bool);
}

interface IHundredEmptyMarketRateTarget {
    function getMetrics() external view returns (uint256 cash, uint256 totalBorrows, uint256 totalReserves, uint256 totalSupply, uint256 exchangeRate, uint256 observedBlockNumber, bool paused);
}

contract HundredEmptyMarketRateTrap is ITrap {
    address public constant REGISTRY = address(0x0000000000000000000000000000000000003001);
    bytes32 public constant INVARIANT_ID = keccak256("HUNDRED_EMPTY_MARKET_EXCHANGE_RATE_V2");
    uint256 public constant REQUIRED_SAMPLES = 5;
    uint8 internal constant STATUS_OK = 0;
    uint8 internal constant STATUS_REGISTRY_INACTIVE = 1;
    uint8 internal constant STATUS_TARGET_MISSING = 2;
    uint8 internal constant STATUS_METRICS_CALL_FAILED = 3;
    uint8 internal constant STATUS_INVALID_METRICS = 4;
    uint256 internal constant BREACH_WINDOW = 5;
    uint256 internal constant MIN_BREACH_COUNT = 2;
    uint256 internal constant LOW_SUPPLY = 2e18;

    struct CollectOutput {
        bytes32 environmentId;
        address registry;
        address target;
        uint8 status;
        uint256 cash;
        uint256 totalBorrows;
        uint256 totalReserves;
        uint256 totalSupply;
        uint256 exchangeRate;
        uint256 observedBlockNumber;
        bool paused;
    }

    function collect() external view returns (bytes memory) {
        if (REGISTRY.code.length == 0) {
            return _status(bytes32(0), address(0), STATUS_REGISTRY_INACTIVE);
        }

        IHundredEmptyMarketRateEnvironmentRegistryView registry = IHundredEmptyMarketRateEnvironmentRegistryView(REGISTRY);
        bytes32 environmentId = registry.environmentId();
        address target = registry.monitoredTarget();
        if (!registry.active()) return _status(environmentId, target, STATUS_REGISTRY_INACTIVE);
        if (target.code.length == 0) return _status(environmentId, target, STATUS_TARGET_MISSING);

        try IHundredEmptyMarketRateTarget(target).getMetrics() returns (uint256 cash, uint256 totalBorrows, uint256 totalReserves, uint256 totalSupply, uint256 exchangeRate, uint256 observedBlockNumber, bool paused) {
            if (observedBlockNumber == 0 || paused) {
                return abi.encode(CollectOutput({
                    environmentId: environmentId,
                    registry: REGISTRY,
                    target: target,
                    status: paused ? STATUS_OK : STATUS_INVALID_METRICS,
                    cash: cash,
                    totalBorrows: totalBorrows,
                    totalReserves: totalReserves,
                    totalSupply: totalSupply,
                    exchangeRate: exchangeRate,
                    observedBlockNumber: observedBlockNumber == 0 ? block.number : observedBlockNumber,
                    paused: paused
                }));
            }
            return abi.encode(CollectOutput({
                environmentId: environmentId,
                registry: REGISTRY,
                target: target,
                status: STATUS_OK,
                cash: cash,
                    totalBorrows: totalBorrows,
                    totalReserves: totalReserves,
                    totalSupply: totalSupply,
                    exchangeRate: exchangeRate,
                observedBlockNumber: observedBlockNumber,
                paused: paused
            }));
        } catch {
            return _status(environmentId, target, STATUS_METRICS_CALL_FAILED);
        }
    }

    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        if (data.length < REQUIRED_SAMPLES) return (false, bytes(""));
        CollectOutput memory latest = abi.decode(data[0], (CollectOutput));
        CollectOutput memory historical = abi.decode(data[data.length - 1], (CollectOutput));
        if (latest.status != STATUS_OK || latest.paused) return (false, bytes(""));
        if (historical.status != STATUS_OK || historical.environmentId != latest.environmentId || historical.target != latest.target) {
            return (false, bytes(""));
        }

        bool latestBreached = (latest.totalSupply < LOW_SUPPLY && latest.exchangeRate > historical.exchangeRate * 5 && latest.cash > historical.cash);
        if (!latestBreached) return (false, bytes(""));

        uint256 checked = data.length < BREACH_WINDOW ? data.length : BREACH_WINDOW;
        uint256 breachCount;
        for (uint256 i = 0; i < checked; i++) {
            CollectOutput memory sample = abi.decode(data[i], (CollectOutput));
            if (sample.status != STATUS_OK || sample.paused || sample.target != latest.target) continue;
            if (sample.observedBlockNumber >= historical.observedBlockNumber) {
                if (sample.totalSupply < LOW_SUPPLY && sample.exchangeRate > historical.exchangeRate * 5 && sample.cash > historical.cash) breachCount++;
            }
        }

        uint256 deteriorationSignals;
        if (latest.observedBlockNumber >= historical.observedBlockNumber) deteriorationSignals++;
        if (latest.target == historical.target) deteriorationSignals++;

        if (breachCount < MIN_BREACH_COUNT || deteriorationSignals < 2) return (false, bytes(""));

        TrapAlert memory alert = TrapAlert({
            invariantId: INVARIANT_ID,
            target: latest.target,
            observed: latest.exchangeRate,
            expected: historical.exchangeRate,
            blockNumber: latest.observedBlockNumber,
            environmentId: latest.environmentId,
            context: abi.encode(latest.registry, latest.status, latest.cash, latest.totalBorrows, latest.totalReserves, latest.totalSupply, latest.exchangeRate, breachCount, deteriorationSignals)
        });
        return (true, abi.encode(alert));
    }

    function _status(bytes32 environmentId, address target, uint8 status) internal view returns (bytes memory) {
        return abi.encode(CollectOutput({
            environmentId: environmentId,
            registry: REGISTRY,
            target: target,
            status: status,
            cash: 100e18,
                    totalBorrows: 0,
                    totalReserves: 0,
                    totalSupply: 10e18,
                    exchangeRate: 1e18,
            observedBlockNumber: block.number,
            paused: false
        }));
    }

}
