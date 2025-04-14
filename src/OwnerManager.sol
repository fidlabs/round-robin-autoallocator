// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Storage} from "./Storage.sol";
import {Errors} from "./lib/Errors.sol";
import {Events} from "./lib/Events.sol";

/**
 * @title OwnerManager
 * @notice This contract provides functions for the owner of the RoundRobinAllocator contract.
 */
abstract contract OwnerManager is Ownable2StepUpgradeable {
    function setCollateralPerCID(uint256 collateralPerCID) external onlyOwner {
        Storage.getAppConfig().collateralPerCID = collateralPerCID;
    }

    function setMinRequiredStorageProviders(uint256 minRequiredStorageProviders) external onlyOwner {
        Storage.getAppConfig().minRequiredStorageProviders = minRequiredStorageProviders;
    }

    function emergencyCollateralRelease(uint256 packageId) external onlyOwner {
        Storage.AllocationPackage storage package = Storage.s().allocationPackages[packageId];

        if (package.client == address(0)) {
            revert Errors.InvalidPackageId();
        }
        if (package.claimed) {
            revert Errors.CollateralAlreadyClaimed();
        }
        package.claimed = true;
        uint256 amount = package.collateral;

        payable(package.client).transfer(amount);

        emit Events.CollateralReleased(msg.sender, package.client, packageId, amount);
    }
}
