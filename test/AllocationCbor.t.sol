// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {DataCapTypes} from "filecoin-solidity/types/DataCapTypes.sol";
import {AllocationResponseCbor} from "../src/libraries/AllocationResponseCbor.sol";
import {AllocationRequestCbor} from "../src/libraries/AllocationRequestCbor.sol";
import {Types} from "../src/libraries/Types.sol";

/**
 * @dev Wrapper so we can use calldata param type.
 */
contract AllocationRequestHelper {
    using AllocationRequestCbor for Types.AllocationRequest[];

    function encodeAllocationDataPerProvider(
        Types.AllocationRequest[] calldata allocReq,
        uint64[] calldata providers,
        uint256 replicaSize,
        int64 termMin,
        int64 termMax,
        int64 expiration
    ) external pure returns (Types.ProviderAllocationPayload[] memory) {
        return AllocationRequestCbor.encodeAllocationDataPerProvider(
            allocReq, providers, replicaSize, termMin, termMax, expiration
        );
    }
}

contract AllocationCborTest is Test {
    using AllocationResponseCbor for DataCapTypes.TransferReturn;
    using AllocationRequestCbor for Types.AllocationRequest[];

    AllocationRequestHelper helper;

    function setUp() public {
        helper = new AllocationRequestHelper();
    }

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

    function test_singleRequestEncode() public view {
        Types.AllocationRequest[] memory allocReq = new Types.AllocationRequest[](1);
        bytes memory dataCID = hex"0181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22";
        allocReq[0] = Types.AllocationRequest({dataCID: dataCID, size: 2048});

        uint64[] memory providers = new uint64[](1);
        providers[0] = 1000;
        int64 termMin = 518400;
        int64 termMax = 5256000;
        int64 expiration = 305;

        Types.ProviderAllocationPayload[] memory results = helper.encodeAllocationDataPerProvider(
            allocReq,
            providers,
            1, // replicaSize
            termMin,
            termMax,
            expiration
        );

        assertEq(
            results[0].payload,
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180"
        );
    }

    function test_multiRequestEncode() public view {
        Types.AllocationRequest[] memory allocReq = new Types.AllocationRequest[](2);
        bytes memory dataCID = hex"0181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22";
        allocReq[0] = Types.AllocationRequest({dataCID: dataCID, size: 2048});
        allocReq[1] = Types.AllocationRequest({dataCID: dataCID, size: 2048});

        uint64[] memory providers = new uint64[](1);
        providers[0] = 1000;
        int64 termMin = 518400;
        int64 termMax = 5256000;
        int64 expiration = 305;

        Types.ProviderAllocationPayload[] memory results = helper.encodeAllocationDataPerProvider(
            allocReq,
            providers,
            1, // replicaSize
            termMin,
            termMax,
            expiration
        );

        assertEq(
            results[0].payload,
            hex"8282861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180"
        );
    }
}
