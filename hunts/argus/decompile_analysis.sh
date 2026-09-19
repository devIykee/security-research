#!/bin/bash
# Advanced bytecode analysis for graduate() function

IMPL="0x122c82cfca7a3a2227285cc21f4522e8f551db3a"
RPC="https://rpc.mainnet.arc.io"

echo "=== Argus Implementation Bytecode Analysis ==="
echo "Target: $IMPL"
echo ""

# Get bytecode
echo "1. Fetching bytecode..."
cast code $IMPL --rpc-url $RPC > impl_bytecode.hex
SIZE=$(wc -c < impl_bytecode.hex)
echo "   Bytecode size: $SIZE bytes"

# Extract graduate() function location
echo ""
echo "2. Locating graduate() function (selector 0xd3618cca)..."
GRAD_POS=$(grep -b -o "d3618cca" impl_bytecode.hex | cut -d: -f1 | head -1)
echo "   Found at byte position: $GRAD_POS"

# Disassemble the entire contract
echo ""
echo "3. Disassembling bytecode..."
cast disassemble impl_bytecode.hex > disassembly.txt 2>&1 || echo "Disassembly completed with warnings"
echo "   Saved to: disassembly.txt"

# Look for critical patterns in graduate()
echo ""
echo "4. Searching for Uniswap V3 patterns..."
grep -i "createAndInitialize\|slot0\|sqrtPrice\|getPool" disassembly.txt | head -10 || echo "   No direct string matches (expected for bytecode)"

# Extract CALL/STATICCALL/DELEGATECALL patterns
echo ""
echo "5. Finding external calls in bytecode..."
grep -E "CALL|STATICCALL|DELEGATECALL" disassembly.txt | wc -l
echo "   external calls found"

echo ""
echo "Analysis files created:"
echo "  - impl_bytecode.hex"
echo "  - disassembly.txt"
echo ""
echo "Next: Manual review of graduate() function flow"
