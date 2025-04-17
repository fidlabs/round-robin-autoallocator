// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

/**
 * @title Storage
 * @dev Storage library for the RoundRobinAllocator contract.
 *
 * TODO: pack structs properly b4 final version
 */
library Storage {
    // keccak256(abi.encode(uint256(keccak256("roundrobinallocator.app.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant APP_STORAGE = 0xa65e097788136ac6708a8b2dc691e4beb32762623723cd0f224c6a07a4075100;
    uint256 private constant APP_CONFIG_SLOT = 0;

    // Main storage struct for the RoundRobinAllocator contract.
    struct AppStorage {
        mapping(uint256 => AppConfig) appConfig; // Application configuration
        mapping(uint256 => AllocationPackage) allocationPackages; // Allocation packages
        uint256 packageCount; // Number of allocation packages, used to generate unique IDs // TODO: might be lees, maybe pack it
        mapping(address => uint256[]) clientAllocationPackages; // List of allocation package IDs per client
        address[] allocators; // List of allocator addresses
        mapping(address => StorageEntity) storageEntities; // Storage entities
        mapping(uint64 => bool) usedStorageProviders; // Used storage providers, used to prevent duplicates
        address[] entityAddresses; // List of storage entity addresses
        uint256 spPickerNonce; // Nonce for the storage provider picker
    }

    struct AppConfig {
        uint256 minReplicas; // Minimum number of replicas
        uint256 maxReplicas; // Maximum number of replicas
        uint256 collateralPerCID; // Collateral per CID
        uint256 minRequiredStorageProviders; // Minimum required storage providers
    }

    // Allocation batch struct, used to store allocations made by a single transaction.
    struct AllocationPackage {
        address client; // Client address
        bool claimed; // Whether the allocation has been claimed
        uint64[] storageProviders; // List of storage provider addresses involved
        mapping(uint64 => uint64[]) spAllocationIds; // List of allocation IDs per storage provider
        uint256 collateral; // Collateral amount
    }

    struct StorageEntity {
        bool isActive; // Whether the storage entity is active
        address owner; // Owner address, used to verify ownership
        uint64[] storageProviders; // List of storage providers
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    function _getAppStorage() private pure returns (AppStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := APP_STORAGE
        }
    }

    /**
     * @dev Returns the storage struct for the RoundRobinAllocator contract.
     */
    function s() internal pure returns (AppStorage storage) {
        return _getAppStorage();
    }

    /**
     * @dev Sets the application configuration.
     */
    function setAppConfig(AppConfig memory appConfig) internal {
        s().appConfig[APP_CONFIG_SLOT] = appConfig;
    }

    /**
     * @dev Returns the application configuration.
     */
    function getAppConfig() internal view returns (AppConfig storage) {
        return s().appConfig[APP_CONFIG_SLOT];
    }
}
