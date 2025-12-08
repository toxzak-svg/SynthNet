# SynthNet v2.0 - Quick Start Guide

## Overview

SynthNet v2.0 implements a layered architecture with:
- **Layer 1 (AgentIdentity)**: Transferable identity tokens  
- **Layer 2 (SoulboundResume)**: Non-transferable job history
- **Layer 3 (VerificationRegistry)**: Job validation system
- **Orchestrator (SynthNetProtocol)**: Unified API

**Key Feature**: L1↔L2 bidirectional lookups enable cross-layer queries.

## Installation

```bash
git clone https://github.com/toxzak-svg/SynthNet.git
cd SynthNet
npm install
```

## Deploy Protocol

### Fresh Deployment
```bash
npx hardhat run scripts/deploy-v2.js --network localhost
# or for testnet
npx hardhat run scripts/deploy-v2.js --network sepolia
```

### Migration from Legacy
```bash
npx hardhat run scripts/deploy-v2.js --network localhost -- --migrate <LEGACY_CONTRACT_ADDRESS>
```

## Basic Usage

### 1. Register an Agent

```javascript
const { ethers } = require("hardhat");

// Get protocol instance
const protocol = await ethers.getContractAt("SynthNetProtocol", PROTOCOL_ADDRESS);

// Register with metadata
const metadata = [
  { key: "name", value: ethers.toUtf8Bytes("AI Agent Alpha") },
  { key: "model", value: ethers.toUtf8Bytes("GPT-4") }
];

const tx = await protocol.registerAgent("ipfs://Qm...", metadata);
const receipt = await tx.wait();

// Extract IDs from event
const event = receipt.logs.find(log => log.fragment?.name === "AgentFullyRegistered");
const agentId = event.args.agentId;
const resumeId = event.args.resumeId;

console.log(`Agent ID (L1): ${agentId}`);
console.log(`Resume ID (L2): ${resumeId}`);
```

### 2. Cross-Layer Lookup (L1↔L2)

```javascript
// Get contracts
const agentIdentity = await ethers.getContractAt("AgentIdentity", IDENTITY_ADDRESS);
const soulboundResume = await ethers.getContractAt("SoulboundResume", RESUME_ADDRESS);

// L1 → L2 lookup
const agentId = await agentIdentity.getAgentIdByAddress(agentAddress);
const resumeId = await agentIdentity.getResumeTokenId(agentId);

// L2 → L1 lookup
const linkedAgentId = await soulboundResume.getAgentId(resumeId);

// Query job history
const jobs = await soulboundResume.getJobRecords(agentId);
const reputation = await soulboundResume.getReputation(agentId);
```

### 3. Add Job Record

```javascript
const fee = await protocol.verificationFee();

const tx = await protocol.addJobRecord(
  agentId,
  0, // JobType.TradeExecution
  "Executed 10 DeFi swaps",
  "ipfs://Qm...proof",
  ethers.keccak256(ethers.toUtf8Bytes("proof data")),
  ethers.parseEther("100"), // value
  { value: fee }
);
```

### 4. Verify Job

```javascript
// Must be owner or authorized verifier
await protocol.addVerifier(verifierAddress);

// Verify with success
await protocol.verifyJob(agentId, jobId, true); // success=true, rep+10
// or failure
await protocol.verifyJob(agentId, jobId, false); // success=false, rep-5
```

### 5. Give Feedback

```javascript
// Direct call to L2 (preserves msg.sender)
const soulboundResume = await ethers.getContractAt("SoulboundResume", RESUME_ADDRESS);

await soulboundResume.giveFeedback(
  agentId,
  85, // score 0-100
  ethers.id("quality"),
  ethers.id("performance"),
  "ipfs://Qm...feedback",
  ethers.keccak256(ethers.toUtf8Bytes("feedback content")),
  "0x" // optional auth signature
);
```

### 6. Query Agent Data

```javascript
// Get statistics
const stats = await protocol.getAgentStatistics(agentId);
console.log(`Total Jobs: ${stats.totalJobs}`);
console.log(`Successful: ${stats.successfulJobs}`);
console.log(`Failed: ${stats.failedJobs}`);
console.log(`Reputation: ${stats.reputation}`);

// Get all jobs
const jobs = await soulboundResume.getJobRecords(agentId);

// Get feedback
const clients = await soulboundResume.getClients(agentId);
for (const client of clients) {
  const feedback = await soulboundResume.readFeedback(agentId, client, 0);
  console.log(`Score from ${client}: ${feedback.score}`);
}
```

## Testing

```bash
# All tests (72 tests)
npx hardhat test

# V2.0 only (44 tests)
npx hardhat test test/SynthNetProtocol.test.js

# Legacy only (28 tests)
npx hardhat test test/AIAgentResumeSBT.test.js
```

## Contract Addresses (After Deployment)

The deployment script outputs:
```
=== Layer 1: AgentIdentity ===
Address: 0x...

=== Layer 2: SoulboundResume ===
Address: 0x...

=== Layer 3: VerificationRegistry ===
Address: 0x...

=== Main Protocol ===
Address: 0x...
```

Save these addresses for interaction.

## Key Concepts

### L1↔L2 Bidirectional Lookups
```
L1 Token 5 ⟷ L2 Token 12

// Find resume from identity
resumeId = agentIdentity.getResumeTokenId(5) → 12

// Find identity from resume  
agentId = soulboundResume.getAgentId(12) → 5
```

### Data Availability
- **On-chain**: Status, reputation, timestamps, L1↔L2 links
- **Off-chain (IPFS/Arweave)**: Proofs, detailed descriptions, metadata

### Standards
- **ERC-721**: Layer 1 identity (transferable)
- **ERC-5192**: Layer 2 resume (soulbound)
- **ERC-8004**: Identity/Reputation/Validation registries

## Job Types

```javascript
enum JobType {
    TradeExecution,        // 0
    TreasuryManagement,    // 1
    ContentCompliance,     // 2
    DataAnalysis,          // 3
    SmartContractAudit,    // 4
    GovernanceVoting,      // 5
    General                // 6
}
```

## Admin Functions

```javascript
// Add verifier
await protocol.addVerifier(verifierAddress);

// Set fee
await protocol.setVerificationFee(ethers.parseEther("0.02"));

// Withdraw collected fees
await protocol.withdrawFees();

// Pause/unpause
await protocol.pause();
await protocol.unpause();
```

## Migration from Legacy

```javascript
const VampireMigration = await ethers.getContractFactory("VampireMigration");
const migration = await VampireMigration.deploy(
  LEGACY_CONTRACT_ADDRESS,
  NEW_PROTOCOL_ADDRESS
);

// User self-migrates
await migration.connect(agentOwner).selfMigrate();

// Or admin batch migrates
await migration.migrateAgentsBatch([agent1, agent2, agent3]);
```

## Next Steps

- Read [ARCHITECTURE.md](ARCHITECTURE.md) for system design details
- Read [API.md](API.md) for complete function reference
- Read [TECHNICAL.md](TECHNICAL.md) for implementation details
- Explore the test suite for usage examples
