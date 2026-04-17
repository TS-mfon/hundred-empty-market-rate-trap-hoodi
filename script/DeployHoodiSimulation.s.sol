// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/mocks/MockToken.sol";
import "../src/mocks/HundredEmptyMarketRateProtocolMock.sol";
import "../src/mocks/HundredEmptyMarketRateAttacker.sol";
import "../src/HundredEmptyMarketRateResponse.sol";
import "../src/HundredEmptyMarketRateEnvironmentRegistry.sol";

interface VmScript {
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract DeployHoodiSimulation {
    VmScript internal constant vm = VmScript(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Deployment {
        address token;
        address protocol;
        address attacker;
        address response;
        address registry;
    }

    function run() external returns (Deployment memory out) {
        vm.startBroadcast();
        MockToken token = new MockToken();
        HundredEmptyMarketRateProtocolMock protocol = new HundredEmptyMarketRateProtocolMock(address(token));
        HundredEmptyMarketRateAttacker attacker = new HundredEmptyMarketRateAttacker(address(protocol));
        HundredEmptyMarketRateResponse response = new HundredEmptyMarketRateResponse();
        protocol.setEmergencyModule(address(response));
        protocol.seedHealthy(address(attacker));
        HundredEmptyMarketRateEnvironmentRegistry registry = new HundredEmptyMarketRateEnvironmentRegistry(keccak256("hundred-empty-market-rate-trap-hoodi"), address(protocol), address(response), address(response), true);
        out = Deployment(address(token), address(protocol), address(attacker), address(response), address(registry));
        vm.stopBroadcast();
    }
}
