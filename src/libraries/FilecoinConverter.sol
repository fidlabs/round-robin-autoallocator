// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";

library FilecoinConverter {
    function allocationIdsToClaimIds(uint64[] memory allocationIds)
        internal
        pure
        returns (CommonTypes.FilActorId[] memory claimIds)
    {
        claimIds = new CommonTypes.FilActorId[](allocationIds.length);
        for (uint256 i = 0; i < allocationIds.length; i++) {
            claimIds[i] = CommonTypes.FilActorId.wrap(allocationIds[i]);
        }
    }
}
