// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {DataCapTypes} from "filecoin-solidity/types/DataCapTypes.sol";
import {DataCapAPI} from "filecoin-solidity/DataCapAPI.sol";
import {BigInts} from "filecoin-solidity/utils/BigInts.sol";
import {FilAddresses} from "filecoin-solidity/utils/FilAddresses.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {IFacet} from "../interfaces/IFacet.sol";
import {Modifiers} from "../Modifiers.sol";
import {Types} from "../libraries/Types.sol";
import {ErrorLib} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {Storage} from "../libraries/Storage.sol";
import {FilecoinEpochCalculator} from "../libraries/FilecoinEpochCalculator.sol";
import {StorageEntityPicker} from "../libraries/StorageEntityPicker.sol";
import {AllocationRequestCbor} from "../libraries/AllocationRequestCbor.sol";
import {AllocationResponseCbor} from "../libraries/AllocationResponseCbor.sol";

contract AllocateFacet is IFacet, Modifiers, PausableUpgradeable {
    using AllocationRequestCbor for Types.AllocationRequest[];
    using AllocationResponseCbor for DataCapTypes.TransferReturn;

    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](1);
        selectors_[0] = this.allocate.selector;
    }

    function allocate(uint256 replicaSize, Types.AllocationRequest[] calldata allocReq)
        external
        payable
        whenNotPaused
        onlyEOA
        returns (uint256)
    {
        return _allocate(replicaSize, allocReq);
    }

    function _allocate(uint256 replicaSize, Types.AllocationRequest[] calldata allocReq) internal returns (uint256) {
        if (allocReq.length == 0) {
            revert ErrorLib.InvalidAllocationRequest();
        }
        Storage.AppConfig memory appConfig = Storage.getAppConfig();
        if (replicaSize < appConfig.minReplicas || replicaSize > appConfig.maxReplicas) {
            revert ErrorLib.InvalidReplicaSize();
        }
        if (allocReq.length * replicaSize < appConfig.minRequiredStorageProviders) {
            revert ErrorLib.NotEnoughAllocationData();
        }
        {
            uint256 requiredCollateral = appConfig.collateralPerCID * allocReq.length * replicaSize;
            if (msg.value < requiredCollateral) {
                revert ErrorLib.InsufficientCollateral(requiredCollateral);
            }
        }
        uint256 maxSpacePerProvider =
            _calculateMaxAllocationSizePerProvider(allocReq, replicaSize, appConfig.minRequiredStorageProviders);
        uint64[] memory providers =
            StorageEntityPicker._pickStorageProviders(appConfig.minRequiredStorageProviders, maxSpacePerProvider);

        int64 termMin = FilecoinEpochCalculator.getTermMin();
        int64 termMax = FilecoinEpochCalculator.calcTermMax();
        int64 expiration = FilecoinEpochCalculator.getExpiration();
        Types.ProviderAllocationPayload[] memory providerPayloads =
            allocReq.encodeAllocationDataPerProvider(providers, replicaSize, termMin, termMax, expiration);

        uint256 packageId = Storage.s().packageCount++;
        Storage.s().clientAllocationPackages[msg.sender].push(packageId);

        Storage.AllocationPackage storage package = Storage.s().allocationPackages[packageId];

        // send data cap separately for each provider so we can track allocation IDs per SP
        for (uint256 i = 0; i < providerPayloads.length; i++) {
            uint256 amount = uint256(providerPayloads[i].totalSize) * 10 ** 18;
            DataCapTypes.TransferParams memory params = DataCapTypes.TransferParams({
                to: FilAddresses.fromActorID(6),
                amount: BigInts.fromUint256(amount),
                operator_data: providerPayloads[i].payload
            });
            (int256 exit_code, DataCapTypes.TransferReturn memory result) = DataCapAPI.transfer(params);

            uint64[] memory allocationIds = result.decodeAllocationResponse();
            package.spAllocationIds[providerPayloads[i].provider] = allocationIds;

            if (allocationIds.length != providerPayloads[i].count) {
                revert ErrorLib.AllocationFailed();
            }

            emit Events.AllocationCreated(msg.sender, providerPayloads[i].provider, packageId, amount, allocationIds);

            if (exit_code != 0) {
                revert ErrorLib.DataCapTransferFailed();
            }
        }

        package.client = msg.sender;
        package.storageProviders = providers;
        package.collateral = msg.value;

        emit Events.CollateralLocked(msg.sender, packageId, msg.value);

        return packageId;
    }

    /**
     * @dev Calculate the worst case (maximum) allocation size based on the request.
     * cost: approx 20 gas per allocReq entry.
     */
    function _calculateMaxAllocationSizePerProvider(
        Types.AllocationRequest[] calldata allocReq,
        uint256 replicaSize,
        uint256 minProviders
    ) internal pure returns (uint256) {
        uint256 totalBytes = 0;
        for (uint256 i = 0; i < allocReq.length; i++) {
            totalBytes += uint256(allocReq[i].size) * replicaSize;
        }
        // ceil(a/b) == (a + b - 1) / b
        return (totalBytes + minProviders - 1) / minProviders;
    }
}
