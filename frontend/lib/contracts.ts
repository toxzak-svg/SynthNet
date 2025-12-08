export const AGENT_IDENTITY_ABI = [
  "function getAgentData(uint256 agentId) external view returns (tuple(string serviceUrl, string category, address paymentAddress))",
  "function getMetadata(uint256 agentId, string key) external view returns (bytes)",
  "function ownerOf(uint256 agentId) external view returns (address)",
  "function isRegistered(uint256 agentId) external view returns (bool)",
  "function getServiceUrl(uint256 agentId) external view returns (string)",
  "function getCategory(uint256 agentId) external view returns (string)",
  "function getPaymentAddress(uint256 agentId) external view returns (address)"
];

export const SOULBOUND_RESUME_ABI = [
  "function getReputation(uint256 agentId) external view returns (uint256)",
  "function getJobRecords(uint256 agentId) external view returns (tuple(uint256 jobId, address employer, uint8 jobType, uint8 status, uint256 timestamp, uint256 value, bytes32 proofHash, string proofUri, string description, bool success, bytes32 tag1, bytes32 tag2)[])",
  "function getAgentStats(uint256 agentId) external view returns (uint256 totalJobs, uint256 successfulJobs, uint256 failedJobs, uint256 reputation)",
  "function getResumeId(uint256 agentId) external view returns (uint256)",
  "function locked(uint256 tokenId) external view returns (bool)"
];

export const VERIFICATION_REGISTRY_ABI = [
  "function isVerifier(address verifier) external view returns (bool)",
  "function getVerifiers() external view returns (address[])"
];

// Contract addresses (update these after deployment)
export const CONTRACT_ADDRESSES = {
  AgentIdentity: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  SoulboundResume: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
  VerificationRegistry: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
};

// Job type enum
export const JOB_TYPES = [
  "Trade Execution",
  "Treasury Management",
  "Content Compliance",
  "Data Analysis",
  "Smart Contract Audit",
  "Governance Voting",
  "Custom"
];

// Job status enum
export const JOB_STATUS = [
  "Pending",
  "Verified",
  "Failed",
  "Disputed"
];
