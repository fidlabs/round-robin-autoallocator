// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "./Storage.sol";
import {ErrorLib} from "./Errors.sol";

library StorageEntityPicker {
    /**
     * @param max The maximum number to return
     * @return A semi-random number between 0 and max
     */
    // slither-disable-next-line weak-prng
    function _getRandomNumber(uint256 max) internal returns (uint256) {
        // two fixed entropy sources
        uint256 past1BlockHash = uint256(blockhash(block.number - 1));
        uint256 past5BlockHash = uint256(blockhash(block.number - 5));
        // drand entropy source
        // https://github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0095.md
        uint256 prevrandao = block.prevrandao;
        uint256 currentNonce = Storage.s().spPickerNonce;

        // Update nonce with multiple entropy sources
        Storage.s().spPickerNonce =
            uint256(keccak256(abi.encodePacked(currentNonce, past1BlockHash, past5BlockHash, prevrandao)));

        // generate semi-random number with multiple entropy sources
        uint256 rand = uint256(
            keccak256(abi.encodePacked(past1BlockHash, past5BlockHash, prevrandao, Storage.s().spPickerNonce))
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
    // slither-disable-next-line weak-prng
    function _pickStorageProviders(uint256 numEntities, uint256 maxSpacePerProvider)
        internal
        returns (uint64[] memory)
    {
        address[] storage entityAddresses = Storage.s().entityAddresses;
        uint256 entityLength = entityAddresses.length;

        if (entityLength < numEntities) {
            revert ErrorLib.NotEnoughStorageEntities();
        }

        // Start from a random index
        uint256 startIndex = _getRandomNumber(entityLength);
        uint64[] memory storageProviders = new uint64[](numEntities);
        uint256 pickedCount = 0;
        // Pick up to numEntities BUT do not loop over the same entity twice
        for (uint256 i = 0; pickedCount < numEntities && i < entityLength; i++) {
            uint256 index = (startIndex + i) % entityLength;
            address entityAddress = entityAddresses[index];

            Storage.StorageEntity storage se = Storage.s().storageEntities[entityAddress];

            if (!se.isActive || se.storageProviders.length == 0) {
                // If the SE is not active
                // or doesn't have at least one provider
                //  then we can skip it
                continue;
            }
            // Select one storage provider from the active storage entity that has enough space left
            for (uint256 j = 0; j < se.storageProviders.length; j++) {
                uint64 provider = se.storageProviders[j];

                if (
                    se.providerDetails[provider].isActive
                        && se.providerDetails[provider].spaceLeft >= maxSpacePerProvider
                ) {
                    storageProviders[pickedCount] = provider;
                    pickedCount++;
                    break; // Break the loop after picking one provider
                }
            }
        }

        if (pickedCount < numEntities) {
            revert ErrorLib.NotEnoughActiveStorageEntities();
        }

        return storageProviders;
    }
}
