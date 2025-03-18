// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "./Storage.sol";
import {Modifiers} from "./Modifiers.sol";
import {Errors} from "./lib/Errors.sol";

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
    event StorageEntityCreated(
        address indexed creator,
        address indexed owner,
        uint64[] storageProviders
    );
    event StrorageProvidersAdded(
        address indexed creator,
        address indexed storageEntity,
        uint64[] addedStorageProviders
    );
    event StorageProviderRemoved(
        address indexed creator,
        address indexed storageEntity,
        uint64[] removedStorageProviders
    );
    event StorageEntityActiveStatusChanged(
        address indexed creator,
        address indexed storageEntity,
        bool isActive
    );

    function createStorageEntity(
        address owner,
        uint64[] calldata storageProviders
    ) public onlyOwnerOrAllocator {
        if (Storage.s().storageEntities[owner].owner != address(0)) {
            revert Errors.StorageEntityAlreadyExists();
        }
        _checkIfAnyStorageProviderIsUsed(storageProviders);

        // Create a new storage entity
        Storage.StorageEntity storage storageEntity = Storage
            .s()
            .storageEntities[owner];
        storageEntity.owner = owner;
        storageEntity.storageProviders = storageProviders;
        storageEntity.isActive = true;

        // Mark each storage provider as used
        for (uint i = 0; i < storageProviders.length; i++) {
            Storage.s().usedStorageProviders[storageProviders[i]] = true;
        }

        emit StorageEntityCreated(msg.sender, owner, storageProviders);
    }

    function addStorageProviders(
        address owner,
        uint64[] calldata storageProviders
    ) public onlyStorageEntity(owner) {
        _checkIfAnyStorageProviderIsUsed(storageProviders);

        Storage.StorageEntity storage se = Storage.s().storageEntities[
            owner
        ];

        _checkIfStorageEntityExists(se);

        for (uint i = 0; i < storageProviders.length; i++) {
            se.storageProviders.push(storageProviders[i]);
            Storage.s().usedStorageProviders[storageProviders[i]] = true;
        }

        emit StrorageProvidersAdded(
            msg.sender,
            owner,
            storageProviders
        );
    }

    function removeStorageProviders(
        address owner,
        uint64[] calldata storageProviders
    ) public onlyStorageEntity(owner) {
        Storage.StorageEntity storage se = Storage.s().storageEntities[
            owner
        ];

        _checkIfStorageEntityExists(se);

        for (uint j = 0; j < storageProviders.length; j++) {
            uint64 sp = storageProviders[j];
            Storage.s().usedStorageProviders[sp] = false;
            for (uint i = 0; i < se.storageProviders.length; i++) {
                if (se.storageProviders[i] == sp) {
                    se.storageProviders[i] = se.storageProviders[
                        se.storageProviders.length - 1
                    ];
                    se.storageProviders.pop();
                    Storage.s().usedStorageProviders[sp] = false;
                    break;
                }
            }
        }

        emit StorageProviderRemoved(msg.sender, owner, storageProviders);
    }

    function changeStorageEntityActiveStatus(
        address owner,
        bool isActive
    ) public onlyStorageEntity(owner) {
        Storage.StorageEntity storage se = Storage.s().storageEntities[
            owner
        ];

        _checkIfStorageEntityExists(se);

        se.isActive = isActive;

        emit StorageEntityActiveStatusChanged(msg.sender, owner, isActive);
    }

    function _checkIfAnyStorageProviderIsUsed(
        uint64[] calldata storageProviders
    ) internal view {
        for (uint i = 0; i < storageProviders.length; i++) {
            if (Storage.s().usedStorageProviders[storageProviders[i]]) {
                revert Errors.StorageProviderAlreadyUsed();
            }
        }
    }

    function _checkIfStorageEntityExists(Storage.StorageEntity storage se)
        internal
        view
    {
        if (se.owner == address(0)) {
            revert Errors.StorageEntityDoesNotExist();
        }
    }

    function getStorageEntity(address owner)
        public
        view
        returns (Storage.StorageEntity memory)
    {
        return Storage.s().storageEntities[owner];
    }

    function isStorageProviderUsed(uint64 storageProvider)
        public
        view
        returns (bool)
    {
        return Storage.s().usedStorageProviders[storageProvider];
    }
}
