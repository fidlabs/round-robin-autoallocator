// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {RoundRobinAllocator, AllocationRequest, AllocationPackageReturn} from "../src/RoundRobinAllocator.sol";
import {DataCapApiMock} from "./mocks/DataCapApiMock.sol";
import {VerifRegApiMock} from "./mocks/VerifRegApiMock.sol";
import {ActorMock} from "./mocks/ActorMock.sol";
import {StorageMock} from "./mocks/StorageMock.sol";
import {FilAddressIdConverter} from "filecoin-solidity/utils/FilAddressIdConverter.sol";
import {ConstantMock} from "./mocks/ConstantMock.sol";
import {Errors} from "../src/lib/Errors.sol";

contract RoundRobinAllocatorTest is Test {
    RoundRobinAllocator public roundRobinAllocator;
    DataCapApiMock public dataCapApiMock;
    VerifRegApiMock public verifRegApiMock;
    ActorMock public actorMock;
    StorageMock public storageMock;

    address public constant CALL_ACTOR_ID = address(FilAddressIdConverter.CALL_ACTOR_BY_ID);
    address public constant datacapContract = address(FilAddressIdConverter.DATACAP_TOKEN_ACTOR);
    address public constant verifRegContract = address(FilAddressIdConverter.VERIFIED_REGISTRY_ACTOR);

    function setUp() public {
        roundRobinAllocator = new RoundRobinAllocator();
        roundRobinAllocator.initialize(address(this));

        address storageMockAddr = ConstantMock.getSaltMockAddress();
        vm.etch(storageMockAddr, type(StorageMock).runtimeCode);
        storageMock = StorageMock(storageMockAddr);
    
        dataCapApiMock = new DataCapApiMock();
        verifRegApiMock = new VerifRegApiMock();
        actorMock = new ActorMock();

        vm.etch(datacapContract, address(dataCapApiMock).code);
        vm.etch(verifRegContract, address(verifRegApiMock).code);
        vm.etch(CALL_ACTOR_ID, address(actorMock).code);

        // add storage entities, half of them are inactive
        for (uint256 i = 1000; i < 1003; i++) {
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

        uint256 replicaSize = 3;
        uint256 packageId = roundRobinAllocator.allocate(replicaSize, requests);
        AllocationPackageReturn memory allocRet = roundRobinAllocator.getAllocationPackage(packageId);

        uint256 expectedAllocCount = requests.length * replicaSize;

        _validateAllocRet(allocRet, expectedAllocCount);
    }

    function _validateAllocRet(AllocationPackageReturn memory allocRet, uint256 expectedAllocCount) internal view {
        assertEq(allocRet.client, address(this));
        assertFalse(allocRet.claimed);
        assertGe(allocRet.storageProviders.length, 3);
        uint256 totalAllocationIdCount = 0;
        for (uint256 i = 0; i < allocRet.storageProviders.length; i++) {
            assertGe(allocRet.spAllocationIds[i].length, 1);
            totalAllocationIdCount += allocRet.spAllocationIds[i].length;
        }
        assertEq(totalAllocationIdCount, expectedAllocCount);
    }

    function test_multiAllocate() public {
        uint256 len = 64;

        AllocationRequest[] memory requests = new AllocationRequest[](len);
        for (uint256 i = 0; i < len; i++) {
            requests[i] = AllocationRequest({
                dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
                size: 2048
            });
        }

        uint256 replicaSize = 1;
        uint256 packageId = roundRobinAllocator.allocate(replicaSize, requests);
        AllocationPackageReturn memory allocRet = roundRobinAllocator.getAllocationPackage(packageId);

        uint256 totalAllocationIdCount = 0;
        for (uint256 sp = 0; sp < allocRet.storageProviders.length; sp++) {
            totalAllocationIdCount += allocRet.spAllocationIds[sp].length;

            uint256 expectedAllocationsPerProvider = len / 3;
            uint256 expectedDiff = 1;
            assertApproxEqAbs(allocRet.spAllocationIds[sp].length, expectedAllocationsPerProvider, expectedDiff);
        }
        assertEq(totalAllocationIdCount, len * replicaSize);
    }

    function test_singleClaimSuccess() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        uint256 replicaSize = 3;
        uint256 packageId = roundRobinAllocator.allocate(replicaSize, requests);
        roundRobinAllocator.claim(packageId);

        AllocationPackageReturn memory allocRet = roundRobinAllocator.getAllocationPackage(packageId);
        assertEq(allocRet.claimed, true);

        vm.expectRevert(abi.encodeWithSelector(Errors.CollateralAlreadyClaimed.selector));
        roundRobinAllocator.claim(packageId);
    }

    function test_multiClaimSuccess() public {
        uint256 allocReqCount = 10;
        uint256 replicaSize = 1;

        AllocationRequest[] memory requests = new AllocationRequest[](allocReqCount);
        for (uint256 i = 0; i < allocReqCount; i++) {
            requests[i] = AllocationRequest({
                dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
                size: 2048
            });
        }
        uint256 packageId = roundRobinAllocator.allocate(replicaSize, requests);

        roundRobinAllocator.claim(packageId);
    }

    function test_singleClaimRevert() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidClaim.selector));
        roundRobinAllocator.claim(123123);
    }

    function test_allocateEmptyRequestRevert() public {
        AllocationRequest[] memory requests = new AllocationRequest[](0);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAllocationRequest.selector));
        roundRobinAllocator.allocate(1, requests);
    }

    function test_allocateInvalidReplicaSizeRevert() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidReplicaSize.selector));
        roundRobinAllocator.allocate(0, requests);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidReplicaSize.selector));
        roundRobinAllocator.allocate(4, requests);
    }

    function test_allocateNotEnoughData() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        vm.expectRevert(abi.encodeWithSelector(Errors.NotEnoughAllocationData.selector));
        roundRobinAllocator.allocate(1, requests);
    }

    function test_getAllocationPackageRevert() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidPackageId.selector));
        roundRobinAllocator.getAllocationPackage(123123);
    }
}
