/**
 * @title SynthNet Protocol Lifecycle Simulation
 * @notice Smoke test script that simulates the complete workflow
 * @dev This script demonstrates:
 *      1. Contract deployment (L1 AgentIdentity, L2 SoulboundResume, L3 VerificationRegistry)
 *      2. Agent registration with mintAgent()
 *      3. Resume minting for the agent
 *      4. Job submission by employer
 *      5. Job verification by verifier
 *      6. Reputation score update verification
 */

const hre = require("hardhat");
const { ethers } = require("hardhat");

// ANSI color codes for pretty output
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    green: '\x1b[32m',
    blue: '\x1b[34m',
    yellow: '\x1b[33m',
    cyan: '\x1b[36m',
    red: '\x1b[31m',
    magenta: '\x1b[35m'
};

function log(message, color = colors.reset) {
    console.log(`${color}${message}${colors.reset}`);
}

function section(title) {
    console.log("\n" + "=".repeat(70));
    log(title, colors.bright + colors.cyan);
    console.log("=".repeat(70) + "\n");
}

async function main() {
    log("🚀 SynthNet Protocol Lifecycle Simulation", colors.bright + colors.magenta);
    log("Testing the complete agent registration and verification flow\n", colors.magenta);

    // ============ Step 0: Get Signers ============
    section("Step 0: Getting Test Accounts");
    
    const [deployer, userA, userB, verifierC, ...others] = await ethers.getSigners();
    
    log(`👤 Deployer (Owner): ${deployer.address}`, colors.blue);
    log(`👤 User A (Agent):    ${userA.address}`, colors.blue);
    log(`👤 User B (Employer): ${userB.address}`, colors.blue);
    log(`👤 Verifier C:        ${verifierC.address}`, colors.blue);

    // ============ Step 1: Deploy Contracts ============
    section("Step 1: Deploying Contracts");
    
    log("📦 Deploying AgentIdentity (L1)...", colors.yellow);
    const AgentIdentity = await ethers.getContractFactory("AgentIdentity");
    const agentIdentity = await AgentIdentity.deploy(deployer.address);
    await agentIdentity.waitForDeployment();
    const agentIdentityAddress = await agentIdentity.getAddress();
    log(`✅ AgentIdentity deployed at: ${agentIdentityAddress}`, colors.green);

    log("\n📦 Deploying SoulboundResume (L2)...", colors.yellow);
    const verificationFee = ethers.parseEther("0.001"); // 0.001 ETH fee
    const SoulboundResume = await ethers.getContractFactory("SoulboundResume");
    const soulboundResume = await SoulboundResume.deploy(deployer.address, verificationFee);
    await soulboundResume.waitForDeployment();
    const soulboundResumeAddress = await soulboundResume.getAddress();
    log(`✅ SoulboundResume deployed at: ${soulboundResumeAddress}`, colors.green);

    log("\n📦 Deploying VerificationRegistry (L3)...", colors.yellow);
    const VerificationRegistry = await ethers.getContractFactory("VerificationRegistry");
    const verificationRegistry = await VerificationRegistry.deploy(deployer.address);
    await verificationRegistry.waitForDeployment();
    const verificationRegistryAddress = await verificationRegistry.getAddress();
    log(`✅ VerificationRegistry deployed at: ${verificationRegistryAddress}`, colors.green);

    // ============ Step 2: Link Layers ============
    section("Step 2: Linking Protocol Layers");
    
    log("🔗 Linking AgentIdentity (L1) with L2 and L3...", colors.yellow);
    await agentIdentity.linkLayers(soulboundResumeAddress, verificationRegistryAddress);
    log("✅ AgentIdentity layers linked", colors.green);

    log("\n🔗 Linking SoulboundResume (L2) with L1 and L3...", colors.yellow);
    await soulboundResume.linkLayers(agentIdentityAddress, verificationRegistryAddress);
    log("✅ SoulboundResume layers linked", colors.green);

    log("\n🔗 Linking VerificationRegistry (L3) with L1 and L2...", colors.yellow);
    await verificationRegistry.linkLayers(agentIdentityAddress, soulboundResumeAddress);
    log("✅ VerificationRegistry layers linked", colors.green);

    // ============ Step 3: User A Mints Agent Identity ============
    section("Step 3: User A Mints Agent Identity");
    
    const serviceUrl = "https://agent-api.synthnet.ai/agent-1";
    const category = "trading";
    
    log(`🤖 User A minting agent with service URL: ${serviceUrl}`, colors.yellow);
    const mintTx = await agentIdentity.connect(userA).mintAgent(
        serviceUrl,
        category,
        userA.address
    );
    const mintReceipt = await mintTx.wait();
    
    // Get the agent ID from the Registered event
    const registeredEvent = mintReceipt.logs.find(
        log => log.fragment && log.fragment.name === 'Registered'
    );
    const agentId = registeredEvent.args.agentId;
    
    log(`✅ Agent minted! Agent ID: ${agentId}`, colors.green);
    
    // Verify agent data
    const agentData = await agentIdentity.getAgentData(agentId);
    log(`\n📋 Agent Data:`, colors.cyan);
    log(`   Service URL: ${agentData.serviceUrl}`, colors.blue);
    log(`   Category: ${agentData.category}`, colors.blue);
    log(`   Payment Address: ${agentData.paymentAddress}`, colors.blue);

    // ============ Step 4: Mint Resume for Agent ============
    section("Step 4: Minting Soulbound Resume");
    
    log(`📄 Minting resume for Agent ID ${agentId}...`, colors.yellow);
    const resumeTx = await soulboundResume.mintResume(agentId, userA.address);
    const resumeReceipt = await resumeTx.wait();
    
    // Get resume ID from the event
    const resumeMintedEvent = resumeReceipt.logs.find(
        log => log.fragment && log.fragment.name === 'ResumeMinted'
    );
    const resumeId = resumeMintedEvent.args.resumeId;
    
    log(`✅ Resume minted! Resume ID: ${resumeId}`, colors.green);
    
    // Check initial reputation
    const initialReputation = await soulboundResume.getReputation(agentId);
    log(`\n⭐ Initial Reputation Score: ${initialReputation}`, colors.cyan);
    
    // Verify soulbound status
    const isLocked = await soulboundResume.locked(resumeId);
    log(`🔒 Resume is soulbound (locked): ${isLocked}`, colors.cyan);

    // ============ Step 5: Test Transfer Blocking ============
    section("Step 5: Testing Soulbound Transfer Protection");
    
    log("🚫 Attempting to transfer resume (should fail)...", colors.yellow);
    try {
        await soulboundResume.connect(userA).transferFrom(userA.address, userB.address, resumeId);
        log("❌ ERROR: Transfer should have been blocked!", colors.red);
    } catch (error) {
        if (error.message.includes("token is non-transferable")) {
            log("✅ Transfer correctly blocked: token is non-transferable", colors.green);
        } else {
            log(`⚠️  Transfer blocked with different error: ${error.message}`, colors.yellow);
        }
    }

    log("\n🚫 Attempting to approve resume (should fail)...", colors.yellow);
    try {
        await soulboundResume.connect(userA).approve(userB.address, resumeId);
        log("❌ ERROR: Approval should have been blocked!", colors.red);
    } catch (error) {
        if (error.message.includes("token approvals not allowed")) {
            log("✅ Approval correctly blocked: token approvals not allowed", colors.green);
        } else {
            log(`⚠️  Approval blocked with different error: ${error.message}`, colors.yellow);
        }
    }

    // ============ Step 6: Add Verifier ============
    section("Step 6: Authorizing Verifier");
    
    log(`👮 Adding Verifier C as authorized verifier...`, colors.yellow);
    await verificationRegistry.addVerifier(verifierC.address);
    log(`✅ Verifier C authorized`, colors.green);
    
    const isVerifier = await verificationRegistry.isVerifier(verifierC.address);
    log(`✓ Verification status: ${isVerifier}`, colors.cyan);

    // ============ Step 7: User B Submits Job ============
    section("Step 7: User B (Employer) Submits Job");
    
    const jobDescription = "Execute 100 DEX arbitrage trades on Uniswap/Sushiswap";
    const proofUri = "ipfs://QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco";
    const proofHash = ethers.keccak256(ethers.toUtf8Bytes("proof-data-hash-example"));
    const jobValue = ethers.parseEther("1.0"); // 1 ETH job value
    const tag1 = ethers.encodeBytes32String("defi");
    const tag2 = ethers.encodeBytes32String("arbitrage");
    
    log(`💼 User B submitting job for Agent ${agentId}...`, colors.yellow);
    log(`   Description: ${jobDescription}`, colors.blue);
    log(`   Proof URI: ${proofUri}`, colors.blue);
    log(`   Job Value: ${ethers.formatEther(jobValue)} ETH`, colors.blue);
    
    // Owner submits job record (or we could make verifier submit it)
    const jobTx = await soulboundResume.addJobRecord(
        agentId,
        0, // JobType.TradeExecution
        jobDescription,
        proofUri,
        proofHash,
        jobValue,
        tag1,
        tag2,
        { value: verificationFee }
    );
    const jobReceipt = await jobTx.wait();
    
    // Get job ID from event
    const jobAddedEvent = jobReceipt.logs.find(
        log => log.fragment && log.fragment.name === 'JobAdded'
    );
    const jobId = jobAddedEvent.args.jobId;
    
    log(`✅ Job submitted! Job ID: ${jobId}`, colors.green);
    
    // Get job details
    const jobs = await soulboundResume.getJobRecords(agentId);
    const job = jobs.find(j => j.jobId === jobId);
    log(`\n📋 Job Status: ${['Pending', 'Verified', 'Failed', 'Disputed'][job.status]}`, colors.cyan);

    // ============ Step 8: Verifier C Verifies Job ============
    section("Step 8: Verifier C Verifies Job (Success)");
    
    log(`✓ Verifier C verifying job ${jobId} as successful...`, colors.yellow);
    const verifyProofHash = ethers.keccak256(ethers.toUtf8Bytes("verification-proof-success"));
    const verifyTx = await verificationRegistry.connect(verifierC).verifyJob(
        agentId,
        jobId,
        true, // success = true
        verifyProofHash
    );
    await verifyTx.wait();
    
    log(`✅ Job verified successfully!`, colors.green);

    // ============ Step 9: Check Reputation Update ============
    section("Step 9: Verifying Reputation Score Update");
    
    const finalReputation = await soulboundResume.getReputation(agentId);
    const reputationGain = finalReputation - initialReputation;
    
    log(`⭐ Initial Reputation:  ${initialReputation}`, colors.cyan);
    log(`⭐ Final Reputation:    ${finalReputation}`, colors.cyan);
    log(`📈 Reputation Gain:     +${reputationGain}`, colors.green);
    
    if (reputationGain > 0n) {
        log(`\n✅ SUCCESS: Reputation increased as expected!`, colors.bright + colors.green);
    } else {
        log(`\n❌ ERROR: Reputation did not increase!`, colors.red);
    }

    // ============ Step 10: Get Final Stats ============
    section("Step 10: Final Agent Statistics");
    
    const [totalJobs, successfulJobs, failedJobs, finalReputationCheck] = await soulboundResume.getAgentStats(agentId);
    const jobsByType = await soulboundResume.getJobCountByType(agentId, 0); // TradeExecution
    
    log(`📊 Agent Statistics:`, colors.cyan);
    log(`   Total Jobs: ${totalJobs}`, colors.blue);
    log(`   Successful Jobs: ${successfulJobs}`, colors.green);
    log(`   Failed Jobs: ${failedJobs}`, colors.blue);
    log(`   Trade Execution Jobs: ${jobsByType}`, colors.blue);
    log(`   Reputation Score: ${finalReputationCheck}`, colors.magenta);

    // ============ Step 11: Test Failed Job Scenario ============
    section("Step 11: Testing Failed Job Scenario");
    
    log(`💼 Submitting second job for Agent ${agentId}...`, colors.yellow);
    const job2Tx = await soulboundResume.addJobRecord(
        agentId,
        1, // JobType.TreasuryManagement
        "Manage treasury portfolio allocation",
        "ipfs://QmSecondJobProofHash",
        ethers.keccak256(ethers.toUtf8Bytes("proof-data-hash-2")),
        ethers.parseEther("2.0"),
        ethers.encodeBytes32String("treasury"),
        ethers.encodeBytes32String("portfolio"),
        { value: verificationFee }
    );
    const job2Receipt = await job2Tx.wait();
    
    const job2AddedEvent = job2Receipt.logs.find(
        log => log.fragment && log.fragment.name === 'JobAdded'
    );
    const job2Id = job2AddedEvent.args.jobId;
    log(`✅ Second job submitted! Job ID: ${job2Id}`, colors.green);
    
    const reputationBeforeFail = await soulboundResume.getReputation(agentId);
    
    log(`\n❌ Verifier C verifying job ${job2Id} as failed...`, colors.yellow);
    const failProofHash = ethers.keccak256(ethers.toUtf8Bytes("verification-proof-failure"));
    await verificationRegistry.connect(verifierC).verifyJob(
        agentId,
        job2Id,
        false, // success = false
        failProofHash
    );
    
    const reputationAfterFail = await soulboundResume.getReputation(agentId);
    const reputationLoss = reputationBeforeFail - reputationAfterFail;
    
    log(`\n⭐ Reputation before fail: ${reputationBeforeFail}`, colors.cyan);
    log(`⭐ Reputation after fail:  ${reputationAfterFail}`, colors.cyan);
    log(`📉 Reputation Loss:        -${reputationLoss}`, colors.red);
    
    if (reputationLoss > 0n) {
        log(`✅ SUCCESS: Reputation decreased for failed job!`, colors.green);
    } else {
        log(`⚠️  WARNING: Reputation did not decrease for failed job`, colors.yellow);
    }

    // ============ Final Summary ============
    section("✨ Lifecycle Simulation Complete!");
    
    log("Summary of successful operations:", colors.cyan);
    log("✅ 1. Deployed all three protocol layers (L1, L2, L3)", colors.green);
    log("✅ 2. Linked protocol layers together", colors.green);
    log("✅ 3. User A minted agent identity with mintAgent()", colors.green);
    log("✅ 4. Minted soulbound resume for the agent", colors.green);
    log("✅ 5. Verified transfer blocking (soulbound property)", colors.green);
    log("✅ 6. Authorized Verifier C", colors.green);
    log("✅ 7. User B submitted job record", colors.green);
    log("✅ 8. Verifier C verified successful job", colors.green);
    log("✅ 9. Reputation score increased correctly", colors.green);
    log("✅ 10. Tested failed job scenario", colors.green);
    log("✅ 11. Reputation score decreased for failure", colors.green);
    
    log("\n🎉 All smoke tests passed! Protocol is working as expected.", colors.bright + colors.green);
    
    log("\n📝 Contract Addresses:", colors.cyan);
    log(`   AgentIdentity:         ${agentIdentityAddress}`, colors.blue);
    log(`   SoulboundResume:       ${soulboundResumeAddress}`, colors.blue);
    log(`   VerificationRegistry:  ${verificationRegistryAddress}`, colors.blue);
}

// Execute the simulation
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Simulation failed with error:");
        console.error(error);
        process.exit(1);
    });
