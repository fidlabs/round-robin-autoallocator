// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {RoundRobinAllocator} from "../src/RoundRobinAllocator.sol";

contract DevnetDeploy is Script {
    function getProxyAddress() internal view returns (address) {
        return vm.envAddress("PROXY_ADDRESS_TEST");
    }

    function getPrivateKey() internal view returns (uint256) {
        return vm.envUint("PRIVATE_KEY_TEST");
    }

    function run() public {
        vm.startBroadcast(getPrivateKey());

        Options memory opts;
        opts.unsafeAllow = "delegatecall"; // lib/filecoin-solidity/contracts/v0.8/utils/Actor.sol:120: Use of delegatecall is not allowed
        opts.unsafeSkipAllChecks = true;

        address proxy = getProxyAddress();

        if (proxy == address(0) || proxy.code.length == 0) {
            bytes memory initializeData = abi.encodeWithSelector(RoundRobinAllocator.initialize.selector, msg.sender);
            proxy = Upgrades.deployUUPSProxy("RoundRobinAllocator.sol", initializeData, opts);
            console.log("Conract deployed.");
        } else {
            opts.unsafeSkipStorageCheck = true; // skip storage layout check, contract does not have direct storage

            Upgrades.upgradeProxy(
                proxy,
                "RoundRobinAllocator.sol",
                "", // no initializer call on upgrade
                opts
            );
            console.log("Conract upgraded.");
        }

        // INFO: CONTRACT_ADDRESS log is used in fresh.sh
        console.log("CONTRACT_ADDRESS:", proxy);

        vm.stopBroadcast();
    }
}
