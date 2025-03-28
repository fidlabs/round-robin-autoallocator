// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "@ensdomains/buffer/contracts/Buffer.sol";
import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";
import {CBORDecoder} from "filecoin-solidity/utils/CborDecode.sol";
import {Misc} from "filecoin-solidity/utils/Misc.sol";
import {FilecoinCBOR} from "filecoin-solidity/cbor/FilecoinCbor.sol";
import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {AllocationRequest} from "../RoundRobinAllocator.sol";

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
    uint replicaSize;
    int64 termMin;
    int64 termMax;
    int64 expiration;
}

struct ProviderParams {
    uint64 providerId;
    uint providerIndex;
    uint allocCount;
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

library AllocationRequestCbor {
    function encodeRequestData(
        AllocationRequestData[] memory requests
    ) internal pure returns (bytes memory) {
        // Calculate the size of the CBOR buffer.
        uint bufSize = requests.length *
            73 +
            2 +
            Misc.getPrefixSize(requests.length);

        // Create a new CBOR buffer with an initial capacity.
        CBOR.CBORBuffer memory buf = CBOR.create(bufSize);

        // Top-level: Fixed array of 2 elements.
        CBOR.startFixedArray(buf, 2);

        // First element: fixed array containing all allocation requests.
        // ref: builtin-actors/actors/verifreg/src/types.rs::AllocationRequest
        CBOR.startFixedArray(buf, uint64(requests.length));
        for (uint256 i = 0; i < requests.length; i++) {
            // Each allocation request is a fixed array of 6 items.
            CBOR.startFixedArray(buf, 6);
            CBOR.writeUInt64(buf, requests[i].provider);
            FilecoinCBOR.writeCid(buf, requests[i].dataCID.data);
            CBOR.writeUInt64(buf, requests[i].size);
            CBOR.writeInt64(buf, requests[i].termMin);
            CBOR.writeInt64(buf, requests[i].termMax);
            CBOR.writeInt64(buf, requests[i].expiration);
        }

        // Second element: an empty array. builtin-actors/actors/verifreg/src/types.rs::ClaimExtensionRequest
        CBOR.startFixedArray(buf, 0);

        return CBOR.data(buf);
    }

    function encodeAllocationDataPerProvider(
        AllocationRequest[] calldata allocReq,
        uint64[] memory providers,
        uint replicaSize,
        int64 termMin,
        int64 termMax,
        int64 expiration
    ) internal pure returns (ProviderAllocationPayload[] memory) {
        // escape too deep stack
        EncodingParams memory params = EncodingParams({
            providers: providers,
            replicaSize: replicaSize,
            termMin: termMin,
            termMax: termMax,
            expiration: expiration
        });

        bytes memory encodedTerms = _preEncodeTerms(
            termMin,
            termMax,
            expiration
        );

        // precompute allocations
        (
            uint[][] memory providerToAllocations,
            uint[] memory counts,
            uint64[] memory sizes
        ) = _mapAllocationsToProviders(allocReq, providers.length, replicaSize);

        ProviderAllocationPayload[]
            memory results = new ProviderAllocationPayload[](providers.length);

        for (uint provider = 0; provider < providers.length; provider++) {
            results[provider] = _encodeProviderWithMappedAllocations(
                allocReq,
                params,
                counts[provider],
                sizes[provider],
                provider,
                providerToAllocations[provider],
                encodedTerms
            );
        }

        return results;
    }

    /**
     * @notice saves a lot of gas by pre-encoding all three terms, that are the same for all allocations
     */
    function _preEncodeTerms(
        int64 termMin,
        int64 termMax,
        int64 expiration
    ) private pure returns (bytes memory) {
        CBOR.CBORBuffer memory termsBuf = CBOR.create(15); // 3 x (1 prefix + 4 bytes per int64)

        CBOR.writeInt64(termsBuf, termMin);
        CBOR.writeInt64(termsBuf, termMax);
        CBOR.writeInt64(termsBuf, expiration);

        return CBOR.data(termsBuf);
    }

    function _mapAllocationsToProviders(
        AllocationRequest[] calldata allocReq,
        uint providersCount,
        uint replicaSize
    )
        private
        pure
        returns (
            uint[][] memory providerToAllocations,
            uint[] memory counts,
            uint64[] memory totalSizes
        )
    {
        counts = new uint[](providersCount);
        totalSizes = new uint64[](providersCount);

        for (uint i = 0; i < allocReq.length; i++) {
            AllocationRequest calldata req = allocReq[i];
            for (uint r = 0; r < replicaSize; r++) {
                uint providerIndex = (i + r) % providersCount;
                counts[providerIndex]++;
                totalSizes[providerIndex] += req.size;
            }
        }

        providerToAllocations = new uint[][](providersCount);
        for (uint provider = 0; provider < providersCount; provider++) {
            providerToAllocations[provider] = new uint[](counts[provider]);
        }

        uint[] memory indexes = new uint[](providersCount);

        for (uint i = 0; i < allocReq.length; i++) {
            for (uint r = 0; r < replicaSize; r++) {
                uint providerIndex = (i + r) % providersCount;
                providerToAllocations[providerIndex][
                    indexes[providerIndex]
                ] = i;
                indexes[providerIndex]++;
            }
        }

        return (providerToAllocations, counts, totalSizes);
    }

    function _encodeProviderWithMappedAllocations(
        AllocationRequest[] calldata allocReq,
        EncodingParams memory params,
        uint allocCount,
        uint64 totalSize,
        uint providerIndex,
        uint[] memory allocIndexes,
         bytes memory encodedTerms
    ) private pure returns (ProviderAllocationPayload memory result) {
        uint64 providerId = params.providers[providerIndex];

        result.provider = providerId;
        result.totalSize = totalSize;
        result.count = uint64(allocCount);

        uint bufSize = allocCount * 73 + 2 + Misc.getPrefixSize(allocCount);
        CBOR.CBORBuffer memory buffer = CBOR.create(bufSize);

        CBOR.startFixedArray(buffer, 2);
        CBOR.startFixedArray(buffer, uint64(allocCount));

        for (uint i = 0; i < allocIndexes.length; i++) {
            _encodeAllocation(
                buffer,
                allocReq[allocIndexes[i]],
                providerId,
                encodedTerms
            );
        }

        CBOR.startFixedArray(buffer, 0);

        result.payload = CBOR.data(buffer);
        return result;
    }

    function _encodeAllocation(
        CBOR.CBORBuffer memory buffer,
        AllocationRequest calldata req,
        uint64 providerId,
         bytes memory encodedTerms
    ) private pure {
        CBOR.startFixedArray(buffer, 6);
        CBOR.writeUInt64(buffer, providerId);
        FilecoinCBOR.writeCid(buffer, req.dataCID);
        CBOR.writeUInt64(buffer, req.size);

        // directly append pre-encoded terms
        Buffer.append(buffer.buf, encodedTerms);
    }
}
