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
if [ -z "${RPC_TEST:-}" ] || [ -z "${PRIVATE_KEY_TEST:-}" ] || [ -z "${MY_FIL_WALLET:-}" ]; then
    echo "Both RPC_TEST and PRIVATE_KEY_TEST must be set in the .env file."
    exit 1
fi

docker exec -it lotus lotus send $MY_FIL_WALLET 1000

echo "Cleaning up..."
forge clean

echo "Deploying fresh contract..."
forge script script/DevnetDeploy.s.sol --gas-estimate-multiplier 100000 --disable-block-gas-limit -vvvv --broadcast --rpc-url $RPC_TEST --private-key $PRIVATE_KEY_TEST > fresh_output.log
DEPLOYMENT=$(cat fresh_output.log)

echo "Extracting contract address..."
CONTRACT_ADDRESS=$(echo "$DEPLOYMENT" | grep -oE 'CONTRACT_ADDRESS: 0x[a-fA-F0-9]{40}'  | cut -d' ' -f2 | head -n 1) || echo "Error extracting address!"

echo "Deployment successful!"
echo "Proxy contract address is: $CONTRACT_ADDRESS"
echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"

sed -i '' "s/^PROXY_ADDRESS_TEST=.*/PROXY_ADDRESS_TEST=$CONTRACT_ADDRESS/" .env

# grant datacap to a contract
echo ""
echo ""
echo "Granting datacap to contract..."
sh devnet_grant_dc.sh
echo ""
echo ""
# send allocation transaction to contract
echo "Adding Storage Entity..."
# disable error checking for the next command
# set +e
cast send --json --gas-limit 9000000000 --private-key $PRIVATE_KEY_TEST --rpc-url $RPC_TEST $PROXY_ADDRESS_TEST "createStorageEntity(address,uint64[])" $MY_ETH_WALLET "[1000]" || echo "Command failed but continuing anyway"
# enable error checking again
# set -e
echo ""
echo "Waiting for storage entity transaction to be processed..."
sleep 10 
echo ""
echo "Sending allocation transaction..."
cast send --json --gas-limit 9000000000 --value 0.01ether --private-key $PRIVATE_KEY_TEST --rpc-url $RPC_TEST $PROXY_ADDRESS_TEST 'allocate(uint256,(bytes,uint64)[])' 1 '[(0x0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b, 2048)]' 
echo ""

# list allocations to prove its working
echo "Listing allocations..."
docker exec -it lotus lotus filplus list-allocations
