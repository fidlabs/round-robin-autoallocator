// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {RoundRobinAllocator, AllocationRequest} from "../src/RoundRobinAllocator.sol";
import {Errors} from "../src/lib/Errors.sol";

contract OwnerManagerTest is Test {
    RoundRobinAllocator public roundRobinAllocator;

    function setUp() public {
        roundRobinAllocator = new RoundRobinAllocator();
        roundRobinAllocator.initialize(address(this), 1, 3);
    }

    function test_whenPausedRevert() public {
        AllocationRequest[] memory requests = new AllocationRequest[](0);
        roundRobinAllocator.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        roundRobinAllocator.allocate(1, requests);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        roundRobinAllocator.claim(1);

        roundRobinAllocator.unpause();
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerIsNotEOA.selector));
        roundRobinAllocator.allocate(1, requests);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidClaim.selector));
        roundRobinAllocator.claim(123);
    }

    function test_pauseUnpauseOwnerRevert() public {
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(1)));
        roundRobinAllocator.pause();

        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(1)));
        roundRobinAllocator.unpause();
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
