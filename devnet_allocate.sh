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
echo "Sending allocation transaction..."
cast send --json --gas-limit 9000000000 --value 0.1ether --private-key $PRIVATE_KEY_TEST --rpc-url $RPC_TEST $PROXY_ADDRESS_TEST 'allocate(uint256,(bytes,uint64)[])' 1 '[(0x0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b, 2048)]' 
echo ""

# list allocations to prove its working
echo "Listing allocations..."
docker exec -it lotus lotus filplus list-allocations