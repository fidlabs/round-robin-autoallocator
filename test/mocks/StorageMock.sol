// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

// new StorageMock{salt:SALT_MOCK}(); // 0x3572B35A3250b0941A27D6F195F8DF7185AEcc31
bytes32 constant SALT_MOCK = 0x1718932719327103279810329817320918320918320918320930918320918321;

/**
 * @notice vm.etch mocked contract CANNOT change its storage
 * unfotunately, we need to use separate contract to store anything between calls
 * we might require storage between transfer and getClaims in DataCapApiMock
 */
contract StorageMock {
    bytes32 private constant SLOT =
        0x1234123451346234561346234561346234561346234561346234561346234561;
    uint public constant allocationIdsSlot = 0;

    struct Storage {
      mapping(uint => uint64[]) allocationIds;
    }

    function s() internal pure returns (Storage storage $) {
        assembly {
            $.slot := SLOT
        }
    }
}