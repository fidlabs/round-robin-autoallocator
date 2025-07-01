# Round Robin AutoAllocator

Auto Allocator that assigns data cap to each client and semi-random storage providers (SPs) in a round-robin fashion on the Filecoin network.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
  - [Core Components](#core-components)
  - [Facets](#facets)
  - [Key Libraries](#key-libraries)
- [Mechanism](#mechanism)
  - [Setup Phase](#setup-phase)
  - [Allocation Phase](#allocation-phase)
  - [Claim Phase](#claim-phase)
  - [Collateral Retrieval](#collateral-retrieval)
- [Demo](#demo)
- [Usage](#usage)
   - [Flow overview](#flow-overview)
   - [Prepare CAR files](#prepare-car-files)
   - [Prepare input data for allocation](#prepare-input-data-for-allocation)
   - [Prepare ETH wallet with sufficient balance](#prepare-eth-wallet-with-sufficient-balance)
   - [Getting current collateral value per CID](#getting-current-collateral-value-per-cid)
   - [Create Allocation Package (Transfer Data Cap for multiple files)](#create-allocation-package-transfer-data-cap-for-multiple-files)
      - [Example of using the Frontend app](#example-of-using-the-frontend-app)
      - [Example of using the CSV file with `cast` command](#example-of-using-the-csv-file-with-cast-command)
   - [Monitoring Allocation Packages](#monitoring-allocation-packages)
   - [Retrieving Collateral](#retrieving-collateral)
- [Deployment](#deployment)
  - [Requirements](#requirements)
  - [Environment Setup](#environment-setup)
   - [Deployment](#deployment-1)
      - [Calibnet Deployment](#calibnet-deployment)
      - [Mainnet Deployment](#mainnet-deployment)
   - [Initial Setup](#initial-setup)

## Overview

Round Robin Allocator is a smart contract system for the Filecoin network that enables fair and efficient allocation of data cap across multiple storage providers. It automates the process of granting data cap and selects storage providers in a round-robin fashion, ensuring fair distribution of storage deals while maintaining security through a collateral system.

The contract automatically handles the complex process of encoding allocation requests in CBOR format and interacting with Filecoin's built-in actors (VerifReg, DataCap) to manage allocations and claims.

## Architecture

The project utilizes the Diamond pattern ([EIP-2535](https://eips.ethereum.org/EIPS/eip-2535)) for upgradeability and modularity, with the following components:

### Core Components

1. **Diamond Contract**: Central contract that delegates calls to various facets
2. **Storage Library**: Central storage for all facets, using namespaced storage patterns
3. **Facets**: Specialized modules for different functionalities

### Facets

- **AllocateFacet**: Handles allocation of data cap to storage providers
- **RetrieveCollateralFacet**: Manages collateral retrieval after successful claims
- **StorageEntityManagerFacet**: Manages storage entities and their providers
- **AllocatorManagerFacet**: Manages allocators who can create storage entities
- **OwnerFacet**: Administrative functions for the contract owner
- **OwnershipFacet**: Ownership management (transfer, accept)
- **FilecoinFacet**: Handles Filecoin-specific methods (FRC-46 token receiver)
- **ViewFacet**: Read-only functions to view contract state

### Key Libraries

- **AllocationRequestCbor**: CBOR encoding for allocation requests
- **AllocationResponseCbor**: CBOR decoding for allocation responses
- **StorageEntityPicker**: Logic for fair selection of storage providers
- **FilecoinEpochCalculator**: Utility for Filecoin-specific time calculations
- **Storage**: Central storage structure and access methods

## Mechanism

The Round Robin Allocator works through a sequence of operations:

1. **Setup Phase**:
   - Contract owner or allocators register storage entities with their storage providers
   - Each storage entity can manage multiple storage providers
   - Storage entities can be activated or deactivated

2. **Allocation Phase**:
   - Clients submit allocation requests with data CIDs and sizes
   - Client provides collateral for each CID × replicas
   - Contract selects storage providers in a semi-random round-robin fashion
   - Data cap is transferred to the VerifReg actor with provider-specific CBOR payloads
   - All allocations from a single request are bundled into an "Allocation Package"
   - The Allocation Package tracks allocation IDs per storage provider and serves as the unit for claiming collateral

3. **Claim Phase**:
   - Storage providers claim the allocations by storing the data
   - Claims are verified through the VerifReg actor
   - Once all providers have claimed their allocations, the client can retrieve their collateral

4. **Collateral Retrieval**:
   - Client calls `retrieveCollateral` to recover their deposit
   - Contract verifies all claims are completed before releasing funds
   - In emergency cases, the owner can force-release collateral

The semi-random selection works by starting from a random index in the storage entities list and picking providers in a round-robin fashion, ensuring that:
- Each CID is only replicated once per provider
- Allocations are distributed fairly across all active providers

## Demo

You can view and try out the Round Robin Allocator on the Filecoin Calibration network using the Louper explorer. 

Direct link for the deployed contract: [https://louper.dev/diamond/0x71B65138aceBe6c010C366586B58BB01D5D97f4E?network=filecoinCalibration](https://louper.dev/diamond/0x71B65138aceBe6c010C366586B58BB01D5D97f4E?network=filecoinCalibration)

Demo Staging Frontend: [https://round-robin.staging.allocator.tech](https://round-robin.staging.allocator.tech)

Video of the demo Frontend: [YouTube Video](https://youtu.be/czBpO_WaVXA)


## Usage

### Flow overview:

1. **Prepare CAR files**
2. **Prepare input data for allocation**: Prepare `CommCID` and `Data Size` for each file.
3. **Call `allocate` contract function**
4. **Provide files to storage providers**: SPs will store the data and claim their allocations.
5. **Retrieve collateral**: After all claims are verified, call `retrieveCollateral` to get your collateral back.


### Prepare CAR files

Use CAR file preparation tools (e.g. Singularity, lotus,  etc.) to create CAR files from your data.

### Prepare input data for allocation

To transfer data cap, for each file, you need to prepare the following:
- **CommCID**: The CommP content identifier for the data you want to allocate, in HEX format
   - Example: `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`
- **Data Size**: The padded size of the data in bytes
   - Example: `2048`
   
To prepare HEX format of CommP, you can use the following docker image: `mmach/car-processor:0.1.0`

This image will require directory with your CAR files to be mounted as a volume.

Output will be created in form of CSV file in the same directory named `output.csv` with the following columns: `CommPCID_InHex,DataSizeInBytes` without header.

Example docker image usage:
```bash
docker run --rm -it -v -v $(pwd)/cars:/data mmach/car-processor:0.1.0
```

### Prepare ETH wallet with sufficient balance

To interact with the Round Robin AutoAllocator contract, you need an Ethereum wallet with sufficient balance to cover gas fees and collateral. You can use tools like [MetaMask](https://metamask.io/) (frontend) or [Foundry](https://book.getfoundry.sh/getting-started/installation) (CLI) to manage your wallet.

### Getting current collateral value per CID

The Easiest way to get current collateral value per CID is to use contract Frontend app where this information is displayed.

Alternatively, you can use the Louper explorer app (or CLI) to invoke the `getAppConfig` function of the contract (in read tab, choose ViewFacet [here](https://louper.dev/diamond/0x71B65138aceBe6c010C366586B58BB01D5D97f4E?network=filecoinCalibration#read)). This function returns current contract config including the collateral value per CID.

### Create Allocation Package (Transfer Data Cap for multiple files)

To create allocation package and transfer Data Cap, you can either:
- Upload the CSV directly in the frontend demo application (refer to the video in demo section)
- Use the CSV content and invoke `allocate` function through command line e.g. using [Foundry](https://book.getfoundry.sh/getting-started/installation) `cast` command to interact with the contract

#### Example of using the Frontend app

1. Open the [Round Robin Allocator Frontend](https://round-robin.staging.allocator.tech).
2. Connect your Ethereum wallet (e.g. MetaMask).
3. Upload CSV file with your prepared data.
4. Specify the number of replicas you want to allocate.
5. Click "Allocate" to send the transaction to the contract.


#### Example of using the CSV file with `cast` command

1. Format CSV content into the required format for the `allocate` function.
   - params: ***replicaAmount, [(CommPCIDinHex, DataPaddedSize)]***
2. Prepare private key and RPC URL in your environment variables or directly in the command.
3. Calculate collateral value based on the number of CIDs and replicas.
3. Use the following command to send the allocation request:

```bash
cast send --json --value 0.1ether --gas-limit 9000000000 --private-key $(PRIVATE_KEY) --rpc-url $(RPC_URL) $(DIAMOND_CONTRACT_ADDRESS) 'allocate(uint256,(bytes,uint64)[])' 1 '[(0x0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b, 2048)]' 
```

### Monitoring Allocation Packages

The Easiest way to monitor your allocation packages is through the Frontend app, where you can connect your wallet and view your allocations.

Alternatively, you can use the Louper explorer to check your allocation packages by invoking the `getClientPackagesWithClaimStatus` function (in read tab, choose ViewFacet [here](https://louper.dev/diamond/0x71B65138aceBe6c010C366586B58BB01D5D97f4E?network=filecoinCalibration#read)). This function will return all allocation packages associated with your wallet address, along with their claim status.

### Retrieving Collateral

Collateral can be retrieved after all storage providers have successfully claimed their allocations. 

You can view the status of your allocation packages and their claims using the Louper explorer or the Frontend app.

The Frontend app will let you call `retrieveCollateral` function directly when conditions are met.

In the Louper explorer, you can invoke the `retrieveCollateral` function (in write tab, choose RetrieveCollateralFacet [here](https://louper.dev/diamond/0x71B65138aceBe6c010C366586B58BB01D5D97f4E?network=filecoinCalibration#write)) to retrieve your collateral.

## Deployment

### Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Solidity](https://docs.soliditylang.org/) version 0.8.25
- Access to a Filecoin network (Devnet/Calibnet/Mainnet)
- DataCap allocation for the contract account
- Environment file (.env) with appropriate configuration

### Environment Setup

Copy the `.env.example` file to `.env` and fill in the required values:

```
# Network RPC URLs
RPC_TEST=http://127.0.0.1:1234/rpc/v1
RPC_CALIBNET=https://filecoin-calibration.chainup.net/rpc/v1
RPC_MAINNET=https://api.node.glif.io/rpc/v1

# Private keys
PRIVATE_KEY_TEST=<your_private_key>
PRIVATE_KEY_CALIBNET=<your_private_key>
PRIVATE_KEY_MAINNET=<your_private_key>

# Contract addresses (will be filled after deployment)
PROXY_ADDRESS_TEST=
PROXY_ADDRESS_CALIBNET=
PROXY_ADDRESS_MAINNET=

# For Mainnet deployment
COLLATERAL_PER_CID=100000000000000000 # 0.1 FIL
MIN_REQUIRED_STORAGE_PROVIDERS=2
MAX_REPLICAS=3

# For Devnet bash deploy scripts
MY_FIL_WALLET=t410...
MY_ETH_WALLET=0xEB...
```

### Deployment

Deployment command will:
- Clean and build the project
- Deploy the Diamond contract with all facets
- Initialize the contract with default parameters
- Output the contract address
- Verify the contract on Calibnet using `calibnet_verify.sh`

#### Calibnet Deployment

```bash
make calibnet_deploy
```

#### Mainnet Deployment

Before proceeding with mainnet deployment, ensure you have:
- Sufficient funds for deployment and gas fees
- A secure private key
- Properly configured environment variables
- Thoroughly tested on Calibnet

Ensure your .env file contains the following variables with appropriate values:

```
RPC_MAINNET=https://api.node.glif.io/rpc/v1
PRIVATE_KEY_MAINNET=<your_secure_private_key>
COLLATERAL_PER_CID=<amount_in_FIL>
MIN_REQUIRED_STORAGE_PROVIDERS=<minimum_number>
MAX_REPLICAS=<maximum_replicas>
```

**Deploy the contract to mainnet:**

```bash
make mainnet_deploy
```

### Initial Setup

First, make sure you have `PROXY_ADDRESS_MAINNET` set in your `.env` file after deployment. This address will be used to interact with the contract.

Then, source your environment variables:

```bash
source .env
```

#### Add allocators (if needed):

*Calibnet Example:*
```bash
cast send --json --gas-limit 9000000000 --private-key $PRIVATE_KEY_CALIBNET --rpc-url $RPC_CALIBNET $PROXY_ADDRESS_CALIBNET "addAllocator(address)" <ALLOCATOR_ADDRESS>
```

*Mainnet Example:*
```bash
cast send --json --gas-limit 9000000000 --private-key $PRIVATE_KEY_MAINNET --rpc-url $RPC_MAINNET $PROXY_ADDRESS_MAINNET "addAllocator(address)" <ALLOCATOR_ADDRESS>
```

#### Create storage entities:

*Calibnet Example:*
```bash
cast send --json --gas-limit 9000000000 --private-key $PRIVATE_KEY_CALIBNET --rpc-url $RPC_CALIBNET $PROXY_ADDRESS_CALIBNET "createStorageEntity(address,uint64[])" <ENTITY_OWNER_ADDRESS> "[<PROVIDER_ID>]"
```

*Mainnet Example:*
```bash
cast send --json --gas-limit 9000000000 --private-key $PRIVATE_KEY_MAINNET --rpc-url $RPC_MAINNET $PROXY_ADDRESS_MAINNET "createStorageEntity(address,uint64[])" <ENTITY_OWNER_ADDRESS> "[<PROVIDER_ID>]"
```

Repeat this step for all required storage entities and their providers.
