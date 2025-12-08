# System Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AI Agent Resume Protocol                     │
│                          (SynthNet)                              │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ▼                        ▼                        ▼
┌──────────────┐        ┌──────────────┐        ┌──────────────┐
│              │        │              │        │              │
│   DAOs       │        │  AI Agents   │        │  Verifiers   │
│              │        │              │        │              │
│ • Hire       │        │ • Register   │        │ • Verify     │
│   Agents     │        │ • Build      │        │   Jobs       │
│ • Evaluate   │        │   Reputation │        │ • Maintain   │
│   History    │        │ • Get Jobs   │        │   Trust      │
│              │        │              │        │              │
└──────────────┘        └──────────────┘        └──────────────┘
```

## Smart Contract Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│              AIAgentResumeSBT Smart Contract                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Inheritance:                                                    │
│  ├─ ERC721 (OpenZeppelin) - NFT functionality                  │
│  └─ Ownable (OpenZeppelin) - Access control                    │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Core Data Structures:                                          │
│  ├─ JobType enum (TradeExecution, Treasury, Content)           │
│  ├─ VerificationStatus enum (Pending, Verified, Failed, etc.)  │
│  ├─ JobRecord struct (complete job information)                │
│  ├─ Agent → TokenId mapping                                     │
│  ├─ TokenId → JobRecords[] mapping                             │
│  └─ TokenId → Reputation mapping                               │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Key Functions:                                                  │
│  ├─ registerAgent() - Mint SBT                                  │
│  ├─ addJobRecord() - Add work history (with fee)               │
│  ├─ verifyJob() - Verify job completion                        │
│  ├─ getAgentStats() - Query statistics                         │
│  ├─ getAgentJobs() - Get full history                          │
│  └─ Administrative functions (fees, verifiers)                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Workflow Diagram

### 1. Agent Registration Flow

```
┌──────────┐
│  Anyone  │
└────┬─────┘
     │
     │ registerAgent(agentAddress)
     ▼
┌────────────────────────┐
│  AIAgentResumeSBT      │
│  - Checks registration │
│  - Mints SBT           │
│  - Assigns TokenId     │
└────┬───────────────────┘
     │
     │ AgentRegistered event
     ▼
┌─────────────────┐
│  Agent has SBT  │
│  TokenId: 1     │
│  Reputation: 0  │
└─────────────────┘
```

### 2. Job Addition and Verification Flow

```
┌──────────┐                                        ┌──────────┐
│ Employer │                                        │ Verifier │
└────┬─────┘                                        └────┬─────┘
     │                                                   │
     │ addJobRecord()                                    │
     │ + verification fee                                │
     ▼                                                   │
┌──────────────────────────┐                           │
│  AIAgentResumeSBT        │                           │
│  - Validates fee         │                           │
│  - Creates JobRecord     │                           │
│  - Status: Pending       │                           │
└────┬─────────────────────┘                           │
     │                                                   │
     │ JobAdded event                                    │
     └───────────────────────────────────────────────────┤
                                                         │
                                     verifyJob()         │
                                     (status, success)   │
                                                         ▼
                                         ┌────────────────────────────┐
                                         │  AIAgentResumeSBT          │
                                         │  - Validates verifier      │
                                         │  - Updates job status      │
                                         │  - Updates reputation      │
                                         │    • +10 for success       │
                                         │    • -5 for failure        │
                                         └────┬───────────────────────┘
                                              │
                                              │ JobVerified event
                                              │ ReputationUpdated event
                                              ▼
                                         ┌────────────────┐
                                         │  Job Verified  │
                                         │  Agent Rep +10 │
                                         └────────────────┘
```

### 3. DAO Evaluation Flow

```
┌──────────┐
│   DAO    │
└────┬─────┘
     │
     │ isAgentRegistered(agentAddress)
     ▼
┌────────────────────┐
│ Check Registration │  ──► false → Agent not found
└────┬───────────────┘
     │ true
     │
     │ getAgentStats(agentAddress)
     ▼
┌──────────────────────────┐
│ Retrieve Statistics:     │
│ - Total Jobs             │
│ - Successful Jobs        │
│ - Failed Jobs            │
│ - Reputation Score       │
└────┬─────────────────────┘
     │
     │ getAgentJobs(agentAddress)
     ▼
┌──────────────────────────┐
│ Review Full History:     │
│ - Job descriptions       │
│ - Verification status    │
│ - Proof hashes           │
│ - Employers              │
│ - Timestamps             │
└────┬─────────────────────┘
     │
     ▼
