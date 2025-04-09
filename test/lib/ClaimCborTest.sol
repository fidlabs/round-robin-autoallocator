// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {VerifRegTypes} from "filecoin-solidity/types/VerifRegTypes.sol";
import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";
import {CBORDecoder} from "filecoin-solidity/utils/CborDecode.sol";
import {Misc} from "filecoin-solidity/utils/Misc.sol";
import {Errors} from "filecoin-solidity/utils/Errors.sol";
import {FilecoinCBOR} from "filecoin-solidity/cbor/FilecoinCbor.sol";
import {VerifRegCBOR} from "filecoin-solidity/cbor/VerifRegCbor.sol";

library ClaimCborTest {
    using CBOR for CBOR.CBORBuffer;
    using CBORDecoder for bytes;
    using FilecoinCBOR for bytes;

    error Err();

    function deserializeGetClaimsParams(bytes memory rawData)
        internal
        pure
        returns (VerifRegTypes.GetClaimsParams memory params)
    {
        uint256 byteIdx = 0;
        uint256 len;

        (len, byteIdx) = rawData.readFixedArray(byteIdx);
        if (!(len == 2)) {
            revert Errors.InvalidArrayLength(2, len);
        }

        (params.provider, byteIdx) = rawData.readFilActorId(byteIdx);

        (len, byteIdx) = rawData.readFixedArray(byteIdx);
        params.claim_ids = new CommonTypes.FilActorId[](len);

        for (uint256 i = 0; i < len; i++) {
            (params.claim_ids[i], byteIdx) = rawData.readFilActorId(byteIdx);
        }

        return params;
    }

    function serializeGetClaimsReturn(VerifRegTypes.GetClaimsReturn memory ret) internal pure returns (bytes memory) {
        uint256 capacity = 0;
        uint256 fail_codes_len = ret.batch_info.fail_codes.length;
        uint256 claims_len = ret.claims.length;

        capacity += Misc.getPrefixSize(2);
        capacity += Misc.getPrefixSize(2);
        capacity += Misc.getPrefixSize(uint256(ret.batch_info.success_count));
        capacity += Misc.getPrefixSize(fail_codes_len);

        for (uint256 i = 0; i < fail_codes_len; i++) {
            capacity += Misc.getPrefixSize(2);
            capacity += Misc.getPrefixSize(uint256(ret.batch_info.fail_codes[i].idx));
            capacity += Misc.getPrefixSize(uint256(ret.batch_info.fail_codes[i].code));
        }
        capacity += Misc.getPrefixSize(claims_len);
        for (uint256 i = 0; i < claims_len; i++) {
            capacity += Misc.getPrefixSize(8);
            capacity += Misc.getFilActorIdSize(ret.claims[i].provider);
            capacity += Misc.getFilActorIdSize(ret.claims[i].client);
            capacity += Misc.getBytesSize(ret.claims[i].data);
            capacity += Misc.getPrefixSize(ret.claims[i].size);
            capacity += Misc.getChainEpochSize(ret.claims[i].term_min);
            capacity += Misc.getChainEpochSize(ret.claims[i].term_max);
            capacity += Misc.getChainEpochSize(ret.claims[i].term_start);
            capacity += Misc.getFilActorIdSize(ret.claims[i].sector);
        }

        CBOR.CBORBuffer memory buf = CBOR.create(capacity);
        buf.startFixedArray(2);
        buf.startFixedArray(2);
        buf.writeUInt64(uint64(ret.batch_info.success_count));
        buf.startFixedArray(uint64(fail_codes_len));
        for (uint256 i = 0; i < fail_codes_len; i++) {
            buf.startFixedArray(2);
            buf.writeUInt64(uint64(ret.batch_info.fail_codes[i].idx));
            buf.writeUInt64(uint64(ret.batch_info.fail_codes[i].code));
        }
        buf.startFixedArray(uint64(claims_len));
        for (uint256 i = 0; i < claims_len; i++) {
            buf.startFixedArray(8);
            buf.writeUInt64(CommonTypes.FilActorId.unwrap(ret.claims[i].provider));
            buf.writeUInt64(CommonTypes.FilActorId.unwrap(ret.claims[i].client));
            buf.writeBytes(ret.claims[i].data);
            buf.writeUInt64(ret.claims[i].size);
            buf.writeInt64(CommonTypes.ChainEpoch.unwrap(ret.claims[i].term_min));
            buf.writeInt64(CommonTypes.ChainEpoch.unwrap(ret.claims[i].term_max));
            buf.writeInt64(CommonTypes.ChainEpoch.unwrap(ret.claims[i].term_start));
            buf.writeUInt64(CommonTypes.FilActorId.unwrap(ret.claims[i].sector));
        }

        return buf.data();
    }
}
