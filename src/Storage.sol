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
    bytes32 private constant APP_STORAGE =
        0xa65e097788136ac6708a8b2dc691e4beb32762623723cd0f224c6a07a4075100;

    // Main storage struct for the RoundRobinAllocator contract.    
    struct AppStorage {
      mapping(uint256 => AllocationPackage) allocationPackages; // Allocation packages
      uint256 packageCount; // Number of allocation packages, used to generate unique IDs
      mapping(address => uint256[]) clientAllocationPackages; // List of allocation package IDs per client
    }

    // Allocation batch struct, used to store allocations made by a single transaction.
    struct AllocationPackage {
        address client; // Client address
        uint64[] storageProviders; // List of storage provider addresses involved
        mapping(uint64 => uint64[]) spAllocationIds; // List of allocation IDs per storage provider
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    function _getAppStorage() private pure returns (AppStorage storage $) {
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
}
