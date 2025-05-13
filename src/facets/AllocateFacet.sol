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
        uint256 requiredCollateral = appConfig.collateralPerCID * allocReq.length * replicaSize;
        if (msg.value < requiredCollateral) {
            revert ErrorLib.InsufficientCollateral(requiredCollateral);
        }

        uint64[] memory providers = StorageEntityPicker._pickStorageProviders(appConfig.minRequiredStorageProviders);

        int64 termMin = 518400;
        int64 termMax = 5256000;
        int64 expiration = 114363;
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
}
