// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Storage} from "../libraries/Storage.sol";
import {IFacet} from "../interfaces/IFacet.sol";
import {Modifiers} from "../Modifiers.sol";

contract DevnetFacet is IFacet, Modifiers {
    error NotOnDevnet(uint256 chainId);

    /**
     * @notice Build-in protection against deploying this facet on mainnet or testnet.
     * 314159 - calibnet
     * 31415926 - localnet / devenet
     * 31337 - hardhat localnet
     */
    constructor() {
        if (
            block.chainid != 31415926 &&
            block.chainid != 314159 &&
            block.chainid != 31337
        ) {
            revert NotOnDevnet(block.chainid);
        }
    }

    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](1);
        selectors_[0] = this.setDevnetAppConfig.selector;
    }

    function setDevnetAppConfig() external onlyOwner {
        Storage.AppConfig storage appConfig = Storage.getAppConfig();
        appConfig.minReplicas = 1;
        appConfig.maxReplicas = 1;
        appConfig.minRequiredStorageProviders = 1;
        appConfig.collateralPerCID = 0.1 ether;
    }
}
