// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {OwnershipFacet} from "../src/facets/OwnershipFacet.sol";
import {DiamondDeployer} from "./lib/DiamondDeployer.sol";
import {ErrorLib} from "../src/libraries/Errors.sol";
import {NotContractOwner} from "../src/libraries/LibDiamond.sol";

contract OwnerFacetTest is Test {
    OwnershipFacet public ownershipFacet;

    function setUp() public {
        address diamond = DiamondDeployer.deployDiamond(address(this));
        ownershipFacet = OwnershipFacet(diamond);
    }

    function test_transferOwnershipRevert() public {
        address newOwner = address(0x123);
        vm.expectRevert(abi.encodeWithSelector(NotContractOwner.selector, address(1), ownershipFacet.owner()));
        vm.prank(address(1));
        ownershipFacet.transferOwnership(newOwner);

        vm.expectRevert(ErrorLib.InvalidZeroAddress.selector);
        ownershipFacet.transferOwnership(address(0));
    }

    function test_transferOwnership() public {
        address newOwner = address(0x123);

        ownershipFacet.transferOwnership(newOwner);
        assertNotEq(ownershipFacet.owner(), newOwner);
        assertEq(ownershipFacet.pendingOwner(), newOwner);

        vm.prank(newOwner);
        ownershipFacet.acceptOwnership();
        assertEq(ownershipFacet.owner(), newOwner);
        assertEq(ownershipFacet.pendingOwner(), address(0));
    }
}