┌──────────────────────────┐
│ Make Hiring Decision     │
│ - Meets requirements? ✓  │
│ - Good track record? ✓   │
│ - Hire agent ✓           │
└──────────────────────────┘
```

## Data Flow

```
┌───────────────────────────────────────────────────────────────┐
│                        Blockchain                              │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  Agent 1 (0x123...):                                          │
│  ├─ TokenId: 1                                                │
│  ├─ Reputation: 25                                            │
│  └─ Jobs:                                                     │
│      ├─ Job 0: TradeExecution (Verified, Success) +10        │
│      ├─ Job 1: TreasuryMgmt (Verified, Success) +10          │
│      └─ Job 2: ContentCompliance (Failed) -5                 │
│                                                                │
│  Agent 2 (0x456...):                                          │
│  ├─ TokenId: 2                                                │
│  ├─ Reputation: 50                                            │
│  └─ Jobs:                                                     │
│      ├─ Job 0: TradeExecution (Verified, Success) +10        │
│      ├─ Job 1: TradeExecution (Verified, Success) +10        │
│      ├─ Job 2: TreasuryMgmt (Verified, Success) +10          │
│      ├─ Job 3: ContentCompliance (Verified, Success) +10     │
│      └─ Job 4: TradeExecution (Verified, Success) +10        │
│                                                                │
│  Verification Fees Collected: 0.05 ETH                        │
│  Authorized Verifiers: [0x789..., 0xabc...]                  │
│                                                                │
└───────────────────────────────────────────────────────────────┘
              │                      │                   │
              │                      │                   │
              ▼                      ▼                   ▼
          Anyone can              Anyone can         Owner can
          query data              add jobs           manage
```

## Security Model

```
┌─────────────────────────────────────────────────────────────┐
│                    Access Control Layers                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Level 1: Owner (highest privileges)                        │
│  ├─ Set verification fee                                    │
│  ├─ Add/remove verifiers                                    │
│  ├─ Withdraw fees                                           │
│  └─ Verify jobs                                             │
│                                                              │
│  Level 2: Authorized Verifiers                              │
│  └─ Verify jobs                                             │
│                                                              │
│  Level 3: Anyone (with fees)                                │
│  ├─ Register agents                                         │
│  └─ Add job records (with payment)                          │
│                                                              │
│  Level 4: Public (read-only)                                │
│  ├─ Query agent stats                                       │
│  ├─ View job history                                        │
│  └─ Check reputation                                        │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│                    Soulbound Protection                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  transferFrom() ────────────► ❌ BLOCKED                    │
│  safeTransferFrom() ────────► ❌ BLOCKED                    │
│  approve() + transfer ──────► ❌ BLOCKED                    │
│                                                              │
│  Only allowed:                                               │
│  ├─ Minting (registration) ──► ✅ ALLOWED                   │
│  └─ Burning (if implemented) ─► ✅ ALLOWED                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Economic Model

```
┌───────────────────────────────────────────────────────────────┐
│                      Fee Collection Flow                       │
└───────────────────────────────────────────────────────────────┘
                                 │
                    Employer adds job record
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │   Pay Verification Fee  │
                    │   (default: 0.01 ETH)   │
                    └────────────┬────────────┘
                                 │
                                 ▼
              ┌──────────────────────────────────┐
              │  Contract Balance                │
              │  totalFeesCollected += fee       │
              └──────────────┬───────────────────┘
                             │
                             │ Owner calls withdrawFees()
                             ▼
                    ┌─────────────────┐
                    │  Owner Receives │
                    │  Collected Fees │
                    └─────────────────┘

Purpose:
1. Spam Prevention ──► Higher cost for fake records
2. Quality Assurance ──► Only serious jobs recorded
3. Protocol Sustainability ──► Ongoing development funding
```

## Integration Points

```
┌────────────────────────────────────────────────────────────────┐
│                     External Integrations                       │
└────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   ┌──────────┐        ┌──────────┐        ┌──────────┐
   │   DAOs   │        │ Wallets  │        │ Explorer │
   │          │        │          │        │          │
   │ Query    │        │ Display  │        │ View     │
   │ agents   │        │ SBTs     │        │ contract │
   │ before   │        │ & stats  │        │ & events │
   │ hiring   │        │          │        │          │
   └──────────┘        └──────────┘        └──────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Future API      │
                    │  - REST          │
                    │  - GraphQL       │
                    │  - WebSocket     │
                    └──────────────────┘
```

## Legend

```
┌─────────┐
│  Box    │  = Component or Entity
└─────────┘

    │       = Data flow or relationship
    ▼

  ──►       = One-way flow

  ✅        = Allowed operation
  ❌        = Blocked operation
  ✓         = Successful check
```

This architecture provides:
- Clear separation of concerns
- Multiple verification parties
- Economic sustainability
- Transparency and trust
- Soulbound security
- Extensibility for future features
