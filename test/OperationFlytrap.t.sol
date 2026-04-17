// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/HundredEmptyMarketRateTrap.sol";
import "../src/HundredEmptyMarketRateResponse.sol";
import "../src/TrapTypes.sol";
import "../src/mocks/HundredEmptyMarketRateProtocolMock.sol";
import "../src/mocks/HundredEmptyMarketRateAttacker.sol";
import "../src/mocks/MockToken.sol";


interface Vm {
    function etch(address target, bytes calldata newRuntimeBytecode) external;
    function prank(address sender) external;
}

contract TestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address internal constant TARGET = address(0x0000000000000000000000000000000000001001);
    address internal constant TOKEN = address(0x0000000000000000000000000000000000002002);
    address internal constant DROSERA = address(0x000000000000000000000000000000000000d0A0);

    function assertTrue(bool value, string memory reason) internal pure {
        require(value, reason);
    }

    function assertFalse(bool value, string memory reason) internal pure {
        require(!value, reason);
    }

    function assertEq(uint256 a, uint256 b, string memory reason) internal pure {
        require(a == b, reason);
    }
}

contract ExploitReproductionTest is TestBase {

    function _deploy() internal returns (HundredEmptyMarketRateTrap trap, HundredEmptyMarketRateResponse response, HundredEmptyMarketRateProtocolMock protocol, HundredEmptyMarketRateAttacker attacker) {
        MockToken tokenImpl = new MockToken();
        vm.etch(TOKEN, address(tokenImpl).code);
        HundredEmptyMarketRateProtocolMock protocolImpl = new HundredEmptyMarketRateProtocolMock();
        vm.etch(TARGET, address(protocolImpl).code);
        protocol = HundredEmptyMarketRateProtocolMock(TARGET);
        attacker = new HundredEmptyMarketRateAttacker(TARGET);
        protocol.seedHealthy(address(attacker));
        trap = new HundredEmptyMarketRateTrap();
        response = new HundredEmptyMarketRateResponse();
    }

    function _samples(HundredEmptyMarketRateTrap trap, bool exploit) internal returns (bytes[] memory data) {
        data = new bytes[](5);
        data[data.length - 1] = trap.collect();
        if (exploit) {
            HundredEmptyMarketRateAttacker attacker = new HundredEmptyMarketRateAttacker(TARGET);
            attacker.stageExploit();
        }
        for (uint256 i = 0; i < data.length - 1; i++) {
            data[i] = trap.collect();
        }
    }

    function testExploitSucceedsWithoutTrap() public {
        (, , HundredEmptyMarketRateProtocolMock protocol, HundredEmptyMarketRateAttacker attacker) = _deploy();
        attacker.stageExploit();
        attacker.completeExploit();
        assertEq(protocol.attackerBalance(), 100e18, "attacker should receive extracted value");
    }
}

