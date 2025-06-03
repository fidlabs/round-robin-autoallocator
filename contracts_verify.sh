#!/bin/bash

set -euo pipefail

NETWORK=${1:-Calibnet}

echo "Starting contract verification script..."

if [[ "$NETWORK" != "Calibnet" && "$NETWORK" != "Mainnet" ]]; then
  echo "Unknown network: $NETWORK, avaliable: <Calibnet|Mainnet>"
  exit 1
fi
echo "Using network: $NETWORK"

if [[ "$NETWORK" == "Calibnet" ]]; then
  CHAIN_ALIAS="filecoin-calibration-testnet"
  CHAIN_ID="314159"
elif [[ "$NETWORK" == "Mainnet" ]]; then
  CHAIN_ALIAS="filecoin"
  CHAIN_ID="314"
else
  echo "Unknown network: $NETWORK. avaliable: <Calibnet|Mainnet>"
  exit 1
fi

DEPLOY_JSON="broadcast/${NETWORK}Deploy.s.sol/${CHAIN_ID}/run-latest.json"
if [[ -z "$DEPLOY_JSON" ]]; then
  echo "Deployment JSON not found: $DEPLOY_JSON"
  exit 1
fi
echo "Using deployment file: $DEPLOY_JSON"


CONTRACTS=()
IFS= # Keep all chars in each line, do not split by whitespace
while read -r line; do
  CONTRACTS+=("$line")
done < <(jq -r '.transactions[] | select(.contractName != null) | select(.contractAddress != null) | "\(.contractName)|\(.contractAddress)|\(.arguments // [])"' "$DEPLOY_JSON")

if [[ ${#CONTRACTS[@]} -eq 0 ]]; then
  echo "No deployed contracts found in $DEPLOY_FILE"
  exit 0
fi

echo "Found ${#CONTRACTS[@]} contracts to verify."

for entry in "${CONTRACTS[@]}"; do
  IFS='|' # split by pipe to get name and address
  read -r NAME ADDR <<< "$entry"
  echo " - $NAME @ $ADDR"
done

for entry in "${CONTRACTS[@]}"; do
  IFS='|' # split by pipe to get name and address
  read -r NAME ADDR ARGS <<< "$entry"
  # locate source file by name
  SRC_PATH=$(find src -type f -name "${NAME}.sol" -print -quit || true)
  if [[ -z "$SRC_PATH" ]]; then
    echo "Source for $NAME not found, skipping."
    continue
  fi

  echo "Verifying $NAME @ $ADDR using $SRC_PATH (chain: $CHAIN_ALIAS)"

  if [[ -n "$ARGS" && "$ARGS" != "[]" ]]; then
    echo "With extra constructor args"

    CLEAN_ARGS=$(echo "$ARGS" | tr -d '()[]"')

    forge verify-contract \
      --chain $CHAIN_ALIAS \
      --watch \
      --constructor-args "$CLEAN_ARGS" \
      --compiler-version 0.8.25 \
      --optimizer-runs 200 \
      --force \
      --retries 1 \
      $ADDR \
      ${SRC_PATH}:${NAME} || true
  else
    forge verify-contract \
      --chain $CHAIN_ALIAS \
      --watch \
      --compiler-version 0.8.25 \
      --optimizer-runs 200 \
      --force \
      --retries 1 \
      $ADDR \
      ${SRC_PATH}:${NAME} || true
  fi

  echo "✅ $NAME @ $ADDR verified!"
  echo " "
  sleep 1
done


echo "Verification complete!"
