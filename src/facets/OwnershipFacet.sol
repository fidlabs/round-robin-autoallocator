// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IFacet} from "../interfaces/IFacet.sol";
import {ErrorLib} from "../libraries/Errors.sol";

contract OwnershipFacet is IFacet, IERC173 {
    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure virtual override returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](4);
        selectors_[0] = this.transferOwnership.selector;
        selectors_[1] = this.owner.selector;
        selectors_[2] = this.acceptOwnership.selector;
        selectors_[3] = this.pendingOwner.selector;
    }

    function transferOwnership(address newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        if (newOwner == address(0)) {
            revert ErrorLib.InvalidZeroAddress();
        }
        LibDiamond.transferOwnership(newOwner);
    }

    function acceptOwnership() external {
        LibDiamond.acceptOwnership();
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    function pendingOwner() external view returns (address) {
        return LibDiamond.pendingOwner();
    }
}
