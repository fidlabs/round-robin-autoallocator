// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "../libraries/Storage.sol";
import {IFacet} from "../interfaces/IFacet.sol";

contract DevnetFacet is IFacet {
    error NotOnDevnet();

    constructor() {
        if (block.chainid != 31415926) {
            revert NotOnDevnet();
        }
    }

    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](1);
        selectors_[0] = this.setDevnetAppConfig.selector;
    }

    function setDevnetAppConfig() external {
        Storage.AppConfig storage appConfig = Storage.getAppConfig();
        appConfig.minReplicas = 1;
        appConfig.maxReplicas = 1;
        appConfig.minRequiredStorageProviders = 1;
        appConfig.collateralPerCID = 0.1 ether;
    }
}
