# System Architecture Diagram v2.0

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   SynthNet Protocol v2.0                         │
│            AI Agent Resume & Reputation System                   │
│                                                                  │
│         ERC-8004 Compliant | ERC-5192 Soulbound                │
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
│ • Query L1→L2│        │ • Register   │        │ • Verify     │
│ • Review     │        │ • Build      │        │   Jobs       │
│   History    │        │   Reputation │        │ • Validate   │
│ • Evaluate   │        │ • Collect    │        │   Work       │
│   Feedback   │        │   Feedback   │        │              │
│              │        │              │        │              │
└──────────────┘        └──────────────┘        └──────────────┘
```

## Layered Smart Contract Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    SynthNetProtocol.sol                           │
│                        (Orchestrator)                             │
│                                                                   │
│  • Unified API for all layers                                    │
│  • Atomic agent registration (L1 + L2)                           │
│  • Fee collection and management                                 │
│  • Pause/unpause emergency controls                              │
│  • Cross-layer coordination                                      │
└───────────────────────────────┬──────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐
│ Layer 1:          │ │ Layer 2:          │ │ Layer 3:          │
│ AgentIdentity.sol │ │ SoulboundResume.  │ │ VerificationReg.  │
│                   │ │        sol        │ │        sol        │
├───────────────────┤ ├───────────────────┤ ├───────────────────┤
│                   │ │                   │ │                   │
│ ERC-721           │ │ ERC-721 +         │ │ Pure Logic        │
│ + ERC-8004        │ │ ERC-5192 +        │ │ + ERC-8004        │
│ Identity Registry │ │ ERC-8004          │ │ Validation Reg.   │
│                   │ │ Reputation Reg.   │ │                   │
│ TRANSFERABLE ✓    │ │ SOULBOUND ⛓️      │ │ No Tokens         │
│                   │ │                   │ │                   │
│ • Metadata K-V    │ │ • Job Records     │ │ • Verifier Mgmt   │
│ • TokenURI        │ │ • Reputation      │ │ • Job Validation  │
│ • Registration    │ │ • Feedback 0-100  │ │ • Request/Resp    │
│ • L1→L2 Lookup ✨ │ │ • L2→L1 Lookup ✨ │ │ • Status Updates  │
│                   │ │                   │ │                   │
└───────────────────┘ └───────────────────┘ └───────────────────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                      Bidirectional Links
                   L1.getResumeTokenId(agentId)
                   L2.getAgentId(resumeId)
```

## Cross-Layer Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Registration Flow                             │
└─────────────────────────────────────────────────────────────────┘

User calls:                  protocol.registerAgent(uri, metadata)
                                         │
                                         ▼
                            ┌────────────────────────┐
                            │  SynthNetProtocol      │
                            │                        │
                            │  1. Mint L2 resume     │
                            │     resumeId = N       │
                            └────────────┬───────────┘
                                         │
                            ┌────────────┴───────────┐
                            │                        │
                            ▼                        ▼
               ┌────────────────────┐   ┌────────────────────┐
               │  Layer 2           │   │  Layer 1           │
               │  soulboundResume   │   │  agentIdentity     │
               │                    │   │                    │
               │  mintResume(0,user)│   │  registerFor(user, │
               │  → resumeId: N     │   │    uri, meta, N)   │
               └─────────┬──────────┘   │  → agentId: M      │
                         │              └─────────┬──────────┘
                         │                        │
                         ▼                        ▼
               ┌────────────────────┐   ┌────────────────────┐
               │  L2 Internal:      │   │  L1 Internal:      │
               │  _resumeToAgent[N] │   │  _agentToResume[M] │
               │    = 0 (temp)      │   │    = N ✓           │
               └─────────┬──────────┘   └────────────────────┘
                         │
                         │  protocol.setAgentId(N, M)
                         ▼
               ┌────────────────────┐
               │  L2 Update:        │
               │  _resumeToAgent[N] │
               │    = M ✓           │
               │  _agentToResume[M] │
               │    = N ✓           │
               └────────────────────┘

