// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "./libraries/Storage.sol";
import {ErrorLib} from "./libraries/Errors.sol";
import {LibDiamond} from "./libraries/LibDiamond.sol";

/**
 * @notice Helper contract for shared modifiers
 */
abstract contract Modifiers {
    modifier onlyOwnerOrAllocator() {
        if (msg.sender != LibDiamond.contractOwner()) {
            bool isAlloc = false;
            Storage.AppStorage storage s = Storage.s();
            for (uint256 i = 0; i < s.allocators.length; i++) {
                if (s.allocators[i] == msg.sender) {
                    isAlloc = true;
                    break;
                }
            }
            if (!isAlloc) {
                revert ErrorLib.CallerIsNotOwnerOrAllocator();
            }
        }
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != LibDiamond.contractOwner()) {
            revert ErrorLib.CallerIsNotOwner();
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
            revert ErrorLib.CallerIsNotAllocator();
        }
        _;
    }

    modifier onlyStorageEntity(address storageEntity) {
        if (msg.sender != storageEntity) {
            revert ErrorLib.CallerIsNotStorageEntity();
        }
        _;
    }

    modifier onlyOwnerOrStorageEntity(address storageEntity) {
        if (msg.sender != LibDiamond.contractOwner() && msg.sender != storageEntity) {
            revert ErrorLib.CallerIsNoOwnerOrStorageEntity();
        }
        _;
    }

    modifier onlyEOA() {
        // solhint-disable-next-line avoid-tx-origin
        if (msg.sender != tx.origin) {
            revert ErrorLib.CallerIsNotEOA();
        }
        _;
    }
}
