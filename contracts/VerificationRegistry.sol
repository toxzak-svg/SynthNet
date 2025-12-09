// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IERC8004.sol";
import "./SoulboundResume.sol";

/**
 * @title VerificationRegistry - Layer 3: Job Verification & Validation
 * @notice ERC-8004 compliant validation registry for job verification
 * @dev This is Layer 3 of the SynthNet protocol stack
 *      - Manages verifier authorization
 *      - Handles job verification workflow
 *      - Supports validation requests and responses
 *      - Off-chain proof verification coordination
 * 
 * Architecture:
 *   Layer 1 (AgentIdentity) - Identity & Metadata
 *   Layer 2 (SoulboundResume) - Job History & Reputation (ERC-5192)
 *   Layer 3 (VerificationRegistry) - Validation & Verification <-- THIS
 * 
 * Verification Flow:
 *   1. Job added to L2 (SoulboundResume) with proof URI
 *   2. Verification request submitted to L3
 *   3. Authorized verifier validates off-chain proof
 *   4. Verifier submits response, L3 updates L2 job status
 */
contract VerificationRegistry is Ownable, ReentrancyGuard, IValidationRegistry {
    
    // ============ State Variables ============
    
    /// @notice Mapping of authorized verifiers
    mapping(address => bool) public override isVerifier;
    
    /// @notice Array of all verifiers (for enumeration)
    address[] private _verifierList;
    
    /// @notice Mapping from request hash to validation request
    mapping(bytes32 => ValidationRequest) private _validationRequests;
    
    /// @notice Mapping from agent ID to their validation request hashes
    mapping(uint256 => bytes32[]) private _agentValidations;
    
    /// @notice Mapping from validator to their validation request hashes
    mapping(address => bytes32[]) private _validatorRequests;
    
    /// @notice Reference to Layer 1 contract (AgentIdentity)
    address public agentIdentityContract;
    
    /// @notice Reference to Layer 2 contract (SoulboundResume)
    address public soulboundResumeContract;
    
    /// @notice Minimum number of verifiers required for consensus (if enabled)
    uint256 public minVerifiersForConsensus;
    
    /// @notice Whether consensus mode is enabled
    bool public consensusModeEnabled;
    
    // ============ Events ============
    
    /// @notice Emitted when layer contracts are linked
    event LayerLinked(address indexed layer1, address indexed layer2);
    
    /// @notice Emitted when consensus settings are updated
    event ConsensusSettingsUpdated(bool enabled, uint256 minVerifiers);
    
    /// @notice Emitted when a job is verified through L3
    event JobVerified(
        uint256 indexed agentId,
        uint256 indexed jobId,
        address indexed verifier,
        bool success,
        bytes32 proofHash
    );
    
    // ============ Modifiers ============
    
    /**
     * @notice Ensure caller is an authorized verifier or owner
     */
    modifier onlyVerifierOrOwner() {
        require(
            isVerifier[msg.sender] || msg.sender == owner(),
            "VerificationRegistry: not authorized"
        );
        _;
    }
    
    /**
     * @notice Ensure layers are linked
     */
    modifier layersLinked() {
        require(
            soulboundResumeContract != address(0),
            "VerificationRegistry: layers not linked"
        );
        _;
    }
    
    // ============ Constructor ============
    
    /**
     * @notice Initialize the VerificationRegistry
     * @param initialOwner The owner of the contract
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        minVerifiersForConsensus = 1;
        consensusModeEnabled = false;
    }
    
    // ============ Layer Linking ============
    
    /**
     * @notice Link Layer 1 and Layer 2 contracts
     * @param _agentIdentity Address of the AgentIdentity contract
     * @param _soulboundResume Address of the SoulboundResume contract
     */
    function linkLayers(
        address _agentIdentity,
        address _soulboundResume
    ) external onlyOwner {
        require(soulboundResumeContract == address(0), "VerificationRegistry: layers already linked");
        require(_agentIdentity != address(0), "VerificationRegistry: invalid L1 address");
        require(_soulboundResume != address(0), "VerificationRegistry: invalid L2 address");
        
        agentIdentityContract = _agentIdentity;
        soulboundResumeContract = _soulboundResume;
        
        emit LayerLinked(_agentIdentity, _soulboundResume);
    }
    
    // ============ IValidationRegistry Implementation ============
    
    /**
     * @inheritdoc IValidationRegistry
     */
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestUri,
        bytes32 requestHash
    ) external override layersLinked {
        require(validatorAddress != address(0), "VerificationRegistry: invalid validator");
        require(
            isVerifier[validatorAddress] || validatorAddress == owner(),
            "VerificationRegistry: validator not authorized"
        );
        require(
            _validationRequests[requestHash].timestamp == 0,
            "VerificationRegistry: request already exists"
        );
        
        ValidationRequest memory newRequest = ValidationRequest({
            validatorAddress: validatorAddress,
            agentId: agentId,
            requestHash: requestHash,
            requestUri: requestUri,
            status: ValidationStatus.Pending,
            response: 0,
            responseUri: "",
            responseHash: bytes32(0),
            tag: bytes32(0),
            timestamp: block.timestamp,
            lastUpdate: block.timestamp
        });
        
        _validationRequests[requestHash] = newRequest;
        _agentValidations[agentId].push(requestHash);
        _validatorRequests[validatorAddress].push(requestHash);
        
        emit ValidationRequested(validatorAddress, agentId, requestUri, requestHash);
    }
    
    /**
     * @inheritdoc IValidationRegistry
     */
    function validationResponse(
        bytes32 requestHash,
        uint8 response,
        string calldata responseUri,
        bytes32 responseHash,
        bytes32 tag
    ) external override onlyVerifierOrOwner layersLinked {
        ValidationRequest storage request = _validationRequests[requestHash];
        
        require(request.timestamp != 0, "VerificationRegistry: request not found");
        require(
            request.validatorAddress == msg.sender || msg.sender == owner(),
            "VerificationRegistry: not designated validator"
        );
        require(
            request.status == ValidationStatus.Pending,
            "VerificationRegistry: request already processed"
        );
        require(response <= 100, "VerificationRegistry: response must be 0-100");
        
        // Update request
        request.response = response;
        request.responseUri = responseUri;
        request.responseHash = responseHash;
        request.tag = tag;
        request.lastUpdate = block.timestamp;
        
        // Determine status based on response
        // 0-49 = Rejected, 50+ = Approved
        if (response >= 50) {
            request.status = ValidationStatus.Approved;
        } else {
            request.status = ValidationStatus.Rejected;
        }
        
        emit ValidationResponse(msg.sender, request.agentId, requestHash, response, responseUri, tag);
    }
    
    /**
     * @inheritdoc IValidationRegistry
     */
    function getValidationStatus(bytes32 requestHash) external view override returns (
        address validatorAddress,
        uint256 agentId,
        uint8 response,
        bytes32 tag,
        uint256 lastUpdate
    ) {
        ValidationRequest storage request = _validationRequests[requestHash];
        return (
            request.validatorAddress,
            request.agentId,
            request.response,
            request.tag,
            request.lastUpdate
        );
    }
    
    /**
     * @inheritdoc IValidationRegistry
     */
    function getValidationSummary(
        uint256 agentId,
        address[] calldata validatorAddresses,
        bytes32 tag
    ) external view override returns (uint64 count, uint8 avgResponse) {
        bytes32[] storage hashes = _agentValidations[agentId];
        
        uint256 totalResponse = 0;
        uint64 matchCount = 0;
        
        for (uint256 i = 0; i < hashes.length; i++) {
            ValidationRequest storage request = _validationRequests[hashes[i]];
            
            // Skip pending requests
            if (request.status == ValidationStatus.Pending) continue;
            
            // Apply tag filter
            if (tag != bytes32(0) && request.tag != tag) continue;
            
            // Apply validator filter
            if (validatorAddresses.length > 0) {
                bool validatorMatch = false;
                for (uint256 j = 0; j < validatorAddresses.length; j++) {
                    if (request.validatorAddress == validatorAddresses[j]) {
                        validatorMatch = true;
                        break;
                    }
                }
                if (!validatorMatch) continue;
            }
            
            totalResponse += request.response;
            matchCount++;
        }
        
        count = matchCount;
        avgResponse = matchCount > 0 ? uint8(totalResponse / matchCount) : 0;
    }
    
    /**
     * @inheritdoc IValidationRegistry
     */
    function addVerifier(address verifier) external override onlyOwner {
        require(verifier != address(0), "VerificationRegistry: invalid address");
        require(!isVerifier[verifier], "VerificationRegistry: already a verifier");
        
        isVerifier[verifier] = true;
        _verifierList.push(verifier);
        
        emit VerifierAdded(verifier);
    }
    
    /**
     * @inheritdoc IValidationRegistry
     */
    function removeVerifier(address verifier) external override onlyOwner {
        require(isVerifier[verifier], "VerificationRegistry: not a verifier");
        
        isVerifier[verifier] = false;
        
        // Remove from list
        for (uint256 i = 0; i < _verifierList.length; i++) {
            if (_verifierList[i] == verifier) {
                _verifierList[i] = _verifierList[_verifierList.length - 1];
                _verifierList.pop();
                break;
            }
        }
        
        emit VerifierRemoved(verifier);
    }
    
    // ============ Job Verification (Main Interface) ============
    
    /**
     * @notice Verify a job directly (simplified interface)
     * @dev This is the main function for verifying jobs on resumes
     * @param agentId The agent ID
     * @param jobId The job ID to verify
     * @param success Whether the job was successful
     * @param proofHash Hash of verification proof
     */
    function verifyJob(
        uint256 agentId,
        uint256 jobId,
        bool success,
        bytes32 proofHash
    ) external onlyVerifierOrOwner layersLinked {
        SoulboundResume resume = SoulboundResume(soulboundResumeContract);
        
        // Status is always Verified when verification is complete
        // The 'success' parameter indicates whether the job was performed successfully
        SoulboundResume.JobStatus status = SoulboundResume.JobStatus.Verified;
        
        // Update job status in L2, storing the verification proof hash
        resume.updateJobStatus(agentId, jobId, status, success, proofHash);
        
        emit JobVerified(agentId, jobId, msg.sender, success, proofHash);
    }
    
    /**
     * @notice Dispute a job verification
     * @param agentId The agent ID
     * @param jobId The job ID to dispute
     */
    function disputeJob(
        uint256 agentId,
        uint256 jobId
    ) external onlyVerifierOrOwner layersLinked {
        SoulboundResume resume = SoulboundResume(soulboundResumeContract);
        
        // Mark job as disputed
        resume.updateJobStatus(
            agentId, 
            jobId, 
            SoulboundResume.JobStatus.Disputed, 
            false,
            bytes32(0) // No verification proof for disputes
        );
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get all verifiers
     * @return verifiers Array of verifier addresses
     */
    function getVerifiers() external view returns (address[] memory) {
        return _verifierList;
    }
    
    /**
     * @notice Get verifier count
     * @return count The number of verifiers
     */
    function getVerifierCount() external view returns (uint256) {
        return _verifierList.length;
    }
    
    /**
     * @notice Get validation requests for an agent
     * @param agentId The agent ID
     * @return hashes Array of request hashes
     */
    function getAgentValidationRequests(uint256 agentId) external view returns (bytes32[] memory) {
        return _agentValidations[agentId];
    }
    
    /**
     * @notice Get validation requests assigned to a validator
     * @param validator The validator address
     * @return hashes Array of request hashes
     */
    function getValidatorRequests(address validator) external view returns (bytes32[] memory) {
        return _validatorRequests[validator];
    }
    
    /**
     * @notice Get full validation request details
     * @param requestHash The request hash
     * @return request The full validation request struct
     */
    function getValidationRequest(bytes32 requestHash) external view returns (ValidationRequest memory) {
        return _validationRequests[requestHash];
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update consensus settings
     * @param enabled Whether consensus mode is enabled
     * @param minVerifiers Minimum verifiers required
     */
    function setConsensusSettings(
        bool enabled,
        uint256 minVerifiers
    ) external onlyOwner {
        require(minVerifiers > 0, "VerificationRegistry: min verifiers must be > 0");
        
        consensusModeEnabled = enabled;
        minVerifiersForConsensus = minVerifiers;
        
        emit ConsensusSettingsUpdated(enabled, minVerifiers);
    }
}
