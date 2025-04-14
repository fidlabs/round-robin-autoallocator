#!/bin/bash

set -euo pipefail

# load .env
if [ -f .env ]; then
    source .env
else
    echo ".env file not found."
    exit 1
fi

echo "Copying car file to boost container volume..."
# TODO: fix this dependency, maybe submodule boost repo
cp $PWD/../boost/z_notes/bafykbzacec432ygday37lj2tvl3e7wl7ij46dko7cbmlndeghx6lhjkluqzhg.car  $PWD/../boost/docker/devnet/data/sample/bafykbzacec432ygday37lj2tvl3e7wl7ij46dko7cbmlndeghx6lhjkluqzhg.car

# list allocations to prove its working
echo "Listing allocations..."
ALLOCATION_ID=$(docker exec -it lotus lotus filplus list-allocations | awk 'NR>1 {id=$1} END {print id}')
echo "Last Allocation ID: $ALLOCATION_ID"

echo "Contract address: $PROXY_ADDRESS_TEST"
CONTRACT_ADDRESS=$(docker exec -it lotus lotus evm stat "$PROXY_ADDRESS_TEST" | awk '/Filecoin address:/{print $3}' | tr -d '\r')
echo "FIL Contract address: $CONTRACT_ADDRESS"

docker exec boost sh -c "
export \$(lotus auth api-info --perm=admin) &&
export \$(lotus-miner auth api-info --perm=admin) &&
export APISEALER=\"\$MINER_API_INFO\" &&
export APISECTORINDEX=\"\$MINER_API_INFO\" &&
export PUBLISH_STORAGE_DEALS_WALLET=\$(boost wallet list | awk 'NR==2 {print \$1}') &&
export COLLAT_WALLET=\$(boost wallet list | awk 'NR==2 {print \$1}') &&
boost init &&
boostx commp /app/public/bafykbzacec432ygday37lj2tvl3e7wl7ij46dko7cbmlndeghx6lhjkluqzhg.car &&
boostd import-direct --client-addr=$CONTRACT_ADDRESS --allocation-id=$ALLOCATION_ID baga6ea4seaqkw2fqpbilvzkewttsb72z7xd544e2rnni5a6ww6vtvqx2qpuemgy /app/public/bafykbzacec432ygday37lj2tvl3e7wl7ij46dko7cbmlndeghx6lhjkluqzhg.car
"
