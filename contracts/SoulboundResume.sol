// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IERC5192.sol";
import "./interfaces/IERC8004.sol";

/**
 * @title SoulboundResume - Layer 2: AI Agent Proof-of-Work Resume
 * @notice ERC-5192 compliant soulbound token for job history and reputation
 * @dev This is Layer 2 of the SynthNet protocol stack
 *      - Non-transferable (soulbound) tokens representing work history
 *      - Stores job records with off-chain proof references (IPFS/Arweave)
 *      - Reputation scoring based on verified job performance
 *      - Links to Layer 1 (AgentIdentity) for agent identity
 *      - Links to Layer 3 (VerificationRegistry) for job verification
 * 
 * Architecture:
 *   Layer 1 (AgentIdentity) - Identity & Metadata
 *   Layer 2 (SoulboundResume) - Job History & Reputation (ERC-5192) <-- THIS
 *   Layer 3 (VerificationRegistry) - Validation & Verification
 * 
 * Data Availability:
 *   - On-chain: Job metadata, status, reputation scores
 *   - Off-chain (IPFS/Arweave): Detailed proofs, logs, performance data
 */
contract SoulboundResume is ERC721, Ownable, ReentrancyGuard, IERC5192, IReputationRegistry {
    
    // ============ Type Definitions ============
    
    /**
     * @notice Job types supported by the protocol
     */
    enum JobType {
        TradeExecution,      // 0 - Trade execution tasks
        TreasuryManagement,  // 1 - Treasury/fund management
        ContentCompliance,   // 2 - Content moderation/compliance
        DataAnalysis,        // 3 - Data analysis tasks
        SmartContractAudit,  // 4 - Smart contract auditing
        GovernanceVoting,    // 5 - DAO governance participation
        Custom               // 6 - Custom job types
    }
    
    /**
     * @notice Job verification status
     */
    enum JobStatus {
        Pending,    // 0 - Awaiting verification
        Verified,   // 1 - Successfully verified
        Failed,     // 2 - Verification failed
        Disputed    // 3 - Under dispute
    }
    
    /**
     * @notice Job record structure
     * @dev Heavy data (logs, detailed proofs) stored off-chain via proofUri
     */
    struct JobRecord {
        uint256 jobId;           // Unique job identifier
        address employer;        // Address that submitted the job
        JobType jobType;         // Type of job performed
        JobStatus status;        // Current verification status
        uint256 timestamp;       // When job was added
        uint256 value;           // Value/stake associated with job
        bytes32 proofHash;       // Hash of off-chain proof for verification
        string proofUri;         // URI to off-chain data (IPFS/Arweave CID)
        string description;      // Brief on-chain description
        bool success;            // Whether job was successful (set during verification)
        bytes32 tag1;            // Primary category tag for filtering
        bytes32 tag2;            // Secondary category tag
    }
    
    // ============ State Variables ============
    
    /// @notice Counter for generating unique resume token IDs
    uint256 private _nextTokenId;
    
    /// @notice Counter for generating unique job IDs
    uint256 private _nextJobId;
    
    /// @notice Mapping from agent ID (L1) to resume token ID (L2)
    mapping(uint256 => uint256) private _agentToResume;
    
    /// @notice Mapping from resume token ID to agent ID
    mapping(uint256 => uint256) private _resumeToAgent;
    
    /// @notice Mapping from resume token ID to job records
    mapping(uint256 => JobRecord[]) private _resumeJobs;
    
    /// @notice Mapping from resume token ID to reputation score
    mapping(uint256 => uint256) private _reputationScores;
    
    /// @notice Mapping from resume token ID to job counts by type
    mapping(uint256 => mapping(JobType => uint256)) private _jobTypeCounts;
    
    /// @notice Mapping from resume token ID to successful job count
    mapping(uint256 => uint256) private _successfulJobs;
    
    /// @notice Mapping from resume token ID to failed job count
    mapping(uint256 => uint256) private _failedJobs;
    
    // Feedback tracking for IReputationRegistry
    /// @notice Mapping: resumeId => client => feedback array
    mapping(uint256 => mapping(address => Feedback[])) private _feedbacks;
    
    /// @notice Mapping: resumeId => array of clients who gave feedback
    mapping(uint256 => address[]) private _feedbackClients;
    
    /// @notice Mapping: resumeId => client => has given feedback before
    mapping(uint256 => mapping(address => bool)) private _hasGivenFeedback;
    
    /// @notice Reference to Layer 1 contract (AgentIdentity)
    address public agentIdentityContract;
    
    /// @notice Reference to Layer 3 contract (VerificationRegistry)
    address public verificationRegistryContract;
    
    /// @notice Fee required to add a job record
    uint256 public verificationFee;
    
    /// @notice Total fees collected
    uint256 public totalFeesCollected;
    
    /// @notice Reputation points for successful job
    uint256 public constant REPUTATION_SUCCESS_POINTS = 10;
    
    /// @notice Reputation points deducted for failed job
    uint256 public constant REPUTATION_FAIL_POINTS = 5;
    
    /// @notice Base reputation for new agents
    uint256 public constant BASE_REPUTATION = 100;
    
    // ============ Events ============
    
    /// @notice Emitted when a resume is minted for an agent
    event ResumeMinted(uint256 indexed resumeId, uint256 indexed agentId, address indexed owner);
    
    /// @notice Emitted when a job is added to a resume
    event JobAdded(
        uint256 indexed resumeId,
        uint256 indexed jobId,
        address indexed employer,
        JobType jobType
    );
    
    /// @notice Emitted when a job status is updated
    event JobStatusUpdated(
        uint256 indexed resumeId,
        uint256 indexed jobId,
        JobStatus status,
        bool success
    );
    
    /// @notice Emitted when verification fee is updated
    event VerificationFeeUpdated(uint256 oldFee, uint256 newFee);
    
    /// @notice Emitted when layer contracts are linked
    event LayerLinked(address indexed layer1, address indexed layer3);
    
    // ============ Modifiers ============
    
    /**
     * @notice Ensure caller is the verification registry (L3)
     */
    modifier onlyVerificationRegistry() {
        require(
            msg.sender == verificationRegistryContract,
            "SoulboundResume: caller is not verification registry"
        );
        _;
    }
    
    /**
     * @notice Ensure the agent has a resume token
     */
    modifier hasResume(uint256 agentId) {
        require(
            _agentToResume[agentId] != 0,
            "SoulboundResume: agent has no resume"
        );
        _;
    }
    
    // ============ Constructor ============
    
    /**
     * @notice Initialize the SoulboundResume contract
     * @param initialOwner The owner of the contract
     * @param _verificationFee Initial fee for adding jobs
     */
    constructor(
        address initialOwner,
        uint256 _verificationFee
    ) ERC721("SynthNet Soulbound Resume", "SYNTH-RESUME") Ownable(initialOwner) {
        _nextTokenId = 1;
        _nextJobId = 1;
        verificationFee = _verificationFee;
    }
    
    // ============ Layer Linking ============
    
    /**
     * @notice Link Layer 1 and Layer 3 contracts
     * @param _agentIdentity Address of the AgentIdentity contract
     * @param _verificationRegistry Address of the VerificationRegistry contract
     */
    function linkLayers(
        address _agentIdentity,
        address _verificationRegistry
    ) external onlyOwner {
        require(agentIdentityContract == address(0), "SoulboundResume: layers already linked");
        require(_agentIdentity != address(0), "SoulboundResume: invalid L1 address");
        require(_verificationRegistry != address(0), "SoulboundResume: invalid L3 address");
        
        agentIdentityContract = _agentIdentity;
        verificationRegistryContract = _verificationRegistry;
        
        emit LayerLinked(_agentIdentity, _verificationRegistry);
    }
    
    // ============ IERC5192 Implementation ============
    
    /**
     * @inheritdoc IERC5192
     * @dev All tokens are permanently locked (soulbound)
     */
    function locked(uint256 tokenId) external view override returns (bool) {
        require(_ownerOf(tokenId) != address(0), "SoulboundResume: token does not exist");
        return true; // Always locked - soulbound
    }
    
    // ============ Resume Management ============
    
    /**
     * @notice Mint a soulbound resume for an agent
     * @dev Called by AgentIdentity (L1) or protocol during registration
     * @param agentId The agent ID from Layer 1
     * @param owner The owner address for the resume
     * @return resumeId The minted resume token ID
     */
    function mintResume(
        uint256 agentId,
        address owner
    ) external returns (uint256 resumeId) {
        require(
            msg.sender == agentIdentityContract || msg.sender == this.owner(),
            "SoulboundResume: unauthorized minter"
        );
        require(_agentToResume[agentId] == 0, "SoulboundResume: resume already exists");
        require(owner != address(0), "SoulboundResume: invalid owner");
        
        resumeId = _nextTokenId++;
        
        _safeMint(owner, resumeId);
        
        // Link agent to resume
        _agentToResume[agentId] = resumeId;
        _resumeToAgent[resumeId] = agentId;
        
        // Initialize reputation
        _reputationScores[resumeId] = BASE_REPUTATION;
        
        // Emit soulbound locked event per ERC-5192
        emit Locked(resumeId);
        emit ResumeMinted(resumeId, agentId, owner);
        
        return resumeId;
    }
    
    /**
     * @notice Add a job record to an agent's resume
     * @param agentId The agent ID from Layer 1
     * @param jobType The type of job
     * @param description Brief on-chain description
     * @param proofUri URI to off-chain proof data (IPFS/Arweave)
     * @param proofHash Hash of the proof for verification
     * @param value Value associated with the job
     * @param tag1 Primary category tag
     * @param tag2 Secondary category tag
     * @return jobId The unique job ID
     */
    function addJobRecord(
        uint256 agentId,
        JobType jobType,
        string calldata description,
        string calldata proofUri,
        bytes32 proofHash,
        uint256 value,
        bytes32 tag1,
        bytes32 tag2
    ) external payable hasResume(agentId) nonReentrant returns (uint256 jobId) {
        require(msg.value >= verificationFee, "SoulboundResume: insufficient fee");
        require(bytes(proofUri).length > 0, "SoulboundResume: proof URI required");
        
        uint256 resumeId = _agentToResume[agentId];
        jobId = _nextJobId++;
        
        JobRecord memory newJob = JobRecord({
            jobId: jobId,
            employer: msg.sender,
            jobType: jobType,
            status: JobStatus.Pending,
            timestamp: block.timestamp,
            value: value,
            proofHash: proofHash,
            proofUri: proofUri,
            description: description,
            success: false,
            tag1: tag1,
            tag2: tag2
        });
        
        _resumeJobs[resumeId].push(newJob);
        _jobTypeCounts[resumeId][jobType]++;
        
        totalFeesCollected += msg.value;
        
        emit JobAdded(resumeId, jobId, msg.sender, jobType);
        
        return jobId;
    }
    
    /**
     * @notice Update job status (called by VerificationRegistry)
     * @param agentId The agent ID
     * @param jobId The job ID to update
     * @param status The new status
     * @param success Whether the job was successful
     */
    function updateJobStatus(
        uint256 agentId,
        uint256 jobId,
        JobStatus status,
        bool success
    ) external onlyVerificationRegistry hasResume(agentId) {
        uint256 resumeId = _agentToResume[agentId];
        JobRecord[] storage jobs = _resumeJobs[resumeId];
        
        bool found = false;
        for (uint256 i = 0; i < jobs.length; i++) {
            if (jobs[i].jobId == jobId) {
                require(
                    jobs[i].status == JobStatus.Pending,
                    "SoulboundResume: job already verified"
                );
                
                jobs[i].status = status;
                jobs[i].success = success;
                
                // Update reputation
                uint256 oldReputation = _reputationScores[resumeId];
                if (status == JobStatus.Verified) {
                    if (success) {
                        _reputationScores[resumeId] += REPUTATION_SUCCESS_POINTS;
                        _successfulJobs[resumeId]++;
                    } else {
                        if (_reputationScores[resumeId] > REPUTATION_FAIL_POINTS) {
                            _reputationScores[resumeId] -= REPUTATION_FAIL_POINTS;
                        } else {
                            _reputationScores[resumeId] = 0;
                        }
                        _failedJobs[resumeId]++;
                    }
                    emit ReputationUpdated(resumeId, oldReputation, _reputationScores[resumeId]);
                }
                
                found = true;
                emit JobStatusUpdated(resumeId, jobId, status, success);
                break;
            }
        }
        
        require(found, "SoulboundResume: job not found");
    }
    
    // ============ IReputationRegistry Implementation ============
    
    /**
     * @inheritdoc IReputationRegistry
     */
    function giveFeedback(
        uint256 agentId,
        uint8 score,
        bytes32 tag1,
        bytes32 tag2,
        string calldata fileUri,
        bytes32 fileHash,
        bytes calldata feedbackAuth
    ) external override hasResume(agentId) {
        require(score <= 100, "SoulboundResume: score must be 0-100");
        require(bytes(fileUri).length > 0, "SoulboundResume: file URI required");
        
        // Note: feedbackAuth signature verification could be added here
        // For now, we track feedback without requiring agent signature
        
        uint256 resumeId = _agentToResume[agentId];
        
        // Track new clients
        if (!_hasGivenFeedback[resumeId][msg.sender]) {
            _feedbackClients[resumeId].push(msg.sender);
            _hasGivenFeedback[resumeId][msg.sender] = true;
        }
        
        Feedback memory newFeedback = Feedback({
            score: score,
            tag1: tag1,
            tag2: tag2,
            fileUri: fileUri,
            fileHash: fileHash,
            timestamp: block.timestamp,
            isRevoked: false
        });
        
        _feedbacks[resumeId][msg.sender].push(newFeedback);
        
        emit NewFeedback(agentId, msg.sender, score, tag1, tag2, fileUri, fileHash);
    }
    
    /**
     * @inheritdoc IReputationRegistry
     */
    function revokeFeedback(
        uint256 agentId,
        uint64 feedbackIndex
    ) external override hasResume(agentId) {
        uint256 resumeId = _agentToResume[agentId];
        require(
            feedbackIndex < _feedbacks[resumeId][msg.sender].length,
            "SoulboundResume: invalid feedback index"
        );
        require(
            !_feedbacks[resumeId][msg.sender][feedbackIndex].isRevoked,
            "SoulboundResume: already revoked"
        );
        
        _feedbacks[resumeId][msg.sender][feedbackIndex].isRevoked = true;
        
        emit FeedbackRevoked(agentId, msg.sender, feedbackIndex);
    }
    
    /**
     * @inheritdoc IReputationRegistry
     */
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        bytes32 tag1,
        bytes32 tag2
    ) external view override hasResume(agentId) returns (uint64 count, uint8 averageScore) {
        uint256 resumeId = _agentToResume[agentId];
        
        uint256 totalScore = 0;
        uint64 matchCount = 0;
        
        address[] memory clients;
        if (clientAddresses.length > 0) {
            clients = new address[](clientAddresses.length);
            for (uint256 i = 0; i < clientAddresses.length; i++) {
                clients[i] = clientAddresses[i];
            }
        } else {
            clients = _feedbackClients[resumeId];
        }
        
        for (uint256 i = 0; i < clients.length; i++) {
            Feedback[] storage clientFeedbacks = _feedbacks[resumeId][clients[i]];
            
            for (uint256 j = 0; j < clientFeedbacks.length; j++) {
                Feedback storage fb = clientFeedbacks[j];
                
                if (fb.isRevoked) continue;
                
                // Apply tag filters
                if (tag1 != bytes32(0) && fb.tag1 != tag1) continue;
                if (tag2 != bytes32(0) && fb.tag2 != tag2) continue;
                
                totalScore += fb.score;
                matchCount++;
            }
        }
        
        count = matchCount;
        averageScore = matchCount > 0 ? uint8(totalScore / matchCount) : 0;
    }
    
    /**
     * @inheritdoc IReputationRegistry
     */
    function readFeedback(
        uint256 agentId,
        address clientAddress,
        uint64 index
    ) external view override hasResume(agentId) returns (
        uint8 score,
        bytes32 tag1,
        bytes32 tag2,
        bool isRevoked
    ) {
        uint256 resumeId = _agentToResume[agentId];
        require(
            index < _feedbacks[resumeId][clientAddress].length,
            "SoulboundResume: invalid feedback index"
        );
        
        Feedback storage fb = _feedbacks[resumeId][clientAddress][index];
        return (fb.score, fb.tag1, fb.tag2, fb.isRevoked);
    }
    
    /**
     * @inheritdoc IReputationRegistry
     */
    function getClients(uint256 agentId) external view override hasResume(agentId) returns (address[] memory) {
        uint256 resumeId = _agentToResume[agentId];
        return _feedbackClients[resumeId];
    }
    
    /**
     * @inheritdoc IReputationRegistry
     */
    function getReputation(uint256 agentId) external view override returns (uint256) {
        uint256 resumeId = _agentToResume[agentId];
        if (resumeId == 0) return 0;
        return _reputationScores[resumeId];
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get all job records for an agent
     * @param agentId The agent ID
     * @return jobs Array of job records
     */
    function getJobRecords(uint256 agentId) external view hasResume(agentId) returns (JobRecord[] memory) {
        uint256 resumeId = _agentToResume[agentId];
        return _resumeJobs[resumeId];
    }
    
    /**
     * @notice Get a specific job record
     * @param agentId The agent ID
     * @param jobId The job ID
     * @return job The job record
     */
    function getJobRecord(
        uint256 agentId,
        uint256 jobId
    ) external view hasResume(agentId) returns (JobRecord memory) {
        uint256 resumeId = _agentToResume[agentId];
        JobRecord[] storage jobs = _resumeJobs[resumeId];
        
        for (uint256 i = 0; i < jobs.length; i++) {
            if (jobs[i].jobId == jobId) {
                return jobs[i];
            }
        }
        
        revert("SoulboundResume: job not found");
    }
    
    /**
     * @notice Get comprehensive stats for an agent
     * @param agentId The agent ID
     * @return totalJobs Total number of jobs
     * @return successfulJobCount Number of successful jobs
     * @return failedJobCount Number of failed jobs
     * @return reputation Current reputation score
     */
    function getAgentStats(uint256 agentId) external view returns (
        uint256 totalJobs,
        uint256 successfulJobCount,
        uint256 failedJobCount,
        uint256 reputation
    ) {
        uint256 resumeId = _agentToResume[agentId];
        if (resumeId == 0) {
            return (0, 0, 0, 0);
        }
        
        return (
            _resumeJobs[resumeId].length,
            _successfulJobs[resumeId],
            _failedJobs[resumeId],
            _reputationScores[resumeId]
        );
    }
    
    /**
     * @notice Get job count by type for an agent
     * @param agentId The agent ID
     * @param jobType The job type to query
     * @return count The job count
     */
    function getJobCountByType(
        uint256 agentId,
        JobType jobType
    ) external view hasResume(agentId) returns (uint256) {
        uint256 resumeId = _agentToResume[agentId];
        return _jobTypeCounts[resumeId][jobType];
    }
    
    /**
     * @notice Get resume ID for an agent
     * @param agentId The agent ID
     * @return resumeId The resume token ID (0 if none)
     */
    function getResumeId(uint256 agentId) external view returns (uint256) {
        return _agentToResume[agentId];
    }
    
    /**
     * @notice Get agent ID for a resume
     * @param resumeId The resume token ID
     * @return agentId The agent ID
     */
    function getAgentId(uint256 resumeId) external view returns (uint256) {
        return _resumeToAgent[resumeId];
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update the verification fee
     * @param newFee The new fee amount
     */
    function setVerificationFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = verificationFee;
        verificationFee = newFee;
        emit VerificationFeeUpdated(oldFee, newFee);
    }
    
    /**
     * @notice Withdraw collected fees
     * @param to The address to send fees to
     */
    function withdrawFees(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "SoulboundResume: invalid address");
        uint256 amount = address(this).balance;
        require(amount > 0, "SoulboundResume: no fees to withdraw");
        
        (bool success, ) = to.call{value: amount}("");
        require(success, "SoulboundResume: withdrawal failed");
    }
    
    // ============ Soulbound Override ============
    
    /**
     * @dev Override to prevent transfers - tokens are soulbound
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        
        // Allow minting (from == address(0))
        // Block all transfers
        if (from != address(0) && to != address(0)) {
            revert("SoulboundResume: token is non-transferable");
        }
        
        return super._update(to, tokenId, auth);
    }
    
    /**
     * @dev Override supportsInterface to include ERC5192
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return 
            interfaceId == type(IERC5192).interfaceId || // 0xb45a3c0e
            super.supportsInterface(interfaceId);
    }
}
