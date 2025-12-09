// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./AgentIdentity.sol";
import "./SoulboundResume.sol";
import "./VerificationRegistry.sol";
import "./interfaces/IERC8004.sol";

/**
 * @title SynthNetProtocol - Main Orchestrator Contract
 * @notice Unified interface for the SynthNet AI Agent Resume Protocol
 * @dev Composes all three layers into a single interface:
 *      - Layer 1 (AgentIdentity) - ERC-8004 Identity Registry
 *      - Layer 2 (SoulboundResume) - ERC-5192 Soulbound Job History
 *      - Layer 3 (VerificationRegistry) - Validation & Verification
 * 
 * This contract provides:
 *   - Unified registration flow (creates identity + resume in one tx)
 *   - Simplified job management API
 *   - Cross-layer coordination
 *   - Backward-compatible function signatures
 * 
 * Data Availability Strategy:
 *   - On-chain: Identity, job metadata, reputation scores, verification status
 *   - Off-chain (IPFS/Arweave): Detailed proofs, logs, agent metadata files
 */
contract SynthNetProtocol is Ownable, ReentrancyGuard {
    
    // ============ Layer Contracts ============
    
    /// @notice Layer 1: Agent Identity Registry
    AgentIdentity public immutable agentIdentity;
    
    /// @notice Layer 2: Soulbound Resume
    SoulboundResume public immutable soulboundResume;
    
    /// @notice Layer 3: Verification Registry
    VerificationRegistry public immutable verificationRegistry;
    
    // ============ Protocol State ============
    
    /// @notice Protocol version
    string public constant VERSION = "2.0.0";
    
    /// @notice Protocol is paused
    bool public paused;
    
    /// @notice Total agents registered through this protocol
    uint256 public totalAgentsRegistered;
    
    /// @notice Total jobs submitted through this protocol
    uint256 public totalJobsSubmitted;
    
    // ============ Job Type Tags ============
    
    /// @notice Tag for trade execution jobs
    bytes32 public constant TAG_TRADE_EXECUTION = keccak256("TradeExecution");
    
    /// @notice Tag for treasury management jobs
    bytes32 public constant TAG_TREASURY_MANAGEMENT = keccak256("TreasuryManagement");
    
    /// @notice Tag for content compliance jobs
    bytes32 public constant TAG_CONTENT_COMPLIANCE = keccak256("ContentCompliance");
    
    /// @notice Tag for data analysis jobs
    bytes32 public constant TAG_DATA_ANALYSIS = keccak256("DataAnalysis");
    
    /// @notice Tag for smart contract audit jobs
    bytes32 public constant TAG_SMART_CONTRACT_AUDIT = keccak256("SmartContractAudit");
    
    /// @notice Tag for governance voting jobs
    bytes32 public constant TAG_GOVERNANCE_VOTING = keccak256("GovernanceVoting");
    
    // ============ Events ============
    
    /// @notice Emitted when an agent is fully registered (L1 + L2)
    event AgentFullyRegistered(
        uint256 indexed agentId,
        uint256 indexed resumeId,
        address indexed owner,
        string tokenUri
    );
    
    /// @notice Emitted when a job is submitted through the protocol
    event JobSubmitted(
        uint256 indexed agentId,
        uint256 indexed jobId,
        address indexed employer,
        SoulboundResume.JobType jobType
    );
    
    /// @notice Emitted when protocol is paused/unpaused
    event ProtocolPaused(bool paused);
    
    // ============ Modifiers ============
    
    /**
     * @notice Ensure protocol is not paused
     */
    modifier whenNotPaused() {
        require(!paused, "SynthNetProtocol: protocol is paused");
        _;
    }
    
    // ============ Constructor ============
    
    /**
     * @notice Deploy the SynthNet Protocol with all layers
     * @param initialOwner The owner of the protocol
     * @param verificationFee Initial fee for adding jobs
     */
    constructor(
        address initialOwner,
        uint256 verificationFee
    ) Ownable(initialOwner) {
        // Deploy Layer 1: Agent Identity
        agentIdentity = new AgentIdentity(address(this));
        
        // Deploy Layer 2: Soulbound Resume
        soulboundResume = new SoulboundResume(address(this), verificationFee);
        
        // Deploy Layer 3: Verification Registry
        verificationRegistry = new VerificationRegistry(address(this));
        
        // Link all layers together
        agentIdentity.linkLayers(address(soulboundResume), address(verificationRegistry));
        soulboundResume.linkLayers(address(agentIdentity), address(verificationRegistry));
        verificationRegistry.linkLayers(address(agentIdentity), address(soulboundResume));
    }
    
    // ============ Unified Registration ============
    
    /**
     * @notice Register a new AI agent with full identity and resume
     * @dev Creates both L1 identity token and L2 soulbound resume in one transaction
     * @param tokenUri URI to off-chain agent data (IPFS/Arweave CID)
     * @param metadata Initial metadata entries for the agent
     * @return agentId The agent ID (L1 token ID)
     * @return resumeId The resume ID (L2 soulbound token ID)
     */
    function registerAgent(
        string calldata tokenUri,
        IIdentityRegistry.MetadataEntry[] calldata metadata
    ) external whenNotPaused nonReentrant returns (uint256 agentId, uint256 resumeId) {
        // Mint soulbound resume on L2 first
        resumeId = soulboundResume.mintResume(0, msg.sender); // agentId will be set via backlink
        
        // Register identity on L1 (mint to the caller) with L2 link
        agentId = agentIdentity.registerFor(msg.sender, tokenUri, metadata, resumeId);
        
        // Update the L2 resume with the correct agentId
        soulboundResume.setAgentId(resumeId, agentId);
        
        totalAgentsRegistered++;
        
        emit AgentFullyRegistered(agentId, resumeId, msg.sender, tokenUri);
        
        return (agentId, resumeId);
    }
    
    /**
     * @notice Register a new AI agent with minimal data
     * @return agentId The agent ID
     * @return resumeId The resume ID
     */
    function registerAgent() external whenNotPaused nonReentrant returns (uint256 agentId, uint256 resumeId) {
        // Mint soulbound resume on L2 first
        resumeId = soulboundResume.mintResume(0, msg.sender); // agentId will be set via backlink
        
        // Register identity on L1 with no metadata and L2 link
        IIdentityRegistry.MetadataEntry[] memory emptyMetadata = new IIdentityRegistry.MetadataEntry[](0);
        agentId = agentIdentity.registerFor(msg.sender, "", emptyMetadata, resumeId);
        
        // Update the L2 resume with the correct agentId
        soulboundResume.setAgentId(resumeId, agentId);
        
        totalAgentsRegistered++;
        
        emit AgentFullyRegistered(agentId, resumeId, msg.sender, "");
        
        return (agentId, resumeId);
    }
    
    // ============ Job Management ============
    
    /**
     * @notice Add a job record to an agent's resume
     * @param agentId The agent ID
     * @param jobType The type of job
     * @param description Brief description
     * @param proofUri URI to off-chain proof (IPFS/Arweave)
     * @param proofHash Hash of the proof for verification
     * @param value Value associated with the job
     * @return jobId The unique job ID
     */
    function addJobRecord(
        uint256 agentId,
        SoulboundResume.JobType jobType,
        string calldata description,
        string calldata proofUri,
        bytes32 proofHash,
        uint256 value
    ) external payable whenNotPaused nonReentrant returns (uint256 jobId) {
        // Get appropriate tags based on job type
        bytes32 tag1 = _getTagForJobType(jobType);
        
        // Add job to L2
        jobId = soulboundResume.addJobRecord{value: msg.value}(
            agentId,
            jobType,
            description,
            proofUri,
            proofHash,
            value,
            tag1,
            bytes32(0)
        );
        
        totalJobsSubmitted++;
        
        emit JobSubmitted(agentId, jobId, msg.sender, jobType);
        
        return jobId;
    }
    
    /**
     * @notice Add a job record with custom tags
     * @param agentId The agent ID
     * @param jobType The type of job
     * @param description Brief description
     * @param proofUri URI to off-chain proof
     * @param proofHash Hash of the proof
     * @param value Value associated with the job
     * @param tag1 Primary category tag
     * @param tag2 Secondary category tag
     * @return jobId The unique job ID
     */
    function addJobRecordWithTags(
        uint256 agentId,
        SoulboundResume.JobType jobType,
        string calldata description,
        string calldata proofUri,
        bytes32 proofHash,
        uint256 value,
        bytes32 tag1,
        bytes32 tag2
    ) external payable whenNotPaused nonReentrant returns (uint256 jobId) {
        jobId = soulboundResume.addJobRecord{value: msg.value}(
            agentId,
            jobType,
            description,
            proofUri,
            proofHash,
            value,
            tag1,
            tag2
        );
        
        totalJobsSubmitted++;
        
        emit JobSubmitted(agentId, jobId, msg.sender, jobType);
        
        return jobId;
    }
    
    // ============ Verification Interface ============
    
    /**
     * @notice Verify a job (owner/verifier only)
     * @param agentId The agent ID
     * @param jobId The job ID
     * @param success Whether the job was successful
     * @param proofHash Verification proof hash
     */
    function verifyJob(
        uint256 agentId,
        uint256 jobId,
        bool success,
        bytes32 proofHash
    ) external {
        // Check authorization at protocol level
        require(
            verificationRegistry.isVerifier(msg.sender) || msg.sender == owner(),
            "SynthNetProtocol: not authorized to verify"
        );
        // Delegate to L3
        verificationRegistry.verifyJob(agentId, jobId, success, proofHash);
    }
    
    /**
     * @notice Add a verifier
     * @param verifier The verifier address
     */
    function addVerifier(address verifier) external onlyOwner {
        verificationRegistry.addVerifier(verifier);
    }
    
    /**
     * @notice Remove a verifier
     * @param verifier The verifier address
     */
    function removeVerifier(address verifier) external onlyOwner {
        verificationRegistry.removeVerifier(verifier);
    }
    
    // ============ Feedback Interface ============
    
    /**
     * @notice Give feedback to an agent
     * @param agentId The agent ID
     * @param score Feedback score (0-100)
     * @param tag1 Primary category tag
     * @param fileUri URI to detailed feedback (IPFS/Arweave)
     * @param fileHash Hash of the feedback file
     */
    function giveFeedback(
        uint256 agentId,
        uint8 score,
        bytes32 tag1,
        string calldata fileUri,
        bytes32 fileHash
    ) external whenNotPaused {
        soulboundResume.giveFeedback(
            agentId,
            score,
            tag1,
            bytes32(0),
            fileUri,
            fileHash,
            ""
        );
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get comprehensive agent information
     * @param agentId The agent ID
     * @return owner The agent owner
     * @return resumeId The resume token ID
     * @return totalJobs Total jobs on resume
     * @return successfulJobs Successful job count
     * @return failedJobs Failed job count
     * @return reputation Current reputation score
     */
    function getAgentInfo(uint256 agentId) external view returns (
        address owner,
        uint256 resumeId,
        uint256 totalJobs,
        uint256 successfulJobs,
        uint256 failedJobs,
        uint256 reputation
    ) {
        owner = agentIdentity.ownerOf(agentId);
        resumeId = soulboundResume.getResumeId(agentId);
        
        (totalJobs, successfulJobs, failedJobs, reputation) = soulboundResume.getAgentStats(agentId);
        
        return (owner, resumeId, totalJobs, successfulJobs, failedJobs, reputation);
    }
    
    /**
     * @notice Get agent stats (backward compatible)
     * @param agentId The agent ID
     * @return totalJobs Total jobs
     * @return successfulJobs Successful jobs
     * @return failedJobs Failed jobs  
     * @return reputation Reputation score
     */
    function getAgentStats(uint256 agentId) external view returns (
        uint256 totalJobs,
        uint256 successfulJobs,
        uint256 failedJobs,
        uint256 reputation
    ) {
        return soulboundResume.getAgentStats(agentId);
    }
    
    /**
     * @notice Get job records for an agent
     * @param agentId The agent ID
     * @return jobs Array of job records
     */
    function getJobRecords(uint256 agentId) external view returns (SoulboundResume.JobRecord[] memory) {
        return soulboundResume.getJobRecords(agentId);
    }
    
    /**
     * @notice Get a specific job record
     * @param agentId The agent ID
     * @param jobId The job ID
     * @return job The job record
     */
    function getJobRecord(uint256 agentId, uint256 jobId) external view returns (SoulboundResume.JobRecord memory) {
        return soulboundResume.getJobRecord(agentId, jobId);
    }
    
    /**
     * @notice Get agent reputation
     * @param agentId The agent ID
     * @return reputation The reputation score
     */
    function getReputation(uint256 agentId) external view returns (uint256) {
        return soulboundResume.getReputation(agentId);
    }
    
    /**
     * @notice Check if an agent is registered
     * @param agentId The agent ID
     * @return bool True if registered
     */
    function isAgentRegistered(uint256 agentId) external view returns (bool) {
        return agentIdentity.isRegistered(agentId);
    }
    
    /**
     * @notice Get agent ID by address
     * @param owner The owner address
     * @return agentId The agent ID (0 if not found)
     */
    function getAgentIdByAddress(address owner) external view returns (uint256) {
        return agentIdentity.getAgentIdByAddress(owner);
    }
    
    /**
     * @notice Get verification fee
     * @return fee The current verification fee
     */
    function getVerificationFee() external view returns (uint256) {
        return soulboundResume.verificationFee();
    }
    
    /**
     * @notice Get all verifiers
     * @return verifiers Array of verifier addresses
     */
    function getVerifiers() external view returns (address[] memory) {
        return verificationRegistry.getVerifiers();
    }
    
    /**
     * @notice Check if address is verifier
     * @param verifier The address to check
     * @return bool True if verifier
     */
    function isVerifier(address verifier) external view returns (bool) {
        return verificationRegistry.isVerifier(verifier);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update verification fee
     * @param newFee The new fee amount
     */
    function setVerificationFee(uint256 newFee) external onlyOwner {
        soulboundResume.setVerificationFee(newFee);
    }
    
    /**
     * @notice Withdraw collected fees
     * @param to The address to send fees to
     */
    function withdrawFees(address payable to) external onlyOwner nonReentrant {
        soulboundResume.withdrawFees(to);
    }
    
    /**
     * @notice Pause/unpause the protocol
     * @param _paused Whether to pause
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit ProtocolPaused(_paused);
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Get tag bytes32 for a job type
     * @param jobType The job type
     * @return tag The tag bytes32
     */
    function _getTagForJobType(SoulboundResume.JobType jobType) internal pure returns (bytes32) {
        if (jobType == SoulboundResume.JobType.TradeExecution) {
            return keccak256("TradeExecution");
        } else if (jobType == SoulboundResume.JobType.TreasuryManagement) {
            return keccak256("TreasuryManagement");
        } else if (jobType == SoulboundResume.JobType.ContentCompliance) {
            return keccak256("ContentCompliance");
        } else if (jobType == SoulboundResume.JobType.DataAnalysis) {
            return keccak256("DataAnalysis");
        } else if (jobType == SoulboundResume.JobType.SmartContractAudit) {
            return keccak256("SmartContractAudit");
        } else if (jobType == SoulboundResume.JobType.GovernanceVoting) {
            return keccak256("GovernanceVoting");
        } else {
            return keccak256("Custom");
        }
    }
    
    // ============ Layer Contract Addresses ============
    
    /**
     * @notice Get all layer contract addresses
     * @return layer1 AgentIdentity address
     * @return layer2 SoulboundResume address
     * @return layer3 VerificationRegistry address
     */
    function getLayerAddresses() external view returns (
        address layer1,
        address layer2,
        address layer3
    ) {
        return (
            address(agentIdentity),
            address(soulboundResume),
            address(verificationRegistry)
        );
    }
}
