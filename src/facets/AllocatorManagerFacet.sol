// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "../libraries/Storage.sol";
import {Modifiers} from "../Modifiers.sol";
import {IFacet} from "../interfaces/IFacet.sol";

/**
 * @title AllocatorManager
 * @notice Manage allocators.
 * Allocators are responsible for Storage Provider creation and management.
 */
contract AllocatorManagerFacet is IFacet, Modifiers {
    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure virtual returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](3);
        selectors_[0] = this.addAllocator.selector;
        selectors_[1] = this.removeAllocator.selector;
        selectors_[2] = this.getAllocators.selector;
    }

    /**
     * @notice Add an allocator
     */
    function addAllocator(address allocator) public onlyOwner {
        Storage.s().allocators.push(allocator);
    }

    /**
     * @notice Remove an allocator
     */
    function removeAllocator(address allocator) public onlyOwner {
        address[] storage allocators = Storage.s().allocators;
        for (uint256 i = 0; i < allocators.length; i++) {
            if (allocators[i] == allocator) {
                allocators[i] = allocators[allocators.length - 1];
                allocators.pop();
                break;
            }
        }
    }

    /**
     * @notice Get all allocators
     */
    function getAllocators() public view returns (address[] memory) {
        return Storage.s().allocators;
    }
}
