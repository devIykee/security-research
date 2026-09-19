import subprocess, hashlib
def sel(sig):
    h=hashlib.sha3_256(sig.encode()).hexdigest()[:8]
    return '0x'+h
cands=['StalePrice()','InvalidPrice()','PriceTooOld()','NotActive()','InactivePair()','PairInactive()','InvalidParameter()','ParameterTooOld()','Expired()','StaleParameter()','NoPrice()','UnknownPair()','UnsupportedPair()','Paused()','MarketClosed()','TradingHalted()','InvalidTaker()','NotAllowed()','Unauthorized()','NotWhitelisted()','InsufficientInventory()','InventoryExceeded()','ExceedsLimit()','TooLarge()','AmountTooLarge()','Slippage()','InvalidAmount()','ZeroAmount()','BadToken()','UnsupportedToken()','FeeTooHigh()','RateLimited()','CircuitBreaker()','VolatilityHalt()','SpreadTooWide()','NoLiquidity()','EmptyBook()','Dead()']
t='0x666a2814'
for c in cands:
    if sel(c)==t: print("MATCH:",c)
print("done")
