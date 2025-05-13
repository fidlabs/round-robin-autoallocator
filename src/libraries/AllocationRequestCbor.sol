// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Buffer} from "@ensdomains/buffer/contracts/Buffer.sol";
import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";
import {Misc} from "filecoin-solidity/utils/Misc.sol";
import {FilecoinCBOR} from "filecoin-solidity/cbor/FilecoinCbor.sol";
import {Types} from "./Types.sol";

library AllocationRequestCbor {
    function encodeAllocationDataPerProvider(
        Types.AllocationRequest[] calldata allocReq,
        uint64[] memory providers,
        uint256 replicaSize,
        int64 termMin,
        int64 termMax,
        int64 expiration
    ) internal pure returns (Types.ProviderAllocationPayload[] memory) {
        // escape too deep stack
        Types.EncodingParams memory params = Types.EncodingParams({
            providers: providers,
            replicaSize: replicaSize,
            termMin: termMin,
            termMax: termMax,
            expiration: expiration
        });

        bytes memory encodedTerms = _preEncodeTerms(termMin, termMax, expiration);

        // precompute allocations
        (uint256[][] memory providerToAllocations, uint256[] memory counts, uint64[] memory sizes) =
            _mapAllocationsToProviders(allocReq, providers.length, replicaSize);

        Types.ProviderAllocationPayload[] memory results = new Types.ProviderAllocationPayload[](providers.length);

        for (uint256 provider = 0; provider < providers.length; provider++) {
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
    function _preEncodeTerms(int64 termMin, int64 termMax, int64 expiration) private pure returns (bytes memory) {
        CBOR.CBORBuffer memory termsBuf = CBOR.create(15); // 3 x (1 prefix + 4 bytes per int64)

        CBOR.writeInt64(termsBuf, termMin);
        CBOR.writeInt64(termsBuf, termMax);
        CBOR.writeInt64(termsBuf, expiration);

        return CBOR.data(termsBuf);
    }

    function _mapAllocationsToProviders(
        Types.AllocationRequest[] calldata allocReq,
        uint256 providersCount,
        uint256 replicaSize
    )
        private
        pure
        returns (uint256[][] memory providerToAllocations, uint256[] memory counts, uint64[] memory totalSizes)
    {
        counts = new uint256[](providersCount);
        totalSizes = new uint64[](providersCount);

        for (uint256 i = 0; i < allocReq.length; i++) {
            Types.AllocationRequest calldata req = allocReq[i];
            for (uint256 r = 0; r < replicaSize; r++) {
                uint256 providerIndex = (i + r) % providersCount;
                counts[providerIndex]++;
                totalSizes[providerIndex] += req.size;
            }
        }

        providerToAllocations = new uint256[][](providersCount);
        for (uint256 provider = 0; provider < providersCount; provider++) {
            providerToAllocations[provider] = new uint256[](counts[provider]);
        }

        uint256[] memory indexes = new uint256[](providersCount);

        for (uint256 i = 0; i < allocReq.length; i++) {
            for (uint256 r = 0; r < replicaSize; r++) {
                uint256 providerIndex = (i + r) % providersCount;
                providerToAllocations[providerIndex][indexes[providerIndex]] = i;
                indexes[providerIndex]++;
            }
        }

        return (providerToAllocations, counts, totalSizes);
    }

    function _encodeProviderWithMappedAllocations(
        Types.AllocationRequest[] calldata allocReq,
        Types.EncodingParams memory params,
        uint256 allocCount,
        uint64 totalSize,
        uint256 providerIndex,
        uint256[] memory allocIndexes,
        bytes memory encodedTerms
    ) private pure returns (Types.ProviderAllocationPayload memory result) {
        uint64 providerId = params.providers[providerIndex];

        result.provider = providerId;
        result.totalSize = totalSize;
        result.count = uint64(allocCount);

        uint256 bufSize = allocCount * 73 + 2 + Misc.getPrefixSize(allocCount);
        CBOR.CBORBuffer memory buffer = CBOR.create(bufSize);

        CBOR.startFixedArray(buffer, 2);
        CBOR.startFixedArray(buffer, uint64(allocCount));

        for (uint256 i = 0; i < allocIndexes.length; i++) {
            _encodeAllocation(buffer, allocReq[allocIndexes[i]], providerId, encodedTerms);
        }

        CBOR.startFixedArray(buffer, 0);

        result.payload = CBOR.data(buffer);
        return result;
    }

    function _encodeAllocation(
        CBOR.CBORBuffer memory buffer,
        Types.AllocationRequest calldata req,
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
