// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {DiamondCutFacet} from "../../src/diamond/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";
import {DiamondInit} from "../../src/diamond/DiamondInit.sol";

import {IFacet} from "../../src/interfaces/IFacet.sol";
import {AllocateFacet} from "../../src/facets/AllocateFacet.sol";
import {AllocatorManagerFacet} from "../../src/facets/AllocatorManagerFacet.sol";
import {FilecoinFacet} from "../../src/facets/FilecoinFacet.sol";
import {OwnerFacet} from "../../src/facets/OwnerFacet.sol";
import {OwnershipFacet} from "../../src/facets/OwnershipFacet.sol";
import {RetrieveCollateralFacet} from "../../src/facets/RetrieveCollateralFacet.sol";
import {StorageEntityManagerFacet} from "../../src/facets/StorageEntityManagerFacet.sol";
import {ViewFacet} from "../../src/facets/ViewFacet.sol";
import {DevnetFacet} from "../../src/facets/DevnetFacet.sol";

import {IDiamond} from "../../src/interfaces/IDiamond.sol";
import {Diamond, DiamondArgs} from "../../src/diamond/Diamond.sol";

library DiamondDeployer {
    uint256 public constant MIN_REQ_SP = 2;
    uint256 public constant MAX_REPLICA_SIZE = 2;
    uint256 public constant COLLATERAL_PER_CID = 0.1 ether; // 0.1 FIL

    enum Action {
        Add,
        Replace
    }

    struct FacetInfo {
        bytes4[] selectors;
        address impl;
        Action action;
    }

    bytes32 constant STORAGE_POSITION = keccak256("test.lib:DiamondDeployer");

    struct DS {
        FacetInfo[] baseFacets;
        bool initialized;
    }

    function ds() internal pure returns (DS storage s) {
        bytes32 pos = STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            s.slot := pos
        }
    }

    function _init() internal {
        DS storage s = ds();
        if (s.initialized) return;
        s.initialized = true;

        _pushFacet(s, new DiamondCutFacet(), Action.Add);
        _pushFacet(s, new DiamondLoupeFacet(), Action.Add);
        _pushFacet(s, new AllocateFacet(), Action.Add);
        _pushFacet(s, new AllocatorManagerFacet(), Action.Add);
        _pushFacet(s, new FilecoinFacet(), Action.Add);
        _pushFacet(s, new OwnerFacet(), Action.Add);
        _pushFacet(s, new OwnershipFacet(), Action.Add);
        _pushFacet(s, new RetrieveCollateralFacet(), Action.Add);
        _pushFacet(s, new StorageEntityManagerFacet(), Action.Add);
        _pushFacet(s, new ViewFacet(), Action.Add);

        // Devnet/Helper Facets
        _pushFacet(s, new DevnetFacet(), Action.Add);
    }

    function _pushFacet(DS storage s, IFacet _facet, Action action) private {
        bytes4[] memory selectors = _facet.selectors();
        address impl = address(_facet);
        s.baseFacets.push(FacetInfo({selectors: selectors, impl: impl, action: action}));
    }

    function deployDiamond(address owner) internal returns (address diamond) {
        _init();

        diamond = _deploy(owner);
    }

    function deployDiamondWithReplace(address owner, IFacet[] memory replaceFacets)
        internal
        returns (address diamond)
    {
        _init();
        _replaceFacets(replaceFacets);

        diamond = _deploy(owner);
    }

    function deployDiamondWithExtraFacets(address owner, IFacet[] memory extraFacets)
        internal
        returns (address diamond)
    {
        _init();

        DS storage s = ds();
        for (uint256 i = 0; i < extraFacets.length; i++) {
            IFacet f = extraFacets[i];
            _pushFacet(s, f, Action.Add);
        }

        diamond = _deploy(owner);
    }

    function _deploy(address owner) private returns (address diamond) {
        DiamondInit init = new DiamondInit();
        DiamondArgs memory args = DiamondArgs({
            owner: owner,
            init: address(init),
            initCalldata: abi.encodeWithSignature(
                "init(uint256,uint256,uint256)", COLLATERAL_PER_CID, MIN_REQ_SP, MAX_REPLICA_SIZE
            )
        });

        diamond = address(new Diamond(_buildCuts(), args));
    }

    function _buildCuts() private view returns (IDiamond.FacetCut[] memory cuts) {
        DS storage s = ds();
        uint256 total = s.baseFacets.length;
        cuts = new IDiamond.FacetCut[](total);

        for (uint256 i = 0; i < total; i++) {
            FacetInfo storage f = s.baseFacets[i];
            cuts[i] = IDiamond.FacetCut({
                facetAddress: f.impl,
                action: f.action == Action.Add ? IDiamond.FacetCutAction.Add : IDiamond.FacetCutAction.Replace,
                functionSelectors: f.selectors
            });
        }
    }

    /**
     * @dev Replace facets and its selectors entirely.
     * Used to replace facets with the same facet wrapper but with different implementation.
     * e.g. to omit onlyEOA modifier.
     */
    function _replaceFacets(IFacet[] memory replaceFacets) internal {
        DS storage s = ds();

        for (uint256 i = 0; i < replaceFacets.length; i++) {
            IFacet f = replaceFacets[i];
            bytes4[] memory selectors = f.selectors();
            address impl = address(f);
            Action action = Action.Add;

            for (uint256 j = 0; j < s.baseFacets.length; j++) {
                FacetInfo storage existingFacet = s.baseFacets[j];
                bool selectorFound = false;

                // Check if any selector matches between the two arrays, if so, replace the facet
                for (uint256 k = 0; k < selectors.length && !selectorFound; k++) {
                    for (uint256 m = 0; m < existingFacet.selectors.length && !selectorFound; m++) {
                        if (existingFacet.selectors[m] == selectors[k]) {
                            // selector already exists, replace it
                            existingFacet.impl = impl;
                            existingFacet.action = action;
                            existingFacet.selectors = selectors;
                            selectorFound = true;
                        }
                    }
                }
            }
        }
    }

    function reset() internal {
        DS storage s = ds();
        delete s.baseFacets;
        s.initialized = false;
    }
}
