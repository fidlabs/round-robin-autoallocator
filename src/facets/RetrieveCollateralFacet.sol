// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {VerifRegTypes} from "filecoin-solidity/types/VerifRegTypes.sol";
import {VerifRegAPI} from "filecoin-solidity/VerifRegAPI.sol";

import {IFacet} from "../interfaces/IFacet.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {Storage} from "../libraries/Storage.sol";
import {ErrorLib} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {FilecoinConverter} from "../libraries/FilecoinConverter.sol";

contract RetrieveCollateralFacet is IFacet, PausableUpgradeable {
    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](1);
        selectors_[0] = this.retrieveCollateral.selector;
    }

    function retrieveCollateral(uint256 packageId) public whenNotPaused {
        Storage.AllocationPackage storage package = Storage.s().allocationPackages[packageId];

        if (package.client == address(0) || package.storageProviders.length == 0) {
            revert ErrorLib.InvalidClaim();
        }
        if (package.claimed) {
            revert ErrorLib.CollateralAlreadyClaimed();
        }
        package.claimed = true;

        for (uint256 sp = 0; sp < package.storageProviders.length; sp++) {
            uint64 provider = package.storageProviders[sp];
            uint64[] memory allocationIds = package.spAllocationIds[provider];

            VerifRegTypes.GetClaimsParams memory params = VerifRegTypes.GetClaimsParams({
                provider: CommonTypes.FilActorId.wrap(provider),
                claim_ids: FilecoinConverter.allocationIdsToClaimIds(allocationIds)
            });

            (int256 exit_code, VerifRegTypes.GetClaimsReturn memory result) = VerifRegAPI.getClaims(params);

            if (exit_code != 0) {
                revert ErrorLib.GetClaimsFailed();
            }

            // https://github.com/filecoin-project/builtin-actors/blob/5aad41bfa29d8eab78f91eb5c82a03466c6062d2/actors/verifreg/src/lib.rs#L505-L506
            if (result.batch_info.success_count != allocationIds.length) {
                revert ErrorLib.IncompleteProviderClaims(provider);
            }

            emit Events.AllocationClaimed(package.client, packageId, provider, allocationIds);
        }

        emit Events.CollateralReleased(msg.sender, package.client, packageId, package.collateral);

        payable(package.client).transfer(package.collateral);
    }
}
