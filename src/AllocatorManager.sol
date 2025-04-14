// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "./Storage.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/**
 * @title AllocatorManager
 * @notice Manage allocators.
 * Allocators are responsible for Storage Provider creation and management.
 */
abstract contract AllocatorManager is Ownable2StepUpgradeable {
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
