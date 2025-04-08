// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "./Storage.sol";
import {Errors} from "./lib/Errors.sol";

abstract contract StorageEntityPicker {
    /**
     * @param max The maximum number to return
     * @return A semi-random number between 0 and max
     */
    function _getRandomNumber(uint256 max) internal returns (uint256) {
        // two fixed entropy sources
        uint256 past1BlockHash = uint256(blockhash(block.number - 1));
        uint256 past5BlockHash = uint256(blockhash(block.number - 5));
        // drand entropy source
        // https://github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0095.md
        uint256 prevrandao = block.prevrandao;
        uint256 currentNonce = Storage.s().spPickerNonce;

        // Update nonce with multiple entropy sources
        Storage.s().spPickerNonce = uint256(
            keccak256(
                abi.encodePacked(
                    currentNonce,
                    past1BlockHash,
                    past5BlockHash,
                    prevrandao
                )
            )
        );

        // generate random number with multiple entropy sources
        uint256 rand = uint256(
            keccak256(
                abi.encodePacked(
                    past1BlockHash,
                    past5BlockHash,
                    prevrandao,
                    Storage.s().spPickerNonce
                )
            )
        ) % max;

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
    function _pickStorageProviders(
        uint numEntities
    ) internal returns (uint64[] memory) {
        address[] storage entityAddresses = Storage.s().entityAddresses;
        uint256 entityLength = entityAddresses.length;

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

            Storage.StorageEntity storage se = Storage.s().storageEntities[
                entityAddress
            ];
            // SE is active, and has at least one storage provider
            if (
                se.isActive &&
                se.storageProviders.length > 0
            ) {
                storageProviders[pickedCount] = Storage
                    .s()
                    .storageEntities[entityAddress]
                    .storageProviders[0];
                pickedCount++;
            }
        }

        if (pickedCount < numEntities) {
            revert Errors.NotEnoughActiveStorageEntities();
        }

        return storageProviders;
    }
}
