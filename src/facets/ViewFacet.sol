// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {VerifRegTypes} from "filecoin-solidity/types/VerifRegTypes.sol";
import {VerifRegAPI} from "filecoin-solidity/VerifRegAPI.sol";

import {IFacet} from "../interfaces/IFacet.sol";
import {Storage} from "../libraries/Storage.sol";
import {Types} from "../libraries/Types.sol";
import {ErrorLib} from "../libraries/Errors.sol";
import {FilecoinConverter} from "../libraries/FilecoinConverter.sol";

contract ViewFacet is IFacet {
    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](5);
        selectors_[0] = this.getAllocationPackage.selector;
        selectors_[1] = this.getClientPackagesWithClaimStatus.selector;
        selectors_[2] = this.getPackageWithClaimStatus.selector;
        selectors_[3] = this.checkProviderClaims.selector;
        selectors_[4] = this.getAppConfig.selector;
    }

    function getAppConfig() external view returns (Storage.AppConfig memory appConfig) {
        appConfig = Storage.getAppConfig();
    }

    function getAllocationPackage(uint256 packageId) external view returns (Types.AllocationPackageReturn memory ret) {
        Storage.AllocationPackage storage package = Storage.s().allocationPackages[packageId];

        if (package.client == address(0)) {
            revert ErrorLib.InvalidPackageId();
        }

        ret.client = package.client;
        ret.storageProviders = package.storageProviders;
        ret.spAllocationIds = new uint64[][](package.storageProviders.length);
        for (uint256 sp = 0; sp < package.storageProviders.length; sp++) {
            uint64 provider = package.storageProviders[sp];
            ret.spAllocationIds[sp] = package.spAllocationIds[provider];
        }
        ret.claimed = package.claimed;
        ret.collateral = package.collateral;
    }

    function getPackageWithClaimStatus(uint256 packageId)
        external
        view
        returns (Types.ClientPackageWithClaimStatus memory package)
    {
        return _getPackageWithClaimStatus(packageId);
    }

    // Function to get all client packages with claim status
    function getClientPackagesWithClaimStatus(address client)
        external
        view
        returns (Types.ClientPackageWithClaimStatus[] memory packages)
    {
        packages = new Types.ClientPackageWithClaimStatus[](Storage.s().clientAllocationPackages[client].length);

        for (uint256 i = 0; i < Storage.s().clientAllocationPackages[client].length; i++) {
            packages[i] = _getPackageWithClaimStatus(Storage.s().clientAllocationPackages[client][i]);
        }

        return packages;
    }

    function _getPackageWithClaimStatus(uint256 packageId)
        internal
        view
        returns (Types.ClientPackageWithClaimStatus memory)
    {
        Types.PackageContext memory ctx;
        ctx.packageId = packageId;
        (ctx.packageInfo,) = _getPackageBasicInfo(ctx);

        return _populateProviderInfo(ctx);
    }

    function _getPackageBasicInfo(Types.PackageContext memory ctx)
        internal
        view
        returns (Types.ClientPackageWithClaimStatus memory, bool)
    {
        Storage.AllocationPackage storage p = Storage.s().allocationPackages[ctx.packageId];

        if (p.client == address(0)) {
            return (ctx.packageInfo, false);
        }

        ctx.packageInfo.packageId = ctx.packageId;
        ctx.packageInfo.client = p.client;
        ctx.packageInfo.claimed = p.claimed;
        ctx.packageInfo.collateral = p.collateral;
        return (ctx.packageInfo, true);
    }

    function _populateProviderInfo(Types.PackageContext memory ctx)
        internal
        view
        returns (Types.ClientPackageWithClaimStatus memory)
    {
        Storage.AllocationPackage storage p = Storage.s().allocationPackages[ctx.packageId];
        uint256 spCount = p.storageProviders.length;

        ctx.packageInfo.providers = new Types.StorageProviderInfo[](spCount);

        bool allComplete = true;
        for (uint256 i = 0; i < spCount; i++) {
            if (!_fillProvider(ctx, i)) {
                allComplete = false;
            }
        }

        ctx.packageInfo.canBeClaimed = allComplete && !ctx.packageInfo.claimed;
        return ctx.packageInfo;
    }

    function _fillProvider(Types.PackageContext memory ctx, uint256 idx) internal view returns (bool) {
        Storage.AllocationPackage storage p = Storage.s().allocationPackages[ctx.packageId];
        uint64 providerId = p.storageProviders[idx];
        uint64[] memory allocs = p.spAllocationIds[providerId];

        Types.StorageProviderInfo memory infoSlot = ctx.packageInfo.providers[idx];
        infoSlot.providerId = providerId;
        infoSlot.allocationIds = allocs;

        bool complete = ctx.packageInfo.claimed ? true : _checkProviderClaimStatus(providerId, allocs);
        infoSlot.claimStatusComplete = complete;
        return complete;
    }

    function _checkProviderClaimStatus(uint64 provider, uint64[] memory allocationIds) internal view returns (bool) {
        // // If package is already claimed, all SPs must have completed their claims
        // if (packageClaimed) {
        //     return true;
        // }
        try this.checkProviderClaims(provider, allocationIds) returns (bool ok) {
            return ok;
        } catch {
            return false;
        }
    }

    /**
     * @notice Check if a provider has completed all claims
     * @dev This function is external so we can use try/catch on it
     */
    function checkProviderClaims(uint64 provider, uint64[] memory allocationIds) external view returns (bool) {
        VerifRegTypes.GetClaimsParams memory params = VerifRegTypes.GetClaimsParams({
            provider: CommonTypes.FilActorId.wrap(provider),
            claim_ids: FilecoinConverter.allocationIdsToClaimIds(allocationIds)
        });

        (int256 exit_code, VerifRegTypes.GetClaimsReturn memory result) = VerifRegAPI.getClaims(params);

        if (exit_code != 0) {
            return false;
        }

        return result.batch_info.success_count == allocationIds.length;
    }
}
