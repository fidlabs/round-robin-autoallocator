// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {ErrorLib} from "../src/libraries/Errors.sol";
import {DiamondDeployer} from "./lib/DiamondDeployer.sol";
import {StorageEntityPicker} from "../src/libraries/StorageEntityPicker.sol";
import {StorageEntityManagerFacet} from "../src/facets/StorageEntityManagerFacet.sol";
import {IFacet} from "../src/interfaces/IFacet.sol";
import {Storage} from "../src/libraries/Storage.sol";

contract StorageEntityPickerFacet is IFacet {
    function selectors() external pure virtual returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](2);
        selectors_[0] = this.getRandomNumber.selector;
        selectors_[1] = this.pickStorageProviders.selector;
    }

    function getRandomNumber(uint256 max) public returns (uint256) {
        return StorageEntityPicker._getRandomNumber(max);
    }

    function pickStorageProviders(uint256 numEntities) public returns (uint64[] memory) {
        return StorageEntityPicker._pickStorageProviders(numEntities, 0);
    }
}

contract StorageEntityPickerTest is Test {
    uint256 public constant SE_INIT_COUNT = 8;

    StorageEntityManagerFacet storageEntityManagerFacet;
    StorageEntityPickerFacet storageEntityPickerFacet;

    function setUp() public {
        IFacet[] memory extraFacets = new IFacet[](1);
        extraFacets[0] = new StorageEntityPickerFacet();
        address diamond = DiamondDeployer.deployDiamondWithExtraFacets(address(this), extraFacets);
        storageEntityManagerFacet = StorageEntityManagerFacet(diamond);
        storageEntityPickerFacet = StorageEntityPickerFacet(diamond);

        uint256 base = 1000;

        // add storage entities, half of them are inactive
        for (uint256 i = base; i < base + SE_INIT_COUNT; i++) {
            address owner = makeAddr(vm.toString(i));
            uint64[] memory storageProviders = new uint64[](1);
            uint64 providerId = uint64(i);
            storageProviders[0] = providerId;
            storageEntityManagerFacet.createStorageEntity(owner, storageProviders);
            Storage.ProviderDetails memory details =
                Storage.ProviderDetails({isActive: true, spaceLeft: type(uint256).max});

            storageEntityManagerFacet.setStorageProviderDetails(owner, providerId, details);
            if (i % 2 == 0) {
                vm.prank(owner);
                storageEntityManagerFacet.setStorageEntityActiveStatus(owner, false);
            }
        }

        // make sure we are able to get blockhash - 5
        vm.roll(100);
    }

    function test_getRandomNumber() public {
        uint256 max = 10;
        uint256 rand = storageEntityPickerFacet.getRandomNumber(max);
        assertTrue(rand >= 0 && rand < max, "Rand should be between 0 and max");
    }

    function test_pickStorageProvidersSuccess() public {
        uint256 numEntities = 3;

        uint64[] memory storageProviders = storageEntityPickerFacet.pickStorageProviders(numEntities);
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
        storageEntityPickerFacet.pickStorageProviders(numEntities);
    }

    function test_pickStorageProvidersAllActiveSuccess() public {
        uint256 numEntities = SE_INIT_COUNT / 2;
        uint64[] memory storageProviders = storageEntityPickerFacet.pickStorageProviders(numEntities);

        _checkForArrayDuplicates(storageProviders);
    }

    function test_pickStorageProvidersNotEnoughActiveSERevert() public {
        uint256 numEntities = SE_INIT_COUNT / 2 + 1;
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.NotEnoughActiveStorageEntities.selector));
        storageEntityPickerFacet.pickStorageProviders(numEntities);
    }
}
