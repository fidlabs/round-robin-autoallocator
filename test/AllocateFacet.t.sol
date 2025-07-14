// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {ErrorLib} from "../src/libraries/Errors.sol";
import {Types} from "../src/libraries/Types.sol";
import {DiamondDeployer} from "./lib/DiamondDeployer.sol";
import {AllocateHelper} from "./lib/AllocateHelper.sol";

contract AllocatorFacetTest is Test, AllocateHelper {
    function setUp() public {
        _setUp();
    }

    receive() external payable {
        // This is to prevent the test from failing when claim sends collateral back
    }

    function test_singleAllocate() public {
        uint256 len = 1;
        uint256 replicaSize = 2;

        (,, uint256 packageId) = _allocate(len, replicaSize);

        {
            Types.AllocationPackageReturn memory allocRet = viewFacet.getAllocationPackage(packageId);
            uint256 expectedAllocCount = len * replicaSize;
            _validateAllocRet(allocRet, expectedAllocCount);
        }
    }

    function _validateAllocRet(Types.AllocationPackageReturn memory allocRet, uint256 expectedAllocCount)
        internal
        view
    {
        assertEq(allocRet.client, address(this));
        assertFalse(allocRet.claimed);
        assertGe(allocRet.storageProviders.length, 2);
        uint256 totalAllocationIdCount = 0;
        for (uint256 i = 0; i < allocRet.storageProviders.length; i++) {
            assertGe(allocRet.spAllocationIds[i].length, 1);
            totalAllocationIdCount += allocRet.spAllocationIds[i].length;
        }
        assertEq(totalAllocationIdCount, expectedAllocCount);
    }

    function test_multiAllocate() public {
        uint256 len = 64;
        (,, uint256 packageId) = _allocate(len, 1);
        {
            Types.AllocationPackageReturn memory allocRet = viewFacet.getAllocationPackage(packageId);
            uint256 total;
            for (uint256 sp = 0; sp < allocRet.storageProviders.length; sp++) {
                uint256 c = allocRet.spAllocationIds[sp].length;
                total += c;
                // check even distribution of allocations
                assertApproxEqAbs(
                    c, len / DiamondDeployer.MIN_REQ_SP, 1, "Allocation count mismatch for storage provider"
                );
            }
            assertEq(total, len * 1);
        }
    }

    function test_allocateEmptyRequestRevert() public {
        Types.AllocationRequest[] memory requests = new Types.AllocationRequest[](0);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidAllocationRequest.selector));
        vm.prank(address(1));
        allocateFacet.allocateWrapper(1, requests);
    }

    function test_allocateInvalidReplicaSizeRevert() public {
        Types.AllocationRequest[] memory requests = new Types.AllocationRequest[](1);
        requests[0] = Types.AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidReplicaSize.selector));
        allocateFacet.allocateWrapper(0, requests);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidReplicaSize.selector));
        allocateFacet.allocateWrapper(4, requests);
    }

    function test_allocateNotEnoughData() public {
        Types.AllocationRequest[] memory requests = new Types.AllocationRequest[](1);
        requests[0] = Types.AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.NotEnoughAllocationData.selector));
        allocateFacet.allocateWrapper(1, requests);
    }

    function test_getAllocationPackageRevert() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidPackageId.selector));
        viewFacet.getAllocationPackage(123123);
    }

    function test_allocateCallerIsNotEOARevert() public {
        Types.AllocationRequest[] memory requests = new Types.AllocationRequest[](1);
        requests[0] = Types.AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotEOA.selector));
        allocateFacet.allocate(1, requests);
    }

    function test_emergenctCollateralReleaseSuccess() public {
        uint256 len = 1;
        uint256 replicaSize = 2;
        (,, uint256 packageId) = _allocate(len, replicaSize);

        uint256 balanceBefore = address(this).balance;
        ownerFacet.emergencyCollateralRelease(packageId);
        uint256 balanceAfter = address(this).balance;
        assertEq(balanceAfter, balanceBefore + (replicaSize * COLLATERAL_PER_CID));
    }

    function test_emergencyCollateralReleaseOwnerRevert() public {
        uint256 len = 1;
        uint256 replicaSize = 2;
        (,, uint256 packageId) = _allocate(len, replicaSize);

        uint256 balanceBefore = address(this).balance;
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotOwner.selector));
        ownerFacet.emergencyCollateralRelease(packageId);
        uint256 balanceAfter = address(this).balance;
        assertEq(balanceAfter, balanceBefore);
    }

    function test_emergencyCollateralReleaseBeforeClaimRevert() public {
        Types.AllocationRequest[] memory requests = new Types.AllocationRequest[](1);
        requests[0] = Types.AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        uint256 replicaSize = 2;
        uint256 collateralAmount = replicaSize * COLLATERAL_PER_CID;
        uint256 packageId = _allocateCallAndCheck(collateralAmount, replicaSize, requests);

        ownerFacet.emergencyCollateralRelease(packageId);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CollateralAlreadyClaimed.selector));
        retrieveCollateralFacet.retrieveCollateral(packageId);
    }

    function test_emergencyCollateralReleaseAfterClaimRevert() public {
        Types.AllocationRequest[] memory requests = new Types.AllocationRequest[](1);
        requests[0] = Types.AllocationRequest({
            dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
            size: 2048
        });

        uint256 replicaSize = 2;
        uint256 collateralAmount = replicaSize * COLLATERAL_PER_CID;
        uint256 packageId = _allocateCallAndCheck(collateralAmount, replicaSize, requests);
        _setClaimedForPackage(packageId);
        retrieveCollateralFacet.retrieveCollateral(packageId);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CollateralAlreadyClaimed.selector));
        ownerFacet.emergencyCollateralRelease(packageId);
    }

    function test_emergencyCollateralReleaseForNonExistingPackageRevert() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidPackageId.selector));
        ownerFacet.emergencyCollateralRelease(123123);
    }
}
