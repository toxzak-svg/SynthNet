// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IIdentityRegistry - ERC-8004 Identity Registry Interface
 * @notice Interface for AI Agent identity registration and metadata management
 * @dev Based on ERC-8004 Trustless Agents specification (Draft)
 *      Customized for SynthNet's proof-of-work resume protocol
 */
interface IIdentityRegistry {
    /**
     * @notice Metadata entry for agent registration
     * @param key The metadata key (e.g., "name", "model", "capabilities")
     * @param value The metadata value as bytes
     */
    struct MetadataEntry {
        string key;
        bytes value;
    }

    /**
     * @notice Emitted when a new agent is registered
     * @param agentId The unique identifier (token ID) for the agent
     * @param tokenURI URI pointing to off-chain agent data (IPFS/Arweave)
     * @param owner The address that owns this agent identity
     */
    event Registered(uint256 indexed agentId, string tokenURI, address indexed owner);

    /**
     * @notice Emitted when agent metadata is updated
     * @param agentId The agent's unique identifier
     * @param indexedKey Indexed version of the key for filtering
     * @param key The metadata key
     * @param value The new metadata value
     */
    event MetadataSet(
        uint256 indexed agentId,
        string indexed indexedKey,
        string key,
        bytes value
    );

    /**
     * @notice Register a new AI agent with tokenURI and metadata
     * @param _tokenURI URI pointing to off-chain agent data (IPFS/Arweave CID)
     * @param metadata Array of initial metadata entries
     * @return agentId The unique identifier for the registered agent
     */
    function register(
        string calldata _tokenURI,
        MetadataEntry[] calldata metadata
    ) external returns (uint256 agentId);

    /**
     * @notice Register a new AI agent with only tokenURI
     * @param _tokenURI URI pointing to off-chain agent data
     * @return agentId The unique identifier for the registered agent
     */
    function register(string calldata _tokenURI) external returns (uint256 agentId);

    /**
     * @notice Register a new AI agent with minimal data
     * @return agentId The unique identifier for the registered agent
     */
    function register() external returns (uint256 agentId);

    /**
     * @notice Get metadata value for a specific key
     * @param agentId The agent's unique identifier
     * @param key The metadata key to retrieve
     * @return value The metadata value as bytes
     */
    function getMetadata(uint256 agentId, string calldata key) external view returns (bytes memory value);

    /**
     * @notice Set metadata value for a specific key
     * @param agentId The agent's unique identifier
     * @param key The metadata key to set
     * @param value The metadata value as bytes
     */
    function setMetadata(uint256 agentId, string calldata key, bytes calldata value) external;

    /**
     * @notice Check if an agent is registered
     * @param agentId The agent's unique identifier
     * @return bool True if the agent is registered
     */
    function isRegistered(uint256 agentId) external view returns (bool);

    /**
     * @notice Get the owner of an agent identity
     * @param agentId The agent's unique identifier
     * @return owner The owner address
     */
    function ownerOf(uint256 agentId) external view returns (address owner);
}

/**
 * @title IReputationRegistry - ERC-8004 Reputation Registry Interface
 * @notice Interface for managing AI agent reputation and feedback
 * @dev Customized for SynthNet's job-based reputation system
 *      Reputation lives on Layer 2 (soulbound) but heavy data is off-chain
 */
interface IReputationRegistry {
    /**
     * @notice Feedback record structure
     * @param score Feedback score (0-100)
     * @param tag1 Primary category tag (e.g., keccak256("TradeExecution"))
     * @param tag2 Secondary category tag
     * @param fileUri URI to detailed feedback data (IPFS/Arweave)
     * @param fileHash Hash of the feedback file for verification
     * @param timestamp When the feedback was given
     * @param isRevoked Whether the feedback has been revoked
     */
    struct Feedback {
        uint8 score;
        bytes32 tag1;
        bytes32 tag2;
        string fileUri;
        bytes32 fileHash;
        uint256 timestamp;
        bool isRevoked;
    }

