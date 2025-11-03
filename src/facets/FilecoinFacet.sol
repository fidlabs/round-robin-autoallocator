// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {DataCapTypes} from "filecoin-solidity/types/DataCapTypes.sol";
import {CBORDecoder} from "filecoin-solidity/utils/CborDecode.sol";
import {UtilsHandlers} from "filecoin-solidity/utils/UtilsHandlers.sol";

import {ErrorLib} from "../libraries/Errors.sol";
import {IFacet} from "../interfaces/IFacet.sol";

contract FilecoinFacet is IFacet {
    uint32 constant _FRC46_TOKEN_TYPE = 2233613279;
    address private constant _DATACAP_ADDRESS = address(0xfF00000000000000000000000000000000000007);

    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure virtual returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](1);
        selectors_[0] = this.handle_filecoin_method.selector;
    }
    /**
     * @notice The handle_filecoin_method function is a universal entry point for calls
     * coming from built-in Filecoin actors. Datacap is an FRC-46 Token. Receiving FRC46
     * tokens requires implementing a Receiver Hook:
     * https://github.com/filecoin-project/FIPs/blob/master/FRCs/frc-0046.md#receiver-hook.
     * We use handle_filecoin_method to handle the receiver hook and make sure that the token
     * sent to our contract is freshly minted Datacap and reject all other calls and transfers.
     * @param method Method number
     * @param inputCodec Codec of the payload
     * @param params Params of the call
     * @dev Reverts if caller is not a datacap contract
     * @dev Reverts if trying to send a unsupported token type
     * @dev Reverts if trying to receive invalid token
     * @dev Reverts if trying to send a unsupported token
     */
    // slither-disable-next-line naming-convention

    function handle_filecoin_method(uint64 method, uint64 inputCodec, bytes calldata params)
        external
        view
        returns (uint32 exitCode, uint64 codec, bytes memory data)
    {
        if (msg.sender != _DATACAP_ADDRESS) {
            revert ErrorLib.InvalidCaller(msg.sender, _DATACAP_ADDRESS);
        }
        CommonTypes.UniversalReceiverParams memory receiverParams =
            UtilsHandlers.handleFilecoinMethod(method, inputCodec, params);
        if (receiverParams.type_ != _FRC46_TOKEN_TYPE) {
            revert ErrorLib.UnsupportedType();
        }
        (uint256 tokenReceivedLength, uint256 byteIdx) = CBORDecoder.readFixedArray(receiverParams.payload, 0);
        if (tokenReceivedLength != 6) revert ErrorLib.InvalidTokenReceived();
        uint64 from;
        (from, byteIdx) = CBORDecoder.readUInt64(receiverParams.payload, byteIdx); // payload == FRC46TokenReceived
        if (from != CommonTypes.FilActorId.unwrap(DataCapTypes.ActorID)) {
            revert ErrorLib.UnsupportedToken();
        }
        exitCode = 0;
        codec = 0;
        data = "";
    }
}