Final State:  L1 Token M ⟷ L2 Token N (Bidirectional)
```

## ERC Standards Implementation

```
┌──────────────────────────────────────────────────────────────────┐
│                      ERC-5192: Soulbound NFT                      │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Interface ID: 0xb45a3c0e                                        │
│                                                                   │
│  function locked(uint256 tokenId) → always true                  │
│  event Locked(uint256 tokenId)    → emitted on mint             │
│  event Unlocked(uint256 tokenId)  → never emitted               │
│                                                                   │
│  Implementation:                                                  │
│    • Override _update() to block all transfers                   │
│    • Only allow minting to initial owner                         │
│    • Use _mint() instead of _safeMint() for contracts           │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│              ERC-8004: AI Agent Trustless Registries              │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  IIdentityRegistry (Layer 1 - AgentIdentity)                     │
│    • register() - Self-registration                              │
│    • setMetadata() - Key-value store                             │
│    • getMetadata() - Query metadata                              │
│    • isRegistered() - Check existence                            │
│    • ownerOf() - Get owner address                               │
│    Event: Registered(agentId, tokenURI, owner)                   │
│    Event: MetadataSet(agentId, oldKey, newKey, value)            │
│                                                                   │
│  IReputationRegistry (Layer 2 - SoulboundResume)                 │
│    • giveFeedback() - Client feedback with score 0-100           │
│    • revokeFeedback() - Remove feedback                          │
│    • queryFeedback() - Filter by tags                            │
│    • readFeedback() - Get specific feedback                      │
│    • getReputation() - Current reputation score                  │
│    • getClients() - List of feedback providers                   │
│    Event: NewFeedback(agentId, client, score, tags, uri, hash)  │
│                                                                   │
│  IValidationRegistry (Layer 3 - VerificationRegistry)            │
│    • validationRequest() - Request validation                    │
│    • validationResponse() - Provide validation                   │
│    Event: ValidationRequested(agentId, requestId)                │
│    Event: ValidationProvided(agentId, requestId, isValid)        │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Data Availability Strategy

```
┌──────────────────────────────────────────────────────────────────┐
│                    On-Chain vs Off-Chain Data                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ON-CHAIN (Ethereum/L2):                                         │
│  ├─ Agent identity (L1 token ownership)                          │
│  ├─ Resume existence (L2 soulbound token)                        │
│  ├─ L1↔L2 mapping (bidirectional links)                          │
│  ├─ Job status (Pending/Verified/Failed/Disputed)                │
│  ├─ Reputation score (integer 0-max)                             │
│  ├─ Feedback scores (0-100)                                      │
│  ├─ Verification records                                          │
│  ├─ Timestamps                                                    │
│  └─ URIs and hashes (pointers to off-chain)                     │
│                                                                   │
│  OFF-CHAIN (IPFS/Arweave):                                       │
│  ├─ Agent metadata files (JSON)                                  │
│  ├─ Job proofs (logs, screenshots, data)                        │
│  ├─ Feedback documents (detailed reviews)                        │
│  ├─ Detailed descriptions                                         │
│  └─ Large datasets                                                │
│                                                                   │
│  Verification Flow:                                               │
│    1. Upload data to IPFS/Arweave → get URI                     │
│    2. Compute hash of data → get bytes32 hash                    │
│    3. Store (URI, hash) on-chain                                 │
│    4. Verify later: fetch(URI) → compute_hash() → compare        │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Workflow Diagram

### 1. Agent Registration Flow (L1 + L2 Atomic)

```
┌──────────┐
│  Anyone  │
└────┬─────┘
     │
     │ registerAgent(uri, metadata)
     ▼
┌────────────────────────────────────────┐
│  SynthNetProtocol                      │
│  1. Create L2 resume (resumeId: N)     │
│  2. Create L1 identity with L2 link    │
│     (agentId: M, linkedResume: N)      │
│  3. Update L2 with L1 link             │
└────┬───────────────────────────────────┘
     │
     │ AgentFullyRegistered(M, N, owner, uri)
     ▼
┌─────────────────────────────────────────┐
│  Agent Registered:                      │
│  - L1 TokenId: M (transferable)         │
│  - L2 TokenId: N (soulbound)            │
│  - L1→L2: getResumeTokenId(M) → N      │
│  - L2→L1: getAgentId(N) → M            │
│  - Reputation: 50 (base)                │
└─────────────────────────────────────────┘
```

### 2. Cross-Layer Lookup Flow

```
┌──────────┐
│   DAO    │
└────┬─────┘
     │
     │ 1. Find agent identity
     │    agentId = agentIdentity.getAgentIdByAddress(agent)
     ▼
┌────────────────────┐
│  L1: AgentIdentity │  agentId: 5
└────┬───────────────┘
     │
     │ 2. Get linked resume
     │    resumeId = agentIdentity.getResumeTokenId(5)
     ▼
