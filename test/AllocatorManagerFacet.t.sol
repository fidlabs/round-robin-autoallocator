// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {DiamondDeployer} from "./lib/DiamondDeployer.sol";
import {AllocatorManagerFacet} from "../src/facets/AllocatorManagerFacet.sol";
import {ErrorLib} from "../src/libraries/Errors.sol";

contract AllocatorManagerFacetTest is Test {
    address public diamond;
    AllocatorManagerFacet public allocatorManagerFacet;
    address public aliceAddress;
    address public bobAddress;

    function setUp() public {
        diamond = DiamondDeployer.deployDiamond(address(this));
        allocatorManagerFacet = AllocatorManagerFacet(address(diamond));

        aliceAddress = makeAddr("alice");
        bobAddress = makeAddr("bob");
    }

    function test_addAllocatorSuccess() public {
        allocatorManagerFacet.addAllocator(aliceAddress);

        address[] memory allocators = allocatorManagerFacet.getAllocators();
        assertEq(allocators.length, 1, "Allocator not added");
        assertEq(allocators[0], aliceAddress, "Wrong allocator address");
    }

    function test_addAllocatorRevertOwner() public {
        vm.prank(aliceAddress);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotOwner.selector));
        allocatorManagerFacet.addAllocator(aliceAddress);
    }

    function test_removeAllocatorSuccess() public {
        allocatorManagerFacet.addAllocator(aliceAddress);
        assertEq(allocatorManagerFacet.getAllocators().length, 1, "Allocator not added");

        allocatorManagerFacet.removeAllocator(aliceAddress);

        address[] memory allocators = allocatorManagerFacet.getAllocators();
        assertEq(allocators.length, 0, "Allocator not removed");
    }

    function test_removeAllocatorRevertOwner() public {
        vm.prank(aliceAddress);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotOwner.selector));
        allocatorManagerFacet.removeAllocator(aliceAddress);
    }

    function test_removeAllocatorNotFound() public {
        allocatorManagerFacet.addAllocator(aliceAddress);

        address[] memory allocatorsBefore = allocatorManagerFacet.getAllocators();

        allocatorManagerFacet.removeAllocator(bobAddress);

        address[] memory allocatorsAfter = allocatorManagerFacet.getAllocators();

        assertEq(allocatorsBefore, allocatorsAfter, "Unexpected change in allocators");
    }
}
