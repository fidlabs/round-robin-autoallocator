// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {CBORDecoder} from "filecoin-solidity/utils/CborDecode.sol";
import {DataCapTypes} from "filecoin-solidity/types/DataCapTypes.sol";
import {ErrorLib} from "./Errors.sol";

library AllocationResponseCbor {
    /**
     * Decode Response from Allocation Request
     * ref: builtin-actors/actors/verifreg/src/types.rs::AllocationsResponse
     * cborData: [[2, []], [0, []], [5, 6]]
     * Array with 3 elements:
     * allocation_results
     * extension_results
     * new_allocations
     */
    function decodeAllocationResponse(DataCapTypes.TransferReturn memory result)
        internal
        pure
        returns (uint64[] memory allocationIds)
    {
        bytes memory cborData = result.recipient_data;

        uint256 topArrayLength;
        uint256 byteIdx = 0;

        // Read the top-level array.
        (topArrayLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        // Expect exactly 3 elements.
        if (topArrayLength != 3) {
            revert ErrorLib.InvalidTopLevelArray();
        }

        // First element: [1, []]
        // allocation_results: [newAllocations, [?]]
        {
            uint256 firstElemLength;
            (firstElemLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
            if (firstElemLength != 2) {
                revert ErrorLib.InvalidFirstElement();
            }
            // First sub-element, ignore it
            // slither-disable-next-line unused-return
            (, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            // Second sub-element
            uint256 innerLength;
            (innerLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
            if (innerLength != 0) {
                revert ErrorLib.InvalidFirstElement();
            }
        }

        // Second element: [0, []]
        // extension_results: [extendedAllocations, [?]]
        {
            uint256 secondElemLength;
            (secondElemLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
            if (secondElemLength != 2) {
                revert ErrorLib.InvalidSecondElement();
            }
            // First sub-element, extension are not supported atm so we ignore it
            // slither-disable-next-line unused-return
            (, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            // Second sub-element
            uint256 innerLength;
            (innerLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
            if (innerLength != 0) {
                revert ErrorLib.InvalidSecondElement();
            }
        }

        // third element: the allocation IDs array
        // new_allocations: [allocationID_1, ..., allocationID_N]
        uint256 allocationIdsLength;
        (allocationIdsLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);

        allocationIds = new uint64[](allocationIdsLength);
        for (uint256 i = 0; i < allocationIdsLength; i++) {
            uint64 allocationId;
            (allocationId, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            allocationIds[i] = allocationId;
        }
    }
}