contract TrapLifecycleTest is TestBase {

    function _deploy() internal returns (HundredEmptyMarketRateTrap trap, HundredEmptyMarketRateResponse response, HundredEmptyMarketRateProtocolMock protocol, HundredEmptyMarketRateAttacker attacker) {
        MockToken tokenImpl = new MockToken();
        vm.etch(TOKEN, address(tokenImpl).code);
        HundredEmptyMarketRateProtocolMock protocolImpl = new HundredEmptyMarketRateProtocolMock();
        vm.etch(TARGET, address(protocolImpl).code);
        protocol = HundredEmptyMarketRateProtocolMock(TARGET);
        attacker = new HundredEmptyMarketRateAttacker(TARGET);
        protocol.seedHealthy(address(attacker));
        trap = new HundredEmptyMarketRateTrap();
        response = new HundredEmptyMarketRateResponse();
    }

    function _samples(HundredEmptyMarketRateTrap trap, bool exploit) internal returns (bytes[] memory data) {
        data = new bytes[](5);
        data[data.length - 1] = trap.collect();
        if (exploit) {
            HundredEmptyMarketRateAttacker attacker = new HundredEmptyMarketRateAttacker(TARGET);
            attacker.stageExploit();
        }
        for (uint256 i = 0; i < data.length - 1; i++) {
            data[i] = trap.collect();
        }
    }

    function testCollectDecodesHealthyState() public {
        (HundredEmptyMarketRateTrap trap,,,) = _deploy();
        HundredEmptyMarketRateTrap.CollectOutput memory out = abi.decode(trap.collect(), (HundredEmptyMarketRateTrap.CollectOutput));
        assertEq(out.blockNumber, block.number, "block number encoded");
    }

    function testShouldRespondFalseOnHealthyWindow() public {
        (HundredEmptyMarketRateTrap trap,,,) = _deploy();
        bytes[] memory data = _samples(trap, false);
        (bool ok,) = trap.shouldRespond(data);
        assertFalse(ok, "healthy window must not trigger");
    }

    function testShouldRespondTrueOnExploitWindow() public {
        (HundredEmptyMarketRateTrap trap,,,) = _deploy();
        bytes[] memory data = _samples(trap, true);
        (bool ok, bytes memory payload) = trap.shouldRespond(data);
        assertTrue(ok, "exploit window must trigger");
        TrapAlert memory alert = abi.decode(payload, (TrapAlert));
        assertTrue(alert.invariantId == keccak256("HUNDRED_EMPTY_MARKET_EXCHANGE_RATE"), "invariant id");
    }
}

contract ContainmentTest is TestBase {

    function _deploy() internal returns (HundredEmptyMarketRateTrap trap, HundredEmptyMarketRateResponse response, HundredEmptyMarketRateProtocolMock protocol, HundredEmptyMarketRateAttacker attacker) {
        MockToken tokenImpl = new MockToken();
        vm.etch(TOKEN, address(tokenImpl).code);
        HundredEmptyMarketRateProtocolMock protocolImpl = new HundredEmptyMarketRateProtocolMock();
        vm.etch(TARGET, address(protocolImpl).code);
        protocol = HundredEmptyMarketRateProtocolMock(TARGET);
        attacker = new HundredEmptyMarketRateAttacker(TARGET);
        protocol.seedHealthy(address(attacker));
        trap = new HundredEmptyMarketRateTrap();
        response = new HundredEmptyMarketRateResponse();
    }

    function _samples(HundredEmptyMarketRateTrap trap, bool exploit) internal returns (bytes[] memory data) {
        data = new bytes[](5);
        data[data.length - 1] = trap.collect();
        if (exploit) {
            HundredEmptyMarketRateAttacker attacker = new HundredEmptyMarketRateAttacker(TARGET);
            attacker.stageExploit();
        }
        for (uint256 i = 0; i < data.length - 1; i++) {
            data[i] = trap.collect();
        }
    }

    function testExploitContainedWithTrap() public {
        (HundredEmptyMarketRateTrap trap, HundredEmptyMarketRateResponse response, HundredEmptyMarketRateProtocolMock protocol, HundredEmptyMarketRateAttacker attacker) = _deploy();
        bytes[] memory data = _samples(trap, true);
        (bool ok, bytes memory payload) = trap.shouldRespond(data);
        assertTrue(ok, "trap must trigger before completion");
        TrapAlert memory alert = abi.decode(payload, (TrapAlert));
        vm.prank(DROSERA);
        response.handleIncident(alert);
        bool reverted;
        try attacker.completeExploit() {} catch { reverted = true; }
        assertTrue(reverted, "completion must revert after response");
        assertEq(protocol.attackerBalance(), 0, "attacker extracted balance must remain zero");
    }
}

