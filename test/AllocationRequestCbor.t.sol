// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AllocationRequestCbor, ProviderAllocationPayload} from "../src/lib/AllocationRequestCbor.sol";
import {AllocationRequest} from "../src/RoundRobinAllocator.sol";

contract AllocationTestWrapper {
    using AllocationRequestCbor for AllocationRequest[];

    function encodeAllocations(
        AllocationRequest[] calldata allocReq,
        uint replicaSize,
        uint64[] memory providers,
        int64 termMin,
        int64 termMax,
        int64 expiration
    ) external pure returns (ProviderAllocationPayload[] memory) {
        return
            AllocationRequestCbor.encodeAllocationDataPerProvider(
                allocReq,
                providers,
                replicaSize,
                termMin,
                termMax,
                expiration
            );
    }
}

contract AllocationRequestCborTest is Test {
    AllocationTestWrapper wrapper;

    function setUp() public {
        wrapper = new AllocationTestWrapper();
    }

    function _createAllocRequest(
        bytes memory cid,
        uint64 size
    ) internal pure returns (AllocationRequest memory) {
        return AllocationRequest({dataCID: cid, size: size});
    }

    function test_singleAllocReqSingleReplica() public view {
        AllocationRequest[] memory allocReqs = new AllocationRequest[](1);
        allocReqs[0] = _createAllocRequest("cid1", 100);
        uint replicaSize = 1;

        uint64[] memory providers = new uint64[](3);
        providers[0] = 100;
        providers[1] = 200;
        providers[2] = 300;

        int64 termMin = 1000;
        int64 termMax = 2000;
        int64 expiration = 3000;

        ProviderAllocationPayload[] memory payloads = wrapper.encodeAllocations(
            allocReqs,
            replicaSize,
            providers,
            termMin,
            termMax,
            expiration
        );

        assertEq(payloads[0].provider, 100);
        assertEq(payloads[0].totalSize, 100);
        assertGt(payloads[0].payload.length, 0);

        assertEq(payloads[1].totalSize, 0);
        assertEq(payloads[2].totalSize, 0);
    }

    function test_twoAllocReqTwoReplicas() public view {
        AllocationRequest[] memory allocReqs = new AllocationRequest[](2);
        allocReqs[0] = _createAllocRequest("cid1", 100);
        allocReqs[1] = _createAllocRequest("cid2", 200);
        uint replicaSize = 2;

        uint64[] memory providers = new uint64[](3);
        providers[0] = 1;
        providers[1] = 2;
        providers[2] = 3;

        int64 termMin = 1000;
        int64 termMax = 2000;
        int64 expiration = 3000;

        ProviderAllocationPayload[] memory payloads = wrapper.encodeAllocations(
            allocReqs,
            replicaSize,
            providers,
            termMin,
            termMax,
            expiration
        );

        // 100
        assertEq(payloads[0].provider, 1);
        assertEq(payloads[0].totalSize, 100);
        assertGt(payloads[0].payload.length, 0);

        // 100 + 200
        assertEq(payloads[1].provider, 2);
        assertEq(payloads[1].totalSize, 300);
        assertGt(payloads[1].payload.length, 0);

        // 200
        assertEq(payloads[2].provider, 3);
        assertEq(payloads[2].totalSize, 200);
        assertGt(payloads[2].payload.length, 0);
    }

    function test_fiveAllocReqThreeReplicas() public view {
        AllocationRequest[] memory allocReqs = new AllocationRequest[](5);
        allocReqs[0] = _createAllocRequest("cid1", 50);
        allocReqs[1] = _createAllocRequest("cid2", 60);
        allocReqs[2] = _createAllocRequest("cid3", 70);
        allocReqs[3] = _createAllocRequest("cid4", 80);
        allocReqs[4] = _createAllocRequest("cid5", 90);
        uint replicaSize = 3;

        uint64[] memory providers = new uint64[](4);
        providers[0] = 101;
        providers[1] = 202;
        providers[2] = 303;
        providers[3] = 404;

        int64 termMin = 1000;
        int64 termMax = 2000;
        int64 expiration = 3000;

        ProviderAllocationPayload[] memory payloads = wrapper.encodeAllocations(
            allocReqs,
            replicaSize,
            providers,
            termMin,
            termMax,
            expiration
        );

        uint64[] memory expectedTotals = new uint64[](4);
        for (uint i = 0; i < allocReqs.length; i++) {
            for (uint r = 0; r < replicaSize; r++) {
                uint providerIndex = (i + r) % providers.length;
                expectedTotals[providerIndex] += allocReqs[i].size;
            }
        }
        for (uint p = 0; p < providers.length; p++) {
            assertEq(payloads[p].provider, providers[p]);
            assertEq(payloads[p].totalSize, expectedTotals[p]);

            if (expectedTotals[p] > 0) {
                assertGt(payloads[p].payload.length, 0);
            }
        }
    }

    function test_thousandsAllocReqThreeReplicas() public view {
        // uneven number of allocations
        uint allocationsCount = 6601;
        AllocationRequest[] memory allocReqs = new AllocationRequest[](
            allocationsCount
        );

        for (uint i = 0; i < allocationsCount; i++) {
            bytes memory cid = bytes(
                string(abi.encodePacked("cid", vm.toString(i)))
            );
            allocReqs[i] = _createAllocRequest(cid, uint64(100 + i));
        }

        uint replicaSize = 3;
        uint providersCount = 10;
        uint64[] memory providers = new uint64[](providersCount);
        for (uint i = 0; i < providersCount; i++) {
            providers[i] = uint64(1000 + i * 100);
        }

        int64 termMin = 1000;
        int64 termMax = 2000;
        int64 expiration = 3000;

        ProviderAllocationPayload[] memory payloads = wrapper.encodeAllocations(
            allocReqs,
            replicaSize,
            providers,
            termMin,
            termMax,
            expiration
        );

        uint64[] memory expectedCounts = new uint64[](providersCount);
        uint64[] memory expectedTotals = new uint64[](providersCount);

        for (uint i = 0; i < allocationsCount; i++) {
            for (uint r = 0; r < replicaSize; r++) {
                uint providerIndex = (i + r) % providersCount;
                expectedCounts[providerIndex]++;
                expectedTotals[providerIndex] += allocReqs[i].size;
            }
        }

        for (uint p = 0; p < providersCount; p++) {
            assertEq(payloads[p].provider, providers[p]);
            assertEq(payloads[p].count, expectedCounts[p]);
            assertEq(payloads[p].totalSize, expectedTotals[p]);

            assertGt(payloads[p].payload.length, 0);
        }

        // allocations are distributed approximately evenly
        uint expectedAllocationsPerProvider = (allocationsCount * replicaSize) /
            providersCount;

        uint expectedMaximumDifference = 1;

        for (uint p = 0; p < providersCount; p++) {
            // allow only small deviation
            assertApproxEqAbs(
                uint(payloads[p].count),
                expectedAllocationsPerProvider,
                expectedMaximumDifference,
                "allocations have more than 1 allocation difference expected from round-robin distribution"
            );
        }
    }
}
