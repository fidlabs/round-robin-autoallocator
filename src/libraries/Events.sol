// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

library Events {
    event AllocationCreated(
        address indexed client,
        uint64 indexed provider,
        uint256 indexed packageId,
        uint256 allocationSize,
        uint64[] allocationIds
    );
    event AllocationClaimed(
        address indexed client, uint256 indexed packageId, uint64 indexed provider, uint64[] allocationIds
    );
    event CollateralLocked(address indexed caller, uint256 indexed packageId, uint256 amount);
    event CollateralReleased(address indexed caller, address indexed client, uint256 indexed packageId, uint256 amount);

    event StorageEntityCreated(address indexed creator, address indexed owner, uint64[] storageProviders);
    event StrorageProvidersAdded(
        address indexed creator, address indexed storageEntity, uint64[] addedStorageProviders
    );
    event StorageProviderRemoved(
        address indexed creator, address indexed storageEntity, uint64[] removedStorageProviders
    );
    event StorageEntityActiveStatusChanged(address indexed creator, address indexed storageEntity, bool isActive);
}
