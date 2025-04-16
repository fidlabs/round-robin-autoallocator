// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {RoundRobinAllocator} from "../src/RoundRobinAllocator.sol";
import {ErrorLib} from "../src/lib/Errors.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @notice Wrapper contract to test internal functions
 */
contract RoundRobinAllocatorWrapper is RoundRobinAllocator {
    function getRandomNumber(uint256 max) public returns (uint256) {
        return _getRandomNumber(max);
    }

    function pickStorageProviders(uint256 numEntities) public returns (uint64[] memory) {
        return _pickStorageProviders(numEntities);
    }
}

contract StorageEntityPickerTest is Test {
    RoundRobinAllocatorWrapper public roundRobinAllocator;
    uint256 public constant SE_INIT_COUNT = 8;

    function setUp() public {
        roundRobinAllocator = _deployRoundRobinAllocator();

        uint256 base = 1000;

        // add storage entities, half of them are inactive
        for (uint256 i = base; i < base + SE_INIT_COUNT; i++) {
            address owner = makeAddr(vm.toString(i));
            uint64[] memory storageProviders = new uint64[](1);
            storageProviders[0] = uint64(i);
            roundRobinAllocator.createStorageEntity(owner, storageProviders);
            if (i % 2 == 0) {
                vm.prank(owner);
                roundRobinAllocator.changeStorageEntityActiveStatus(owner, false);
            }
        }

        // make sure we are able to get blockhash - 5
        vm.roll(100);
    }

    function _deployRoundRobinAllocator() internal returns (RoundRobinAllocatorWrapper) {
        RoundRobinAllocatorWrapper allocator = new RoundRobinAllocatorWrapper();
        bytes memory initData = abi.encodeWithSelector(RoundRobinAllocator.initialize.selector, address(this));
        ERC1967Proxy proxy = new ERC1967Proxy(address(allocator), initData);
        return RoundRobinAllocatorWrapper(address(proxy));
    }

    function test_getRandomNumber() public {
        uint256 max = 10;
        uint256 rand = roundRobinAllocator.getRandomNumber(max);
        assertTrue(rand >= 0 && rand < max, "Rand should be between 0 and max");
    }

    function test_pickStorageProvidersSuccess() public {
        uint256 numEntities = 3;

        uint64[] memory storageProviders = roundRobinAllocator.pickStorageProviders(numEntities);
        assertEq(storageProviders.length, numEntities, "Should return the correct number of storage providers");

        // check if all storage providers are unique
        _checkForArrayDuplicates(storageProviders);
    }

    function _checkForArrayDuplicates(uint64[] memory arr) internal pure {
        for (uint256 i = 0; i < arr.length; i++) {
            for (uint256 j = i + 1; j < arr.length; j++) {
                assertNotEq(arr[i], arr[j], "arr should not have duplicates");
            }
        }
    }

    function test_pickStorageProvidersNotEnoughSERevert() public {
        uint256 numEntities = SE_INIT_COUNT + 1;

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.NotEnoughStorageEntities.selector));
        roundRobinAllocator.pickStorageProviders(numEntities);
    }

    function test_pickStorageProvidersAllActiveSuccess() public {
        uint256 numEntities = SE_INIT_COUNT / 2;
        uint64[] memory storageProviders = roundRobinAllocator.pickStorageProviders(numEntities);

        for (uint256 i = 0; i < storageProviders.length; i++) {
            console.log("storageProviders: ", i, storageProviders[i]);
        }
        _checkForArrayDuplicates(storageProviders);
    }

    function test_pickStorageProvidersNotEnoughActiveSERevert() public {
        uint256 numEntities = SE_INIT_COUNT / 2 + 1;
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.NotEnoughActiveStorageEntities.selector));
        roundRobinAllocator.pickStorageProviders(numEntities);
    }
}
