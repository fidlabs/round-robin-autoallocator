// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Diamond, DiamondArgs} from "../src/diamond/Diamond.sol";
import {DiamondInit} from "../src/diamond/DiamondInit.sol";
import {IFacet} from "../src/interfaces/IFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamond} from "../src/interfaces/IDiamond.sol";

import {FacetRegistry} from "./utils/FacetRegistry.sol";

contract CalibnetDeploy is FacetRegistry, Script {
    error InvalidEnv();

    function run() external {
        if (!vm.envExists("PRIVATE_KEY_CALIBNET")) {
            revert InvalidEnv();
        }

        vm.startBroadcast(vm.envUint("PRIVATE_KEY_CALIBNET"));

        // core diamond init
        DiamondInit diamondInit = new DiamondInit();

        // core diamond facets
        deployAndRegisterCoreFacets();

        // app facets
        deployAndRegisterAppFacets();

        address[] memory facetAddrs = getAllFacetAddresses();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](facetAddrs.length);
        for (uint256 i = 0; i < facetAddrs.length; i++) {
            cuts[i] = IDiamond.FacetCut({
                facetAddress: facetAddrs[i],
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: IFacet(facetAddrs[i]).selectors()
            });
        }

        DiamondArgs memory _args = DiamondArgs({
            owner: msg.sender,
            init: address(diamondInit),
            initCalldata: abi.encodeWithSignature("init(uint256,uint256,uint256)", 0.1 ether, 2, 2)
        });

        // deploy diamond with initial cuts and init
        Diamond diamond = new Diamond(cuts, _args);

        vm.stopBroadcast();

        // Log the deployed contract address
        console.log("Calibnet Diamond deployed");
        console.log("CONTRACT_ADDRESS:", address(diamond));
    }
}
