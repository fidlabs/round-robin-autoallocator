// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {RoundRobinAllocator} from "../src/RoundRobinAllocator.sol";

contract AllocatorManagerTest is Test {
    RoundRobinAllocator public roundRobinAllocator;
    address public aliceAddress;
    address public bobAddress;

    function setUp() public {
        roundRobinAllocator = new RoundRobinAllocator();
        roundRobinAllocator.initialize(address(this));

        aliceAddress = makeAddr("alice");
        bobAddress = makeAddr("bob");
    }

    /**
     * ===== ADD ALLOCATOR =====
     */
    function test_addAllocatorSuccess() public {
        roundRobinAllocator.addAllocator(aliceAddress);

        address[] memory allocators = roundRobinAllocator.getAllocators();
        assertEq(allocators.length, 1, "Allocator not added");
        assertEq(allocators[0], aliceAddress, "Wrong allocator address");
    }

    function test_addAllocatorRevertOwner() public {
        vm.prank(aliceAddress);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, aliceAddress));
        roundRobinAllocator.addAllocator(aliceAddress);
    }

    /**
     * ===== REMOVE ALLOCATOR =====
     */
    function test_removeAllocatorSuccess() public {
        roundRobinAllocator.addAllocator(aliceAddress);
        assertEq(roundRobinAllocator.getAllocators().length, 1, "Allocator not added");

        roundRobinAllocator.removeAllocator(aliceAddress);

        address[] memory allocators = roundRobinAllocator.getAllocators();
        assertEq(allocators.length, 0, "Allocator not removed");
    }

    function test_removeAllocatorRevertOwner() public {
        vm.prank(aliceAddress);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, aliceAddress));
        roundRobinAllocator.removeAllocator(aliceAddress);
    }

    function test_removeAllocatorNotFound() public {
        roundRobinAllocator.addAllocator(aliceAddress);

        address[] memory allocatorsBefore = roundRobinAllocator.getAllocators();

        roundRobinAllocator.removeAllocator(bobAddress);

        address[] memory allocatorsAfter = roundRobinAllocator.getAllocators();

        assertEq(allocatorsBefore, allocatorsAfter, "Unexpected change in allocators");
    }
}
