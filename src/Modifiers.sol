// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {Storage} from "./Storage.sol";
import {Errors} from "./lib/Errors.sol";

/**
 * @notice Helper contract for shared modifiers
 */
abstract contract Modifiers is Ownable2StepUpgradeable {
    modifier onlyOwnerOrAllocator() {
        if (msg.sender != owner()) {
            bool isAlloc = false;
            Storage.AppStorage storage s = Storage.s();
            for (uint256 i = 0; i < s.allocators.length; i++) {
                if (s.allocators[i] == msg.sender) {
                    isAlloc = true;
                    break;
                }
            }
            if (!isAlloc) {
                revert Errors.CallerIsNotOwnerOrAllocator();
            }
        }
        _;
    }

    modifier onlyAllocator() {
        Storage.AppStorage storage s = Storage.s();
        bool isAlloc = false;
        for (uint256 i = 0; i < s.allocators.length; i++) {
            if (s.allocators[i] == msg.sender) {
                isAlloc = true;
                break;
            }
        }
        if (!isAlloc) {
            revert Errors.CallerIsNotAllocator();
        }
        _;
    }

    modifier onlyStorageEntity(address storageEntity) {
        if (msg.sender != storageEntity) {
            revert Errors.CallerIsNotStorageEntity();
        }
        _;
    }

    modifier onlyEOA() {
        // solhint-disable-next-line avoid-tx-origin
        if (msg.sender != tx.origin) {
            revert Errors.CallerIsNotEOA();
        }
        _;
    }
}
