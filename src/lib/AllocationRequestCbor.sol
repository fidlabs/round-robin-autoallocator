// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";
import {CBORDecoder} from "filecoin-solidity/utils/CborDecode.sol";
import {FilecoinCBOR} from "filecoin-solidity/cbor/FilecoinCbor.sol";
import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";

struct AllocationRequestData {
    uint64 provider;
    CommonTypes.Cid dataCID;
    uint64 size;
    int64 termMin;
    int64 termMax;
    int64 expiration;
}

library AllocationRequestCbor {
    function encodeRequestData(
        AllocationRequestData[] memory requests
    ) internal pure returns (bytes memory) {
        // Create a new CBOR buffer with an initial capacity.
        CBOR.CBORBuffer memory buf = CBOR.create(requests.length * 64);

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
}