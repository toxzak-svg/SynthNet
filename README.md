# SynthNet - AI Agent Resume Protocol v2.0

A blockchain-based Proof-of-Work Resume Protocol for AI Agents that automatically records their on-chain "job history" using Soulbound Tokens (SBT).

## Overview

SynthNet v2.0 provides a verification layer that every AI agent needs to get hired by DAOs. It creates a permanent, non-transferable record of an AI agent's work history on-chain, enabling transparent verification of their performance across different types of jobs.

**Architecture**: SynthNet v2.0 implements a layered architecture following ERC-8004 (AI Agent Identity/Reputation/Validation Registries) and ERC-5192 (Minimal Soulbound NFT) standards.

## Features

### 🏗️ Layered Architecture
- **Layer 1 (AgentIdentity)**: ERC-721 transferable identity tokens with metadata storage
- **Layer 2 (SoulboundResume)**: ERC-5192 non-transferable job history with reputation system
- **Layer 3 (VerificationRegistry)**: Job verification and validator management
- **Orchestrator (SynthNetProtocol)**: Unified API coordinating all layers

### 🔗 Cross-Layer Lookups
- Layer 1 → Layer 2: `agentIdentity.getResumeTokenId(agentId)` returns corresponding resume
- Layer 2 → Layer 1: `soulboundResume.getAgentId(resumeId)` returns identity token
- Bidirectional mapping ensures data integrity across layers

### 🔐 Soulbound Token (Non-Transferable)
- Each AI agent receives a unique, non-transferable NFT that serves as their permanent resume
- ERC-5192 compliant with `locked()` always returning true
- Tokens cannot be transferred, ensuring authenticity and preventing credential fraud

### 📊 Job Verification Types
The protocol supports seven primary job categories:
1. **Trade Execution**: DeFi trading operations
2. **Treasury Management**: Asset and fund management
3. **Content Compliance**: Content moderation and policy enforcement
4. **Data Analysis**: Analytics and insights generation
5. **Smart Contract Audit**: Code review and security analysis
6. **Governance Voting**: DAO participation and decision-making
7. **General**: Miscellaneous tasks

### ✅ Verification System
- Multi-party verification with designated verifiers
- Owner and authorized verifiers can validate job completions
- Four verification statuses: Pending, Verified, Failed, Disputed
- Success/failure tracking independent of verification status

### 🎯 Reputation System
- Automatic reputation scoring based on job performance
- Base reputation: 50 points
- Successful jobs increase reputation (+10 points)
- Failed jobs decrease reputation (-5 points)
- Minimum reputation floor: 0 points
- Transparent history for DAOs to make informed hiring decisions

### 💬 Feedback System (ERC-8004 Compliance)
- Clients can provide feedback with 0-100 scores
- Tag-based categorization with dual tags
- Off-chain proof storage via IPFS/Arweave URIs
- Feedback revocation capability
- Query feedback by tags and compute average scores

### 🌐 Data Availability Strategy
- **On-chain**: Identity metadata, job status, reputation scores, verification records
- **Off-chain (IPFS/Arweave)**: Detailed proofs, logs, agent metadata files, feedback documents
- URIs stored in `tokenURI`, `proofUri`, and `fileUri` fields
- Hash verification via `proofHash` and `fileHash` fields

### 💰 Verification Fee Model
- Small fee required for each job added to an agent's resume
- Fees collected go to the protocol for sustainability
- Configurable fee structure by contract owner

### 🧛 Vampire Migration
- Migration contract for importing data from legacy systems
- Batch migration support for multiple agents
- Self-migration for agent owners
- Job history conversion with proof preservation

## Smart Contract Architecture

### Layer 1: `AgentIdentity.sol`
**ERC-8004 Identity Registry + ERC-721**

Key Functions:
- `register()`: Self-register and mint identity token
- `registerFor()`: Protocol-mediated registration with L2 link
- `setMetadata()`: Store key-value metadata
- `getResumeTokenId()`: **NEW** Find linked Layer 2 resume token
- `tokenURI()`: IPFS/Arweave URI for off-chain data

### Layer 2: `SoulboundResume.sol`
**ERC-8004 Reputation Registry + ERC-5192 Soulbound**

Key Functions:
- `mintResume()`: Create soulbound resume for an agent
- `addJobRecord()`: Add job with off-chain proof URI
- `updateJobStatus()`: Verify jobs and update reputation
- `giveFeedback()`: Client feedback with scores 0-100
- `getReputation()`: Get current reputation score
- `locked()`: ERC-5192 - always returns true
- `getAgentId()`: Find linked Layer 1 identity token

### Layer 3: `VerificationRegistry.sol`
**ERC-8004 Validation Registry**

Key Functions:
- `verifyJob()`: Main verification interface
- `addVerifier()`/`removeVerifier()`: Manage validators
- `validationRequest()`/`validationResponse()`: ERC-8004 workflow
- `isVerifier()`: Check verifier authorization

### Orchestrator: `SynthNetProtocol.sol`
**Unified API**

Key Functions:
- `registerAgent()`: Create L1 identity + L2 resume atomically
- `addJobRecord()`: Submit job with fee collection
- `verifyJob()`: Authorized verification
- `giveFeedback()`: Client feedback interface
- `pause()`/`unpause()`: Emergency controls

### Migration: `VampireMigration.sol`

Key Functions:
- `migrateAgent()`: Admin-initiated migration
- `selfMigrate()`: User-initiated migration
- `migrateAgentsBatch()`: Batch processing
- Job type conversion and metadata preservation

## Installation

```bash
# Clone the repository
git clone https://github.com/toxzak-svg/SynthNet.git
cd SynthNet

# Install dependencies
npm install
```

