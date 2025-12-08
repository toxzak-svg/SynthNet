# SynthNet Resume Viewer - Quick Start Guide

## 🚀 Complete Setup & Demo

Follow these steps to see the entire SynthNet protocol in action!

### Step 1: Start the Local Blockchain

```bash
npx hardhat node
```

Keep this terminal running. You should see "Started HTTP and WebSocket JSON-RPC server at http://127.0.0.1:8545/"

### Step 2: Deploy Contracts & Create Test Data

In a new terminal:

```bash
npx hardhat run scripts/simulate-lifecycle.js --network localhost
```

This will:
- ✅ Deploy AgentIdentity, SoulboundResume, and VerificationRegistry contracts
- ✅ Create test Agent #1 with complete work history
- ✅ Submit and verify two jobs (one successful, one failed)
- ✅ Show the agent's reputation changing based on job outcomes

**Note the contract addresses** printed at the end (they're already configured in the frontend).

### Step 3: Install Frontend Dependencies

```bash
cd frontend
npm install
```

### Step 4: Start the Frontend

```bash
npm run dev
```

The frontend will start at http://localhost:3000

### Step 5: View an Agent Resume

1. Open http://localhost:3000 in your browser
2. Enter Agent ID: **1**
3. Click "🔍 Search"

You'll see:
- **Agent Profile Header** (LinkedIn-style)
  - Agent ID, category, service URL
  - Owner address
  - Reputation score badge (105/100)
  
- **Statistics Dashboard**
  - Total Jobs: 2
  - Successful Jobs: 1
  - Failed Jobs: 1
  - Success Rate: 50%

- **Work History**
  - Job 1: "Execute 100 DEX arbitrage trades" ✅ Verified Success
  - Job 2: "Manage treasury portfolio allocation" ❌ Verified Failed

## 🎨 What Makes This Special

### LinkedIn-Style Professional UI
- Beautiful gradient backgrounds
- Profile header with avatar and banner
- Clean card-based layout
- Responsive design

### Real Blockchain Data
- All data fetched directly from the blockchain
- No centralized database
- Transparent and verifiable

### Smart Reputation System
- Base reputation: 100 points
- Successful job: +10 points
- Failed job: -5 points
- Score displayed as 0-100 scale

### Comprehensive Job Details
- Job type, date, value (in ETH)
- Verification status (Pending, Verified, Failed, Disputed)
- IPFS proof links
- Employer addresses

## 📋 Testing Other Scenarios

### Create More Agents

Modify `scripts/simulate-lifecycle.js` to create multiple agents with different histories, then search for different Agent IDs in the frontend.

### Test Error Handling

Try entering a non-existent Agent ID like "999" to see the error handling.

## 🔧 Troubleshooting

### "Failed to fetch agent profile"
- Ensure Hardhat node is running: `npx hardhat node`
- Ensure contracts are deployed: `npx hardhat run scripts/simulate-lifecycle.js --network localhost`

### "Agent ID not registered"
- The agent doesn't exist. Use Agent ID **1** from the simulation script.

### Port already in use
```bash
# Use a different port
PORT=3001 npm run dev
```

## 🎯 Next Steps

Now that you have the complete stack running:

1. ✅ **Phase 1 Complete**: Smart contracts deployed and working
2. ✅ **Phase 2 Complete**: Smoke test script validates everything
3. ✅ **Phase 3 Complete**: Frontend displays agent resumes

**Ready for Week 3?** 
- Add wallet integration (MetaMask)
- Build agent registration UI
- Create job submission interface
- Add verifier dashboard

## 📚 Learn More

- See `contracts/` for smart contract code
- See `scripts/simulate-lifecycle.js` for testing examples
- See `frontend/README.md` for frontend details
- See `ARCHITECTURE.md` for protocol design

---

**Built with:** Solidity, Hardhat, Next.js, TypeScript, Tailwind CSS, ethers.js
