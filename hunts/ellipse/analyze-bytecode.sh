#!/bin/bash
# Bytecode Analysis Script for Unverified Contracts

CONTRACT=$1
RPC=$2
OUTPUT_DIR=${3:-"bytecode-analysis"}

if [ -z "$CONTRACT" ] || [ -z "$RPC" ]; then
    echo "Usage: $0 <contract_address> <rpc_url> [output_dir]"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== Analyzing contract $CONTRACT ==="

# 1. Get bytecode
echo "[1/6] Fetching bytecode..."
cast code "$CONTRACT" --rpc-url "$RPC" > "$OUTPUT_DIR/bytecode.bin"
SIZE=$(wc -c < "$OUTPUT_DIR/bytecode.bin")
echo "  Bytecode size: $SIZE bytes"

# 2. Disassemble
echo "[2/6] Disassembling..."
cast disassemble $(cat "$OUTPUT_DIR/bytecode.bin") > "$OUTPUT_DIR/disasm.txt" 2>&1
echo "  Disassembly lines: $(wc -l < "$OUTPUT_DIR/disasm.txt")"

# 3. Extract function selectors
echo "[3/6] Extracting function selectors..."
grep -E "PUSH4 0x[0-9a-f]{8}" "$OUTPUT_DIR/disasm.txt" | \
  sed -E 's/.*PUSH4 (0x[0-9a-f]{8}).*/\1/' | \
  sort -u > "$OUTPUT_DIR/selectors.txt"
echo "  Found $(wc -l < "$OUTPUT_DIR/selectors.txt") unique selectors"

# 4. Decode known selectors
echo "[4/6] Decoding selectors..."
while read selector; do
    sig=$(cast 4byte-decode "$selector" 2>/dev/null | head -1)
    if [ -n "$sig" ]; then
        echo "$selector $sig"
    else
        echo "$selector UNKNOWN"
    fi
done < "$OUTPUT_DIR/selectors.txt" > "$OUTPUT_DIR/functions.txt"

# 5. Search for critical patterns
echo "[5/6] Searching for critical patterns..."
{
    echo "=== Uniswap v3 Factory Calls ==="
    grep -E "a1671295|1698ee82" "$OUTPUT_DIR/disasm.txt" | head -5
    echo ""
    echo "=== Pool Initialize Calls ==="
    grep -E "f637731d" "$OUTPUT_DIR/disasm.txt" | head -5
    echo ""
    echo "=== External Calls ==="
    grep -nE "^[0-9a-f]+: (CALL|STATICCALL|DELEGATECALL)" "$OUTPUT_DIR/disasm.txt" | head -20
    echo ""
    echo "=== Storage Writes ==="
    grep -nE "^[0-9a-f]+: SSTORE" "$OUTPUT_DIR/disasm.txt" | wc -l
} > "$OUTPUT_DIR/patterns.txt"

# 6. Generate summary
echo "[6/6] Generating summary..."
cat > "$OUTPUT_DIR/ANALYSIS.md" <<SUMMARY
# Bytecode Analysis - $CONTRACT

**Generated:** $(date)
**Bytecode size:** $SIZE bytes
**Disassembly lines:** $(wc -l < "$OUTPUT_DIR/disasm.txt")
**Functions found:** $(wc -l < "$OUTPUT_DIR/selectors.txt")

## Functions

\`\`\`
$(cat "$OUTPUT_DIR/functions.txt")
\`\`\`

## Critical Patterns

\`\`\`
$(cat "$OUTPUT_DIR/patterns.txt")
\`\`\`

## Files Generated

- \`bytecode.bin\` - Raw bytecode
- \`disasm.txt\` - Full disassembly
- \`selectors.txt\` - Function selectors
- \`functions.txt\` - Decoded functions
- \`patterns.txt\` - Critical pattern search
SUMMARY

echo ""
echo "✓ Analysis complete! Results in $OUTPUT_DIR/"
echo "  Review: $OUTPUT_DIR/ANALYSIS.md"
