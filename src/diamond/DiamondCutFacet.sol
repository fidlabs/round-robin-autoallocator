// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

//******************************************************************************\
//* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
//* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
//******************************************************************************/

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IFacet} from "../interfaces/IFacet.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

contract DiamondCutFacet is IFacet, IDiamondCut {
    // get the function selectors for this facet for deployment and update scripts
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory _selectors = new bytes4[](1);
        _selectors[0] = this.diamondCut.selector;
        return _selectors;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}
