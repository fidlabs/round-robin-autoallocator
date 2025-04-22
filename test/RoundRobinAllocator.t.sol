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
import {ErrorLib} from "../src/lib/Errors.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract RoundRobinAllocatorWrapper is RoundRobinAllocator {
    function allocateWrapper(uint256 replicaSize, AllocationRequest[] calldata allocReq)
        external
        payable
        returns (uint256)
    {
        return _allocate(replicaSize, allocReq);
    }
}

contract RoundRobinAllocatorTest is Test {
    RoundRobinAllocatorWrapper public roundRobinAllocator;
    DataCapApiMock public dataCapApiMock;
    VerifRegApiMock public verifRegApiMock;
    ActorMock public actorMock;
    StorageMock public storageMock;

    address public constant CALL_ACTOR_ID = address(FilAddressIdConverter.CALL_ACTOR_BY_ID);
    address public constant datacapContract = address(FilAddressIdConverter.DATACAP_TOKEN_ACTOR);
    address public constant verifRegContract = address(FilAddressIdConverter.VERIFIED_REGISTRY_ACTOR);

    uint256 public constant COLLATERAL_PER_CID = 1 * 10 ** 18;
    uint256 public constant MIN_REQ_SP = 3;

    function setUp() public {
        roundRobinAllocator = _deployRoundRobinAllocator();

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

    function _deployRoundRobinAllocator() internal returns (RoundRobinAllocatorWrapper) {
        RoundRobinAllocatorWrapper allocator = new RoundRobinAllocatorWrapper();
        bytes memory initData = abi.encodeWithSelector(RoundRobinAllocator.initialize.selector, address(this), 1, 3);
        ERC1967Proxy proxy = new ERC1967Proxy(address(allocator), initData);
        return RoundRobinAllocatorWrapper(address(proxy));
    }

    receive() external payable {
        // This is to prevent the test from failing when claim sends collateral back
    }

    function _allocateCallAndCheck(uint256 collateralAmount, uint256 replicaSize, AllocationRequest[] memory requests)
        internal
        returns (uint256)
    {
        uint256 contractBalanceBefore = address(roundRobinAllocator).balance;
        uint256 testContractBalanceBefore = address(this).balance;

        uint256 packageId = roundRobinAllocator.allocateWrapper{value: collateralAmount}(replicaSize, requests);

        uint256 contractBalanceAfter = address(roundRobinAllocator).balance;
        uint256 testContractBalanceAfter = address(this).balance;

        assertEq(contractBalanceAfter, contractBalanceBefore + collateralAmount);
        assertEq(testContractBalanceAfter, testContractBalanceBefore - collateralAmount);

        return packageId;
    }

    function test_singleAllocate() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        uint256 replicaSize = 3;
        uint256 collateralAmount = replicaSize * COLLATERAL_PER_CID;

        uint256 packageId = _allocateCallAndCheck(collateralAmount, replicaSize, requests);

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
        uint256 collateralAmount = len * replicaSize * COLLATERAL_PER_CID;
        uint256 packageId = _allocateCallAndCheck(collateralAmount, replicaSize, requests);
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
        uint256 collateralAmount = replicaSize * COLLATERAL_PER_CID;
        uint256 packageId = _allocateCallAndCheck(collateralAmount, replicaSize, requests);
        roundRobinAllocator.claim(packageId);

        AllocationPackageReturn memory allocRet = roundRobinAllocator.getAllocationPackage(packageId);
        assertEq(allocRet.claimed, true);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CollateralAlreadyClaimed.selector));
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
        uint256 collateralAmount = allocReqCount * replicaSize * COLLATERAL_PER_CID;
        uint256 packageId = _allocateCallAndCheck(collateralAmount, replicaSize, requests);

        roundRobinAllocator.claim(packageId);
    }

    function test_singleClaimRevert() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidClaim.selector));
        roundRobinAllocator.claim(123123);
    }

    function test_allocateEmptyRequestRevert() public {
        AllocationRequest[] memory requests = new AllocationRequest[](0);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidAllocationRequest.selector));
        vm.prank(address(1));
        roundRobinAllocator.allocateWrapper(1, requests);
    }

    function test_allocateInvalidReplicaSizeRevert() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidReplicaSize.selector));
        roundRobinAllocator.allocateWrapper(0, requests);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidReplicaSize.selector));
        roundRobinAllocator.allocateWrapper(4, requests);
    }

    function test_allocateNotEnoughData() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.NotEnoughAllocationData.selector));
        roundRobinAllocator.allocateWrapper(1, requests);
    }

    function test_getAllocationPackageRevert() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidPackageId.selector));
        roundRobinAllocator.getAllocationPackage(123123);
    }

    function test_allocateCallerIsNotEOARevert() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotEOA.selector));
        roundRobinAllocator.allocate(1, requests);
    }

    function test_emergenctCollateralReleaseSuccess() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        uint256 replicaSize = 3;
        uint256 collateralAmount = replicaSize * COLLATERAL_PER_CID;
        uint256 packageId = _allocateCallAndCheck(collateralAmount, replicaSize, requests);

        roundRobinAllocator.emergencyCollateralRelease(packageId);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CollateralAlreadyClaimed.selector));
        roundRobinAllocator.claim(packageId);
    }

    function test_emergencyCollateralReleaseOwnerRevert() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        uint256 replicaSize = 3;
        uint256 collateralAmount = replicaSize * COLLATERAL_PER_CID;
        uint256 packageId = _allocateCallAndCheck(collateralAmount, replicaSize, requests);

        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(1)));
        roundRobinAllocator.emergencyCollateralRelease(packageId);
    }

    function test_emergencyCollateralReleaseBeforeClaimRevert() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        uint256 replicaSize = 3;
        uint256 collateralAmount = replicaSize * COLLATERAL_PER_CID;
        uint256 packageId = _allocateCallAndCheck(collateralAmount, replicaSize, requests);

        roundRobinAllocator.emergencyCollateralRelease(packageId);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CollateralAlreadyClaimed.selector));
        roundRobinAllocator.claim(packageId);
    }

    function test_emergencyCollateralReleaseAfterClaimRevert() public {
        AllocationRequest[] memory requests = new AllocationRequest[](1);
        requests[0] = AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        uint256 replicaSize = 3;
        uint256 collateralAmount = replicaSize * COLLATERAL_PER_CID;
        uint256 packageId = _allocateCallAndCheck(collateralAmount, replicaSize, requests);

        roundRobinAllocator.claim(packageId);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CollateralAlreadyClaimed.selector));
        roundRobinAllocator.emergencyCollateralRelease(packageId);
    }

    function test_rraInitializeCollateralRevert() public {
        RoundRobinAllocator rra = new RoundRobinAllocator();
        bytes memory initData =
            abi.encodeWithSelector(RoundRobinAllocator.initialize.selector, address(this), 0, rra.MIN_REQ_SP() - 1);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidCollateralPerCID.selector));
        new ERC1967Proxy(address(rra), initData);
    }

    function test_rraInitializeMinStorageProvidersRevert() public {
        RoundRobinAllocator rra = new RoundRobinAllocator();
        bytes memory initData = abi.encodeWithSelector(
            RoundRobinAllocator.initialize.selector, address(this), rra.MIN_COLLATERAL_PER_CID() - 1, 1
        );
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidCollateralPerCID.selector));
        new ERC1967Proxy(address(rra), initData);
    }
}
