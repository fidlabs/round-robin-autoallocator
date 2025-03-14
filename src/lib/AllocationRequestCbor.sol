// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";
import {CBORDecoder} from "filecoin-solidity/utils/CborDecode.sol";
import {FilecoinCBOR} from "filecoin-solidity/cbor/FilecoinCbor.sol";
import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";

/**
 * @title AllocationRequestData
 * @notice Data structure for allocation request
 * 
 * @dev 
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
        uint bufSize = requests.length * 73 + 3 + _calculateDataArrayPrefix(requests.length);

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

    function _calculateDataArrayPrefix(uint dataSize) internal pure returns (uint) {
        if (dataSize <= 23) {
            return 1;
        } else if (dataSize <= 0xFF) {
            return 2;
        } else if (dataSize <= 0xFFFF) {
            return 3;
        } else if (dataSize <= 0xFFFFFFFF) {
            return 5;
        }
        return 9;
    }
}