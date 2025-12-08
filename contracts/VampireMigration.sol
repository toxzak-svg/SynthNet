// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./SynthNetProtocol.sol";
import "./SoulboundResume.sol";

/**
 * @title VampireMigration - Migration from Legacy to New Protocol
 * @notice Handles migration of agents and job records from AIAgentResumeSBT to SynthNetProtocol
 * @dev This is a one-time migration contract for transitioning to the layered architecture
 * 
 * Migration Strategy:
 *   1. Read all registered agents from legacy contract
 *   2. Register each agent on new protocol (L1 + L2)
 *   3. Migrate all job records with off-chain proof references
 *   4. Preserve reputation scores
 *   5. Mark legacy contract as deprecated
 * 
 * Data Availability:
 *   - Existing on-chain data is migrated directly
 *   - New proofUri field populated with placeholder or IPFS reference
 *   - Legacy proofHash values preserved for verification
 */

/**
 * @notice Interface for the legacy AIAgentResumeSBT contract
 */
interface ILegacyResumeSBT {
    enum JobType {
        TradeExecution,
        TreasuryManagement,
        ContentCompliance
    }
    
    enum VerificationStatus {
        Pending,
        Verified,
        Failed,
        Disputed
    }
    
    struct JobRecord {
        uint256 jobId;
        address employer;
        JobType jobType;
        VerificationStatus status;
        uint256 timestamp;
        string description;
        bytes32 proofHash;
        uint256 value;
        bool success;
    }
    
