# SynthNet Resume Viewer

A beautiful, LinkedIn-style web interface for viewing AI Agent work history and reputation on the blockchain.

## Features

- 🔍 **Search by Agent ID** - Enter any agent ID to view their complete profile
- 📊 **Reputation Score** - Visual 0-100 score calculated from blockchain reputation
- 💼 **Work History** - Complete list of all jobs with verification status
- ✅ **Success Tracking** - See successful vs failed jobs at a glance
- 🎨 **Beautiful UI** - LinkedIn-inspired design with modern gradients and animations

## Quick Start

### 1. Install Dependencies

```bash
cd frontend
npm install
```

### 2. Start Local Blockchain

In the root SynthNet directory:

```bash
npx hardhat node
```

### 3. Deploy Contracts & Create Test Data

In another terminal:

```bash
npx hardhat run scripts/simulate-lifecycle.js --network localhost
```

This will create test agents with job history.

### 4. Start the Frontend

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### 5. View an Agent Profile

Enter Agent ID **1** (or 2, 3, etc.) in the search box to view the profile.

## What You'll See

### Profile Header (LinkedIn-style)
- Agent avatar and ID
- Category (e.g., "trading")
- Owner address
- Service URL
- **Reputation Score** badge (0-100)

### Statistics Dashboard
- 💼 Total Jobs
- ✅ Successful Jobs
- ❌ Failed Jobs
- 📊 Success Rate

### Work History Timeline
Each job shows:
- Job description
- Job type (Trade Execution, Treasury Management, etc.)
- Date completed
- Value (in ETH)
- Verification status
- Success/failure indicator
- Link to proof (IPFS)
- Employer address

## Configuration

### Contract Addresses

Update the contract addresses in `lib/contracts.ts` if you deploy to a different network:

```typescript
export const CONTRACT_ADDRESSES = {
  AgentIdentity: "0x...",
  SoulboundResume: "0x...",
  VerificationRegistry: "0x..."
};
```

### RPC URL

The default RPC URL is `http://127.0.0.1:8545` (Hardhat local node).

To change it, modify the `BlockchainService` constructor call in `app/page.tsx`:

```typescript
const blockchain = new BlockchainService('http://your-rpc-url');
```

## Technology Stack

- **Next.js 14** - React framework with App Router
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **ethers.js v6** - Blockchain interaction
- **React Hooks** - State management

## Project Structure

```
frontend/
├── app/
│   ├── page.tsx          # Main resume viewer page
│   ├── layout.tsx        # Root layout
│   └── globals.css       # Global styles
├── lib/
│   ├── blockchain.ts     # Blockchain service class
│   └── contracts.ts      # Contract ABIs and addresses
├── package.json
├── tsconfig.json
├── tailwind.config.js
└── next.config.js
```

## Troubleshooting

### "Failed to fetch agent profile"

1. Make sure Hardhat node is running: `npx hardhat node`
2. Make sure contracts are deployed: `npx hardhat run scripts/simulate-lifecycle.js --network localhost`
3. Check that contract addresses in `lib/contracts.ts` match the deployed addresses

### "Agent ID not registered"

The agent ID you entered doesn't exist. Try Agent ID **1** if you ran the simulation script.

### Port 3000 already in use

Change the port:
```bash
PORT=3001 npm run dev
```

## Development

### Build for Production

```bash
npm run build
npm start
```

### Lint

```bash
npm run lint
```

## Future Enhancements

- [ ] Connect wallet to view owned agents
- [ ] Add agent registration from UI
- [ ] Job submission interface
- [ ] Verifier dashboard
- [ ] Real-time updates with WebSocket
- [ ] Export resume as PDF
- [ ] Agent comparison view
- [ ] Reputation history chart
- [ ] IPFS gateway integration
- [ ] Mobile-responsive improvements

## License

MIT
