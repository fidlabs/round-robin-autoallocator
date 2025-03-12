// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import "@ensdomains/buffer/contracts/Buffer.sol"; // for appendUint8
import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";
import {CBORDecoder} from "filecoin-solidity/utils/CborDecode.sol";

struct AllocationRequestData {
    uint64 provider;
    bytes dataCID;
    uint64 size;
    int64 termMin;
    int64 termMax;
    int64 expiration;
}

library AllocationCbor {
    using Buffer for Buffer.buffer; // for appendUint8

    function encodeData(
        AllocationRequestData memory request
    ) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        // Start the top-level array
        CBOR.startFixedArray(buf, 2);

        // Start the first nested array
        CBOR.startFixedArray(buf, 1);

        // Start the allocation request array
        CBOR.startFixedArray(buf, 6);
        CBOR.writeUInt64(buf, request.provider);
        // Insert tag(42) before writing the dataCID
        writeTag(buf, 42);
        CBOR.writeBytes(buf, request.dataCID);
        CBOR.writeUInt64(buf, request.size);
        CBOR.writeInt64(buf, request.termMin);
        CBOR.writeInt64(buf, request.termMax);
        CBOR.writeInt64(buf, request.expiration);

        // Write the empty array
        CBOR.startFixedArray(buf, 0);

        return CBOR.data(buf);
    }

    function encodeDataArray(
        AllocationRequestData[] memory requests
    ) internal pure returns (bytes memory) {
        // Create a new CBOR buffer with an initial capacity.
        CBOR.CBORBuffer memory buf = CBOR.create(128);

        // Top-level: Fixed array of 2 elements.
        CBOR.startFixedArray(buf, 2);

        // First element: fixed array containing all allocation requests. 
        // ref: builtin-actors/actors/verifreg/src/types.rs::AllocationRequest
        CBOR.startFixedArray(buf, uint64(requests.length));
        for (uint256 i = 0; i < requests.length; i++) {
            // Each allocation request is a fixed array of 6 items.
            CBOR.startFixedArray(buf, 6);
            CBOR.writeUInt64(buf, requests[i].provider);

            // Insert tag(42) before writing the dataCID.
            writeTag(buf, 42);

            CBOR.writeBytes(buf, requests[i].dataCID);
            CBOR.writeUInt64(buf, requests[i].size);
            CBOR.writeInt64(buf, requests[i].termMin);
            CBOR.writeInt64(buf, requests[i].termMax);
            CBOR.writeInt64(buf, requests[i].expiration);
        }

        // Second element: an empty array. builtin-actors/actors/verifreg/src/types.rs::ClaimExtensionRequest
        CBOR.startFixedArray(buf, 0);

        return CBOR.data(buf);
    }

    // Helper to write an arbitrary tag.
    // For tag(42), it writes 0xD8 0x2A.
    function writeTag(
        CBOR.CBORBuffer memory _buf,
        uint64 tagVal
    ) internal pure {
        // Major type 6 (CBOR Tag).
        // For tag(42), this will produce 0xD8 0x2A.
        if (tagVal <= 23) {
            _buf.buf.appendUint8(uint8((6 << 5) | tagVal));
        } else if (tagVal <= 0xFF) {
            _buf.buf.appendUint8(uint8((6 << 5) | 24));
            _buf.buf.appendUint8(uint8(tagVal));
        } else if (tagVal <= 0xFFFF) {
            _buf.buf.appendUint8(uint8((6 << 5) | 25));
            _buf.buf.appendInt(tagVal, 2);
        } else if (tagVal <= 0xFFFFFFFF) {
            _buf.buf.appendUint8(uint8((6 << 5) | 26));
            _buf.buf.appendInt(tagVal, 4);
        } else {
            _buf.buf.appendUint8(uint8((6 << 5) | 27));
            _buf.buf.appendInt(tagVal, 8);
        }
    }

    /**
     * Decode Response from Allocation Request
     * ref: builtin-actors/actors/verifreg/src/types.rs::AllocationsResponse
     * cborData: [[2, []], [0, []], [5, 6]]
     * Array with 3 elements:
     * allocation_results
     * extension_results
     * new_allocations
     */
    function decodeAllocationResponse(
        bytes memory cborData
    ) internal pure returns (uint64[] memory allocationIds) {
        uint256 topArrayLength;
        uint256 byteIdx = 0;

        // Read the top-level array.
        (topArrayLength, byteIdx) = CBORDecoder.readFixedArray(
            cborData,
            byteIdx
        );
        // Expect exactly 3 elements.
        require(topArrayLength == 3, "Invalid top-level array length");

        // First element: [1, []]
        // allocation_results: [newAllocations, [?]]
        {
            uint256 firstElemLength;
            (firstElemLength, byteIdx) = CBORDecoder.readFixedArray(
                cborData,
                byteIdx
            );
            require(firstElemLength == 2, "Invalid first element length");
            // First sub-element
            (, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            // Second sub-element
            uint256 innerLength;
            (innerLength, byteIdx) = CBORDecoder.readFixedArray(
                cborData,
                byteIdx
            );
            require(innerLength == 0, "Expected empty array in first element");
        }

        // Second element: [0, []]
        // extension_results: [extendedAllocations, [?]]
        {
            uint256 secondElemLength;
            (secondElemLength, byteIdx) = CBORDecoder.readFixedArray(
                cborData,
                byteIdx
            );
            require(secondElemLength == 2, "Invalid second element length");
            // First sub-element, extension are not supported atm so we ignore it
            (, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            // Second sub-element
            uint256 innerLength;
            (innerLength, byteIdx) = CBORDecoder.readFixedArray(
                cborData,
                byteIdx
            );
            require(innerLength == 0, "Expected empty array in second element");
        }

        // third element: the allocation IDs array
        // new_allocations: [allocationID_1, ..., allocationID_N]
        uint256 allocationIdsLength;
        (allocationIdsLength, byteIdx) = CBORDecoder.readFixedArray(
            cborData,
            byteIdx
        );

        allocationIds = new uint64[](allocationIdsLength);
        for (uint256 i = 0; i < allocationIdsLength; i++) {
            uint64 allocationId;
            (allocationId, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            allocationIds[i] = allocationId;
        }
    }
}