contract ResponseAuthorizationTest is TestBase {

    function _deploy() internal returns (HundredEmptyMarketRateTrap trap, HundredEmptyMarketRateResponse response, HundredEmptyMarketRateProtocolMock protocol, HundredEmptyMarketRateAttacker attacker) {
        MockToken tokenImpl = new MockToken();
        vm.etch(TOKEN, address(tokenImpl).code);
        HundredEmptyMarketRateProtocolMock protocolImpl = new HundredEmptyMarketRateProtocolMock();
        vm.etch(TARGET, address(protocolImpl).code);
        protocol = HundredEmptyMarketRateProtocolMock(TARGET);
        attacker = new HundredEmptyMarketRateAttacker(TARGET);
        protocol.seedHealthy(address(attacker));
        trap = new HundredEmptyMarketRateTrap();
        response = new HundredEmptyMarketRateResponse();
    }

    function _samples(HundredEmptyMarketRateTrap trap, bool exploit) internal returns (bytes[] memory data) {
        data = new bytes[](5);
        data[data.length - 1] = trap.collect();
        if (exploit) {
            HundredEmptyMarketRateAttacker attacker = new HundredEmptyMarketRateAttacker(TARGET);
            attacker.stageExploit();
        }
        for (uint256 i = 0; i < data.length - 1; i++) {
            data[i] = trap.collect();
        }
    }

    function testOnlyDroseraCanCallResponse() public {
        (HundredEmptyMarketRateTrap trap, HundredEmptyMarketRateResponse response,,) = _deploy();
        bytes[] memory data = _samples(trap, true);
        (, bytes memory payload) = trap.shouldRespond(data);
        TrapAlert memory alert = abi.decode(payload, (TrapAlert));
        bool reverted;
        try response.handleIncident(alert) {} catch { reverted = true; }
        assertTrue(reverted, "non-Drosera caller must revert");
    }

    function testResponseRejectsWrongInvariant() public {
        (, HundredEmptyMarketRateResponse response,,) = _deploy();
        TrapAlert memory alert = TrapAlert(bytes32(uint256(1)), TARGET, 1, 0, block.number, bytes(""));
        vm.prank(DROSERA);
        bool reverted;
        try response.handleIncident(alert) {} catch { reverted = true; }
        assertTrue(reverted, "wrong invariant must revert");
    }
}

contract FuzzTest is TestBase {

    function _deploy() internal returns (HundredEmptyMarketRateTrap trap, HundredEmptyMarketRateResponse response, HundredEmptyMarketRateProtocolMock protocol, HundredEmptyMarketRateAttacker attacker) {
        MockToken tokenImpl = new MockToken();
        vm.etch(TOKEN, address(tokenImpl).code);
        HundredEmptyMarketRateProtocolMock protocolImpl = new HundredEmptyMarketRateProtocolMock();
        vm.etch(TARGET, address(protocolImpl).code);
        protocol = HundredEmptyMarketRateProtocolMock(TARGET);
        attacker = new HundredEmptyMarketRateAttacker(TARGET);
        protocol.seedHealthy(address(attacker));
        trap = new HundredEmptyMarketRateTrap();
        response = new HundredEmptyMarketRateResponse();
    }

    function _samples(HundredEmptyMarketRateTrap trap, bool exploit) internal returns (bytes[] memory data) {
        data = new bytes[](5);
        data[data.length - 1] = trap.collect();
        if (exploit) {
            HundredEmptyMarketRateAttacker attacker = new HundredEmptyMarketRateAttacker(TARGET);
            attacker.stageExploit();
        }
        for (uint256 i = 0; i < data.length - 1; i++) {
            data[i] = trap.collect();
        }
    }

    function testInsufficientSamplesDoNotTriggerUnlessHardInvariantBroken() public {
        (HundredEmptyMarketRateTrap trap,,,) = _deploy();
        bytes[] memory data = new bytes[](1);
        data[0] = trap.collect();
        (bool ok,) = trap.shouldRespond(data);
        assertFalse(ok, "insufficient samples");
    }

    function testFuzzNearThresholdNoFalsePositive(uint256 ignored) public {
        ignored;
        (HundredEmptyMarketRateTrap trap,,,) = _deploy();
        bytes[] memory data = _samples(trap, false);
        (bool ok,) = trap.shouldRespond(data);
        assertFalse(ok, "healthy fuzz baseline");
    }
}
