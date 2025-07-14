// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {DataCapApiMock} from "../mocks/DataCapApiMock.sol";
import {VerifRegApiMock} from "../mocks/VerifRegApiMock.sol";
import {ActorMock} from "../mocks/ActorMock.sol";
import {StorageMock} from "../mocks/StorageMock.sol";
import {FilAddressIdConverter} from "filecoin-solidity/utils/FilAddressIdConverter.sol";
import {ConstantMock} from "../mocks/ConstantMock.sol";
import {AllocateFacet} from "../../src/facets/AllocateFacet.sol";
import {RetrieveCollateralFacet} from "../../src/facets/RetrieveCollateralFacet.sol";
import {OwnerFacet} from "../../src/facets/OwnerFacet.sol";
import {Types} from "../../src/libraries/Types.sol";
import {DiamondDeployer} from "../lib/DiamondDeployer.sol";
import {IFacet} from "../../src/interfaces/IFacet.sol";
import {StorageEntityManagerFacet} from "../../src/facets/StorageEntityManagerFacet.sol";
import {ViewFacet} from "../../src/facets/ViewFacet.sol";
import {Storage} from "../../src/libraries/Storage.sol";

contract AllocateFacetWrapper is AllocateFacet {
    function selectors() external pure override returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](2);
        selectors_[0] = this.allocate.selector;
        selectors_[1] = this.allocateWrapper.selector;
    }

    function allocateWrapper(uint256 replicaSize, Types.AllocationRequest[] calldata allocReq)
        external
        payable
        returns (uint256)
    {
        return _allocate(replicaSize, allocReq);
    }
}

contract AllocateHelper is Test {
    AllocateFacetWrapper public allocateFacet;
    StorageEntityManagerFacet public storageEntityManagerFacet;
    ViewFacet public viewFacet;
    OwnerFacet public ownerFacet;
    DataCapApiMock public dataCapApiMock;
    VerifRegApiMock public verifRegApiMock;
    ActorMock public actorMock;
    StorageMock public storageMock;
    RetrieveCollateralFacet public retrieveCollateralFacet;

    address public constant CALL_ACTOR_ID = address(FilAddressIdConverter.CALL_ACTOR_BY_ID);
    address public constant datacapContract = address(FilAddressIdConverter.DATACAP_TOKEN_ACTOR);
    address public constant verifRegContract = address(FilAddressIdConverter.VERIFIED_REGISTRY_ACTOR);

    uint256 public constant COLLATERAL_PER_CID = 1 * 10 ** 18; // TODO: fix this !
    uint256 public constant MIN_REQ_SP = 3;

    function _setUp() internal {
        AllocateFacetWrapper _allocateFacet = new AllocateFacetWrapper();
        IFacet[] memory replaceFacets = new IFacet[](1);
        replaceFacets[0] = _allocateFacet;
        address diamond = DiamondDeployer.deployDiamondWithReplace(address(this), replaceFacets);
        allocateFacet = AllocateFacetWrapper(diamond);
        storageEntityManagerFacet = StorageEntityManagerFacet(diamond);
        viewFacet = ViewFacet(diamond);
        ownerFacet = OwnerFacet(diamond);
        retrieveCollateralFacet = RetrieveCollateralFacet(diamond);

        address storageMockAddr = ConstantMock.getSaltMockAddress();
        vm.etch(storageMockAddr, type(StorageMock).runtimeCode);
        storageMock = StorageMock(storageMockAddr);

        dataCapApiMock = new DataCapApiMock();
        verifRegApiMock = new VerifRegApiMock();
        actorMock = new ActorMock();

        vm.etch(datacapContract, address(dataCapApiMock).code);
        vm.etch(verifRegContract, address(verifRegApiMock).code);
        vm.etch(CALL_ACTOR_ID, address(actorMock).code);

        Storage.ProviderDetails memory _spDetails =
            Storage.ProviderDetails({isActive: true, spaceLeft: type(uint256).max});

        // add storage entities, half of them are inactive
        for (uint256 i = 1000; i < 1010; i++) {
            address owner = makeAddr(vm.toString(i));
            uint64[] memory storageProviders = new uint64[](1);
            storageProviders[0] = uint64(i);
            storageEntityManagerFacet.createStorageEntity(owner, storageProviders);
            storageEntityManagerFacet.setStorageProviderDetails(owner, storageProviders[0], _spDetails);
        }

        // make sure we are able to get blockhash - 5
        vm.roll(100);
    }

    function _prepRequest(uint256 len) internal pure returns (Types.AllocationRequest[] memory requests) {
        requests = new Types.AllocationRequest[](len);
        for (uint256 i = 0; i < len; i++) {
            requests[i] = Types.AllocationRequest({
                dataCID: hex"0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b",
                size: 2048
            });
        }
    }

    function _allocateCallAndCheck(
        uint256 collateralAmount,
        uint256 replicaSize,
        Types.AllocationRequest[] memory requests
    ) internal returns (uint256) {
        uint256 contractBalanceBefore = address(allocateFacet).balance;
        uint256 testContractBalanceBefore = address(this).balance;

        uint256 packageId = allocateFacet.allocateWrapper{value: collateralAmount}(replicaSize, requests);

        uint256 contractBalanceAfter = address(allocateFacet).balance;
        uint256 testContractBalanceAfter = address(this).balance;

        assertEq(contractBalanceAfter, contractBalanceBefore + collateralAmount, "Diamond Contract balance mismatch");
        assertEq(
            testContractBalanceAfter, testContractBalanceBefore - collateralAmount, "Test contract balance mismatch"
        );

        return packageId;
    }

    function _allocate(uint256 requestLen, uint256 replicaSize)
        internal
        returns (Types.AllocationRequest[] memory requests, uint256 collateralAmount, uint256 packageId)
    {
        requests = _prepRequest(requestLen);

        assertEq(requests.length, requestLen, "Request length mismatch");

        collateralAmount = requests.length * replicaSize * COLLATERAL_PER_CID;

        packageId = _allocateCallAndCheck(collateralAmount, replicaSize, requests);
    }

    function _setClaimedForPackage(uint256 packageId) internal {
        Types.AllocationPackageReturn memory package = viewFacet.getAllocationPackage(packageId);
        for (uint256 i = 0; i < package.storageProviders.length; i++) {
            for (uint256 j = 0; j < package.spAllocationIds[i].length; j++) {
                storageMock.setAllocationProviderClaimed(
                    package.storageProviders[i], package.spAllocationIds[i][j], true
                );
            }
        }
    }
}
