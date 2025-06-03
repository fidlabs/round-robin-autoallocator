// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Diamond, DiamondArgs} from "../src/diamond/Diamond.sol";
import {DiamondInit} from "../src/diamond/DiamondInit.sol";
import {IFacet} from "../src/interfaces/IFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamond} from "../src/interfaces/IDiamond.sol";

import {FacetRegistry} from "./utils/FacetRegistry.sol";

contract MainnetDeploy is FacetRegistry, Script {
    error InvalidEnv();

    function run() external {
        if (
            !vm.envExists("PRIVATE_KEY_MAINNET") || !vm.envExists("RPC_MAINNET")
                || !vm.envExists("COLLATERAL_PER_CID") || !vm.envExists("MIN_REQUIRED_STORAGE_PROVIDERS")
                || !vm.envExists("MAX_REPLICAS")
        ) {
            revert InvalidEnv();
        }

        uint256 collateralPerCID = vm.envUint("COLLATERAL_PER_CID") * 1e18;
        uint256 minRequiredStorageProviders = vm.envUint("MIN_REQUIRED_STORAGE_PROVIDERS");
        uint256 maxReplicas = vm.envUint("MAX_REPLICAS");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY_MAINNET"));

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
            initCalldata: abi.encodeWithSignature(
                "init(uint256,uint256,uint256)", collateralPerCID, minRequiredStorageProviders, maxReplicas
            )
        });

        // deploy diamond with initial cuts and init
        Diamond diamond = new Diamond(cuts, _args);

        vm.stopBroadcast();

        // Log the deployed contract address
        console.log("CONTRACT_ADDRESS:", address(diamond));
    }
}