## Usage

### Compile Contracts
```bash
npx hardhat compile
```

### Run Tests
```bash
# All tests (72 tests)
npx hardhat test

# V2.0 architecture tests (44 tests)
npx hardhat test test/SynthNetProtocol.test.js

# Legacy tests (28 tests)
npx hardhat test test/AIAgentResumeSBT.test.js
```

### Deploy

#### Fresh Deployment
```bash
npx hardhat run scripts/deploy-v2.js --network <network-name>
```

#### Migration Deployment
```bash
npx hardhat run scripts/deploy-v2.js --network <network-name> -- --migrate <legacy-contract-address>
```

## Testing

The project includes comprehensive tests covering:
- ✅ 72 total tests passing
- ✅ Layer 1 identity registration and metadata
- ✅ Layer 2 soulbound resume and reputation
- ✅ Layer 3 verification and validator management
- ✅ Cross-layer lookups (L1↔L2)
- ✅ ERC-5192 compliance (soulbound functionality)
- ✅ ERC-8004 compliance (identity/reputation/validation)
- ✅ Feedback system with scoring
- ✅ Administrative functions and access control
- ✅ Fee collection and withdrawal
- ✅ Seven job types support
- ✅ Migration contract functionality

## Use Cases

### For DAOs
- Review verified work history before hiring AI agents
- Query cross-layer data: `getResumeTokenId()` → `getJobRecords()`
- Make data-driven decisions based on reputation scores
- Access feedback from previous clients
- Reduce risk by seeing past performance

### For AI Agents
- Build a verifiable on-chain resume
- Prove competency through verified job completions
- Increase reputation to access better opportunities
- Transferable identity (L1) with non-transferable history (L2)

### For Employers
- Submit job records with IPFS/Arweave proofs
- Pay small verification fee to document agent performance
- Provide feedback with detailed scores and tags
- Contribute to agent's permanent record

## Architecture Benefits

1. **Standards Compliance**: ERC-5192 and ERC-8004 compatibility
2. **Layer Separation**: Identity, reputation, and validation are distinct
3. **Cross-Layer Navigation**: Bidirectional lookups between L1 and L2
4. **Transparency**: All job records are on-chain and publicly verifiable
5. **Immutability**: Soulbound tokens cannot be transferred or manipulated
6. **Decentralized Verification**: Multiple verifiers can validate work
7. **Economic Sustainability**: Verification fees support protocol maintenance
8. **Reputation Accumulation**: Agents build value over time through good work
9. **Data Availability**: Hybrid on-chain/off-chain storage via IPFS/Arweave
10. **Migration Support**: Import legacy data with vampire migration

## Security Features

- Ownable pattern for administrative functions
- ReentrancyGuard on state-changing functions
- Multi-verifier system prevents single point of failure
- Non-transferable L2 tokens prevent fraud
- Authorization checks at protocol and registry boundaries
- Fee collection safeguards
- Pause mechanism for emergencies

## Development

### Project Structure
```
SynthNet/
├── contracts/
│   ├── AgentIdentity.sol           # Layer 1: ERC-721 Identity
│   ├── SoulboundResume.sol         # Layer 2: ERC-5192 Resume
│   ├── VerificationRegistry.sol    # Layer 3: Validation
│   ├── SynthNetProtocol.sol        # Orchestrator
│   ├── VampireMigration.sol        # Migration Tool
│   ├── AIAgentResumeSBT.sol        # Legacy (v1.0)
│   └── interfaces/
│       ├── IERC5192.sol            # Soulbound interface
│       └── IERC8004.sol            # AI Agent registries
├── test/
│   ├── SynthNetProtocol.test.js    # V2.0 tests (44 tests)
│   └── AIAgentResumeSBT.test.js    # Legacy tests (28 tests)
├── scripts/
│   ├── deploy-v2.js                # V2.0 deployment
│   └── deploy.js                   # Legacy deployment
├── hardhat.config.js               # Hardhat configuration
└── package.json                    # Project dependencies
```

### Technologies Used
- **Solidity 0.8.20**: Smart contract language
- **Hardhat**: Development environment with viaIR compilation
- **OpenZeppelin Contracts v5.4.0**: Security-audited libraries
- **Ethers.js v6**: Ethereum interaction library
- **ERC-5192**: Minimal Soulbound NFT standard
- **ERC-8004**: AI Agent trustless registry standard (draft)

## Standards Implemented

### ERC-5192: Minimal Soulbound NFT
- Interface ID: `0xb45a3c0e`
- `locked(uint256 tokenId)`: Always returns true
- `Locked(uint256 tokenId)`: Emitted on mint
- Prevents all transfers via `_update()` override

### ERC-8004: AI Agent Registries (Draft)
- **IIdentityRegistry**: Agent registration and metadata
- **IReputationRegistry**: Feedback and reputation management
- **IValidationRegistry**: Validation request/response workflow

## Future Enhancements

Potential areas for expansion:
- Multi-chain deployment with cross-chain identity
- Enhanced dispute resolution with on-chain arbitration
- Integration with AI agent frameworks (LangChain, AutoGPT)
- Advanced analytics dashboard
- Credential verification oracles
- Staking mechanisms for verifiers
- Tiered reputation levels with benefits
- Decentralized storage incentives

## Contributing

Contributions are welcome! Please follow these steps:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality (maintain 100% pass rate)
5. Update documentation
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

For questions, suggestions, or collaborations, please open an issue on GitHub.

---

**Note**: This is a verification layer protocol. It does not build or manage AI agents themselves, but provides the infrastructure for verifying their work history on-chain.
