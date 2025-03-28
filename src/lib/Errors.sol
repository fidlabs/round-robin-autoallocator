// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

library Errors {
    // @dev Error thrown when renounceOwnership is called
    // 0x2fab92ca
    error OwnershipCannotBeRenounced();

    /// @dev Thrown if trying to receive ussuported token type
    // 0xc6de466a
    error UnsupportedType();

    /// @dev Thrown if trying to receive invalid token
    // 0x6d5f86d5
    error InvalidTokenReceived();

    /// @dev Thrown if trying to receive unsupported token
    // 0x6a172882
    error UnsupportedToken();

    /// @dev Thrown if caller is invalid
    // 0x6a172882
    error InvalidCaller(address caller, address expectedCaller);

    /// @dev Thrown if data cap transfer failed
    // 0x728dfdbb
    error DataCapTransferFailed();

    /// @dev Thrown if allocation request is invalid
    // 0x46ac3f35
    error InvalidAllocationRequest();

    // 0xc5271dad
    error AllocationFailed();

    // 0xd0d9169a
    error StorageEntityAlreadyExists();

    // 0x87afb878
    error StorageProviderAlreadyUsed();

    // 0xe300f557
    error CallerIsNotAllocator();

    // 0xac57b77e
    error CallerIsNotStorageEntity();

    // 0xe9211a00
    error CallerIsNotOwnerOrAllocator();

    // 0xa6d5c1f0
    error StorageEntityDoesNotExist();

    // 0x0e7d9cac
    error NotEnoughActiveStorageEntities();

    // 0x391fe496
    error NotEnoughStorageEntities();
}
