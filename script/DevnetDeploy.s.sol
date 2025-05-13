// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Diamond, DiamondArgs} from "../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../src/diamond/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/DiamondLoupeFacet.sol";
import {DiamondInit} from "../src/diamond/DiamondInit.sol";
import {IFacet} from "../src/interfaces/IFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamond} from "../src/interfaces/IDiamond.sol";

import {AllocateFacet} from "../src/facets/AllocateFacet.sol";
import {AllocatorManagerFacet} from "../src/facets/AllocatorManagerFacet.sol";
import {FilecoinFacet} from "../src/facets/FilecoinFacet.sol";
import {OwnerFacet} from "../src/facets/OwnerFacet.sol";
import {OwnershipFacet} from "../src/facets/OwnershipFacet.sol";
import {RetrieveCollateralFacet} from "../src/facets/RetrieveCollateralFacet.sol";
import {StorageEntityManagerFacet} from "../src/facets/StorageEntityManagerFacet.sol";
import {ViewFacet} from "../src/facets/ViewFacet.sol";
import {DevnetFacet} from "../src/facets/DevnetFacet.sol";

contract DeployDiamond is Script {
    error InvalidEnv();

    function run() external {
        if (!vm.envExists("PRIVATE_KEY_TEST")) {
            revert InvalidEnv();
        }

        vm.startBroadcast(vm.envUint("PRIVATE_KEY_TEST"));

        // core diamond components
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        DiamondInit diamondInit = new DiamondInit();

        // app facets
        AllocateFacet allocateFacet = new AllocateFacet();
        AllocatorManagerFacet allocatorManagerFacet = new AllocatorManagerFacet();
        FilecoinFacet filecoinFacet = new FilecoinFacet();
        OwnerFacet ownerFacet = new OwnerFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        RetrieveCollateralFacet retrieveCollateralFacet = new RetrieveCollateralFacet();
        StorageEntityManagerFacet storageEntityManagerFacet = new StorageEntityManagerFacet();
        ViewFacet viewFacet = new ViewFacet();
        DevnetFacet devnetFacet = new DevnetFacet();

        address[] memory facetAddrs = new address[](11);
        facetAddrs[0] = address(cutFacet);
        facetAddrs[1] = address(loupeFacet);
        facetAddrs[2] = address(allocateFacet);
        facetAddrs[3] = address(allocatorManagerFacet);
        facetAddrs[4] = address(filecoinFacet);
        facetAddrs[5] = address(ownerFacet);
        facetAddrs[6] = address(ownershipFacet);
        facetAddrs[7] = address(retrieveCollateralFacet);
        facetAddrs[8] = address(storageEntityManagerFacet);
        facetAddrs[9] = address(viewFacet);
        facetAddrs[10] = address(devnetFacet);

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
        // Used in devnet_init.sh
        console.log("CONTRACT_ADDRESS:", address(diamond));
    }
}
