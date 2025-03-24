// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {RoundRobinAllocator} from "../src/RoundRobinAllocator.sol";
import {Errors} from "../src/lib/Errors.sol";

/**
 * @notice Wrapper contract to test internal functions 
 */
contract RoundRobinAllocatorWrapper is RoundRobinAllocator {
    function getRandomNumber(uint256 max) public returns (uint256) {
        return _getRandomNumber(max);
    }

    function pickStorageProviders(
        uint numEntities
    ) public returns (uint64[] memory) {
        return _pickStorageProviders(numEntities);
    }
}

contract StorageEntityPickerTest is Test {
    RoundRobinAllocatorWrapper public roundRobinAllocator;
    uint public constant SE_INIT_COUNT = 8;

    function setUp() public {
        roundRobinAllocator = new RoundRobinAllocatorWrapper();
        roundRobinAllocator.initialize(address(this));

        // add storage entities, half of them are inactive
        for (uint i = 0; i < SE_INIT_COUNT; i++) {
            address owner = makeAddr(vm.toString(i));
            uint64[] memory storageProviders = new uint64[](1);
            storageProviders[0] = uint64(i);
            roundRobinAllocator.createStorageEntity(owner, storageProviders);
            if (i % 2 == 0) {
                vm.prank(owner);
                roundRobinAllocator.changeStorageEntityActiveStatus(
                    owner,
                    false
                );
            }
        }

        // make sure we are able to get blockhash - 5
        vm.roll(100);
    }

    function test_getRandomNumber() public {
        uint256 max = 10;
        uint256 rand = roundRobinAllocator.getRandomNumber(max);
        assertTrue(rand >= 0 && rand < max, "Rand should be between 0 and max");
    }

    function test_pickStorageProvidersSuccess() public {
        uint numEntities = 3;

        uint64[] memory storageProviders = roundRobinAllocator
            .pickStorageProviders(numEntities);
        assertEq(
            storageProviders.length,
            numEntities,
            "Should return the correct number of storage providers"
        );

        // check if all storage providers are unique
        _checkForArrayDuplicates(storageProviders);
    }

    function _checkForArrayDuplicates(uint64[] memory arr) internal pure {
        for (uint i = 0; i < arr.length; i++) {
            for (uint j = i + 1; j < arr.length; j++) {
                assertNotEq(arr[i], arr[j], "arr should not have duplicates");
            }
        }
    }

    function test_pickStorageProvidersNotEnoughSERevert() public {
        uint numEntities = SE_INIT_COUNT + 1;

        vm.expectRevert(
            abi.encodeWithSelector(Errors.NotEnoughStorageEntities.selector)
        );
        roundRobinAllocator.pickStorageProviders(numEntities);
    }

    function test_pickStorageProvidersAllActiveSuccess() public {
      uint numEntities = SE_INIT_COUNT / 2;
      uint64[] memory storageProviders = roundRobinAllocator.pickStorageProviders(numEntities);
      
      for (uint i = 0; i < storageProviders.length; i++) {
        console.log("storageProviders: ", i, storageProviders[i]);
      }
      _checkForArrayDuplicates(storageProviders);
    }

    function test_pickStorageProvidersNotEnoughActiveSERevert() public {
      uint numEntities = SE_INIT_COUNT / 2 + 1;
      vm.expectRevert(
            abi.encodeWithSelector(Errors.NotEnoughActiveStorageEntities.selector)
        );
      roundRobinAllocator.pickStorageProviders(numEntities);
    }
}
