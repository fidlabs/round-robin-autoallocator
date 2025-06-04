// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

//******************************************************************************\
//* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
//* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
//*
//* Implementation of a diamond.
/**
 *
 */
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IERC165} from "../interfaces/IERC165.sol";

import {ErrorLib} from "../libraries/Errors.sol";
import {Storage} from "../libraries/Storage.sol";

// It is expected that this contract is customized if you want to deploy your diamond
// with data from a deployment script. Use the init function to initialize state variables
// of your diamond. Add parameters to the init funciton if you need to.

// Adding parameters to the `init` or other functions you add here can make a single deployed
// DiamondInit contract reusable accross upgrades, and can be used for multiple diamonds.

contract DiamondInit {
    uint256 constant MIN_REQ_SP = 2;

    // You can add parameters to this function in order to pass in
    // data to set your own state variables
    function init(uint256 collateralPerCID, uint256 minRequiredStorageProviders, uint256 maxReplicas) external {
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        // TODO: add ownable interfaceId !
        // TODO: make sure all interfaces are added

        // add your own state variables
        // EIP-2535 specifies that the `diamondCut` function takes two optional
        // arguments: address _init and bytes calldata _calldata
        // These arguments are used to execute an arbitrary function using delegatecall
        // in order to set state variables in the diamond during deployment or an upgrade
        // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface

        if (collateralPerCID == 0) {
            revert ErrorLib.InvalidCollateralPerCID();
        }
        if (minRequiredStorageProviders < MIN_REQ_SP) {
            revert ErrorLib.InvalidMinRequiredStorageProviders();
        }
        if (minRequiredStorageProviders < maxReplicas) {
            revert ErrorLib.InvalidMinRequiredStorageProviders();
        }

        Storage.AppConfig memory appConfig = Storage.AppConfig({
            minReplicas: 1,
            maxReplicas: maxReplicas,
            collateralPerCID: collateralPerCID,
            minRequiredStorageProviders: minRequiredStorageProviders,
            dataCapTermMaxDays: 1_825 // 5 years
        });

        Storage.setAppConfig(appConfig);
    }
}
