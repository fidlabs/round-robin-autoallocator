// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

library ErrorLib {
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

    // 0xafa2b48b
    error InvalidReplicaSize();

    // 0x2b3bc985
    error InsufficientCollateral(uint256);

    // 0x449e70a5
    error NotEnoughAllocationData();

    // 0xed3c247c
    error InvalidClaim();

    // 0xc9bab621
    error CollateralAlreadyClaimed();

    // 0x08ebe172
    error GetClaimsFailed();

    // 0x17076eb1
    error IncompleteProviderClaims(uint64);

    // 0xe9d8d821
    error CallerIsNotEOA();

    // 0x25a87396
    error InvalidPackageId();

    // 0x3a4735aa
    error InvalidTopLevelArray();

    // 0xccfa6de2
    error InvalidFirstElement();

    // 0x87537aa0
    error InvalidSecondElement();

    // 0xe5f19a39
    error InvalidThirdElement();
}
