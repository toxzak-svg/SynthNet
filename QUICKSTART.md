# Quick Start Guide

## Installation

```bash
git clone https://github.com/toxzak-svg/SynthNet.git
cd SynthNet
npm install
```

## Quick Compilation Check

```bash
# Verify the contract compiles
./scripts/compile-simple.sh
```

## Basic Usage Example

### 1. Deploy the Contract

```javascript
const { ethers } = require("hardhat");

async function deployContract() {
    const verificationFee = ethers.parseEther("0.01"); // 0.01 ETH per job
    
    const AIAgentResumeSBT = await ethers.getContractFactory("AIAgentResumeSBT");
    const contract = await AIAgentResumeSBT.deploy(verificationFee);
    await contract.waitForDeployment();
    
    console.log("Contract deployed at:", await contract.getAddress());
    return contract;
}
```

### 2. Register an AI Agent

```javascript
async function registerAgent(contract, agentAddress) {
    const tx = await contract.registerAgent(agentAddress);
    await tx.wait();
    
    const tokenId = await contract.getAgentTokenId(agentAddress);
    console.log(`Agent registered with token ID: ${tokenId}`);
    return tokenId;
}
```

### 3. Add a Verified Job

```javascript
async function addAndVerifyJob(contract, agentAddress, verifierSigner) {
    // Get verification fee
    const fee = await contract.verificationFee();
    
    // Add job record
    const jobTx = await contract.addJobRecord(
        agentAddress,
        0, // TradeExecution
        "Executed $10K Uniswap swap successfully",
        ethers.id("proof-hash"),
        ethers.parseEther("10000"),
        { value: fee }
    );
    await jobTx.wait();
    
    // Verify the job
    const verifyTx = await contract.connect(verifierSigner).verifyJob(
        agentAddress,
        0, // jobId
        1, // Verified
        true // success
    );
    await verifyTx.wait();
    
    console.log("Job added and verified!");
}
```

### 4. Query Agent Statistics

```javascript
async function getAgentProfile(contract, agentAddress) {
    // Get statistics
    const stats = await contract.getAgentStats(agentAddress);
    
    console.log("Agent Profile:");
    console.log(`- Total Jobs: ${stats.totalJobs}`);
    console.log(`- Successful Jobs: ${stats.successfulJobs}`);
    console.log(`- Failed Jobs: ${stats.failedJobs}`);
    console.log(`- Reputation: ${stats.reputation}`);
    console.log(`- Success Rate: ${stats.successfulJobs / stats.totalJobs * 100}%`);
    
    // Get full job history
    const jobs = await contract.getAgentJobs(agentAddress);
    console.log("\nJob History:");
    jobs.forEach((job, i) => {
        console.log(`  Job ${i}: ${job.description}`);
        console.log(`    Status: ${["Pending", "Verified", "Failed", "Disputed"][job.status]}`);
        console.log(`    Success: ${job.success}`);
    });
}
```

## Running the Example

```bash
# Run the complete example script
npx hardhat run scripts/example.js --network hardhat
```

## Common Operations

### For DAOs (Evaluating Agents)

```javascript
// Check if agent meets minimum requirements
async function meetsRequirements(contract, agentAddress) {
    const stats = await contract.getAgentStats(agentAddress);
    
    // Example requirements
    const minJobs = 5;
    const minReputation = 30;
    const minSuccessRate = 0.8; // 80%
    
    const successRate = stats.totalJobs > 0 
        ? Number(stats.successfulJobs) / Number(stats.totalJobs)
        : 0;
    
    return (
        stats.totalJobs >= minJobs &&
        stats.reputation >= minReputation &&
        successRate >= minSuccessRate
    );
}
```

### For Employers (Recording Jobs)

```javascript
// Record a treasury management job
async function recordTreasuryJob(contract, agentAddress, treasurySize, duration) {
    const fee = await contract.verificationFee();
    
    const description = `Managed $${ethers.formatEther(treasurySize)} treasury for ${duration} days`;
    const proofHash = ethers.id(JSON.stringify({
        treasurySize: treasurySize.toString(),
        duration,
        timestamp: Date.now()
    }));
    
    const tx = await contract.addJobRecord(
        agentAddress,
        1, // TreasuryManagement
        description,
        proofHash,
        treasurySize,
        { value: fee }
    );
    
    await tx.wait();
    console.log("Treasury management job recorded");
}
```

### For Verifiers

```javascript
// Verify a job with detailed checks
async function verifyJobWithChecks(contract, agentAddress, jobId, proofData) {
    // Get job details
    const job = await contract.getJobRecord(agentAddress, jobId);
    
    // Verify proof (implementation depends on job type)
    const isValid = await validateProof(job.proofHash, proofData);
    
    if (isValid) {
        await contract.verifyJob(
            agentAddress,
            jobId,
            1, // Verified
            true // success
        );
        console.log(`Job ${jobId} verified as successful`);
    } else {
        await contract.verifyJob(
            agentAddress,
            jobId,
            2, // Failed
            false // not successful
        );
        console.log(`Job ${jobId} marked as failed`);
    }
}
```

## Important Notes

### Soulbound Token Behavior

The tokens are **non-transferable**. Any attempt to transfer will fail:

```javascript
// This will FAIL
try {
    await contract.connect(agent).transferFrom(agent.address, other.address, tokenId);
} catch (error) {
    console.log("Transfer blocked: Token is soulbound");
}
```

### Fee Management

Always check the current fee before adding jobs:

```javascript
const currentFee = await contract.verificationFee();
console.log(`Current fee: ${ethers.formatEther(currentFee)} ETH`);
```

### Verifier Authorization

Only authorized verifiers can verify jobs:

```javascript
// Owner adds verifier
await contract.addVerifier(verifierAddress);

// Check if address is a verifier
const isVerifier = await contract.verifiers(someAddress);
```

## Testing

The project includes comprehensive tests. Run them with:

```bash
# Note: Requires network access for compiler download
# If network is restricted, use the compile-simple.sh script instead
npx hardhat test
```

## Deployment to Networks

### Local Network

```bash
# Terminal 1: Start local node
npx hardhat node

# Terminal 2: Deploy
npx hardhat run scripts/deploy.js --network localhost
```

### Testnet (e.g., Sepolia)

1. Add network configuration to `hardhat.config.js`
2. Set up your private key (use environment variables!)
3. Deploy:

```bash
npx hardhat run scripts/deploy.js --network sepolia
```

## Support

For issues or questions:
- Check the [API Documentation](./API.md)
- Review the [Technical Documentation](./TECHNICAL.md)
- Open an issue on GitHub

## Next Steps

1. Review the smart contract: `contracts/AIAgentResumeSBT.sol`
2. Study the test suite: `test/AIAgentResumeSBT.test.js`
3. Run the example: `scripts/example.js`
4. Read the technical documentation: `TECHNICAL.md`
5. Explore the API reference: `API.md`
