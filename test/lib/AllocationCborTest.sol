// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";
import {CBORDecoder} from "filecoin-solidity/utils/CborDecode.sol";
import {BigIntCBOR} from "filecoin-solidity/cbor/BigIntCbor.sol";
import {Misc} from "filecoin-solidity/utils/Misc.sol";
import {DataCapTypes} from "filecoin-solidity/types/DataCapTypes.sol";
import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {AllocationRequestData} from "../../src/lib/AllocationRequestCbor.sol";
import {FilecoinCBOR} from "filecoin-solidity/cbor/FilecoinCbor.sol";

/**
 * @title AllocationCborTest
 * @dev Helper library to reverse the AllocationCbor library.
 * This library is a bandate for missing builtin-actors precompiles.
 * This library is for testing purposes only.
 */
library AllocationCborTest {
    using CBOR for CBOR.CBORBuffer;
    using BigIntCBOR for CommonTypes.BigInt;

    /**
     * @dev Encode Response for Allocation Request
     * ref: builtin-actors/actors/verifreg/src/types.rs::AllocationsResponse
     * Produces a CBOR payload with the following structure:
     * [
     *   [allocationResult, []],
     *   [0, []],
     *   allocationIds
     * ]
     */
    function encodeAllocationResponse(uint64 allocationResult, uint64[] memory allocationIds)
        public
        pure
        returns (bytes memory cborData)
    {
        // Create a CBOR buffer with an initial capacity.
        CBOR.CBORBuffer memory cbor = CBOR.create(256);

        // Write the top-level fixed array with 3 elements.
        CBOR.startFixedArray(cbor, 3);

        // First element: [allocationResult, []]
        CBOR.startFixedArray(cbor, 2);
        CBOR.writeUInt64(cbor, allocationResult);
        // Write an empty fixed array.
        CBOR.startFixedArray(cbor, 0);

        // Second element: [0, []] (extension results, not supported atm)
        CBOR.startFixedArray(cbor, 2);
        CBOR.writeUInt64(cbor, 0);
        // Write an empty fixed array.
        CBOR.startFixedArray(cbor, 0);

        // Third element: allocationIds array.
        CBOR.startFixedArray(cbor, uint64(allocationIds.length));
        for (uint256 i = 0; i < allocationIds.length; i++) {
            CBOR.writeUInt64(cbor, allocationIds[i]);
        }

        // Return the encoded CBOR data.
        return CBOR.data(cbor);
    }

    /**
     * @dev Helper function to decode a CBOR tag.
     */
    function decodeTag(bytes memory cborData, uint256 byteIdx) internal pure returns (uint64 tag, uint256 newIdx) {
        (uint8 maj, uint64 value, uint256 idxAfter) = CBORDecoder.parseCborHeader(cborData, byteIdx);
        // solhint-disable-next-line gas-custom-errors
        require(maj == 6, "Expected CBOR tag");
        return (value, idxAfter);
    }

    /**
     * @dev Decode CBOR data back into an array of AllocationRequestData.
     */
    function decodeDataArray(bytes memory cborData) public pure returns (AllocationRequestData[] memory requests) {
        uint256 byteIdx = 0;

        // Read the top-level fixed array of 2 elements.
        uint256 topArrayLength;
        (topArrayLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        // solhint-disable-next-line gas-custom-errors
        require(topArrayLength == 2, "Invalid top-level array length");

        // First element: Fixed array of allocation requests.
        uint256 requestsCount;
        (requestsCount, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        requests = new AllocationRequestData[](requestsCount);

        for (uint256 i = 0; i < requestsCount; i++) {
            // Each allocation request is a fixed array of 6 items.
            uint256 arrLength;
            (arrLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
            // solhint-disable-next-line gas-custom-errors
            require(arrLength == 6, "Invalid alloc request array len");

            uint64 provider;
            (provider, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);

            CommonTypes.Cid memory dataCID;
            (dataCID, byteIdx) = FilecoinCBOR.readCid(cborData, byteIdx);

            uint64 size;
            (size, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);

            int64 termMin;
            (termMin, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx);

            int64 termMax;
            (termMax, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx);

            int64 expiration;
            (expiration, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx);

            requests[i] = AllocationRequestData(provider, dataCID, size, termMin, termMax, expiration);
        }

        // Second element: an empty array for ClaimExtensionRequest.
        uint256 extArrayLength;
        (extArrayLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        // solhint-disable-next-line gas-custom-errors
        require(extArrayLength == 0, "Expected empty claim ext array");

        return requests;
    }

    /**
     * @notice Deserialize CBOR encoded data into a TransferParams struct.
     */
    function deserializeTransferParams(bytes memory cborData)
        public
        pure
        returns (DataCapTypes.TransferParams memory params)
    {
        uint256 byteIdx = 0;

        // Read the top-level fixed array and ensure it has exactly 3 elements.
        uint256 topArrayLength;
        (topArrayLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        // solhint-disable-next-line gas-custom-errors
        require(topArrayLength == 3, "Invalid top-level array length");

        // First element: the "to" address as a byte string.
        bytes memory toData;
        (toData, byteIdx) = CBORDecoder.readBytes(cborData, byteIdx);
        params.to = CommonTypes.FilAddress({data: toData});

        // Second element: the serialized BigInt (amount) as a CBOR tagged bignum.
        bytes memory amountBytes;
        (amountBytes, byteIdx) = CBORDecoder.readBytes(cborData, byteIdx);
        params.amount = CommonTypes.BigInt({val: amountBytes, neg: false});

        // Third element: the operator_data as a byte string.
        bytes memory operatorData;
        (operatorData, byteIdx) = CBORDecoder.readBytes(cborData, byteIdx);
        params.operator_data = operatorData;

        return params;
    }

    /**
     * @dev Serializes a TransferReturn struct to CBOR bytes.
     */
    function serializeTransferReturn(DataCapTypes.TransferReturn memory ret)
        internal
        pure
        returns (bytes memory cborData)
    {
        bytes memory fromBalanceBytes = ret.from_balance.serializeBigInt();
        bytes memory toBalanceBytes = ret.to_balance.serializeBigInt();

        uint256 capacity = Misc.getPrefixSize(3);
        capacity += Misc.getBytesSize(fromBalanceBytes);
        capacity += Misc.getBytesSize(toBalanceBytes);
        capacity += Misc.getBytesSize(ret.recipient_data);

        // Create a CBOR buffer with the calculated capacity
        CBOR.CBORBuffer memory buf = CBOR.create(capacity);

        // Write CBOR array of 3 elements
        buf.startFixedArray(3);
        buf.writeBytes(fromBalanceBytes);
        buf.writeBytes(toBalanceBytes);
        buf.writeBytes(ret.recipient_data);

        return buf.data();
    }
}
