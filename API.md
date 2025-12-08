# AIAgentResumeSBT API Reference

## Contract Overview

**Contract Name**: `AIAgentResumeSBT`  
**Inheritance**: `ERC721`, `Ownable`  
**License**: MIT  
**Solidity Version**: ^0.8.20

## Enums

### JobType

```solidity
enum JobType {
    TradeExecution,      // 0: Did the agent execute the trade correctly?
    TreasuryManagement,  // 1: Did it manage the treasury without losing funds?
    ContentCompliance    // 2: Did it post compliant content?
}
```

### VerificationStatus

```solidity
enum VerificationStatus {
    Pending,    // 0: Job added but not yet verified
    Verified,   // 1: Job confirmed as successful
    Failed,     // 2: Job confirmed as unsuccessful
    Disputed    // 3: Job outcome under dispute
}
```

## Structs

### JobRecord

```solidity
struct JobRecord {
    uint256 jobId;              // Unique identifier for this job
    address employer;           // Address of the DAO/entity that hired the agent
    JobType jobType;            // Type of job performed
    VerificationStatus status;  // Current verification status
    uint256 timestamp;          // Unix timestamp when job was added
    string description;         // Human-readable job description
    bytes32 proofHash;          // Hash of proof data (tx hash, content hash, etc.)
    uint256 value;              // Economic value involved (in wei)
    bool success;               // Whether the job was successful
}
```

## State Variables

### Public Variables

```solidity
uint256 public verificationFee;
```
Fee required (in wei) to add a job record to an agent's resume.

```solidity
uint256 public totalFeesCollected;
```
Cumulative total of all verification fees collected by the contract.

```solidity
mapping(address => bool) public verifiers;
```
Mapping of addresses authorized to verify job records.

## Events

### AgentRegistered
```solidity
event AgentRegistered(address indexed agent, uint256 indexed tokenId);
```
Emitted when a new AI agent is registered and receives their SBT.

**Parameters**:
- `agent`: Address of the registered agent
- `tokenId`: Token ID assigned to the agent

### JobAdded
```solidity
event JobAdded(uint256 indexed tokenId, uint256 indexed jobId, JobType jobType);
```
Emitted when a new job record is added to an agent's resume.

**Parameters**:
- `tokenId`: Agent's token ID
- `jobId`: ID of the new job record
- `jobType`: Type of job added

### JobVerified
```solidity
event JobVerified(uint256 indexed tokenId, uint256 indexed jobId, VerificationStatus status);
```
Emitted when a job is verified.

**Parameters**:
- `tokenId`: Agent's token ID
- `jobId`: ID of the verified job
- `status`: New verification status

### VerificationFeeUpdated
```solidity
event VerificationFeeUpdated(uint256 oldFee, uint256 newFee);
```
Emitted when the verification fee is updated.

**Parameters**:
- `oldFee`: Previous fee amount (in wei)
- `newFee`: New fee amount (in wei)

### VerifierAdded
```solidity
event VerifierAdded(address indexed verifier);
```
Emitted when a new verifier is authorized.

**Parameters**:
- `verifier`: Address of the new verifier

### VerifierRemoved
```solidity
event VerifierRemoved(address indexed verifier);
```
Emitted when a verifier's authorization is revoked.

**Parameters**:
- `verifier`: Address of the removed verifier

### ReputationUpdated
```solidity
event ReputationUpdated(uint256 indexed tokenId, uint256 newScore);
```
Emitted when an agent's reputation score changes.

**Parameters**:
- `tokenId`: Agent's token ID
- `newScore`: New reputation score

## Functions

### Constructor

```solidity
constructor(uint256 _verificationFee)
```

Initializes the contract with a verification fee.

**Parameters**:
- `_verificationFee`: Initial fee required to add job records (in wei)

**Example**:
```javascript
const fee = ethers.parseEther("0.01");
const contract = await AIAgentResumeSBT.deploy(fee);
```

---

### registerAgent

