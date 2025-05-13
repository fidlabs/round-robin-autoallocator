// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

interface IFacet {
    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure returns (bytes4[] memory selectors_);
}
