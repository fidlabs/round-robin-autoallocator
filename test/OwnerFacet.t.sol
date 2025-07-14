// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {ErrorLib} from "../src/libraries/Errors.sol";
import {OwnerFacet} from "../src/facets/OwnerFacet.sol";
import {DiamondDeployer} from "./lib/DiamondDeployer.sol";
import {ViewFacet} from "../src/facets/ViewFacet.sol";
import {FilecoinEpochCalculator} from "../src/libraries/FilecoinEpochCalculator.sol";

contract OwnerFacetTest is Test {
    ViewFacet public viewFacet;
    OwnerFacet public ownerFacet;

    function setUp() public {
        address diamond = DiamondDeployer.deployDiamond(address(this));
        ownerFacet = OwnerFacet(diamond);
        viewFacet = ViewFacet(diamond);
    }

    function test_pauseUnpauseOwnerRevert() public {
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotOwner.selector));
        ownerFacet.pause();

        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotOwner.selector));
        ownerFacet.unpause();
    }

    function test_setCollateralPerCID() public {
        uint256 newCollateralPerCID = 1000;
        ownerFacet.setCollateralPerCID(newCollateralPerCID);
        assertEq(viewFacet.getAppConfig().collateralPerCID, newCollateralPerCID);
    }

    function test_setCollateralPerCIDRevert() public {
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotOwner.selector));
        ownerFacet.setCollateralPerCID(0);
    }

    function test_setMinRequiredStorageProviders() public {
        uint256 newMinRequiredStorageProviders = 5;
        ownerFacet.setMinRequiredStorageProviders(newMinRequiredStorageProviders);
        assertEq(viewFacet.getAppConfig().minRequiredStorageProviders, newMinRequiredStorageProviders);
    }

    function test_setMinRequiredStorageProvidersRevert() public {
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotOwner.selector));
        ownerFacet.setMinRequiredStorageProviders(0);
    }

    function test_pauseContract() public {
        ownerFacet.pause();
        assertTrue(ownerFacet.paused());

        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotOwner.selector));
        ownerFacet.unpause();
    }

    function test_unpauseContract() public {
        ownerFacet.pause();
        assertTrue(ownerFacet.paused());

        ownerFacet.unpause();
        assertFalse(ownerFacet.paused());
    }

    function test_setDataCapTermMaxDays() public {
        int64 newDataCapTermMaxDays = FilecoinEpochCalculator.TERM_MIN_IN_DAYS + 1000;
        ownerFacet.setDataCapTermMaxDays(newDataCapTermMaxDays);
        assertEq(viewFacet.getAppConfig().dataCapTermMaxDays, newDataCapTermMaxDays);
    }

    function test_setDataCapTermMaxDaysRevert() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidDataCapTermMaxDays.selector));
        ownerFacet.setDataCapTermMaxDays(FilecoinEpochCalculator.TERM_MIN_IN_DAYS - 1);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidDataCapTermMaxDays.selector));
        ownerFacet.setDataCapTermMaxDays(FilecoinEpochCalculator.FIVE_YEARS_IN_DAYS + 1);

        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.CallerIsNotOwner.selector));
        ownerFacet.setDataCapTermMaxDays(FilecoinEpochCalculator.TERM_MIN_IN_DAYS);
    }
}