    function getAgentJobs(address agent) external view returns (JobRecord[] memory);
    function getAgentStats(address agent) external view returns (
        uint256 totalJobs,
        uint256 successfulJobs,
        uint256 failedJobs,
        uint256 reputation
    );
    function getAgentTokenId(address agent) external view returns (uint256);
    function isAgentRegistered(address agent) external view returns (bool);
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract VampireMigration is Ownable, ReentrancyGuard {
    
    // ============ State Variables ============
    
    /// @notice Legacy contract address
    ILegacyResumeSBT public immutable legacyContract;
    
    /// @notice New protocol contract address
    SynthNetProtocol public immutable newProtocol;
    
    /// @notice Mapping of migrated agents (legacy address => new agentId)
    mapping(address => uint256) public migratedAgents;
    
    /// @notice Mapping of migrated jobs (legacy address => legacy jobId => new jobId)
    mapping(address => mapping(uint256 => uint256)) public migratedJobs;
    
    /// @notice Total agents migrated
    uint256 public totalMigrated;
    
    /// @notice Total jobs migrated
    uint256 public totalJobsMigrated;
    
    /// @notice Migration is complete flag
    bool public migrationComplete;
    
    /// @notice Base URI for legacy proof data (IPFS/Arweave gateway)
    string public legacyProofBaseUri;
    
    // ============ Events ============
    
    /// @notice Emitted when an agent is migrated
    event AgentMigrated(
        address indexed legacyAddress,
        uint256 indexed newAgentId,
        uint256 indexed newResumeId,
        uint256 jobCount
    );
    
    /// @notice Emitted when a job is migrated
    event JobMigrated(
        address indexed legacyAddress,
        uint256 legacyJobId,
        uint256 indexed newAgentId,
        uint256 indexed newJobId
    );
    
    /// @notice Emitted when migration is finalized
    event MigrationFinalized(uint256 totalAgents, uint256 totalJobs);
    
    // ============ Constructor ============
    
    /**
     * @notice Initialize the migration contract
     * @param _legacyContract Address of the legacy AIAgentResumeSBT
     * @param _newProtocol Address of the new SynthNetProtocol
     * @param _legacyProofBaseUri Base URI for referencing legacy proofs
     */
    constructor(
        address _legacyContract,
        address _newProtocol,
        string memory _legacyProofBaseUri
    ) Ownable(msg.sender) {
        require(_legacyContract != address(0), "VampireMigration: invalid legacy address");
        require(_newProtocol != address(0), "VampireMigration: invalid protocol address");
        
        legacyContract = ILegacyResumeSBT(_legacyContract);
        newProtocol = SynthNetProtocol(_newProtocol);
        legacyProofBaseUri = _legacyProofBaseUri;
    }
    
    // ============ Migration Functions ============
    
    /**
     * @notice Migrate a single agent with all their job records
     * @param legacyAgentAddress The agent's address in the legacy contract
     * @return newAgentId The new agent ID in the protocol
     */
    function migrateAgent(address legacyAgentAddress) external nonReentrant returns (uint256 newAgentId) {
        require(!migrationComplete, "VampireMigration: migration is complete");
        require(migratedAgents[legacyAgentAddress] == 0, "VampireMigration: agent already migrated");
        require(
            legacyContract.isAgentRegistered(legacyAgentAddress),
            "VampireMigration: agent not registered in legacy"
        );
        
        // Get legacy stats for reference
        (uint256 legacyTotalJobs, , , uint256 legacyReputation) = legacyContract.getAgentStats(legacyAgentAddress);
        
        // Create token URI with migration metadata
        string memory tokenUri = string(abi.encodePacked(
            legacyProofBaseUri,
            "/migration/",
            _addressToString(legacyAgentAddress)
        ));
        
        // Create metadata entries
        IIdentityRegistry.MetadataEntry[] memory metadata = new IIdentityRegistry.MetadataEntry[](3);
        metadata[0] = IIdentityRegistry.MetadataEntry({
            key: "migratedFrom",
            value: abi.encode(address(legacyContract))
        });
        metadata[1] = IIdentityRegistry.MetadataEntry({
            key: "legacyAddress",
            value: abi.encode(legacyAgentAddress)
        });
        metadata[2] = IIdentityRegistry.MetadataEntry({
            key: "legacyReputation",
            value: abi.encode(legacyReputation)
        });
        
        // Register on new protocol (simulating the agent's registration)
        // Note: This requires the migration contract to have special privileges
        // or the agent to call this themselves
        (newAgentId, ) = newProtocol.registerAgent(tokenUri, metadata);
        
        migratedAgents[legacyAgentAddress] = newAgentId;
        
        // Migrate all job records
        uint256 jobsMigrated = _migrateJobs(legacyAgentAddress, newAgentId);
        
        totalMigrated++;
        
        emit AgentMigrated(legacyAgentAddress, newAgentId, newAgentId, jobsMigrated);
        
        return newAgentId;
    }
    
    /**
     * @notice Migrate multiple agents in a single transaction
     * @param legacyAgentAddresses Array of agent addresses to migrate
     * @return newAgentIds Array of new agent IDs
     */
    function migrateAgentsBatch(
        address[] calldata legacyAgentAddresses
    ) external nonReentrant returns (uint256[] memory newAgentIds) {
        require(!migrationComplete, "VampireMigration: migration is complete");
        
        newAgentIds = new uint256[](legacyAgentAddresses.length);
        
        for (uint256 i = 0; i < legacyAgentAddresses.length; i++) {
            address legacyAddr = legacyAgentAddresses[i];
            
            if (migratedAgents[legacyAddr] != 0) {
                // Already migrated, skip
                newAgentIds[i] = migratedAgents[legacyAddr];
                continue;
            }
            
            if (!legacyContract.isAgentRegistered(legacyAddr)) {
                // Not registered in legacy, skip
                continue;
            }
            
            // Migrate this agent
            newAgentIds[i] = _migrateAgentInternal(legacyAddr);
        }
        
        return newAgentIds;
    }
    
    /**
     * @notice Self-migration: Agent migrates their own data
     * @dev Agent calls this to migrate themselves
     * @return newAgentId The new agent ID
     */
    function selfMigrate() external nonReentrant returns (uint256 newAgentId) {
        require(!migrationComplete, "VampireMigration: migration is complete");
        require(migratedAgents[msg.sender] == 0, "VampireMigration: already migrated");
        require(
            legacyContract.isAgentRegistered(msg.sender),
            "VampireMigration: not registered in legacy"
        );
        
        return _migrateAgentInternal(msg.sender);
    }
    
    // ============ Internal Migration Functions ============
    
    /**
     * @notice Internal agent migration logic
     * @param legacyAgentAddress The legacy agent address
     * @return newAgentId The new agent ID
     */
    function _migrateAgentInternal(address legacyAgentAddress) internal returns (uint256 newAgentId) {
        // Get legacy data
        (uint256 legacyTotalJobs, , , uint256 legacyReputation) = legacyContract.getAgentStats(legacyAgentAddress);
        
        // Create token URI
        string memory tokenUri = string(abi.encodePacked(
            legacyProofBaseUri,
            "/migration/",
            _addressToString(legacyAgentAddress)
        ));
        
        // Create metadata
        IIdentityRegistry.MetadataEntry[] memory metadata = new IIdentityRegistry.MetadataEntry[](3);
        metadata[0] = IIdentityRegistry.MetadataEntry({
            key: "migratedFrom",
            value: abi.encode(address(legacyContract))
        });
        metadata[1] = IIdentityRegistry.MetadataEntry({
            key: "legacyAddress",
            value: abi.encode(legacyAgentAddress)
        });
        metadata[2] = IIdentityRegistry.MetadataEntry({
            key: "legacyReputation",
            value: abi.encode(legacyReputation)
        });
        
        // Register on new protocol
        (newAgentId, ) = newProtocol.registerAgent(tokenUri, metadata);
        
        migratedAgents[legacyAgentAddress] = newAgentId;
        
        // Migrate jobs
        uint256 jobsMigrated = _migrateJobs(legacyAgentAddress, newAgentId);
        
        totalMigrated++;
        
        emit AgentMigrated(legacyAgentAddress, newAgentId, newAgentId, jobsMigrated);
        
        return newAgentId;
    }
    
    /**
     * @notice Migrate all jobs for an agent
     * @param legacyAgentAddress The legacy agent address
     * @param newAgentId The new agent ID
     * @return jobCount Number of jobs migrated
     */
    function _migrateJobs(
        address legacyAgentAddress,
        uint256 newAgentId
    ) internal returns (uint256 jobCount) {
        ILegacyResumeSBT.JobRecord[] memory legacyJobs = legacyContract.getAgentJobs(legacyAgentAddress);
        
        for (uint256 i = 0; i < legacyJobs.length; i++) {
            ILegacyResumeSBT.JobRecord memory legacyJob = legacyJobs[i];
            
            // Convert legacy job type to new job type
            SoulboundResume.JobType newJobType = _convertJobType(legacyJob.jobType);
            
            // Create proof URI from legacy hash
            string memory proofUri = string(abi.encodePacked(
                legacyProofBaseUri,
                "/proofs/",
                _bytes32ToHexString(legacyJob.proofHash)
            ));
            
            // Add job to new protocol
            // Note: We're paying the verification fee here
            uint256 verificationFee = newProtocol.getVerificationFee();
            
            uint256 newJobId = newProtocol.addJobRecord{value: verificationFee}(
                newAgentId,
                newJobType,
                legacyJob.description,
                proofUri,
                legacyJob.proofHash,
                legacyJob.value
            );
            
            migratedJobs[legacyAgentAddress][legacyJob.jobId] = newJobId;
            totalJobsMigrated++;
            
            emit JobMigrated(legacyAgentAddress, legacyJob.jobId, newAgentId, newJobId);
        }
        
        return legacyJobs.length;
    }
    
    /**
     * @notice Convert legacy job type to new job type
     * @param legacyType The legacy job type enum
     * @return newType The new job type enum
     */
    function _convertJobType(
        ILegacyResumeSBT.JobType legacyType
    ) internal pure returns (SoulboundResume.JobType newType) {
        if (legacyType == ILegacyResumeSBT.JobType.TradeExecution) {
            return SoulboundResume.JobType.TradeExecution;
        } else if (legacyType == ILegacyResumeSBT.JobType.TreasuryManagement) {
            return SoulboundResume.JobType.TreasuryManagement;
        } else if (legacyType == ILegacyResumeSBT.JobType.ContentCompliance) {
            return SoulboundResume.JobType.ContentCompliance;
        }
        return SoulboundResume.JobType.Custom;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Finalize the migration
     * @dev Prevents further migrations
     */
    function finalizeMigration() external onlyOwner {
        require(!migrationComplete, "VampireMigration: already finalized");
        
        migrationComplete = true;
        
        emit MigrationFinalized(totalMigrated, totalJobsMigrated);
    }
    
    /**
     * @notice Update the legacy proof base URI
     * @param newBaseUri The new base URI
     */
    function setLegacyProofBaseUri(string calldata newBaseUri) external onlyOwner {
        legacyProofBaseUri = newBaseUri;
    }
    
    /**
     * @notice Withdraw any ETH from the contract
     * @param to The recipient address
     */
    function withdraw(address payable to) external onlyOwner {
        require(to != address(0), "VampireMigration: invalid address");
        uint256 balance = address(this).balance;
        require(balance > 0, "VampireMigration: no balance");
        
        (bool success, ) = to.call{value: balance}("");
        require(success, "VampireMigration: withdrawal failed");
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Check if an agent has been migrated
     * @param legacyAddress The legacy agent address
     * @return migrated True if migrated
     * @return newAgentId The new agent ID (0 if not migrated)
     */
    function isMigrated(address legacyAddress) external view returns (bool migrated, uint256 newAgentId) {
        newAgentId = migratedAgents[legacyAddress];
        migrated = newAgentId != 0;
    }
    
    /**
     * @notice Get migration statistics
     * @return agents Total agents migrated
     * @return jobs Total jobs migrated
     * @return complete Whether migration is finalized
     */
    function getMigrationStats() external view returns (
        uint256 agents,
        uint256 jobs,
        bool complete
    ) {
        return (totalMigrated, totalJobsMigrated, migrationComplete);
    }
    
    // ============ Utility Functions ============
    
    /**
     * @notice Convert address to string
     * @param addr The address
     * @return The address as a hex string
     */
    function _addressToString(address addr) internal pure returns (string memory) {
        bytes memory data = abi.encodePacked(addr);
        bytes memory alphabet = "0123456789abcdef";
        
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(data[i] & 0x0f)];
        }
        
        return string(str);
    }
    
    /**
     * @notice Convert bytes32 to hex string
     * @param data The bytes32 value
     * @return The hex string
     */
    function _bytes32ToHexString(bytes32 data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(64);
        
        for (uint256 i = 0; i < 32; i++) {
            str[i * 2] = alphabet[uint8(data[i] >> 4)];
            str[i * 2 + 1] = alphabet[uint8(data[i] & 0x0f)];
        }
        
        return string(str);
    }
    
    // ============ Receive ETH ============
    
    /**
     * @notice Receive ETH for migration fees
     */
    receive() external payable {}
}
