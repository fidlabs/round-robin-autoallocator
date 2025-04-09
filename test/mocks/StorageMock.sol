// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {console} from "forge-std/console.sol";

bytes32 constant SALT_MOCK = 0x1718932719327103279810329817320918320918320918320930918320918321;

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
        mapping(uint64 => mapping(uint64 => bool)) allocationProviderIsSet;
    }

    function s() internal pure returns (Storage storage $) {
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
}
