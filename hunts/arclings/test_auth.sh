#!/bin/bash
# Arclings Auth Triage Test Script
# Tests admin functions from unauthorized address

set -e

TARGET=0xEb03AC9cE0DCCbb95c0ecF17C957D979233D97Fd
RPC=https://rpc.testnet.arc.io
ATTACKER=0x000000000000000000000000000000000000dEaD

echo "=========================================="
echo "ARCLINGS AUTH TRIAGE"
echo "Target: $TARGET"
echo "Chain: Arc Testnet (5042002)"
echo "Attacker: $ATTACKER"
echo "=========================================="
echo ""

# Function to test and report
test_function() {
    local name=$1
    local selector=$2
    local args=$3

    echo -n "Testing $name ... "

    result=$(cast call $TARGET "$selector" $args \
        --from $ATTACKER \
        --rpc-url $RPC 2>&1) || true

    if echo "$result" | grep -qi "revert\|error"; then
        echo "✓ GUARDED (reverted)"
        echo "  Response: $(echo $result | head -c 100)"
    else
        echo "✗ OPEN <-- CHECK"
        echo "  Response: $result"
    fi
    echo ""
}

echo "=== CRITICAL ADMIN FUNCTIONS ==="
echo ""

test_function "adminMint" "adminMint(address,uint256)" "$ATTACKER 1"
test_function "adminMintBatch" "adminMintBatch(address[],uint256[])" "[$ATTACKER] [1]"
test_function "withdraw" "withdraw()" ""
test_function "setMintPrice" "setMintPrice(uint256)" "0"
test_function "setPhase" "setPhase(uint8)" "2"
test_function "setMerkleRoot" "setMerkleRoot(bytes32)" "0x0000000000000000000000000000000000000000000000000000000000000000"
test_function "setMaxPerWalletPublic" "setMaxPerWalletPublic(uint256)" "1000"
test_function "setMaxPerWalletAllowlist" "setMaxPerWalletAllowlist(uint256)" "1000"
test_function "setTradingEnabled" "setTradingEnabled(bool)" "true"
test_function "setTransferValidator" "setTransferValidator(address)" "$ATTACKER"
test_function "setDescriptor" "setDescriptor(address)" "$ATTACKER"
test_function "transferOwnership" "transferOwnership(address)" "$ATTACKER"

echo ""
echo "=== VIEW FUNCTIONS (STATE QUERY) ==="
echo ""

query_function() {
    local name=$1
    local selector=$2

    echo -n "$name: "
    cast call $TARGET "$selector" --rpc-url $RPC 2>&1 || echo "Failed"
}

query_function "totalSupply" "totalSupply()(uint256)"
query_function "MAX_SUPPLY" "MAX_SUPPLY()(uint256)"
query_function "mintPrice" "mintPrice()(uint256)"
query_function "phase" "phase()(uint8)"
query_function "tradingEnabled" "tradingEnabled()(bool)"
query_function "owner" "owner()(address)"
query_function "merkleRoot" "merkleRoot()(bytes32)"
query_function "maxPerWalletPublic" "maxPerWalletPublic()(uint256)"
query_function "maxPerWalletAllowlist" "maxPerWalletAllowlist()(uint256)"
query_function "descriptor" "descriptor()(address)"
query_function "transferValidator" "getTransferValidator()(address)"

echo ""
echo "=========================================="
echo "Auth triage complete"
echo "=========================================="
