// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "../libraries/Storage.sol";

/**
 * Term Length	Seconds (≈)	    Epochs (≈)
 * 1 day	    86 400 s	    2 880 epochs
 * 1 year	    31 536 000 s	1 051 200 epochs
 * 5 years	    157 680 000 s	5 256 000 epochs
 */
library FilecoinEpochCalculator {
    int64 public constant EPOCHS_PER_DAY = 2_880;
    int64 public constant FIVE_YEARS_IN_DAYS = 1_825;

    function calcTermMax() internal view returns (int64) {
        return Storage.getAppConfig().dataCapTermMaxDays * EPOCHS_PER_DAY;
    }

    function getExpiration() internal pure returns (int64) {
        return 30 * EPOCHS_PER_DAY; // 30 days
    }
}
