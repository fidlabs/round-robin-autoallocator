// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "../libraries/Storage.sol";
import {Modifiers} from "../Modifiers.sol";
import {ErrorLib} from "../libraries/Errors.sol";
import {IFacet} from "../interfaces/IFacet.sol";
import {Events} from "../libraries/Events.sol";

/**
 * @title
 * @author
 * @notice
 *
 * @dev
 * Only Allocator can create a Storage Entity
 * Only Storage Entity can add/remove storage providers
 * Only Storage Entity can change its active status
 */
contract StorageEntityManagerFacet is IFacet, Modifiers {
    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure virtual returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](6);
        selectors_[0] = this.createStorageEntity.selector;
        selectors_[1] = this.addStorageProviders.selector;
        selectors_[2] = this.removeStorageProviders.selector;
        selectors_[3] = this.setStorageEntityActiveStatus.selector;
        selectors_[4] = this.isStorageProviderUsed.selector;
        selectors_[5] = this.setStorageProviderDetails.selector;
    }

    function createStorageEntity(address entityOwner, uint64[] calldata storageProviders)
        external
        onlyOwnerOrAllocator
    {
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

        emit Events.StorageEntityCreated(msg.sender, entityOwner, storageProviders);
    }

    function addStorageProviders(address entityOwner, uint64[] calldata storageProviders)
        external
        onlyOwnerOrStorageEntity(entityOwner)
    {
        _ensureNoStorageProviderUsed(storageProviders);

        Storage.StorageEntity storage se = Storage.s().storageEntities[entityOwner];

        _ensureStorageEntityExists(se);

        for (uint256 i = 0; i < storageProviders.length; i++) {
            se.storageProviders.push(storageProviders[i]);
            Storage.s().usedStorageProviders[storageProviders[i]] = true;
        }

        emit Events.StrorageProvidersAdded(msg.sender, entityOwner, storageProviders);
    }

    function removeStorageProviders(address entityOwner, uint64[] calldata storageProviders)
        external
        onlyOwnerOrStorageEntity(entityOwner)
    {
        Storage.StorageEntity storage se = Storage.s().storageEntities[entityOwner];

        _ensureStorageEntityExists(se);

        for (uint256 j = 0; j < storageProviders.length; j++) {
            uint64 sp = storageProviders[j];

            _ensureStorageProviderIsAssignedToStorageEntity(se, sp);

            Storage.s().usedStorageProviders[sp] = false;
            for (uint256 i = 0; i < se.storageProviders.length; i++) {
                if (se.storageProviders[i] == sp) {
                    se.storageProviders[i] = se.storageProviders[se.storageProviders.length - 1];
                    se.storageProviders.pop();
                    Storage.s().usedStorageProviders[sp] = false;

                    se.providerDetails[sp] = Storage.ProviderDetails({isActive: false, spaceLeft: 0});
                    break;
                }
            }
        }

        emit Events.StorageProviderRemoved(msg.sender, entityOwner, storageProviders);
    }

    function setStorageEntityActiveStatus(address entityOwner, bool isActive)
        external
        onlyOwnerOrStorageEntity(entityOwner)
    {
        Storage.StorageEntity storage se = Storage.s().storageEntities[entityOwner];

        _ensureStorageEntityExists(se);

        se.isActive = isActive;

        emit Events.StorageEntityActiveStatusChanged(msg.sender, entityOwner, isActive);
    }

    function _ensureNoStorageProviderUsed(uint64[] calldata storageProviders) internal view {
        for (uint256 i = 0; i < storageProviders.length; i++) {
            if (Storage.s().usedStorageProviders[storageProviders[i]]) {
                revert ErrorLib.StorageProviderAlreadyUsed();
            }
        }
    }

    function _ensureStorageEntityExists(Storage.StorageEntity storage se) internal view {
        if (se.owner == address(0)) {
            revert ErrorLib.StorageEntityDoesNotExist();
        }
    }

    function isStorageProviderUsed(uint64 storageProvider) external view returns (bool) {
        return Storage.s().usedStorageProviders[storageProvider];
    }

    function setStorageProviderDetails(
        address entityOwner,
        uint64 storageProvider,
        Storage.ProviderDetails calldata details
    ) external onlyOwnerOrStorageEntity(entityOwner) {
        Storage.StorageEntity storage se = Storage.s().storageEntities[entityOwner];

        _ensureStorageEntityExists(se);

        _ensureStorageProviderIsAssignedToStorageEntity(se, storageProvider);

        se.providerDetails[storageProvider] = details;
    }

    function _ensureStorageProviderIsAssignedToStorageEntity(Storage.StorageEntity storage se, uint64 storageProvider)
        internal
        view
    {
        // Check if sp is assigned to the entity
        bool isAssigned = false;
        for (uint256 i = 0; i < se.storageProviders.length; i++) {
            if (se.storageProviders[i] == storageProvider) {
                isAssigned = true;
                break;
            }
        }
        if (!isAssigned) {
            revert ErrorLib.StorageProviderNotAssignedToEntity();
        }
    }
}
