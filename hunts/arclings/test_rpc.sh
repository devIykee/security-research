#!/bin/bash
# Quick RPC connectivity and state check

TARGET=0xEb03AC9cE0DCCbb95c0ecF17C957D979233D97Fd
RPC=https://rpc.testnet.arc.io

echo "Testing Arc Testnet RPC..."
echo ""

# Test 1: Chain ID
echo -n "Chain ID: "
timeout 10 cast chain-id --rpc-url $RPC 2>&1 || echo "TIMEOUT"

# Test 2: Block number
echo -n "Block Number: "
timeout 10 cast block-number --rpc-url $RPC 2>&1 || echo "TIMEOUT"

# Test 3: Contract code size
echo -n "Contract Code Size: "
timeout 10 cast codesize $TARGET --rpc-url $RPC 2>&1 || echo "TIMEOUT"

# Test 4: Simple call
echo -n "Total Supply: "
timeout 10 cast call $TARGET "totalSupply()(uint256)" --rpc-url $RPC 2>&1 || echo "TIMEOUT"

echo ""
echo "If all tests timeout, RPC is down."
echo "If some work, proceed with auth triage."
