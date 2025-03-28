// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {DataCapTypes} from "filecoin-solidity/types/DataCapTypes.sol";
import {Misc} from "filecoin-solidity/utils/Misc.sol";
import {BigInts} from "filecoin-solidity/utils/BigInts.sol";

import {AllocationCborTest} from "../lib/AllocationCborTest.sol";
import {AllocationRequestData} from "../../src/lib/AllocationRequestCbor.sol";

contract DataCapApiMock {
    error Err();    

    event DebugBytes(address indexed client, bytes data);
    event DebugAllocationRequest(
        address indexed client,
        AllocationRequestData[] requests
    );

    fallback(bytes calldata data) external returns (bytes memory) {
        (uint256 methodNum, , , , bytes memory raw_request, uint64 target) = abi
            .decode(data, (uint64, uint256, uint64, uint64, bytes, uint64));

        // datacap transfer
        if (target == 7 && methodNum == 80475954) {
            DataCapTypes.TransferParams memory params = AllocationCborTest
                .deserializeTransferParams(raw_request);

            emit DebugBytes(msg.sender, raw_request);
            emit DebugBytes(msg.sender, params.operator_data);

            AllocationRequestData[] memory requests = AllocationCborTest
                .decodeDataArray(params.operator_data);
            emit DebugAllocationRequest(msg.sender, requests);

            uint64[] memory allocationIds = new uint64[](requests.length);
            for (uint256 i = 0; i < requests.length; i++) {
                uint64 deno = 100000;
                allocationIds[i] = uint64(
                    (uint256(blockhash(block.number)) % deno) + i
                );
            }

            bytes memory recipient_data = AllocationCborTest
                .encodeAllocationResponse(1, allocationIds);

            emit DebugBytes(msg.sender, recipient_data);

            DataCapTypes.TransferReturn memory transferReturn = DataCapTypes
                .TransferReturn({
                    recipient_data: recipient_data,
                    from_balance: BigInts.fromUint256(0),
                    to_balance: BigInts.fromUint256(0)
                });

            bytes memory transferReturnBytes = AllocationCborTest
                .serializeTransferReturn(transferReturn);

            return abi.encode(0, Misc.CBOR_CODEC, transferReturnBytes);
        }
        revert Err();
    }
}
