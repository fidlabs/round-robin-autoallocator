// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {DiamondCutFacet} from "../../src/diamond/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";

import {AllocateFacet} from "../../src/facets/AllocateFacet.sol";
import {AllocatorManagerFacet} from "../../src/facets/AllocatorManagerFacet.sol";
import {FilecoinFacet} from "../../src/facets/FilecoinFacet.sol";
import {OwnerFacet} from "../../src/facets/OwnerFacet.sol";
import {OwnershipFacet} from "../../src/facets/OwnershipFacet.sol";
import {RetrieveCollateralFacet} from "../../src/facets/RetrieveCollateralFacet.sol";
import {StorageEntityManagerFacet} from "../../src/facets/StorageEntityManagerFacet.sol";
import {ViewFacet} from "../../src/facets/ViewFacet.sol";
import {DevnetFacet} from "../../src/facets/DevnetFacet.sol";

abstract contract FacetRegistry {
    struct FacetInfo {
        string name;
        address impl;
        bool isCore;
    }

    FacetInfo[] internal facets;

    function isDevnet() internal view returns (bool) {
        return block.chainid == 31415926;
    }

    function getNonCoreFacetAddresses()
        internal
        view
        returns (address[] memory facetAddresses)
    {
        uint coreCount = 0;
        for (uint256 i = 0; i < facets.length; i++) {
            if (facets[i].isCore) {
                coreCount++;
            }
        }
        uint256 numFacets = facets.length;
        uint256 nonCoreCount = numFacets - coreCount;
        facetAddresses = new address[](nonCoreCount);
        for (uint256 i = 0; i < numFacets; i++) {
            facetAddresses[i] = facets[i].impl;
        }
    }

    function getAllFacetAddresses()
        internal
        view
        returns (address[] memory allFacets)
    {
        allFacets = new address[](facets.length);
        for (uint i = 0; i < facets.length; i++) {
            allFacets[i] = facets[i].impl;
        }
    }

    function _registerCoreFacet(string memory name, address impl) internal {
        facets.push(FacetInfo(name, impl, true));
    }

    function _registerFacet(string memory name, address impl) internal {
        facets.push(FacetInfo(name, impl, false));
    }

    function deployAndRegisterCoreFacets() internal {
        _registerCoreFacet("DiamondCutFacet", address(new DiamondCutFacet()));
        _registerCoreFacet(
            "DiamondLoupeFacet",
            address(new DiamondLoupeFacet())
        );
    }

    function deployAndRegisterAppFacets() internal {
        _registerFacet("AllocateFacet", address(new AllocateFacet()));
        _registerFacet(
            "AllocatorManagerFacet",
            address(new AllocatorManagerFacet())
        );
        _registerFacet("FilecoinFacet", address(new FilecoinFacet()));
        _registerFacet("OwnerFacet", address(new OwnerFacet()));
        _registerFacet("OwnershipFacet", address(new OwnershipFacet()));
        _registerFacet(
            "RetrieveCollateralFacet",
            address(new RetrieveCollateralFacet())
        );
        _registerFacet(
            "StorageEntityManagerFacet",
            address(new StorageEntityManagerFacet())
        );
        _registerFacet("ViewFacet", address(new ViewFacet()));
        if (isDevnet()) {
            _registerFacet("DevnetFacet", address(new DevnetFacet()));
        }
    }
}