    /**
     * @notice Emitted when new feedback is given to an agent
     */
    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint8 score,
        bytes32 indexed tag1,
        bytes32 tag2,
        string fileUri,
        bytes32 fileHash
    );

    /**
     * @notice Emitted when feedback is revoked
     */
    event FeedbackRevoked(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 indexed feedbackIndex
    );

    /**
     * @notice Emitted when reputation score is updated
     */
    event ReputationUpdated(
        uint256 indexed agentId,
        uint256 oldScore,
        uint256 newScore
    );

    /**
     * @notice Give feedback to an agent for completed work
     * @param agentId The agent's unique identifier
     * @param score Feedback score (0-100)
     * @param tag1 Primary category tag
     * @param tag2 Secondary category tag  
     * @param fileUri URI to detailed feedback (IPFS/Arweave)
     * @param fileHash Hash of the feedback file
     * @param feedbackAuth Signature from agent authorizing feedback
     */
    function giveFeedback(
        uint256 agentId,
        uint8 score,
        bytes32 tag1,
        bytes32 tag2,
        string calldata fileUri,
        bytes32 fileHash,
        bytes calldata feedbackAuth
    ) external;

    /**
     * @notice Revoke previously given feedback
     * @param agentId The agent's unique identifier
     * @param feedbackIndex The index of feedback to revoke
     */
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external;

    /**
     * @notice Get summary statistics for an agent
     * @param agentId The agent's unique identifier
     * @param clientAddresses Filter by specific clients (empty for all)
     * @param tag1 Filter by primary tag (bytes32(0) for all)
     * @param tag2 Filter by secondary tag (bytes32(0) for all)
     * @return count Number of matching feedback entries
     * @return averageScore Average score of matching entries
     */
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        bytes32 tag1,
        bytes32 tag2
    ) external view returns (uint64 count, uint8 averageScore);

    /**
     * @notice Read a specific feedback entry
     * @param agentId The agent's unique identifier
     * @param clientAddress The client who gave feedback
     * @param index The feedback index
     * @return score The feedback score
     * @return tag1 Primary tag
     * @return tag2 Secondary tag
     * @return isRevoked Whether revoked
     */
    function readFeedback(
        uint256 agentId,
        address clientAddress,
        uint64 index
    ) external view returns (uint8 score, bytes32 tag1, bytes32 tag2, bool isRevoked);

    /**
     * @notice Get all clients who have given feedback to an agent
     * @param agentId The agent's unique identifier
     * @return clients Array of client addresses
     */
    function getClients(uint256 agentId) external view returns (address[] memory clients);

    /**
     * @notice Get the total reputation score for an agent
     * @param agentId The agent's unique identifier
     * @return score The cumulative reputation score
     */
    function getReputation(uint256 agentId) external view returns (uint256 score);
}

/**
 * @title IValidationRegistry - ERC-8004 Validation Registry Interface
 * @notice Interface for job verification and validation
 * @dev Handles verification workflow for proof-of-work job history
 */
interface IValidationRegistry {
    /**
     * @notice Validation request status
     */
    enum ValidationStatus {
        Pending,
        Approved,
        Rejected,
        Disputed
    }

    /**
     * @notice Validation request structure
     */
    struct ValidationRequest {
        address validatorAddress;
        uint256 agentId;
        bytes32 requestHash;
        string requestUri;
        ValidationStatus status;
        uint8 response;
        string responseUri;
        bytes32 responseHash;
        bytes32 tag;
        uint256 timestamp;
        uint256 lastUpdate;
    }

    /**
     * @notice Emitted when a validation request is created
     */
    event ValidationRequested(
        address indexed validatorAddress,
        uint256 indexed agentId,
        string requestUri,
        bytes32 indexed requestHash
    );

    /**
     * @notice Emitted when a validator responds to a request
     */
    event ValidationResponse(
        address indexed validatorAddress,
        uint256 indexed agentId,
        bytes32 indexed requestHash,
        uint8 response,
        string responseUri,
        bytes32 tag
    );

    /**
     * @notice Emitted when a verifier is added
     */
    event VerifierAdded(address indexed verifier);

    /**
     * @notice Emitted when a verifier is removed
     */
    event VerifierRemoved(address indexed verifier);

    /**
     * @notice Submit a validation request
     * @param validatorAddress The designated validator
     * @param agentId The agent being validated
     * @param requestUri URI to validation request details (IPFS/Arweave)
     * @param requestHash Hash of the request for verification
     */
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestUri,
        bytes32 requestHash
    ) external;

    /**
     * @notice Submit a validation response
     * @param requestHash The hash of the original request
     * @param response Response value (0-100, where 100 = fully approved)
     * @param responseUri URI to detailed response (IPFS/Arweave)
     * @param responseHash Hash of the response file
     * @param tag Category tag for the validation
     */
    function validationResponse(
        bytes32 requestHash,
        uint8 response,
        string calldata responseUri,
        bytes32 responseHash,
        bytes32 tag
    ) external;

    /**
     * @notice Get the status of a validation request
     * @param requestHash The request hash
     * @return validatorAddress The validator
     * @return agentId The agent
     * @return response The response value
     * @return tag The category tag
     * @return lastUpdate Last update timestamp
     */
    function getValidationStatus(bytes32 requestHash) external view returns (
        address validatorAddress,
        uint256 agentId,
        uint8 response,
        bytes32 tag,
        uint256 lastUpdate
    );

    /**
     * @notice Get validation summary for an agent
     * @param agentId The agent's unique identifier
     * @param validatorAddresses Filter by validators (empty for all)
     * @param tag Filter by tag (bytes32(0) for all)
     * @return count Number of validations
     * @return avgResponse Average response score
     */
    function getValidationSummary(
        uint256 agentId,
        address[] calldata validatorAddresses,
        bytes32 tag
    ) external view returns (uint64 count, uint8 avgResponse);

    /**
     * @notice Check if an address is an authorized verifier
     * @param verifier The address to check
     * @return bool True if authorized
     */
    function isVerifier(address verifier) external view returns (bool);

    /**
     * @notice Add a new authorized verifier
     * @param verifier The address to authorize
     */
    function addVerifier(address verifier) external;

    /**
     * @notice Remove an authorized verifier
     * @param verifier The address to remove
     */
    function removeVerifier(address verifier) external;
}
