// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {StorageMock} from "./StorageMock.sol";

library ConstantMock {
    address public constant FIXED_DEPLOYER = 0x000000000000000000000000000000000000dEaD;

    bytes32 public constant SALT_MOCK = 0x1718932719327103279810329817320918320918320918320930918320918321;

    function getSaltMockAddress() internal pure returns (address) {
        return computeCreate2Address(FIXED_DEPLOYER, SALT_MOCK, type(StorageMock).creationCode);
    }

    function computeCreate2Address(address deployer, bytes32 salt, bytes memory bytecode)
        internal
        pure
        returns (address)
    {
        bytes32 bytecodeHash = keccak256(bytecode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash));
        return address(uint160(uint256(hash)));
    }
}
