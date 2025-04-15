#!/bin/bash

set -euo pipefail

# load .env
if [ -f .env ]; then
    source .env
else
    echo ".env file not found."
    exit 1
fi

# Create allocator wallet
ALLOCATOR_WALLET=$(docker exec -ti lotus lotus wallet new | tr -d '\r')
echo "Allocator Wallet: $ALLOCATOR_WALLET"

# Retrieve Filecoin address from PROXY_ADDRESS_TEST
FIL_ADDRESS=$(docker exec -ti lotus lotus evm stat "$PROXY_ADDRESS_TEST" | awk '/Filecoin address:/{print $3}' | tr -d '\r')
CONTRACT_WALLET="$FIL_ADDRESS"
export CONTRACT_WALLET
echo "Contract Wallet set to: $CONTRACT_WALLET"

# Ensure required variables are set
if [ -z "${ALLOCATOR_WALLET:-}" ] || [ -z "${CONTRACT_WALLET:-}" ]; then
    echo "Both ALLOCATOR_WALLET and CONTRACT_WALLET must be set in the .env file."
    exit 1
fi

echo "Allocator Wallet: $ALLOCATOR_WALLET"
echo "Client Wallet: $CONTRACT_WALLET"

echo "Sending funds to allocator wallet..."
docker exec -ti lotus lotus send "$ALLOCATOR_WALLET" 10000

echo "Adding verifier..."
docker exec -i lotus lotus-shed verifreg add-verifier t0100 "$ALLOCATOR_WALLET" 99999999999

# Retrieve the highest transaction ID from the multisig wallet
LATEST_TX_ID=$(docker exec -i lotus lotus msig inspect f080 | \
    awk '/^Transactions:/{flag=1; next} flag && /^[0-9]+/{print $1}' | sort -nr | head -n1)

echo "Latest Transaction ID: $LATEST_TX_ID"
echo "Approving transaction..."
if [ -n "$LATEST_TX_ID" ]; then
    echo "Approving transaction ID: $LATEST_TX_ID"
    docker exec -i lotus lotus msig approve --from t0101 f080 "$LATEST_TX_ID"
else
    echo "No pending transactions to approve."
fi

NOTARIES=$(docker exec -i lotus lotus filplus list-notaries)
echo "Notaries List:"
echo "$NOTARIES"

echo "Granting datacap to contract..."      
docker exec -ti lotus lotus filplus grant-datacap --from "$ALLOCATOR_WALLET" "$CONTRACT_WALLET" 99999999999

echo "Checking contract datacap..."
docker exec -ti lotus lotus filplus check-client-datacap "$CONTRACT_WALLET"

