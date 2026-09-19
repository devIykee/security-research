import hashlib
def sel(sig):
    return '0x'+hashlib.sha3_256(sig.encode()).hexdigest()[:8]
