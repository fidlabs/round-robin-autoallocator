// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AllocationCborTest} from "./lib/AllocationCborTest.sol";
import {RoundRobinAllocator, AllocationRequest, AllocationResponse} from "../src/RoundRobinAllocator.sol";
import {DataCapApiMock} from "./mocks/DataCapApiMock.sol";
import {DataCapActorMock} from "./mocks/ActorMock.sol";
import {StorageMock, SALT_MOCK} from "./mocks/StorageMock.sol";

contract RoundRobinAllocatorTest is Test {
    RoundRobinAllocator public roundRobinAllocator;
    DataCapApiMock public dataCapApiMock;
    DataCapActorMock public actorMock;
    StorageMock public storageMock;

    address public constant CALL_ACTOR_ID =
        address(0xfe00000000000000000000000000000000000005);
    address public constant datacapContract =
        address(0xfF00000000000000000000000000000000000007);

    function setUp() public {
        roundRobinAllocator = new RoundRobinAllocator();
        roundRobinAllocator.initialize(address(this));
        dataCapApiMock = new DataCapApiMock();
        actorMock = new DataCapActorMock();
        storageMock = new StorageMock{salt: SALT_MOCK}(); // 0x3572B35A3250b0941A27D6F195F8DF7185AEcc31

        vm.etch(datacapContract, address(dataCapApiMock).code);
        vm.etch(CALL_ACTOR_ID, address(actorMock).code);

        // add storage entities, half of them are inactive
        for (uint i = 1000; i < 1003; i++) {
            address owner = makeAddr(vm.toString(i));
            uint64[] memory storageProviders = new uint64[](1);
            storageProviders[0] = uint64(i);
            roundRobinAllocator.createStorageEntity(owner, storageProviders);
        }

        // make sure we are able to get blockhash - 5
        vm.roll(100);
    }

    function test_singleAllocate() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        uint replicaSize = 3;
        AllocationResponse[] memory allocationResponses = roundRobinAllocator
            .allocate(replicaSize, requests);

        assertEq(allocationResponses.length, replicaSize);
        for (uint i = 0; i < allocationResponses.length; i++) {
            assertEq(
                allocationResponses[i].allocationIds.length,
                requests.length
            );
        }
    }

    function test_multiAllocate() public {
        uint len = 64;

        AllocationRequest[] memory requests = new AllocationRequest[](len);
        for (uint i = 0; i < len; i++) {
            requests[i] = AllocationRequest({
                dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
                size: 2048
            });
        }

        AllocationResponse[] memory allocationResponses = roundRobinAllocator
            .allocate(1, requests);

        uint totalAllocationIdCount = 0;
        for (uint i = 0; i < allocationResponses.length; i++) {
            totalAllocationIdCount += allocationResponses[i]
                .allocationIds
                .length;

            uint expectedAllocationsPerProvider = len / 3;
            uint expectedDiff = 1;
            assertApproxEqAbs(
                allocationResponses[i].allocationIds.length,
                expectedAllocationsPerProvider,
                expectedDiff
            );
        }

        assertEq(totalAllocationIdCount, len);
    }
}
