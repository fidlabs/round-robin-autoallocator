// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {ErrorLib} from "../src/libraries/Errors.sol";
import {DiamondDeployer} from "./lib/DiamondDeployer.sol";
import {Types} from "../src/libraries/Types.sol";
import {ViewFacet} from "../src/facets/ViewFacet.sol";
import {StorageEntityManagerFacet} from "../src/facets/StorageEntityManagerFacet.sol";
import {AllocatorManagerFacet} from "../src/facets/AllocatorManagerFacet.sol";

contract StorageEntityManagerFacetTest is Test {
    address public aliceAddress;
    address public allocatorAddress;
    address public seAddress;

    StorageEntityManagerFacet public storageEntityManagerFacet;
    AllocatorManagerFacet public allocatorManagerFacet;
    ViewFacet public viewFacet;

    function setUp() public {
        address diamond = DiamondDeployer.deployDiamond(address(this));
        storageEntityManagerFacet = StorageEntityManagerFacet(diamond);
        allocatorManagerFacet = AllocatorManagerFacet(diamond);
        viewFacet = ViewFacet(diamond);

        aliceAddress = makeAddr("alice");
        allocatorAddress = makeAddr("allocator");
        seAddress = makeAddr("storageEntity");

        allocatorManagerFacet.addAllocator(allocatorAddress);
    }

    function test_createStorageEntitySuccess() public {
        address[] memory allowedCallers = new address[](2);
        allowedCallers[0] = address(this); // contract owner
        allowedCallers[1] = allocatorAddress; // allocator

        for (uint256 i = 1; i <= allowedCallers.length; i++) {
            uint64[] memory storageProviders = new uint64[](1);
            storageProviders[0] = uint64(i);
            address se = address(uint160(i));
            storageEntityManagerFacet.createStorageEntity(se, storageProviders);

            Types.StorageEntityView memory storageEntity = viewFacet.getStorageEntity(se);
            assertEq(storageEntity.owner, se);
            assertEq(storageEntity.storageProviders[0], storageProviders[0]);
            assertTrue(storageEntityManagerFacet.isStorageProviderUsed(storageProviders[0]));
        }
        Types.StorageEntityView[] memory storageEntities = viewFacet.getStorageEntities();
        assertEq(storageEntities.length, allowedCallers.length);
    }

    function test_createStorageEntityExistsRevert() public {
        Types.StorageEntityView memory se = _prepareStorageEntity(address(1), new uint64[](0));

        vm.prank(allocatorAddress);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.StorageEntityAlreadyExists.selector));
        storageEntityManagerFacet.createStorageEntity(se.owner, se.storageProviders);
    }

    function test_createStorageEntityOwnerRevert() public {
        vm.prank(aliceAddress);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotOwnerOrAllocator.selector));
        storageEntityManagerFacet.createStorageEntity(aliceAddress, new uint64[](1));
    }

    function test_createStorageEntityStorageProviderUsedRevert() public {
        Types.StorageEntityView memory se = _prepareStorageEntity(address(1), new uint64[](0));

        vm.prank(allocatorAddress);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.StorageProviderAlreadyUsed.selector));
        storageEntityManagerFacet.createStorageEntity(address(2), se.storageProviders);
    }

    function _prepareStorageEntity(address seAddress_, uint64[] memory storageProviders_)
        private
        returns (Types.StorageEntityView memory)
    {
        address _seAddress = seAddress_ == address(0) ? seAddress : seAddress_;
        uint64[] memory storageProviders = new uint64[](1);
        storageProviders[0] = 1;
        uint64[] memory _storageProviders = storageProviders_.length == 0 ? storageProviders : storageProviders_;
        vm.prank(allocatorAddress);
        storageEntityManagerFacet.createStorageEntity(_seAddress, _storageProviders);
        vm.prank(address(this));

        return viewFacet.getStorageEntity(_seAddress);
    }

    function test_addStorageProviderSuccess() public {
        Types.StorageEntityView memory storageEntity = _prepareStorageEntity(address(1), new uint64[](0));
        assertEq(storageEntity.storageProviders.length, 1);

        uint64[] memory storageProviders = new uint64[](1);
        storageProviders[0] = 2;

        vm.prank(storageEntity.owner);
        storageEntityManagerFacet.addStorageProviders(storageEntity.owner, storageProviders);

        Types.StorageEntityView memory updatedStorageEntity = viewFacet.getStorageEntity(storageEntity.owner);
        assertEq(updatedStorageEntity.storageProviders.length, 2);
        assertEq(updatedStorageEntity.storageProviders[1], storageProviders[0]);
        assertTrue(storageEntityManagerFacet.isStorageProviderUsed(updatedStorageEntity.storageProviders[0]));
        assertTrue(storageEntityManagerFacet.isStorageProviderUsed(updatedStorageEntity.storageProviders[1]));
    }

    function test_addStorageProviderOwnerRevert() public {
        Types.StorageEntityView memory storageEntity = _prepareStorageEntity(address(1), new uint64[](0));
        assertEq(storageEntity.storageProviders.length, 1);

        vm.prank(aliceAddress);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNoOwnerOrStorageEntity.selector));
        storageEntityManagerFacet.addStorageProviders(address(1), new uint64[](1));
    }

    function test_removeStorageProvidersSuccess() public {
        uint64[] memory storageProviders = new uint64[](1);
        storageProviders[0] = 1;

        Types.StorageEntityView memory storageEntity = _prepareStorageEntity(address(1), storageProviders);
        assertEq(storageEntity.storageProviders.length, 1);

        vm.prank(storageEntity.owner);
        storageEntityManagerFacet.removeStorageProviders(storageEntity.owner, storageEntity.storageProviders);

        Types.StorageEntityView memory updatedStorageEntity = viewFacet.getStorageEntity(storageEntity.owner);
        assertEq(updatedStorageEntity.storageProviders.length, 0);
        assertFalse(storageEntityManagerFacet.isStorageProviderUsed(storageProviders[0]));
    }

    function test_removeStorageProviderOwnerRevert() public {
        Types.StorageEntityView memory storageEntity = _prepareStorageEntity(address(1), new uint64[](0));
        assertEq(storageEntity.storageProviders.length, 1);

        vm.prank(aliceAddress);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNoOwnerOrStorageEntity.selector));
        storageEntityManagerFacet.removeStorageProviders(storageEntity.owner, storageEntity.storageProviders);
    }

    function test_removeStorageProviderMissingStorageProviderSuccess() public {
        Types.StorageEntityView memory storageEntity = _prepareStorageEntity(address(1), new uint64[](0));
        assertEq(storageEntity.storageProviders.length, 1);

        vm.prank(storageEntity.owner);
        storageEntityManagerFacet.removeStorageProviders(storageEntity.owner, new uint64[](0));

        Types.StorageEntityView memory updatedStorageEntity = viewFacet.getStorageEntity(storageEntity.owner);

        assertEq(updatedStorageEntity.storageProviders.length, 1);
        assertEq(updatedStorageEntity.storageProviders[0], storageEntity.storageProviders[0]);
    }

    function test_changeStorageEntityActiveStatusSuccess() public {
        Types.StorageEntityView memory storageEntity = _prepareStorageEntity(address(1), new uint64[](0));
        assertEq(storageEntity.isActive, true);

        vm.prank(storageEntity.owner);
        storageEntityManagerFacet.setStorageEntityActiveStatus(storageEntity.owner, false);

        Types.StorageEntityView memory updatedStorageEntity = viewFacet.getStorageEntity(storageEntity.owner);
        assertEq(updatedStorageEntity.isActive, false);

        vm.prank(storageEntity.owner);
        storageEntityManagerFacet.setStorageEntityActiveStatus(storageEntity.owner, true);

        Types.StorageEntityView memory reupdatedStorageEntity = viewFacet.getStorageEntity(storageEntity.owner);
        assertEq(reupdatedStorageEntity.isActive, true);
    }

    function test_changeStorageEntityActiveStatusOwnerRevert() public {
        Types.StorageEntityView memory storageEntity = _prepareStorageEntity(address(1), new uint64[](0));
        assertEq(storageEntity.isActive, true);

        vm.prank(aliceAddress);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNoOwnerOrStorageEntity.selector));
        storageEntityManagerFacet.setStorageEntityActiveStatus(storageEntity.owner, false);

        Types.StorageEntityView memory updatedStorageEntity = viewFacet.getStorageEntity(storageEntity.owner);

        assertEq(updatedStorageEntity.isActive, true);
    }
}
