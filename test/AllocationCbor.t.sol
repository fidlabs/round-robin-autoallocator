// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {DataCapTypes} from "filecoin-solidity/types/DataCapTypes.sol";
import {AllocationRequestCbor, AllocationRequestData} from "../src/lib/AllocationRequestCbor.sol";
import {AllocationResponseCbor} from "../src/lib/AllocationResponseCbor.sol";

contract AllocationCborTest is Test {
    using AllocationResponseCbor for DataCapTypes.TransferReturn;
    using AllocationRequestCbor for AllocationRequestData[];

    function _transferReturnFromBytes(bytes memory data) private pure returns (DataCapTypes.TransferReturn memory) {
        return DataCapTypes.TransferReturn({
            from_balance: CommonTypes.BigInt({val: hex"00", neg: false}),
            to_balance: CommonTypes.BigInt({val: hex"00", neg: false}),
            recipient_data: data
        });
    }

    function test_singleResponseDecode() public pure {
        bytes memory recipient_data = hex"838201808200808104";
        uint64[] memory allocationIds = _transferReturnFromBytes(recipient_data).decodeAllocationResponse();

        assertEq(allocationIds.length, 1);
        assertEq(allocationIds[0], 4);
    }

    function test_multiResponseDecode() public pure {
        bytes memory recipient_data = hex"83820c808200808c05060708090a0b0c0d0e0f10000000000000000000000000";
        uint64[] memory allocationIds = _transferReturnFromBytes(recipient_data).decodeAllocationResponse();

        assertEq(allocationIds.length, 12);
        assertEq(allocationIds[0], 5);
        assertEq(allocationIds[11], 16);
    }

    function test_singleRequestEncode() public pure {
        AllocationRequestData[] memory allocationRequestData = new AllocationRequestData[](1);
        allocationRequestData[0] = AllocationRequestData({
            provider: 1000,
            dataCID: CommonTypes.Cid({
                data: hex"0181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22"
            }),
            size: 2048,
            termMin: 518400,
            termMax: 5256000,
            expiration: 305
        });

        bytes memory operator_data = allocationRequestData.encodeRequestData();

        assertEq(
            operator_data,
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180"
        );
    }

    function test_multiRequestEncode() public pure {
        AllocationRequestData[] memory allocationRequestData = new AllocationRequestData[](2);
        allocationRequestData[0] = AllocationRequestData({
            provider: 1000,
            dataCID: CommonTypes.Cid({
                data: hex"0181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22"
            }),
            size: 2048,
            termMin: 518400,
            termMax: 5256000,
            expiration: 305
        });
        allocationRequestData[1] = AllocationRequestData({
            provider: 1000,
            dataCID: CommonTypes.Cid({
                data: hex"0181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22"
            }),
            size: 2048,
            termMin: 518400,
            termMax: 5256000,
            expiration: 305
        });

        bytes memory operator_data = allocationRequestData.encodeRequestData();

        assertEq(
            operator_data,
            hex"8282861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180"
        );
    }
}
