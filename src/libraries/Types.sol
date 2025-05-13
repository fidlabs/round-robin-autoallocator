// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";

library Types {
    struct AllocationRequest {
        bytes dataCID;
        uint64 size;
    }

    struct AllocationPackageReturn {
        address client;
        bool claimed;
        uint64[] storageProviders;
        uint64[][] spAllocationIds;
        uint256 collateral;
    }

    struct StorageProviderInfo {
        uint64 providerId;
        bool claimStatusComplete;
        uint64[] allocationIds;
    }

    struct ClientPackageWithClaimStatus {
        uint256 packageId;
        address client;
        bool claimed;
        bool canBeClaimed; // Overall package claim status
        uint256 collateral;
        StorageProviderInfo[] providers; // Single array of structured provider data
    }

    struct PackageContext {
        uint256 packageId;
        ClientPackageWithClaimStatus packageInfo;
    }

    /**
     * @notice Container for a provider's CBOR payload.
     */
    struct ProviderAllocationPayload {
        uint64 provider;
        uint64 totalSize;
        uint64 count;
        bytes payload;
    }

    // Define parameter structs to minimize stack variables
    struct EncodingParams {
        uint64[] providers;
        uint256 replicaSize;
        int64 termMin;
        int64 termMax;
        int64 expiration;
    }

    struct ProviderParams {
        uint64 providerId;
        uint256 providerIndex;
        uint256 allocCount;
    }

    /**
     * @title AllocationRequestData
     * @notice Data structure for allocation request
     * @dev Produces per-storage-provider CBOR payloads without copying the huge calldata array.
     *
     * Each CBOR payload follows your expected format:
     *  - A top-level fixed array with 2 elements:
     *       [ [ allocation entries... ], [] ]
     *
     * Each allocation entry is a fixed array of 6 items:
     *       [ provider, dataCID, size, termMin, termMax, expiration ]
     *
     * The assignment is done in a round-robin fashion:
     *      assignedProviderIndex = (allocReq index + replica index) mod numProviders
     * This ensures that each dataCID is only replicated once per provider.
     *
     * CBOR encoding size params:
     * now (13.3.2025) epoch: 4786800
     * 5y (13.3.2030) epoch: 10042800
     * 10y (13.3.2035) epoch: 15301680
     * 64GB: 68719476736
     * MAX providerId now: 3499325
     *
     * CBOR payload example (only new allocations):
     * [[[
     *      34993250,
     *      42(h'000181E203922020AB68B07850BAE544B4E720FF59FDC7DE709A8B5A8E83D6B7AB3AC2FA83E8461B'),
     *      68719476736,
     *      15301680,
     *      15301680,
     *      15301680
     *  ]],
     *  []
     * ]
     *
     * Single Allocation:
     * 3x array header: 3 bytes
     * data: 1+4+2+2+40+1+8+1+4+1+4+1+4 = 73 bytes
     * dangling array: 1 byte
     * == 77 bytes
     *
     * Multi Allocation:
     * 2x array header: 2 bytes
     * 1x array with variable prefix: 1 - 9 bytes
     * data: 73 bytes * n
     * dangling array: 1 byte
     * == 73n + 3 bytes + 1 - 9 bytes
     */
    struct AllocationRequestData {
        // The provider (miner actor) which may claim the allocation.
        // 34993250 -> 1A 0215F462 -> 1 + 4 bytes
        uint64 provider;
        // Identifier of the data to be committed.
        // D8 2A (tag) 58 28 (bytes40) 000181E203922020AB68B07850BAE544B4E720FF59FDC7DE709A8B5A8E83D6B7AB3AC2FA83E8461B => 2 + 2 + 40 bytes
        CommonTypes.Cid dataCID;
        // The (padded) size of data.
        // 68719476736 -> 1B 0000001000000000 -> 1 + 8 bytes
        uint64 size;
        // The minimum duration which the provider must commit to storing the piece to avoid
        // early-termination penalties (epochs).
        // 15301680 -> 1A 00E9A4A0 -> 1 + 4 bytes
        int64 termMin;
        // The maximum period for which a provider can earn quality-adjusted power
        // for the piece (epochs).
        // 15301680 -> 1A 00E9A4A0 -> 1 + 4 bytes
        int64 termMax;
        // The latest epoch by which a provider must commit data before the allocation expires.
        // 15301680 -> 1A 00E9A4A0 -> 1 + 4 bytes
        int64 expiration;
    }
}
