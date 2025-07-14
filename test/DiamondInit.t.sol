// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {IDiamond} from "../src/interfaces/IDiamond.sol";
import {Diamond, DiamondArgs} from "../src/diamond/Diamond.sol";
import {DiamondInit} from "../src/diamond/DiamondInit.sol";
import {DiamondDeployer} from "./lib/DiamondDeployer.sol";
import {ErrorLib} from "../src/libraries/Errors.sol";

contract DiamondInitTest is Test {
    DiamondArgs public diamondArgs;
    IDiamond public diamond;

    uint256 COLLATERAL_PER_CID = DiamondDeployer.COLLATERAL_PER_CID;
    uint256 MIN_REQ_SP = DiamondDeployer.MIN_REQ_SP;
    uint256 MAX_REPLICA_SIZE = DiamondDeployer.MAX_REPLICA_SIZE;

    function _deployExpectRevert(
        bytes4 revertSelector,
        uint256 collateralPerCid,
        uint256 minReqSp,
        uint256 maxReplicaSize
    ) internal {
        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](0);
        address owner = address(this);

        DiamondInit init = new DiamondInit();
        DiamondArgs memory args = DiamondArgs({
            owner: owner,
            init: address(init),
            initCalldata: abi.encodeWithSignature(
                "init(uint256,uint256,uint256)", collateralPerCid, minReqSp, maxReplicaSize
            )
        });

        vm.expectRevert(revertSelector);
        new Diamond(cuts, args);
    }

    function test_invalidCollateralPerCid() public {
        uint256 INVALID_COLLATERAL_PER_CID = 0;

        _deployExpectRevert(
            ErrorLib.InvalidCollateralPerCID.selector, INVALID_COLLATERAL_PER_CID, MIN_REQ_SP, MAX_REPLICA_SIZE
        );
    }

    function test_tooLowMinReqSP() public {
        uint256 TOO_LOW_MIN_REQ_SP = 1;

        _deployExpectRevert(
            ErrorLib.InvalidMinRequiredStorageProviders.selector,
            COLLATERAL_PER_CID,
            TOO_LOW_MIN_REQ_SP,
            MAX_REPLICA_SIZE
        );
    }

    function test_maxReplicasMoreThanMinReqSP() public {
        _deployExpectRevert(
            ErrorLib.InvalidMinRequiredStorageProviders.selector, COLLATERAL_PER_CID, MIN_REQ_SP, MIN_REQ_SP + 1
        );
    }

    function test_maxReplicasMoreThanMinReqSPLarge() public {
        uint256 minReqSP = 1000;

        _deployExpectRevert(
            ErrorLib.InvalidMinRequiredStorageProviders.selector, COLLATERAL_PER_CID, minReqSP, minReqSP + 1
        );
    }
}