```solidity
function registerAgent(address agent) external returns (uint256)
```

Registers a new AI agent and mints their Soulbound Token.

**Parameters**:
- `agent`: Address of the AI agent to register

**Returns**:
- `uint256`: Token ID assigned to the agent

**Requirements**:
- Agent address must not be zero address
- Agent must not already be registered

**Example**:
```javascript
const tokenId = await contract.registerAgent(agentAddress);
console.log(`Agent registered with token ID: ${tokenId}`);
```

---

### addJobRecord

```solidity
function addJobRecord(
    address agent,
    JobType jobType,
    string calldata description,
    bytes32 proofHash,
    uint256 value
) external payable returns (uint256)
```

Adds a job record to an agent's resume.

**Parameters**:
- `agent`: Address of the AI agent
- `jobType`: Type of job (0=TradeExecution, 1=TreasuryManagement, 2=ContentCompliance)
- `description`: Human-readable description of the job
- `proofHash`: Hash of proof data (transaction hash, content hash, etc.)
- `value`: Economic value involved in the job (in wei)

**Returns**:
- `uint256`: Job ID of the created record

**Requirements**:
- Must send at least `verificationFee` in ETH
- Agent must be registered

**Example**:
```javascript
const jobType = 0; // TradeExecution
const description = "Executed $10K swap on Uniswap";
const proofHash = ethers.id("proof-data-string");
const value = ethers.parseEther("10000");
const fee = await contract.verificationFee();

const jobId = await contract.addJobRecord(
    agentAddress,
    jobType,
    description,
    proofHash,
    value,
    { value: fee }
);
```

---

### verifyJob

```solidity
function verifyJob(
    address agent,
    uint256 jobId,
    VerificationStatus status,
    bool success
) external
```

Verifies a job record. Only callable by authorized verifiers or owner.

**Parameters**:
- `agent`: Address of the AI agent
- `jobId`: ID of the job to verify
- `status`: New verification status
- `success`: Whether the job was successful

**Requirements**:
- Caller must be owner or authorized verifier
- Agent must be registered
- Job ID must be valid
- Job must be in Pending status

**Effects**:
- Updates job status and success flag
- Adjusts agent's reputation score:
  - Verified + Success: +10 points
  - Failed: -5 points (minimum 0)

**Example**:
```javascript
await contract.connect(verifier).verifyJob(
    agentAddress,
    0, // jobId
    1, // Verified
    true // success
);
```

---

### getAgentJobs

```solidity
function getAgentJobs(address agent) external view returns (JobRecord[] memory)
```

Retrieves all job records for an agent.

**Parameters**:
- `agent`: Address of the AI agent

**Returns**:
- `JobRecord[]`: Array of all job records

**Requirements**:
- Agent must be registered

**Example**:
```javascript
const jobs = await contract.getAgentJobs(agentAddress);
jobs.forEach(job => {
    console.log(`Job ${job.jobId}: ${job.description}`);
});
```

---

### getJobRecord

```solidity
function getJobRecord(address agent, uint256 jobId) external view returns (JobRecord memory)
```

Retrieves a specific job record.

**Parameters**:
- `agent`: Address of the AI agent
- `jobId`: ID of the job

**Returns**:
- `JobRecord`: The job record struct

**Requirements**:
- Agent must be registered
- Job ID must be valid

**Example**:
```javascript
const job = await contract.getJobRecord(agentAddress, 0);
console.log(`Description: ${job.description}`);
console.log(`Status: ${job.status}`);
```

---

### getReputationScore

```solidity
function getReputationScore(address agent) external view returns (uint256)
```

Gets the reputation score for an agent.

**Parameters**:
- `agent`: Address of the AI agent

**Returns**:
- `uint256`: Current reputation score

**Requirements**:
- Agent must be registered

**Example**:
```javascript
const reputation = await contract.getReputationScore(agentAddress);
console.log(`Agent reputation: ${reputation}`);
```

---

### getAgentStats

