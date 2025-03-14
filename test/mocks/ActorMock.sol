// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";

contract DataCapActorMock {
    error Err();

    address public constant _actor = address(0xfF00000000000000000000000000000000000007);

    fallback(bytes calldata data) external returns (bytes memory) {
        (bool success, bytes memory retData) = _actor.call(data);
        if (!success) revert Err();
        return retData;
    }
}