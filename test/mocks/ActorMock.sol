// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {console} from "forge-std/console.sol";
import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {FilAddressIdConverter} from "filecoin-solidity/utils/FilAddressIdConverter.sol";

contract ActorMock {
    error Err();

    fallback(bytes calldata data) external returns (bytes memory) {
        (uint256 methodNum,,,,, uint64 target) = abi.decode(data, (uint64, uint256, uint64, uint64, bytes, uint64));

        console.log("ActorMock: methodNum: %s, target: %s", methodNum, target);

        address _actor;
        if (target == 7) {
            _actor = FilAddressIdConverter.DATACAP_TOKEN_ACTOR;
        } else if (target == 6) {
            _actor = FilAddressIdConverter.VERIFIED_REGISTRY_ACTOR;
        } else {
            revert Err();
        }

        (bool success, bytes memory retData) = _actor.call(data);
        if (!success) revert Err();
        return retData;
    }
}