```solidity
function getAgentStats(address agent) external view returns (
    uint256 totalJobs,
    uint256 successfulJobs,
    uint256 failedJobs,
    uint256 reputation
)
```

Gets comprehensive statistics for an agent.

**Parameters**:
- `agent`: Address of the AI agent

**Returns**:
- `totalJobs`: Total number of jobs recorded
- `successfulJobs`: Number of verified successful jobs
- `failedJobs`: Number of failed jobs
- `reputation`: Current reputation score

**Requirements**:
- Agent must be registered

**Example**:
```javascript
const stats = await contract.getAgentStats(agentAddress);
console.log(`Total Jobs: ${stats.totalJobs}`);
console.log(`Success Rate: ${stats.successfulJobs / stats.totalJobs * 100}%`);
console.log(`Reputation: ${stats.reputation}`);
```

---

### getAgentTokenId

```solidity
function getAgentTokenId(address agent) external view returns (uint256)
```

Gets the token ID for an agent address.

**Parameters**:
- `agent`: Address of the AI agent

**Returns**:
- `uint256`: Token ID (0 if not registered)

**Example**:
```javascript
const tokenId = await contract.getAgentTokenId(agentAddress);
```

---

### isAgentRegistered

```solidity
function isAgentRegistered(address agent) external view returns (bool)
```

Checks if an agent is registered.

**Parameters**:
- `agent`: Address to check

**Returns**:
- `bool`: True if registered, false otherwise

**Example**:
```javascript
if (await contract.isAgentRegistered(agentAddress)) {
    console.log("Agent is registered");
}
```

---

### setVerificationFee

```solidity
function setVerificationFee(uint256 newFee) external onlyOwner
```

Updates the verification fee. Only callable by owner.

**Parameters**:
- `newFee`: New fee amount (in wei)

**Example**:
```javascript
const newFee = ethers.parseEther("0.02");
await contract.setVerificationFee(newFee);
```

---

### addVerifier

```solidity
function addVerifier(address verifier) external onlyOwner
```

Authorizes a new verifier. Only callable by owner.

**Parameters**:
- `verifier`: Address to authorize

**Requirements**:
- Verifier address must not be zero address

**Example**:
```javascript
await contract.addVerifier(verifierAddress);
```

---

### removeVerifier

```solidity
function removeVerifier(address verifier) external onlyOwner
```

Removes a verifier's authorization. Only callable by owner.

**Parameters**:
- `verifier`: Address to remove

**Example**:
```javascript
await contract.removeVerifier(verifierAddress);
```

---

### withdrawFees

```solidity
function withdrawFees() external onlyOwner
```

Withdraws collected fees to owner. Only callable by owner.

**Requirements**:
- Contract must have a positive balance

**Example**:
```javascript
await contract.withdrawFees();
```

---

## Soulbound Token Behavior

The token is **non-transferable** (soulbound). The following functions will revert:

- `transferFrom()`
- `safeTransferFrom()`
- Any function that attempts to change token ownership

**Error Message**: "Soulbound: Token is non-transferable"

## Gas Estimates

Approximate gas costs (may vary based on network conditions):

| Function | Estimated Gas |
|----------|--------------|
| registerAgent | ~150,000 |
| addJobRecord | ~100,000 |
| verifyJob | ~80,000 |
| getAgentJobs | View (free) |
| getAgentStats | View (free) |

## Error Messages

| Error | Cause |
|-------|-------|
| "Invalid agent address" | Zero address provided for agent |
| "Agent already registered" | Attempting to register same agent twice |
| "Agent not registered" | Operating on unregistered agent |
| "Insufficient verification fee" | Sent value < verificationFee |
| "Not authorized to verify" | Non-verifier attempting to verify |
| "Job already verified" | Attempting to verify non-pending job |
| "Invalid job ID" | Job ID out of range |
| "No fees to withdraw" | Contract balance is zero |
| "Soulbound: Token is non-transferable" | Attempting to transfer SBT |
