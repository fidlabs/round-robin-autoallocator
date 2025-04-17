// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

library Events {
    event AllocationCreated(
        address indexed client,
        uint64 indexed provider,
        uint256 indexed packageId,
        uint256 allocationSize,
        uint64[] allocationIds
    );
    event AllocationClaimed(
        address indexed client, uint256 indexed packageId, uint64 indexed provider, uint64[] allocationIds
    );
    event CollateralLocked(address indexed caller, uint256 indexed packageId, uint256 amount);
    event CollateralReleased(address indexed caller, address indexed client, uint256 indexed packageId, uint256 amount);
}
