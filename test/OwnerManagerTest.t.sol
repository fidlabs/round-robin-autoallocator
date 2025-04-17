// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {RoundRobinAllocator, AllocationRequest} from "../src/RoundRobinAllocator.sol";
import {ErrorLib} from "../src/lib/Errors.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract OwnerManagerTest is Test {
    RoundRobinAllocator public roundRobinAllocator;

    function setUp() public {
        roundRobinAllocator = _deployRoundRobinAllocator();
    }

    function _deployRoundRobinAllocator() internal returns (RoundRobinAllocator) {
        RoundRobinAllocator allocator = new RoundRobinAllocator();
        bytes memory initData = abi.encodeWithSelector(RoundRobinAllocator.initialize.selector, address(this), 1, 3);
        ERC1967Proxy proxy = new ERC1967Proxy(address(allocator), initData);
        return RoundRobinAllocator(address(proxy));
    }

    function test_whenPausedRevert() public {
        AllocationRequest[] memory requests = new AllocationRequest[](0);
        roundRobinAllocator.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        roundRobinAllocator.allocate(1, requests);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        roundRobinAllocator.claim(1);

        roundRobinAllocator.unpause();
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotEOA.selector));
        roundRobinAllocator.allocate(1, requests);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidClaim.selector));
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
