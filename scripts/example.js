const hre = require("hardhat");

/**
 * Example script demonstrating how to interact with the AIAgentResumeSBT contract
 */
async function main() {
  console.log("Starting AIAgentResumeSBT interaction example...\n");

  // Get signers
  const [owner, agent1, agent2, employer1, verifier1] = await hre.ethers.getSigners();
  
  console.log("Accounts:");
  console.log("- Owner:", owner.address);
  console.log("- Agent 1:", agent1.address);
  console.log("- Agent 2:", agent2.address);
  console.log("- Employer 1:", employer1.address);
  console.log("- Verifier 1:", verifier1.address);
  console.log();

  // Deploy contract
  console.log("Deploying AIAgentResumeSBT contract...");
  const verificationFee = hre.ethers.parseEther("0.01");
  const AIAgentResumeSBT = await hre.ethers.getContractFactory("AIAgentResumeSBT");
  const contract = await AIAgentResumeSBT.deploy(verificationFee);
  await contract.waitForDeployment();
  const contractAddress = await contract.getAddress();
  console.log("Contract deployed at:", contractAddress);
  console.log("Verification fee:", hre.ethers.formatEther(verificationFee), "ETH\n");

  // Add a verifier
  console.log("Adding verifier...");
  await contract.addVerifier(verifier1.address);
  console.log("Verifier added:", verifier1.address, "\n");

  // Register agents
  console.log("Registering Agent 1...");
  let tx = await contract.registerAgent(agent1.address);
  await tx.wait();
  const tokenId1 = await contract.getAgentTokenId(agent1.address);
  console.log("Agent 1 registered with token ID:", tokenId1.toString());

  console.log("Registering Agent 2...");
  tx = await contract.registerAgent(agent2.address);
  await tx.wait();
  const tokenId2 = await contract.getAgentTokenId(agent2.address);
  console.log("Agent 2 registered with token ID:", tokenId2.toString(), "\n");

  // Add job records for Agent 1
  console.log("Adding job records for Agent 1...");
  
  // Job 1: Trade Execution
  console.log("- Trade Execution Job");
  tx = await contract.connect(employer1).addJobRecord(
    agent1.address,
    0, // TradeExecution
    "Executed $10,000 swap on Uniswap with 0.1% slippage",
    hre.ethers.id("trade-proof-hash-123"),
    hre.ethers.parseEther("10000"),
    { value: verificationFee }
  );
  await tx.wait();

  // Job 2: Treasury Management
  console.log("- Treasury Management Job");
  tx = await contract.connect(employer1).addJobRecord(
    agent1.address,
    1, // TreasuryManagement
    "Managed DAO treasury of $100,000 for 30 days with 5% yield",
    hre.ethers.id("treasury-proof-hash-456"),
    hre.ethers.parseEther("100000"),
    { value: verificationFee }
  );
  await tx.wait();

  // Job 3: Content Compliance
  console.log("- Content Compliance Job");
  tx = await contract.connect(employer1).addJobRecord(
    agent1.address,
    2, // ContentCompliance
    "Posted 50 compliant social media posts with 0 violations",
    hre.ethers.id("content-proof-hash-789"),
    0,
    { value: verificationFee }
  );
  await tx.wait();
  console.log();

  // Verify jobs
  console.log("Verifying jobs for Agent 1...");
  
  // Verify Job 0 as successful
  console.log("- Verifying Trade Execution job as successful");
  tx = await contract.connect(verifier1).verifyJob(
    agent1.address,
    0,
    1, // Verified
    true // Success
  );
  await tx.wait();

  // Verify Job 1 as successful
  console.log("- Verifying Treasury Management job as successful");
  tx = await contract.connect(verifier1).verifyJob(
    agent1.address,
    1,
    1, // Verified
    true // Success
  );
  await tx.wait();

  // Verify Job 2 as failed
  console.log("- Verifying Content Compliance job as failed");
  tx = await contract.connect(verifier1).verifyJob(
    agent1.address,
    2,
    2, // Failed
    false // Not successful
  );
  await tx.wait();
  console.log();

  // Get agent statistics
  console.log("Agent 1 Statistics:");
  const stats = await contract.getAgentStats(agent1.address);
  console.log("- Total Jobs:", stats.totalJobs.toString());
  console.log("- Successful Jobs:", stats.successfulJobs.toString());
  console.log("- Failed Jobs:", stats.failedJobs.toString());
  console.log("- Reputation Score:", stats.reputation.toString());
  console.log();

  // Get job records
  console.log("Agent 1 Job History:");
  const jobs = await contract.getAgentJobs(agent1.address);
  jobs.forEach((job, index) => {
    const jobTypes = ["Trade Execution", "Treasury Management", "Content Compliance"];
    const statuses = ["Pending", "Verified", "Failed", "Disputed"];
    console.log(`\nJob ${index}:`);
    console.log("  Type:", jobTypes[job.jobType]);
    console.log("  Description:", job.description);
    console.log("  Status:", statuses[job.status]);
    console.log("  Success:", job.success);
    console.log("  Value:", hre.ethers.formatEther(job.value), "ETH");
    console.log("  Employer:", job.employer);
    console.log("  Timestamp:", new Date(Number(job.timestamp) * 1000).toISOString());
  });
  console.log();

  // Try to transfer (should fail - soulbound)
  console.log("Attempting to transfer SBT (should fail)...");
  try {
    await contract.connect(agent1).transferFrom(agent1.address, agent2.address, tokenId1);
    console.log("ERROR: Transfer succeeded when it should have failed!");
  } catch (error) {
    console.log("✓ Transfer correctly blocked - Token is soulbound\n");
  }

  // Check total fees collected
  const totalFees = await contract.totalFeesCollected();
  console.log("Total Verification Fees Collected:", hre.ethers.formatEther(totalFees), "ETH");
  
  // Check contract balance
  const balance = await hre.ethers.provider.getBalance(contractAddress);
  console.log("Contract Balance:", hre.ethers.formatEther(balance), "ETH");
  console.log();

  console.log("Example completed successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
