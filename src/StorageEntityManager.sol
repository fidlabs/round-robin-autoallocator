// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "./Storage.sol";
import {Modifiers} from "./Modifiers.sol";
import {ErrorLib} from "./lib/Errors.sol";

/**
 * @title
 * @author
 * @notice
 *
 * TODO: is adding not-yours storage provider allowed? possible? injects any risks?
 *
 * @dev
 * Only Allocator can create a Storage Entity
 * Only Storage Entity can add/remove storage providers
 * Only Storage Entity can change its active status
 */
abstract contract StorageEntityManager is Modifiers {
    event StorageEntityCreated(address indexed creator, address indexed owner, uint64[] storageProviders);
    event StrorageProvidersAdded(
        address indexed creator, address indexed storageEntity, uint64[] addedStorageProviders
    );
    event StorageProviderRemoved(
        address indexed creator, address indexed storageEntity, uint64[] removedStorageProviders
    );
    event StorageEntityActiveStatusChanged(address indexed creator, address indexed storageEntity, bool isActive);

    function createStorageEntity(address entityOwner, uint64[] calldata storageProviders) public onlyOwnerOrAllocator {
        if (Storage.s().storageEntities[entityOwner].owner != address(0)) {
            revert ErrorLib.StorageEntityAlreadyExists();
        }
        _ensureNoStorageProviderUsed(storageProviders);

        // Create a new storage entity
        Storage.StorageEntity storage storageEntity = Storage.s().storageEntities[entityOwner];
        storageEntity.owner = entityOwner;
        storageEntity.storageProviders = storageProviders;
        storageEntity.isActive = true;

        Storage.s().entityAddresses.push(entityOwner);

        // Mark each storage provider as used
        for (uint256 i = 0; i < storageProviders.length; i++) {
            Storage.s().usedStorageProviders[storageProviders[i]] = true;
        }

        emit StorageEntityCreated(msg.sender, entityOwner, storageProviders);
    }

    function addStorageProviders(address entityOwner, uint64[] calldata storageProviders)
        public
        onlyStorageEntity(entityOwner)
    {
        _ensureNoStorageProviderUsed(storageProviders);

        Storage.StorageEntity storage se = Storage.s().storageEntities[entityOwner];

        _ensureStorageEntityNotExists(se);

        for (uint256 i = 0; i < storageProviders.length; i++) {
            se.storageProviders.push(storageProviders[i]);
            Storage.s().usedStorageProviders[storageProviders[i]] = true;
        }

        emit StrorageProvidersAdded(msg.sender, entityOwner, storageProviders);
    }

    function removeStorageProviders(address entityOwner, uint64[] calldata storageProviders)
        public
        onlyStorageEntity(entityOwner)
    {
        Storage.StorageEntity storage se = Storage.s().storageEntities[entityOwner];

        _ensureStorageEntityNotExists(se);

        for (uint256 j = 0; j < storageProviders.length; j++) {
            uint64 sp = storageProviders[j];
            Storage.s().usedStorageProviders[sp] = false;
            for (uint256 i = 0; i < se.storageProviders.length; i++) {
                if (se.storageProviders[i] == sp) {
                    se.storageProviders[i] = se.storageProviders[se.storageProviders.length - 1];
                    se.storageProviders.pop();
                    Storage.s().usedStorageProviders[sp] = false;
                    break;
                }
            }
        }

        emit StorageProviderRemoved(msg.sender, entityOwner, storageProviders);
    }

    function changeStorageEntityActiveStatus(address entityOwner, bool isActive)
        public
        onlyStorageEntity(entityOwner)
    {
        Storage.StorageEntity storage se = Storage.s().storageEntities[entityOwner];

        _ensureStorageEntityNotExists(se);

        se.isActive = isActive;

        emit StorageEntityActiveStatusChanged(msg.sender, entityOwner, isActive);
    }

    function _ensureNoStorageProviderUsed(uint64[] calldata storageProviders) internal view {
        for (uint256 i = 0; i < storageProviders.length; i++) {
            if (Storage.s().usedStorageProviders[storageProviders[i]]) {
                revert ErrorLib.StorageProviderAlreadyUsed();
            }
        }
    }

    function _ensureStorageEntityNotExists(Storage.StorageEntity storage se) internal view {
        if (se.owner == address(0)) {
            revert ErrorLib.StorageEntityDoesNotExist();
        }
    }

    function getStorageEntity(address entityOwner) public view returns (Storage.StorageEntity memory) {
        return Storage.s().storageEntities[entityOwner];
    }

    function isStorageProviderUsed(uint64 storageProvider) public view returns (bool) {
        return Storage.s().usedStorageProviders[storageProvider];
    }

    function getStorageEntities() public view returns (Storage.StorageEntity[] memory) {
        address[] storage entityAddresses = Storage.s().entityAddresses;
        Storage.StorageEntity[] memory storageEntities = new Storage.StorageEntity[](entityAddresses.length);
        for (uint256 i = 0; i < entityAddresses.length; i++) {
            storageEntities[i] = Storage.s().storageEntities[entityAddresses[i]];
        }
        return storageEntities;
    }
}
