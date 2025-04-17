// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {console} from "forge-std/Test.sol";
import {VerifRegTypes} from "filecoin-solidity/types/VerifRegTypes.sol";
import {StorageMock} from "./StorageMock.sol";
import {ConstantMock} from "./ConstantMock.sol";
import {Misc} from "filecoin-solidity/utils/Misc.sol";
import {ClaimCborTest} from "../lib/ClaimCborTest.sol";
import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {StorageMock} from "./StorageMock.sol";

contract VerifRegApiMock {
    error Err();

    function getStorageMock() internal pure returns (StorageMock) {
        return StorageMock(ConstantMock.getSaltMockAddress());
    }

    event DebugBytes(address indexed client, bytes data);
    event DebugAllocationRequest(address indexed client, bytes[] requests);

    // solhint-disable-next-line no-complex-fallback, payable-fallback
    fallback(bytes calldata data) external returns (bytes memory) {
        (uint256 methodNum,,,, bytes memory raw_request, uint64 target) =
            abi.decode(data, (uint64, uint256, uint64, uint64, bytes, uint64));

        if (target == 6 && methodNum == VerifRegTypes.GetClaimsMethodNum) {
            VerifRegTypes.GetClaimsParams memory params = ClaimCborTest.deserializeGetClaimsParams(raw_request);

            VerifRegTypes.Claim[] memory claims = new VerifRegTypes.Claim[](params.claim_ids.length);

            uint32 success_count = 0;

            for (uint256 c = 0; c < params.claim_ids.length; c++) {
                CommonTypes.FilActorId claim_id_f = params.claim_ids[c];
                CommonTypes.FilActorId provider_f = params.provider;

                uint64 claim_id = CommonTypes.FilActorId.unwrap(claim_id_f);
                uint64 provider = CommonTypes.FilActorId.unwrap(provider_f);

                console.log("VerifRegApiMock: claim", claim_id);

                bool isSet = getStorageMock().isAllocationProviderSet(provider, claim_id);

                if (isSet) {
                    success_count++;
                }

                claims[c] = VerifRegTypes.Claim({
                    data: hex"00",
                    provider: params.provider,
                    client: params.provider,
                    term_min: CommonTypes.ChainEpoch.wrap(0),
                    term_max: CommonTypes.ChainEpoch.wrap(0),
                    term_start: CommonTypes.ChainEpoch.wrap(0),
                    sector: params.provider,
                    size: 0
                });
            }
            bytes memory getClaimsReturnBytes = ClaimCborTest.serializeGetClaimsReturn(
                VerifRegTypes.GetClaimsReturn({
                    batch_info: CommonTypes.BatchReturn({
                        success_count: success_count,
                        fail_codes: new CommonTypes.FailCode[](0)
                    }),
                    claims: claims
                })
            );

            return abi.encode(0, Misc.CBOR_CODEC, getClaimsReturnBytes);
        }
        revert Err();
    }
}
