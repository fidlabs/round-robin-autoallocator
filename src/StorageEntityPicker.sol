// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {console} from "forge-std/Console.sol";

import {Storage} from "./Storage.sol";
import {Errors} from "./lib/Errors.sol";

abstract contract StorageEntityPicker {
    event NewRand(uint256 rand, uint256 max);

    /**
     * @param max The maximum number to return
     * @return A semi-random number between 0 and max
     */
    function _getRandomNumber(uint256 max) internal returns (uint256) {
        uint256 nonce = Storage.s().spPickerNonce++;

        uint256 rand = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    msg.sender,
                    nonce
                )
            )
        ) % max;

        emit NewRand(rand, max);

        return rand;
    }

    /**
     * @notice Pick storage providers from the list of storage entities
     * @dev 
     * Providers are picked in round-robin fashion, starting from a random index, until numEntities are picked.
     * Reverts when there are not enough storage entities or not enough active storage entities.
     * Storage providers list is looped over in a round-robin fashion, preventing the same provider from being picked twice.
     * 
     * @param numEntities The number of storage providers to pick
     */
    function _pickStorageProviders(uint numEntities) internal returns (uint64[] memory) {
        address[] storage entityAddresses = Storage.s().entityAddresses;
        uint256 entityLength = entityAddresses.length;

        console.log("entityLength: %d", entityLength);

        if (entityLength < numEntities) {
            revert Errors.NotEnoughStorageEntities();
        }

        // Start from a random index
        uint256 startIndex = _getRandomNumber(entityLength);

        uint64[] memory storageProviders = new uint64[](numEntities);
        uint pickedCount = 0;
        // Pick up to numEntities BUT do not loop over the same entity twice
        for (uint i = 0; pickedCount < numEntities && i < entityLength; i++) {
            uint index = (startIndex + i) % entityLength;
            address entityAddress = entityAddresses[index];

            Storage.StorageEntity storage se = Storage.s().storageEntities[entityAddress];
            // SE is active, not zeroed out, and has at least one storage provider
            if (se.owner != address(0) && se.isActive && se.storageProviders.length > 0) {
                storageProviders[pickedCount] = Storage.s().storageEntities[entityAddress].storageProviders[0];
                pickedCount++;
            }
        }

        if (pickedCount < numEntities) {
            revert Errors.NotEnoughActiveStorageEntities();
        }

        return storageProviders;
    }
}
