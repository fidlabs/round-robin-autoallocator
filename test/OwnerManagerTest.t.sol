// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {RoundRobinAllocator} from "../src/RoundRobinAllocator.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract OwnerManagerTest is Test {
    RoundRobinAllocator public roundRobinAllocator;

    function setUp() public {
        roundRobinAllocator = new RoundRobinAllocator();
        roundRobinAllocator.initialize(address(this), 1, 3);
    }

    function test_setCollateralPerCID() public {
        uint256 newCollateralPerCID = 1000;
        roundRobinAllocator.setCollateralPerCID(newCollateralPerCID);
        assertEq(roundRobinAllocator.getAppConfig().collateralPerCID, newCollateralPerCID);
    }

    function test_setCollateralPerCIDRevert() public {
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(1)));
        roundRobinAllocator.setCollateralPerCID(0);
    }

    function test_setMinRequiredStorageProviders() public {
        uint256 newMinRequiredStorageProviders = 5;
        roundRobinAllocator.setMinRequiredStorageProviders(newMinRequiredStorageProviders);
        assertEq(roundRobinAllocator.getAppConfig().minRequiredStorageProviders, newMinRequiredStorageProviders);
    }

    function test_setMinRequiredStorageProvidersRevert() public {
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(1)));
        roundRobinAllocator.setMinRequiredStorageProviders(0);
    }
}