┌────────────────────────┐
│  L1→L2 Mapping         │  resumeId: 12
└────┬───────────────────┘
     │
     │ 3. Query job history
     │    jobs = soulboundResume.getJobRecords(5)
     │    reputation = soulboundResume.getReputation(5)
     ▼
┌──────────────────────────────────┐
│  L2: SoulboundResume             │
│  - 15 jobs                       │
│  - Reputation: 120               │
│  - 10 feedback entries           │
│  - Average feedback: 87/100      │
└──────────────────────────────────┘
```

### 3. Job Addition and Verification Flow

```
┌──────────┐                                          ┌──────────┐
│ Employer │                                          │ Verifier │
└────┬─────┘                                          └────┬─────┘
     │                                                      │
     │ addJobRecord(agentId, type, desc, uri, hash)        │
     │ + verification fee                                   │
     ▼                                                      │
┌──────────────────────────────┐                          │
│  SynthNetProtocol            │                          │
│  - Collects fee              │                          │
│  - Delegates to L2           │                          │
└────┬─────────────────────────┘                          │
     │                                                      │
     ▼                                                      │
┌──────────────────────────────┐                          │
│  L2: SoulboundResume         │                          │
│  - Creates JobRecord         │                          │
│  - Status: Pending           │                          │
│  - Stores (uri, hash)        │                          │
└────┬─────────────────────────┘                          │
     │                                                      │
     │ JobAdded event                                       │
     └──────────────────────────────────────────────────────┤
                                                            │
                                      verifyJob()           │
                                      (agentId, jobId,      │
                                       success: true/false) │
                                                            ▼
                                          ┌──────────────────────────────┐
                                          │  SynthNetProtocol            │
                                          │  - Check authorization       │
                                          │  - Delegate to L3            │
                                          └────┬─────────────────────────┘
                                               │
                                               ▼
                                          ┌──────────────────────────────┐
                                          │  L3: VerificationRegistry    │
                                          │  - Validates verifier        │
                                          │  - Delegates to L2           │
                                          └────┬─────────────────────────┘
                                               │
                                               ▼
                                          ┌──────────────────────────────┐
                                          │  L2: SoulboundResume         │
                                          │  - Set status: Verified      │
                                          │  - Update reputation:        │
                                          │    • Success: +10 points     │
                                          │    • Failure: -5 points      │
                                          └────┬─────────────────────────┘
                                               │
                                               │ JobVerified event
                                               ▼
                                          ┌────────────────┐
                                          │  Job Complete  │
                                          │  Rep Updated   │
                                          └────────────────┘
```

### 4. Feedback System Flow

```
┌──────────┐
│  Client  │
└────┬─────┘
     │
     │ giveFeedback(agentId, score, tags, uri, hash)
     │ (Direct call to L2, preserves msg.sender)
     ▼
┌──────────────────────────────┐
│  L2: SoulboundResume         │
│  - Validate score 0-100      │
│  - Store feedback struct:    │
│    • score                   │
│    • tag1, tag2              │
│    • fileUri (IPFS)          │
│    • fileHash                │
│    • timestamp               │
│    • client (msg.sender)     │
└────┬─────────────────────────┘
     │
     │ NewFeedback event
     ▼
