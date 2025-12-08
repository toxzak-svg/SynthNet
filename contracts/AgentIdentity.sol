// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC8004.sol";

/**
 * @title AgentIdentity - Layer 1: AI Agent Identity Registry
 * @notice ERC-8004 compliant identity registry for AI agents
 * @dev This is Layer 1 of the SynthNet protocol stack
 *      - Manages agent registration and identity tokens
 *      - Stores on-chain metadata with off-chain data references (IPFS/Arweave)
 *      - Tokens ARE transferable (identity ownership can change)
 *      - Links to Layer 2 (SoulboundResume) for work history
 * 
 * Architecture:
 *   Layer 1 (AgentIdentity) - Identity & Metadata
 *   Layer 2 (SoulboundResume) - Job History & Reputation (ERC-5192)
 *   Layer 3 (VerificationRegistry) - Validation & Verification
 */
contract AgentIdentity is ERC721, ERC721URIStorage, Ownable, IIdentityRegistry {
    
    // ============ State Variables ============
    
    /// @notice Counter for generating unique agent IDs
    uint256 private _nextAgentId;
    
    /// @notice Mapping from agent ID to metadata key-value pairs
    mapping(uint256 => mapping(string => bytes)) private _metadata;
    
    /// @notice Mapping from agent ID to list of metadata keys (for enumeration)
    mapping(uint256 => string[]) private _metadataKeys;
    
    /// @notice Mapping from agent address to agent ID (for quick lookup)
    mapping(address => uint256) private _addressToAgentId;
    
    /// @notice Mapping to track if an address has a registered agent
    mapping(address => bool) private _hasRegistered;
    
    /// @notice Mapping from L1 agent ID to L2 resume token ID
    mapping(uint256 => uint256) private _agentToResumeToken;
    
    /// @notice Reference to Layer 2 contract (set after deployment)
    address public soulboundResumeContract;
    
    /// @notice Reference to Layer 3 contract (set after deployment)
    address public verificationRegistryContract;
    
    // ============ Standard Metadata Keys ============
    
    /// @notice Standard key for agent name
    string public constant KEY_NAME = "name";
    
    /// @notice Standard key for agent model/version
    string public constant KEY_MODEL = "model";
    
    /// @notice Standard key for agent capabilities
    string public constant KEY_CAPABILITIES = "capabilities";
    
    /// @notice Standard key for agent description
    string public constant KEY_DESCRIPTION = "description";
    
    /// @notice Standard key for agent creation timestamp
    string public constant KEY_CREATED_AT = "createdAt";
    
    // ============ Events ============
    
    /// @notice Emitted when layer contracts are linked
    event LayerLinked(address indexed layer2, address indexed layer3);
    
    // ============ Constructor ============
    
    /**
     * @notice Initialize the AgentIdentity registry
     * @param initialOwner The owner of the contract
     */
    constructor(address initialOwner) 
        ERC721("SynthNet Agent Identity", "SYNTH-ID") 
        Ownable(initialOwner) 
    {
        _nextAgentId = 1; // Start IDs at 1
    }
    
    // ============ Layer Linking ============
    
    /**
     * @notice Link Layer 2 and Layer 3 contracts
     * @dev Can only be called once by owner
     * @param _soulboundResume Address of the SoulboundResume contract
     * @param _verificationRegistry Address of the VerificationRegistry contract
     */
    function linkLayers(
        address _soulboundResume,
        address _verificationRegistry
    ) external onlyOwner {
        require(soulboundResumeContract == address(0), "AgentIdentity: layers already linked");
        require(_soulboundResume != address(0), "AgentIdentity: invalid L2 address");
        require(_verificationRegistry != address(0), "AgentIdentity: invalid L3 address");
        
        soulboundResumeContract = _soulboundResume;
        verificationRegistryContract = _verificationRegistry;
        
        emit LayerLinked(_soulboundResume, _verificationRegistry);
    }
    
    // ============ IIdentityRegistry Implementation ============
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function register(
        string calldata _tokenURI,
        MetadataEntry[] calldata metadata
    ) external override returns (uint256 agentId) {
        return _registerFor(msg.sender, _tokenURI, metadata);
    }
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function register(string calldata _tokenURI) external override returns (uint256 agentId) {
        MetadataEntry[] memory empty = new MetadataEntry[](0);
        return _registerFor(msg.sender, _tokenURI, empty);
    }
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function register() external override returns (uint256 agentId) {
        MetadataEntry[] memory empty = new MetadataEntry[](0);
        return _registerFor(msg.sender, "", empty);
    }
    
    /**
     * @notice Register an agent on behalf of another address (protocol only)
     * @param recipient The address to receive the identity token
     * @param _tokenURI URI to off-chain data
     * @param metadata Initial metadata entries
     * @param resumeTokenId The L2 resume token ID to link to this identity
     * @return agentId The new agent ID
     */
    function registerFor(
        address recipient,
        string calldata _tokenURI,
        MetadataEntry[] calldata metadata,
        uint256 resumeTokenId
    ) external returns (uint256 agentId) {
        require(msg.sender == owner(), "AgentIdentity: only owner can registerFor");
        agentId = _registerFor(recipient, _tokenURI, metadata);
        _agentToResumeToken[agentId] = resumeTokenId;
        return agentId;
    }
    
    /**
     * @notice Internal registration logic
     */
    function _registerFor(
        address recipient,
        string memory _tokenURI,
        MetadataEntry[] memory metadata
    ) internal returns (uint256 agentId) {
        require(!_hasRegistered[recipient], "AgentIdentity: already registered");
        require(recipient != address(0), "AgentIdentity: invalid recipient");
        
        agentId = _nextAgentId++;
        
        // Mint identity token to the recipient
        _mint(recipient, agentId);
        
        if (bytes(_tokenURI).length > 0) {
            _setTokenURI(agentId, _tokenURI);
        }
        
        // Store address mapping
        _addressToAgentId[recipient] = agentId;
        _hasRegistered[recipient] = true;
        
        // Store creation timestamp
        _setMetadataInternal(agentId, KEY_CREATED_AT, abi.encode(block.timestamp));
        
        // Store provided metadata
        for (uint256 i = 0; i < metadata.length; i++) {
            _setMetadataInternal(agentId, metadata[i].key, metadata[i].value);
        }
        
        emit Registered(agentId, _tokenURI, recipient);
        
        return agentId;
    }
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function getMetadata(
        uint256 agentId, 
        string calldata key
    ) external view override returns (bytes memory value) {
        require(_ownerOf(agentId) != address(0), "AgentIdentity: agent does not exist");
        return _metadata[agentId][key];
    }
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function setMetadata(
        uint256 agentId, 
        string calldata key, 
        bytes calldata value
    ) external override {
        require(_ownerOf(agentId) == msg.sender, "AgentIdentity: not agent owner");
        _setMetadataInternal(agentId, key, value);
    }
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function isRegistered(uint256 agentId) external view override returns (bool) {
        return _ownerOf(agentId) != address(0);
    }
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function ownerOf(uint256 agentId) public view override(ERC721, IERC721, IIdentityRegistry) returns (address) {
        return super.ownerOf(agentId);
    }
    
    // ============ Additional View Functions ============
    
    /**
     * @notice Get agent ID by owner address
     * @param owner The owner address
     * @return agentId The agent ID (0 if not registered)
     */
    function getAgentIdByAddress(address owner) external view returns (uint256) {
        return _addressToAgentId[owner];
    }
    
    /**
     * @notice Check if an address has registered an agent
     * @param owner The address to check
     * @return bool True if registered
     */
    function hasRegisteredAgent(address owner) external view returns (bool) {
        return _hasRegistered[owner];
    }
    
    /**
     * @notice Get all metadata keys for an agent
     * @param agentId The agent ID
     * @return keys Array of metadata keys
     */
    function getMetadataKeys(uint256 agentId) external view returns (string[] memory) {
        return _metadataKeys[agentId];
    }
    
    /**
     * @notice Get the total number of registered agents
     * @return count The total count
     */
    function totalAgents() external view returns (uint256) {
        return _nextAgentId - 1;
    }
    
    /**
     * @notice Get the L2 resume token ID linked to this L1 agent ID
     * @param agentId The L1 agent ID
     * @return resumeTokenId The linked L2 resume token ID (0 if none)
     */
    function getResumeTokenId(uint256 agentId) external view returns (uint256) {
        require(_ownerOf(agentId) != address(0), "AgentIdentity: agent does not exist");
        return _agentToResumeToken[agentId];
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Internal function to set metadata
     * @param agentId The agent ID
     * @param key The metadata key
     * @param value The metadata value
     */
    function _setMetadataInternal(
        uint256 agentId,
        string memory key,
        bytes memory value
    ) internal {
        // Track new keys for enumeration
        if (_metadata[agentId][key].length == 0 && value.length > 0) {
            _metadataKeys[agentId].push(key);
        }
        
        _metadata[agentId][key] = value;
        
        emit MetadataSet(agentId, key, key, value);
    }
    
    // ============ Override Required Functions ============
    
    /**
     * @dev Override required by Solidity for multiple inheritance
     */
    function tokenURI(uint256 tokenId) 
        public 
        view 
        override(ERC721, ERC721URIStorage) 
        returns (string memory) 
    {
        return super.tokenURI(tokenId);
    }
    
    /**
     * @dev Override required by Solidity for multiple inheritance
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
