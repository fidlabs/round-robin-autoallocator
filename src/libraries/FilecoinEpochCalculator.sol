// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "../libraries/Storage.sol";
import {ErrorLib} from "../libraries/Errors.sol";

/**
 * Term Length	Seconds (≈)	    Epochs (≈)
 * 1 day	    86 400 s	    2 880 epochs
 * 1 year	    31 536 000 s	1 051 200 epochs
 * 5 years	    157 680 000 s	5 256 000 epochs
 */
library FilecoinEpochCalculator {
    int64 public constant EPOCHS_PER_DAY = 2_880;
    int64 public constant TERM_MIN = 518_400; // 180 days
    int64 public constant FIVE_YEARS_IN_DAYS = 1_825;
    uint256 public constant EXPIRATION = 86_400; // 30 days

    /**
     * @dev Relative to current epoch
     */
    function getTermMin() internal pure returns (int64) {
        // 180 days, required by the Filecoin network
        return TERM_MIN;
    }

    /**
     * @dev Relative to current epoch
     */
    function calcTermMax() internal view returns (int64) {
        return Storage.getAppConfig().dataCapTermMaxDays * EPOCHS_PER_DAY;
    }

    /**
     * @dev Absolute to current epoch
     */
    function getExpiration() internal view returns (int64) {
        // uint256 rawExpiration = block.number + uint256(uint64(EXPIRATION));
        uint256 rawExpiration = block.number + EXPIRATION;
        if (rawExpiration > uint256(int256(type(int64).max))) {
            revert ErrorLib.Overflow();
        }
        return int64(int256(rawExpiration));
    }
}
