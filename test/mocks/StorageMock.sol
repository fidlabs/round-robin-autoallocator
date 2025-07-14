// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

/**
 * @notice vm.etch mocked contract CANNOT change its storage
 * unfotunately, we need to use separate contract to store anything between calls
 * we might require storage between transfer and getClaims in DataCapApiMock
 */
contract StorageMock {
    bytes32 private constant SLOT = 0x1234123451346234561346234561346234561346234561346234561346234561;
    uint256 public constant allocationIdsSlot = 0;

    struct Storage {
        bool works;
        uint64 allocationId;
        mapping(uint64 => mapping(uint64 => bool)) allocationProviderIsSet;
        mapping(uint64 => mapping(uint64 => bool)) allocationProviderIsClaimed;
    }

    function s() internal pure returns (Storage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := SLOT
        }
    }

    function setAllocationProviderIsSet(uint64 providerId, uint64 allocationId, bool isSet) external {
        s().allocationProviderIsSet[allocationId][providerId] = isSet;
    }

    function isAllocationProviderSet(uint64 providerId, uint64 allocationId) external view returns (bool) {
        return s().allocationProviderIsSet[allocationId][providerId];
    }

    function getNewAllocationId() external returns (uint64) {
        s().allocationId++;
        return s().allocationId;
    }

    function setAllocationProviderClaimed(uint64 providerId, uint64 allocationId, bool isClaimed) external {
        s().allocationProviderIsClaimed[allocationId][providerId] = isClaimed;
    }

    function isAllocationProviderClaimed(uint64 providerId, uint64 allocationId) external view returns (bool) {
        return s().allocationProviderIsClaimed[allocationId][providerId];
    }
}
