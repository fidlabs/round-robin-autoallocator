// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {Storage} from "../src/Storage.sol";
import {Errors} from "../src/lib/Errors.sol";
import {RoundRobinAllocator} from "../src/RoundRobinAllocator.sol";

contract StorageEntityManagerTest is Test {
    RoundRobinAllocator public roundRobinAllocator;
    address public aliceAddress;
    address public allocatorAddress;
    address public seAddress;

    function setUp() public {
        roundRobinAllocator = new RoundRobinAllocator();
        roundRobinAllocator.initialize(address(this));

        aliceAddress = makeAddr("alice");
        allocatorAddress = makeAddr("allocator");
        seAddress = makeAddr("storageEntity");

        roundRobinAllocator.addAllocator(allocatorAddress);
    }

    /**
     * ===== CREATE STORAGE ENTITY =====
     */

    function test_createStorageEntitySuccess() public {
        address[] memory allowedCallers = new address[](2);
        allowedCallers[0] = address(this); // contract owner
        allowedCallers[1] = allocatorAddress; // allocator

        for (uint i = 0; i < allowedCallers.length; i++) {
            uint64[] memory storageProviders = new uint64[](1);
            storageProviders[0] = uint64(i);
            address se = address(uint160(i)); // just get me an address ;)
            roundRobinAllocator.createStorageEntity(se, storageProviders);

            Storage.StorageEntity memory storageEntity = roundRobinAllocator
                .getStorageEntity(se);
            assertEq(storageEntity.owner, se);
            assertEq(storageEntity.storageProviders[0], storageProviders[0]);
            assertTrue(
                roundRobinAllocator.isStorageProviderUsed(storageProviders[0])
            );
        }
    }

    function test_createStorageEntityOwnerRevert() public {
        vm.prank(aliceAddress);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CallerIsNotOwnerOrAllocator.selector)
        );
        roundRobinAllocator.createStorageEntity(aliceAddress, new uint64[](1));
    }

    function test_createStorageEntityStorageProviderUsedRevert() public {
        Storage.StorageEntity memory se = _prepareStorageEntity(
            address(1),
            new uint64[](0)
        );

        vm.prank(allocatorAddress);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.StorageProviderAlreadyUsed.selector)
        );
        roundRobinAllocator.createStorageEntity(
            address(2),
            se.storageProviders
        );
    }

    function _prepareStorageEntity(
        address seAddress_,
        uint64[] memory storageProviders_
    ) private returns (Storage.StorageEntity memory) {
        address _seAddress = seAddress_ == address(0) ? seAddress : seAddress_;
        uint64[] memory storageProviders = new uint64[](1);
        storageProviders[0] = 1;
        uint64[] memory _storageProviders = storageProviders_.length == 0
            ? storageProviders
            : storageProviders_;
        vm.prank(allocatorAddress);
        roundRobinAllocator.createStorageEntity(_seAddress, _storageProviders);
        vm.prank(address(this));

        return roundRobinAllocator.getStorageEntity(_seAddress);
    }

    /**
     * ===== ADD STORAGE PROVIDER =====
     */

    function test_addStorageProviderSuccess() public {
        Storage.StorageEntity memory storageEntity = _prepareStorageEntity(
            address(1),
            new uint64[](0)
        );
        assertEq(storageEntity.storageProviders.length, 1);

        uint64[] memory storageProviders = new uint64[](1);
        storageProviders[0] = 2;

        vm.prank(storageEntity.owner);
        roundRobinAllocator.addStorageProviders(
            storageEntity.owner,
            storageProviders
        );

        Storage.StorageEntity memory updatedStorageEntity = roundRobinAllocator
            .getStorageEntity(storageEntity.owner);
        assertEq(updatedStorageEntity.storageProviders.length, 2);
        assertEq(updatedStorageEntity.storageProviders[1], storageProviders[0]);
        assertTrue(
            roundRobinAllocator.isStorageProviderUsed(
                updatedStorageEntity.storageProviders[0]
            )
        );
        assertTrue(
            roundRobinAllocator.isStorageProviderUsed(
                updatedStorageEntity.storageProviders[1]
            )
        );
    }

    function test_addStorageProviderOwnerRevert() public {
        Storage.StorageEntity memory storageEntity = _prepareStorageEntity(
            address(1),
            new uint64[](0)
        );
        assertEq(storageEntity.storageProviders.length, 1);

        vm.prank(aliceAddress);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CallerIsNotStorageEntity.selector)
        );
        roundRobinAllocator.addStorageProviders(address(1), new uint64[](1));
    }

    /**
     * ===== REMOVE STORAGE PROVIDER =====
     */

    function test_removeStorageProvidersSuccess() public {
        uint64[] memory storageProviders = new uint64[](1);
        storageProviders[0] = 1;

        Storage.StorageEntity memory storageEntity = _prepareStorageEntity(
            address(1),
            storageProviders
        );
        assertEq(storageEntity.storageProviders.length, 1);

        vm.prank(storageEntity.owner);
        roundRobinAllocator.removeStorageProviders(
            storageEntity.owner,
            storageEntity.storageProviders
        );

        Storage.StorageEntity memory updatedStorageEntity = roundRobinAllocator
            .getStorageEntity(storageEntity.owner);
        assertEq(updatedStorageEntity.storageProviders.length, 0);
        assertFalse(
            roundRobinAllocator.isStorageProviderUsed(storageProviders[0])
        );
    }

    function test_removeStorageProviderOwnerRevert() public {
        Storage.StorageEntity memory storageEntity = _prepareStorageEntity(
            address(1),
            new uint64[](0)
        );
        assertEq(storageEntity.storageProviders.length, 1);

        vm.prank(aliceAddress);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CallerIsNotStorageEntity.selector)
        );
        roundRobinAllocator.removeStorageProviders(
            storageEntity.owner,
            storageEntity.storageProviders
        );
    }

    function test_removeStorageProviderMissingStorageProviderSuccess() public {
        Storage.StorageEntity memory storageEntity = _prepareStorageEntity(
            address(1),
            new uint64[](0)
        );
        assertEq(storageEntity.storageProviders.length, 1);

        vm.prank(storageEntity.owner);
        roundRobinAllocator.removeStorageProviders(
            storageEntity.owner,
            new uint64[](1)
        );

        Storage.StorageEntity memory updatedStorageEntity = roundRobinAllocator
            .getStorageEntity(storageEntity.owner);

        assertEq(updatedStorageEntity.storageProviders.length, 1);
        assertEq(
            updatedStorageEntity.storageProviders[0],
            storageEntity.storageProviders[0]
        );
    }

    /**
     * ===== CHANGE STORAGE ENTITY ACTIVE STATUS =====
     */

    function test_changeStorageEntityActiveStatusSuccess() public {
        Storage.StorageEntity memory storageEntity = _prepareStorageEntity(
            address(1),
            new uint64[](0)
        );
        assertEq(storageEntity.isActive, true);

        vm.prank(storageEntity.owner);
        roundRobinAllocator.changeStorageEntityActiveStatus(
            storageEntity.owner,
            false
        );

        Storage.StorageEntity memory updatedStorageEntity = roundRobinAllocator
            .getStorageEntity(storageEntity.owner);
        assertEq(updatedStorageEntity.isActive, false);

        vm.prank(storageEntity.owner);
        roundRobinAllocator.changeStorageEntityActiveStatus(
            storageEntity.owner,
            true
        );

        Storage.StorageEntity
            memory reupdatedStorageEntity = roundRobinAllocator
                .getStorageEntity(storageEntity.owner);
        assertEq(reupdatedStorageEntity.isActive, true);
    }

    function test_changeStorageEntityActiveStatusOwnerRevert() public {
        Storage.StorageEntity memory storageEntity = _prepareStorageEntity(
            address(1),
            new uint64[](0)
        );
        assertEq(storageEntity.isActive, true);

        vm.prank(aliceAddress);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CallerIsNotStorageEntity.selector)
        );
        roundRobinAllocator.changeStorageEntityActiveStatus(
            storageEntity.owner,
            false
        );
        
        Storage.StorageEntity memory updatedStorageEntity = roundRobinAllocator
            .getStorageEntity(storageEntity.owner);

        assertEq(updatedStorageEntity.isActive, true);
    }
}
