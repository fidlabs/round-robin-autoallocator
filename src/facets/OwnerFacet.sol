// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Storage} from "../libraries/Storage.sol";
import {ErrorLib} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {Modifiers} from "../Modifiers.sol";
import {IFacet} from "../interfaces/IFacet.sol";

/**
 * @title OwnerManager
 * @notice This contract provides functions for the owner of the RoundRobinAllocator contract.
 */
contract OwnerFacet is IFacet, Modifiers, PausableUpgradeable {
    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](5);
        selectors_[0] = this.setCollateralPerCID.selector;
        selectors_[1] = this.setMinRequiredStorageProviders.selector;
        selectors_[2] = this.emergencyCollateralRelease.selector;
        selectors_[3] = this.pause.selector;
        selectors_[4] = this.unpause.selector;
    }

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
