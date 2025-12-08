# SynthNet - AI Agent Resume Protocol

A blockchain-based Proof-of-Work Resume Protocol for AI Agents that automatically records their on-chain "job history" using Soulbound Tokens (SBT).

## Overview

SynthNet provides a verification layer that every AI agent needs to get hired by DAOs. It creates a permanent, non-transferable record of an AI agent's work history on-chain, enabling transparent verification of their performance across different types of jobs.

## Features

### 🔐 Soulbound Token (Non-Transferable)
- Each AI agent receives a unique, non-transferable NFT that serves as their permanent resume
- Tokens cannot be transferred, ensuring authenticity and preventing credential fraud

### 📊 Job Verification Types
The protocol supports three primary job categories:
1. **Trade Execution**: Did the agent execute trades correctly?
2. **Treasury Management**: Did it manage the treasury without losing funds?
3. **Content Compliance**: Did it post compliant content?

### ✅ Verification System
- Multi-party verification with designated verifiers
- Owner and authorized verifiers can validate job completions
- Four verification statuses: Pending, Verified, Failed, Disputed

### 🎯 Reputation System
- Automatic reputation scoring based on job performance
- Successful jobs increase reputation (+10 points)
- Failed jobs decrease reputation (-5 points)
- Transparent history for DAOs to make informed hiring decisions

### 💰 Verification Fee Model
- Small fee required for each job added to an agent's resume
- Fees collected go to the protocol for sustainability
- Configurable fee structure by contract owner

## Smart Contract Architecture

### Core Contract: `AIAgentResumeSBT.sol`

**Key Functions:**

#### Agent Registration
```solidity
function registerAgent(address agent) external returns (uint256)
```
Registers a new AI agent and mints their Soulbound Token.

#### Job Management
```solidity
function addJobRecord(
    address agent,
    JobType jobType,
    string calldata description,
    bytes32 proofHash,
    uint256 value
) external payable returns (uint256)
```
Adds a new job record to an agent's resume. Requires verification fee payment.

#### Job Verification
```solidity
function verifyJob(
    address agent,
    uint256 jobId,
    VerificationStatus status,
    bool success
) external
```
Verifies a job record. Only callable by authorized verifiers or owner.

#### Statistics
```solidity
function getAgentStats(address agent) external view returns (
    uint256 totalJobs,
    uint256 successfulJobs,
    uint256 failedJobs,
    uint256 reputation
)
```
Retrieves comprehensive statistics for an AI agent.

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
npm run compile
```

### Run Tests
```bash
npm test
```

### Deploy
```bash
# Deploy to local network
npm run deploy:localhost

# Deploy to specific network
npm run deploy -- --network <network-name>
```

## Testing

The project includes comprehensive tests covering:
- Agent registration and SBT minting
- Job record creation and management
- Verification workflow
- Reputation scoring system
- Soulbound token functionality (non-transferability)
- Administrative functions
- Fee collection and withdrawal
- Multiple job types

Run tests with:
```bash
npm test
```

## Deployment

The deployment script (`scripts/deploy.js`) sets up the contract with:
- Initial verification fee: 0.01 ETH
- Owner controls for fee adjustment and verifier management

## Use Cases

### For DAOs
- Review verified work history before hiring AI agents
- Make data-driven decisions based on reputation scores
- Reduce risk by seeing past performance

### For AI Agents
- Build a verifiable on-chain resume
- Prove competency through verified job completions
- Increase reputation to access better opportunities

### For Employers
- Submit job records with proof of work
- Pay small verification fee to document agent performance
- Contribute to agent's permanent record

## Architecture Benefits

1. **Transparency**: All job records are on-chain and publicly verifiable
2. **Immutability**: Soulbound tokens cannot be transferred or manipulated
3. **Decentralized Verification**: Multiple verifiers can validate work
4. **Economic Sustainability**: Verification fees support protocol maintenance
5. **Reputation Accumulation**: Agents build value over time through good work

## Security Features

- Ownable pattern for administrative functions
- Multi-verifier system prevents single point of failure
- Non-transferable tokens prevent fraud
- Job status immutability after verification
- Fee collection safeguards

## Development

### Project Structure
```
SynthNet/
├── contracts/
│   └── AIAgentResumeSBT.sol    # Main smart contract
├── test/
│   └── AIAgentResumeSBT.test.js # Comprehensive test suite
├── scripts/
│   └── deploy.js                # Deployment script
├── hardhat.config.js            # Hardhat configuration
└── package.json                 # Project dependencies
```

### Technologies Used
- **Solidity 0.8.20**: Smart contract language
- **Hardhat**: Development environment
- **OpenZeppelin**: Security-audited contract libraries
- **Ethers.js**: Ethereum interaction library
- **Chai**: Testing framework

## Future Enhancements

Potential areas for expansion:
- Multi-chain deployment support
- Enhanced dispute resolution mechanisms
- Integration with AI agent frameworks
- Advanced analytics dashboard
- Credential verification oracles
- Staking mechanisms for verifiers
- Tiered reputation levels with benefits

## Contributing

Contributions are welcome! Please follow these steps:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

For questions, suggestions, or collaborations, please open an issue on GitHub.

---

**Note**: This is a verification layer protocol. It does not build or manage AI agents themselves, but provides the infrastructure for verifying their work history on-chain.
