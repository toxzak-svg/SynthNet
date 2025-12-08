// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AIAgentResumeSBT
 * @dev Soulbound Token (SBT) for AI Agents that records their on-chain job history
 * This is a non-transferable NFT that serves as a verifiable resume for AI agents
 */
contract AIAgentResumeSBT is ERC721, Ownable, ReentrancyGuard {
    // Token ID counter
    uint256 private _nextTokenId;
    
    // Verification fee for adding jobs to resume
    uint256 public verificationFee;
    
    // Job verification types
    enum JobType {
        TradeExecution,      // Did the agent execute the trade correctly?
        TreasuryManagement,  // Did it manage the treasury without losing funds?
        ContentCompliance    // Did it post compliant content?
    }
    
    // Job verification status
    enum VerificationStatus {
        Pending,
        Verified,
        Failed,
        Disputed
    }
    
    // Job record structure
    struct JobRecord {
        uint256 jobId;
        address employer;      // DAO or entity that hired the agent
        JobType jobType;
        VerificationStatus status;
        uint256 timestamp;
        string description;
        bytes32 proofHash;     // Hash of proof data (transaction hash, content hash, etc.)
        uint256 value;         // Value involved (trade amount, treasury size, etc.)
        bool success;          // Whether the job was successful
    }
    
    // Mapping from agent address to token ID
    mapping(address => uint256) private _agentToToken;
    
    // Mapping from token ID to agent address
    mapping(uint256 => address) private _tokenToAgent;
    
    // Mapping from token ID to job records
    mapping(uint256 => JobRecord[]) private _tokenJobs;
    
    // Mapping from token ID to reputation score
    mapping(uint256 => uint256) private _reputationScores;
    
    // Verifiers who can verify jobs
    mapping(address => bool) public verifiers;
    
    // Total fees collected
    uint256 public totalFeesCollected;
    
    // Events
    event AgentRegistered(address indexed agent, uint256 indexed tokenId);
    event JobAdded(uint256 indexed tokenId, uint256 indexed jobId, JobType jobType);
    event JobVerified(uint256 indexed tokenId, uint256 indexed jobId, VerificationStatus status);
    event VerificationFeeUpdated(uint256 oldFee, uint256 newFee);
    event VerifierAdded(address indexed verifier);
    event VerifierRemoved(address indexed verifier);
    event ReputationUpdated(uint256 indexed tokenId, uint256 newScore);
    
    /**
     * @dev Constructor
     * @param _verificationFee Initial verification fee in wei
     */
    constructor(uint256 _verificationFee) ERC721("AI Agent Resume", "AIRSBT") Ownable(msg.sender) {
        verificationFee = _verificationFee;
        _nextTokenId = 1; // Start token IDs from 1
    }
    
    /**
     * @dev Register a new AI agent and mint their SBT
     * @param agent Address of the AI agent
     */
    function registerAgent(address agent) external returns (uint256) {
        require(agent != address(0), "Invalid agent address");
        require(_agentToToken[agent] == 0, "Agent already registered");
        
        uint256 newTokenId = _nextTokenId++;
        
        _safeMint(agent, newTokenId);
        _agentToToken[agent] = newTokenId;
        _tokenToAgent[newTokenId] = agent;
        
        emit AgentRegistered(agent, newTokenId);
        return newTokenId;
    }
    
    /**
     * @dev Add a job record to an agent's resume
     * @param agent Address of the AI agent
     * @param jobType Type of job performed
     * @param description Description of the job
     * @param proofHash Hash of proof data
     * @param value Value involved in the job
     */
    function addJobRecord(
        address agent,
        JobType jobType,
        string calldata description,
        bytes32 proofHash,
        uint256 value
    ) external payable returns (uint256) {
        require(msg.value >= verificationFee, "Insufficient verification fee");
        
        uint256 tokenId = _agentToToken[agent];
        require(tokenId != 0, "Agent not registered");
        
        uint256 jobId = _tokenJobs[tokenId].length;
        
        JobRecord memory newJob = JobRecord({
            jobId: jobId,
            employer: msg.sender,
            jobType: jobType,
            status: VerificationStatus.Pending,
            timestamp: block.timestamp,
            description: description,
            proofHash: proofHash,
            value: value,
            success: false
        });
        
        _tokenJobs[tokenId].push(newJob);
        totalFeesCollected += msg.value;
        
        emit JobAdded(tokenId, jobId, jobType);
        return jobId;
    }
    
    /**
     * @dev Verify a job record (only verifiers)
     * @param agent Address of the AI agent
     * @param jobId ID of the job to verify
     * @param status Verification status
     * @param success Whether the job was successful
     */
    function verifyJob(
        address agent,
        uint256 jobId,
        VerificationStatus status,
        bool success
    ) external {
        require(verifiers[msg.sender] || msg.sender == owner(), "Not authorized to verify");
        
        uint256 tokenId = _agentToToken[agent];
        require(tokenId != 0, "Agent not registered");
        require(jobId < _tokenJobs[tokenId].length, "Invalid job ID");
        
        JobRecord storage job = _tokenJobs[tokenId][jobId];
        require(job.status == VerificationStatus.Pending, "Job already verified");
        
        job.status = status;
        job.success = success;
        
        // Update reputation score based on verification
        if (status == VerificationStatus.Verified && success) {
            _reputationScores[tokenId] += 10;
        } else if (status == VerificationStatus.Failed) {
            if (_reputationScores[tokenId] >= 5) {
                _reputationScores[tokenId] -= 5;
            }
        }
        
        emit JobVerified(tokenId, jobId, status);
        emit ReputationUpdated(tokenId, _reputationScores[tokenId]);
    }
    
    /**
     * @dev Get all job records for an agent
     * @param agent Address of the AI agent
     */
    function getAgentJobs(address agent) external view returns (JobRecord[] memory) {
        uint256 tokenId = _agentToToken[agent];
        require(tokenId != 0, "Agent not registered");
        return _tokenJobs[tokenId];
    }
    
    /**
     * @dev Get a specific job record
     * @param agent Address of the AI agent
     * @param jobId ID of the job
     */
    function getJobRecord(address agent, uint256 jobId) external view returns (JobRecord memory) {
        uint256 tokenId = _agentToToken[agent];
        require(tokenId != 0, "Agent not registered");
        require(jobId < _tokenJobs[tokenId].length, "Invalid job ID");
        return _tokenJobs[tokenId][jobId];
    }
    
    /**
     * @dev Get reputation score for an agent
     * @param agent Address of the AI agent
     */
    function getReputationScore(address agent) external view returns (uint256) {
        uint256 tokenId = _agentToToken[agent];
        require(tokenId != 0, "Agent not registered");
        return _reputationScores[tokenId];
    }
    
    /**
     * @dev Get agent statistics
     * @param agent Address of the AI agent
     */
    function getAgentStats(address agent) external view returns (
        uint256 totalJobs,
        uint256 successfulJobs,
        uint256 failedJobs,
        uint256 reputation
    ) {
        uint256 tokenId = _agentToToken[agent];
        require(tokenId != 0, "Agent not registered");
        
        JobRecord[] memory jobs = _tokenJobs[tokenId];
        totalJobs = jobs.length;
        
        for (uint256 i = 0; i < jobs.length; i++) {
            if (jobs[i].status == VerificationStatus.Verified && jobs[i].success) {
                successfulJobs++;
            } else if (jobs[i].status == VerificationStatus.Failed) {
                failedJobs++;
            }
        }
        
        reputation = _reputationScores[tokenId];
    }
    
    /**
     * @dev Get token ID for an agent address
     * @param agent Address of the AI agent
     */
    function getAgentTokenId(address agent) external view returns (uint256) {
        return _agentToToken[agent];
    }
    
    /**
     * @dev Check if an agent is registered
     * @param agent Address of the AI agent
     */
    function isAgentRegistered(address agent) external view returns (bool) {
        return _agentToToken[agent] != 0;
    }
    
    /**
     * @dev Update verification fee (only owner)
     * @param newFee New verification fee in wei
     */
    function setVerificationFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = verificationFee;
        verificationFee = newFee;
        emit VerificationFeeUpdated(oldFee, newFee);
    }
    
    /**
     * @dev Add a verifier (only owner)
     * @param verifier Address of the verifier
     */
    function addVerifier(address verifier) external onlyOwner {
        require(verifier != address(0), "Invalid verifier address");
        verifiers[verifier] = true;
        emit VerifierAdded(verifier);
    }
    
    /**
     * @dev Remove a verifier (only owner)
     * @param verifier Address of the verifier
     */
    function removeVerifier(address verifier) external onlyOwner {
        verifiers[verifier] = false;
        emit VerifierRemoved(verifier);
    }
    
    /**
     * @dev Withdraw collected fees (only owner)
     */
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Override transfer functions to make token soulbound (non-transferable)
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        
        // Allow minting (from == address(0))
        // Block all transfers (from != address(0) && to != address(0))
        // Allow burning if needed (to == address(0))
        if (from != address(0) && to != address(0)) {
            revert("Soulbound: Token is non-transferable");
        }
        
        return super._update(to, tokenId, auth);
    }
}
