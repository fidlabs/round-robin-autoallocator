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
- [Requirements](#requirements)
- [Demo](#demo)
- [Deployment](#deployment)
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

## Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Solidity](https://docs.soliditylang.org/) version 0.8.25
- Access to a Filecoin network (Devnet/Calibnet/Mainnet)
- DataCap allocation for the contract account
- Environment file (.env) with appropriate configuration

## Demo

You can view and try out the Round Robin Allocator on the Filecoin Calibration network using the Louper explorer. 
Direct link for the deployed contract: [https://louper.dev/diamond/0x71B65138aceBe6c010C366586B58BB01D5D97f4E?network=filecoinCalibration](https://louper.dev/diamond/0x71B65138aceBe6c010C366586B58BB01D5D97f4E?network=filecoinCalibration)

## Deployment

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
