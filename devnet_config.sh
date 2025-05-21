#!/bin/bash

set -euo pipefail

# load .env
if [ -f .env ]; then
    source .env
else
    echo ".env file not found. Please create one with ALLOCATOR_WALLET and CONTRACT_WALLET defined."
    exit 1
fi

# ensure .env 
if [ -z "${RPC_TEST:-}" ] || [ -z "${PRIVATE_KEY_TEST:-}" ] || [ -z "${PROXY_ADDRESS_TEST:-}" ]; then
    echo "Both RPC_TEST and PRIVATE_KEY_TEST must be set in the .env file."
    exit 1
fi

echo "Setting devnet config..."
cast send --json --gas-limit 9000000000 --private-key $PRIVATE_KEY_TEST --rpc-url $RPC_TEST $PROXY_ADDRESS_TEST "setDevnetAppConfig()" || echo "Command failed but continuing anyway"
echo "Waiting for devnet config transaction to be processed..."

