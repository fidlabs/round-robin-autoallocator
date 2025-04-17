// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Storage} from "./Storage.sol";
import {ErrorLib} from "./lib/Errors.sol";
import {Events} from "./lib/Events.sol";

/**
 * @title OwnerManager
 * @notice This contract provides functions for the owner of the RoundRobinAllocator contract.
 */
abstract contract OwnerManager is Ownable2StepUpgradeable, PausableUpgradeable {
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setCollateralPerCID(uint256 collateralPerCID) external onlyOwner {
        Storage.getAppConfig().collateralPerCID = collateralPerCID;
    }

    function setMinRequiredStorageProviders(uint256 minRequiredStorageProviders) external onlyOwner {
        Storage.getAppConfig().minRequiredStorageProviders = minRequiredStorageProviders;
    }

    function emergencyCollateralRelease(uint256 packageId) external onlyOwner {
        Storage.AllocationPackage storage package = Storage.s().allocationPackages[packageId];

        if (package.client == address(0)) {
            revert ErrorLib.InvalidPackageId();
        }
        if (package.claimed) {
            revert ErrorLib.CollateralAlreadyClaimed();
        }
        package.claimed = true;
        uint256 amount = package.collateral;

        emit Events.CollateralReleased(msg.sender, package.client, packageId, amount);

        payable(package.client).transfer(amount);
    }
}
