#!/usr/bin/env python3
"""
Decompile Argus implementation contract using ethervm.io API
"""
import requests
import json
import sys

def decompile_contract(address, chain_id=5042):
    """Try multiple decompiler services"""
    
    print(f"Attempting to decompile {address}...")
    
    # Try Dedaub API (if available)
    try:
        print("\n1. Trying Dedaub decompiler...")
        dedaub_url = f"https://library.dedaub.com/decompile"
        response = requests.post(dedaub_url, 
                                json={"bytecode": open('impl_bytecode.hex').read().strip()},
                                timeout=30)
        if response.status_code == 200:
            print("✓ Dedaub decompilation successful!")
            return response.text
    except Exception as e:
        print(f"✗ Dedaub failed: {e}")
    
    # Try ethervm.io
    try:
        print("\n2. Trying ethervm.io decompiler...")
        bytecode = open('impl_bytecode.hex').read().strip()
        if bytecode.startswith('0x'):
            bytecode = bytecode[2:]
        
        ethervm_url = "https://ethervm.io/decompile"
        response = requests.post(ethervm_url, 
                                data={"bytecode": bytecode},
                                timeout=60)
        if response.status_code == 200 and response.text:
            print("✓ Ethervm decompilation successful!")
            return response.text
    except Exception as e:
        print(f"✗ Ethervm failed: {e}")
    
    print("\n✗ All online decompilers failed")
    return None

if __name__ == "__main__":
    result = decompile_contract("0x122c82cfca7a3a2227285cc21f4522e8f551db3a")
    if result:
        with open('decompiled_source.sol', 'w') as f:
            f.write(result)
        print(f"\n✓ Decompiled source saved to: decompiled_source.sol")
        print(f"Size: {len(result)} bytes")
    else:
        print("\n✗ Decompilation failed")
        sys.exit(1)