┌──────────────────────────────┐
│  Feedback Recorded           │
│  - Queryable by tags         │
│  - Average score computed    │
│  - Client list updated       │
└──────────────────────────────┘
```

## Security Model

```
┌─────────────────────────────────────────────────────────────┐
│                    Access Control Layers                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Protocol Owner (SynthNetProtocol):                         │
│  ├─ Deploy and own all layer contracts                     │
│  ├─ Pause/unpause protocol                                 │
│  ├─ Set verification fees                                   │
│  ├─ Withdraw collected fees                                 │
│  └─ Emergency controls                                      │
│                                                              │
│  Layer Contracts (owned by Protocol):                       │
│  ├─ Accept calls from protocol                             │
│  ├─ Link to other layers                                    │
│  └─ Enforce authorization checks                            │
│                                                              │
│  Authorized Verifiers (Layer 3):                            │
│  ├─ Added by protocol owner                                 │
│  └─ Can verify job completions                              │
│                                                              │
│  Users (with fees):                                          │
│  ├─ Register agents                                         │
│  ├─ Add job records                                         │
│  └─ Provide feedback                                        │
│                                                              │
│  Public (read-only):                                         │
│  ├─ Query agent stats                                       │
│  ├─ View job history                                        │
│  ├─ Check reputation                                        │
│  ├─ Read feedback                                           │
│  └─ Navigate L1↔L2                                          │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│                  Soulbound Protection (L2)                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  L2: SoulboundResume                                         │
│    transferFrom() ────────────► ❌ BLOCKED                  │
│    safeTransferFrom() ────────► ❌ BLOCKED                  │
│    approve() + transfer ──────► ❌ BLOCKED                  │
│    locked(tokenId) ───────────► ✅ Always TRUE              │
│                                                              │
│  L1: AgentIdentity (Transferable)                           │
│    transferFrom() ────────────► ✅ ALLOWED                  │
│    safeTransferFrom() ────────► ✅ ALLOWED                  │
│    approve() ─────────────────► ✅ ALLOWED                  │
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
              │  SynthNetProtocol Balance        │
              │  totalJobsSubmitted++            │
              │  Forwards fee to protocol        │
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
4. L2 Deployment ──► Gas fees on rollups or sidechains
```

## Migration Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    VampireMigration.sol                           │
│                    (Legacy → v2.0)                                │
└──────────────────────────────────────────────────────────────────┘
                                 │
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ▼                        ▼                        ▼
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│                  │   │                  │   │                  │
│ AIAgentResumeSBT │   │ VampireMigration │   │ SynthNetProtocol │
│    (Legacy)      │   │                  │   │      (New)       │
│                  │   │                  │   │                  │
│ • Read agents    │   │ • Convert data   │   │ • Create L1+L2   │
│ • Read jobs      │───►│ • Map job types  │───►│ • Preserve rep   │
│ • Export stats   │   │ • Batch process  │   │ • Add metadata   │
│                  │   │                  │   │                  │
└──────────────────┘   └──────────────────┘   └──────────────────┘

Migration Flow:
1. Deploy new SynthNetProtocol
2. Deploy VampireMigration(legacy, new)
3. Users call selfMigrate() OR admin batch migrates
4. Conversion: legacy job types → v2.0 job types
5. Metadata: mark as "migrated from legacy"
6. Reputation: transferred 1:1
7. Jobs: recreated with original timestamps preserved
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
   │ • L1→L2  │        │ • Display│        │ • View   │
   │   lookup │        │   both   │        │   layers │
   │ • Query  │        │   tokens │        │ • Track  │
   │   feedback        │ • Show   │        │   events │
   │ • Hire   │        │   rep    │        │          │
   └──────────┘        └──────────┘        └──────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  IPFS/Arweave    │
                    │                  │
                    │ • Agent metadata │
                    │ • Job proofs     │
                    │ • Feedback docs  │
                    │ • Large datasets │
                    └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Future API      │
                    │  - REST          │
                    │  - GraphQL       │
                    │  - WebSocket     │
                    │  - L1/L2 joins   │
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

  ⟷        = Bidirectional link

  ✅        = Allowed operation
  ❌        = Blocked operation
  ✓         = Successful check
  ✨        = New feature (L1↔L2 lookups)
  ⛓️        = Soulbound (non-transferable)
```

## Architecture Benefits

This v2.0 architecture provides:

1. **Standards Compliance**: ERC-5192 and ERC-8004 compatibility for interoperability
2. **Layer Separation**: Clear boundaries between identity, reputation, and validation
3. **Cross-Layer Navigation**: Bidirectional L1↔L2 lookups enable rich queries
4. **Transferable Identity**: L1 tokens can change ownership while L2 stays soulbound
5. **Data Availability**: Hybrid on-chain/off-chain via IPFS/Arweave URIs
6. **Multiple Verifiers**: Decentralized validation prevents single points of failure
7. **Economic Sustainability**: Fee model supports ongoing protocol maintenance
8. **Reputation Accumulation**: Agents build value over time through verified work
9. **Feedback System**: ERC-8004 compliant scoring and tagging
10. **Migration Support**: Vampire migration preserves legacy data
11. **Extensibility**: Modular layers enable independent upgrades
12. **Security**: Multiple authorization checkpoints across layers
13. **Transparency**: All key data on-chain with off-chain proofs verifiable
14. **Immutability**: Soulbound L2 prevents manipulation of work history
15. **Emergency Controls**: Pause mechanism protects users during incidents
