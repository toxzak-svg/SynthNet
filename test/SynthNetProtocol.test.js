// test/SynthNetProtocol.test.js
// Comprehensive test suite for SynthNet Protocol v2.0 (Layered Architecture)

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SynthNet Protocol v2.0 - Layered Architecture", function () {
    let protocol;
    let agentIdentity;
    let soulboundResume;
    let verificationRegistry;
    
    let owner;
    let agent1;
    let agent2;
    let employer;
    let verifier;
    let unauthorized;
    
    const VERIFICATION_FEE = ethers.parseEther("0.01");
    const BASE_REPUTATION = 100n;
    const REPUTATION_SUCCESS_POINTS = 10n;
    const REPUTATION_FAIL_POINTS = 5n;
    
    // Job type enum values
    const JobType = {
        TradeExecution: 0,
        TreasuryManagement: 1,
        ContentCompliance: 2,
        DataAnalysis: 3,
        SmartContractAudit: 4,
        GovernanceVoting: 5,
        Custom: 6
    };
    
    // Job status enum values
    const JobStatus = {
        Pending: 0,
        Verified: 1,
        Failed: 2,
        Disputed: 3
    };
    
    beforeEach(async function () {
        [owner, agent1, agent2, employer, verifier, unauthorized] = await ethers.getSigners();
        
        // Deploy the protocol (deploys all layers)
        const SynthNetProtocol = await ethers.getContractFactory("SynthNetProtocol");
        protocol = await SynthNetProtocol.deploy(owner.address, VERIFICATION_FEE);
        await protocol.waitForDeployment();
        
        // Get layer contract instances
        const [l1Addr, l2Addr, l3Addr] = await protocol.getLayerAddresses();
        
        agentIdentity = await ethers.getContractAt("AgentIdentity", l1Addr);
        soulboundResume = await ethers.getContractAt("SoulboundResume", l2Addr);
        verificationRegistry = await ethers.getContractAt("VerificationRegistry", l3Addr);
    });
    
    // ================================================================
    // DEPLOYMENT TESTS
    // ================================================================
    
    describe("Deployment", function () {
        it("Should deploy with correct owner", async function () {
            expect(await protocol.owner()).to.equal(owner.address);
        });
        
        it("Should deploy all layer contracts", async function () {
            const [l1, l2, l3] = await protocol.getLayerAddresses();
            expect(l1).to.not.equal(ethers.ZeroAddress);
            expect(l2).to.not.equal(ethers.ZeroAddress);
            expect(l3).to.not.equal(ethers.ZeroAddress);
        });
        
        it("Should set correct verification fee", async function () {
            expect(await protocol.getVerificationFee()).to.equal(VERIFICATION_FEE);
        });
        
        it("Should have correct protocol version", async function () {
            expect(await protocol.VERSION()).to.equal("2.0.0");
        });
        
        it("Should link layer contracts correctly", async function () {
            // Check L1 links
            expect(await agentIdentity.soulboundResumeContract()).to.equal(await soulboundResume.getAddress());
            expect(await agentIdentity.verificationRegistryContract()).to.equal(await verificationRegistry.getAddress());
            
            // Check L2 links
            expect(await soulboundResume.agentIdentityContract()).to.equal(await agentIdentity.getAddress());
            expect(await soulboundResume.verificationRegistryContract()).to.equal(await verificationRegistry.getAddress());
            
            // Check L3 links
            expect(await verificationRegistry.agentIdentityContract()).to.equal(await agentIdentity.getAddress());
            expect(await verificationRegistry.soulboundResumeContract()).to.equal(await soulboundResume.getAddress());
        });
    });
    
    // ================================================================
    // AGENT REGISTRATION TESTS (Layer 1 + Layer 2)
    // ================================================================
    
    describe("Agent Registration", function () {
        it("Should register an agent with full metadata", async function () {
            const tokenUri = "ipfs://QmTestHash123";
            const metadata = [
                { key: "name", value: ethers.toUtf8Bytes("TestAgent") },
                { key: "model", value: ethers.toUtf8Bytes("GPT-4") }
            ];
            
            const tx = await protocol.connect(agent1).registerAgent(tokenUri, metadata);
            const receipt = await tx.wait();
            
            // Check agent is registered
            expect(await protocol.isAgentRegistered(1)).to.be.true;
            
            // Check identity token minted
            expect(await agentIdentity.ownerOf(1)).to.equal(agent1.address);
            
            // Check resume token minted
            const resumeId = await soulboundResume.getResumeId(1);
            expect(resumeId).to.equal(1);
            expect(await soulboundResume.ownerOf(resumeId)).to.equal(agent1.address);
        });
        
        it("Should register an agent with minimal data", async function () {
            const tx = await protocol.connect(agent1)["registerAgent()"]();
            await tx.wait();
            
            expect(await protocol.isAgentRegistered(1)).to.be.true;
        });
        
        it("Should initialize reputation to base value", async function () {
            await protocol.connect(agent1)["registerAgent()"]();
            
            const reputation = await protocol.getReputation(1);
            expect(reputation).to.equal(BASE_REPUTATION);
        });
        
        it("Should prevent duplicate registration", async function () {
            await protocol.connect(agent1)["registerAgent()"]();
            
            await expect(
                protocol.connect(agent1)["registerAgent()"]()
            ).to.be.revertedWith("AgentIdentity: already registered");
        });
        
        it("Should track total agents registered", async function () {
            await protocol.connect(agent1)["registerAgent()"]();
            await protocol.connect(agent2)["registerAgent()"]();
            
            expect(await protocol.totalAgentsRegistered()).to.equal(2);
        });
        
        it("Should get agent ID by address", async function () {
            await protocol.connect(agent1)["registerAgent()"]();
            
            const agentId = await protocol.getAgentIdByAddress(agent1.address);
            expect(agentId).to.equal(1);
        });
    });
    
    // ================================================================
    // ERC-5192 SOULBOUND TOKEN TESTS (Layer 2)
    // ================================================================
    
    describe("ERC-5192 Soulbound Token", function () {
        beforeEach(async function () {
            await protocol.connect(agent1)["registerAgent()"]();
        });
        
        it("Should report token as locked", async function () {
            const resumeId = await soulboundResume.getResumeId(1);
            expect(await soulboundResume.locked(resumeId)).to.be.true;
        });
        
        it("Should emit Locked event on mint", async function () {
            // Register another agent to check event
            await expect(protocol.connect(agent2)["registerAgent()"]())
                .to.emit(soulboundResume, "Locked");
        });
        
        it("Should prevent transfer of soulbound token", async function () {
            const resumeId = await soulboundResume.getResumeId(1);
            
            await expect(
                soulboundResume.connect(agent1).transferFrom(agent1.address, agent2.address, resumeId)
            ).to.be.revertedWith("SoulboundResume: token is non-transferable");
        });
        
        it("Should prevent safeTransfer of soulbound token", async function () {
            const resumeId = await soulboundResume.getResumeId(1);
            
            await expect(
                soulboundResume.connect(agent1)["safeTransferFrom(address,address,uint256)"](
                    agent1.address, agent2.address, resumeId
                )
            ).to.be.revertedWith("SoulboundResume: token is non-transferable");
        });
        
        it("Should support ERC-5192 interface", async function () {
            // Interface ID for ERC-5192: 0xb45a3c0e
            const ERC5192_INTERFACE_ID = "0xb45a3c0e";
            expect(await soulboundResume.supportsInterface(ERC5192_INTERFACE_ID)).to.be.true;
        });
    });
    
    // ================================================================
    // JOB RECORD TESTS (Layer 2)
    // ================================================================
    
    describe("Job Records", function () {
        beforeEach(async function () {
            await protocol.connect(agent1)["registerAgent()"]();
        });
        
        it("Should add a job record with fee", async function () {
            const proofUri = "ipfs://QmProofHash";
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("proof"));
            
            const tx = await protocol.connect(employer).addJobRecord(
                1, // agentId
                JobType.TradeExecution,
                "Executed 100 trades",
                proofUri,
                proofHash,
                ethers.parseEther("1.0"),
                { value: VERIFICATION_FEE }
            );
            
            await tx.wait();
            
            const jobs = await protocol.getJobRecords(1);
            expect(jobs.length).to.equal(1);
            expect(jobs[0].jobType).to.equal(JobType.TradeExecution);
            expect(jobs[0].status).to.equal(JobStatus.Pending);
            expect(jobs[0].proofUri).to.equal(proofUri);
        });
        
        it("Should reject job without sufficient fee", async function () {
            const proofUri = "ipfs://QmProofHash";
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("proof"));
            
            await expect(
                protocol.connect(employer).addJobRecord(
                    1,
                    JobType.TradeExecution,
                    "Test job",
                    proofUri,
                    proofHash,
                    0,
                    { value: VERIFICATION_FEE / 2n }
                )
            ).to.be.revertedWith("SoulboundResume: insufficient fee");
        });
        
        it("Should require proof URI", async function () {
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("proof"));
            
            await expect(
                protocol.connect(employer).addJobRecord(
                    1,
                    JobType.TradeExecution,
                    "Test job",
                    "", // empty proof URI
                    proofHash,
                    0,
                    { value: VERIFICATION_FEE }
                )
            ).to.be.revertedWith("SoulboundResume: proof URI required");
        });
        
        it("Should track total jobs submitted", async function () {
            const proofUri = "ipfs://QmProofHash";
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("proof"));
            
            await protocol.connect(employer).addJobRecord(
                1, JobType.TradeExecution, "Job 1", proofUri, proofHash, 0,
                { value: VERIFICATION_FEE }
            );
            await protocol.connect(employer).addJobRecord(
                1, JobType.TreasuryManagement, "Job 2", proofUri, proofHash, 0,
                { value: VERIFICATION_FEE }
            );
            
            expect(await protocol.totalJobsSubmitted()).to.equal(2);
        });
        
        it("Should support all job types", async function () {
            const proofUri = "ipfs://QmProofHash";
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("proof"));
            
            for (const [name, value] of Object.entries(JobType)) {
                await protocol.connect(employer).addJobRecord(
                    1, value, `${name} job`, proofUri, proofHash, 0,
                    { value: VERIFICATION_FEE }
                );
            }
            
            const jobs = await protocol.getJobRecords(1);
            expect(jobs.length).to.equal(Object.keys(JobType).length);
        });
    });
    
    // ================================================================
    // VERIFICATION TESTS (Layer 3)
    // ================================================================
    
    describe("Job Verification", function () {
        beforeEach(async function () {
            await protocol.connect(agent1)["registerAgent()"]();
            await protocol.connect(owner).addVerifier(verifier.address);
            
            const proofUri = "ipfs://QmProofHash";
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("proof"));
            
            await protocol.connect(employer).addJobRecord(
                1, JobType.TradeExecution, "Test job", proofUri, proofHash, 0,
                { value: VERIFICATION_FEE }
            );
        });
        
        it("Should verify a job as successful", async function () {
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("verification"));
            
            await protocol.connect(verifier).verifyJob(1, 1, true, proofHash);
            
            const job = await protocol.getJobRecord(1, 1);
            expect(job.status).to.equal(JobStatus.Verified);
            expect(job.success).to.be.true;
        });
        
        it("Should verify a job as failed", async function () {
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("verification"));
            
            await protocol.connect(verifier).verifyJob(1, 1, false, proofHash);
            
            const job = await protocol.getJobRecord(1, 1);
            expect(job.status).to.equal(JobStatus.Verified); // Status is Verified, success is false
            expect(job.success).to.be.false;
        });
        
        it("Should update reputation on successful verification", async function () {
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("verification"));
            
            await protocol.connect(verifier).verifyJob(1, 1, true, proofHash);
            
            const reputation = await protocol.getReputation(1);
            expect(reputation).to.equal(BASE_REPUTATION + REPUTATION_SUCCESS_POINTS);
        });
        
        it("Should decrease reputation on failed verification", async function () {
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("verification"));
            
            await protocol.connect(verifier).verifyJob(1, 1, false, proofHash);
            
            const reputation = await protocol.getReputation(1);
            expect(reputation).to.equal(BASE_REPUTATION - REPUTATION_FAIL_POINTS);
        });
        
        it("Should prevent re-verification", async function () {
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("verification"));
            
            await protocol.connect(verifier).verifyJob(1, 1, true, proofHash);
            
            await expect(
                protocol.connect(verifier).verifyJob(1, 1, false, proofHash)
            ).to.be.revertedWith("SoulboundResume: job already verified");
        });
        
        it("Should allow owner to verify", async function () {
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("verification"));
            
            await protocol.connect(owner).verifyJob(1, 1, true, proofHash);
            
            const job = await protocol.getJobRecord(1, 1);
            expect(job.status).to.equal(JobStatus.Verified);
        });
        
        it("Should reject verification from unauthorized address", async function () {
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("verification"));
            
            await expect(
                protocol.connect(unauthorized).verifyJob(1, 1, true, proofHash)
            ).to.be.revertedWith("SynthNetProtocol: not authorized to verify");
        });
    });
    
    // ================================================================
    // VERIFIER MANAGEMENT TESTS
    // ================================================================
    
    describe("Verifier Management", function () {
        it("Should add a verifier", async function () {
            await protocol.connect(owner).addVerifier(verifier.address);
            
            expect(await protocol.isVerifier(verifier.address)).to.be.true;
        });
        
        it("Should remove a verifier", async function () {
            await protocol.connect(owner).addVerifier(verifier.address);
            await protocol.connect(owner).removeVerifier(verifier.address);
            
            expect(await protocol.isVerifier(verifier.address)).to.be.false;
        });
        
        it("Should only allow owner to add verifier", async function () {
            await expect(
                protocol.connect(unauthorized).addVerifier(verifier.address)
            ).to.be.revertedWithCustomError(protocol, "OwnableUnauthorizedAccount");
        });
        
        it("Should return all verifiers", async function () {
            await protocol.connect(owner).addVerifier(verifier.address);
            await protocol.connect(owner).addVerifier(agent1.address);
            
            const verifiers = await protocol.getVerifiers();
            expect(verifiers.length).to.equal(2);
            expect(verifiers).to.include(verifier.address);
            expect(verifiers).to.include(agent1.address);
        });
    });
    
    // ================================================================
    // AGENT STATS TESTS
    // ================================================================
    
    describe("Agent Statistics", function () {
        beforeEach(async function () {
            await protocol.connect(agent1)["registerAgent()"]();
            await protocol.connect(owner).addVerifier(verifier.address);
            
            const proofUri = "ipfs://QmProofHash";
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("proof"));
            
            // Add multiple jobs
            await protocol.connect(employer).addJobRecord(
                1, JobType.TradeExecution, "Job 1", proofUri, proofHash, 0,
                { value: VERIFICATION_FEE }
            );
            await protocol.connect(employer).addJobRecord(
                1, JobType.TreasuryManagement, "Job 2", proofUri, proofHash, 0,
                { value: VERIFICATION_FEE }
            );
            await protocol.connect(employer).addJobRecord(
                1, JobType.ContentCompliance, "Job 3", proofUri, proofHash, 0,
                { value: VERIFICATION_FEE }
            );
        });
        
        it("Should return correct stats after verification", async function () {
            const verifyHash = ethers.keccak256(ethers.toUtf8Bytes("verify"));
            
            // Verify jobs: 2 success, 1 fail
            await protocol.connect(verifier).verifyJob(1, 1, true, verifyHash);
            await protocol.connect(verifier).verifyJob(1, 2, true, verifyHash);
            await protocol.connect(verifier).verifyJob(1, 3, false, verifyHash);
            
            const [totalJobs, successfulJobs, failedJobs, reputation] = 
                await protocol.getAgentStats(1);
            
            expect(totalJobs).to.equal(3);
            expect(successfulJobs).to.equal(2);
            expect(failedJobs).to.equal(1);
            expect(reputation).to.equal(
                BASE_REPUTATION + (REPUTATION_SUCCESS_POINTS * 2n) - REPUTATION_FAIL_POINTS
            );
        });
        
        it("Should return comprehensive agent info", async function () {
            const info = await protocol.getAgentInfo(1);
            
            expect(info.owner).to.equal(agent1.address);
            expect(info.resumeId).to.equal(1);
            expect(info.totalJobs).to.equal(3);
            expect(info.reputation).to.equal(BASE_REPUTATION);
        });
    });
    
    // ================================================================
    // FEEDBACK SYSTEM TESTS (ERC-8004 Reputation)
    // ================================================================
    
    describe("Feedback System", function () {
        beforeEach(async function () {
            await protocol.connect(agent1)["registerAgent()"]();
        });
        
        it("Should give feedback to an agent", async function () {
            const fileUri = "ipfs://QmFeedbackHash";
            const fileHash = ethers.keccak256(ethers.toUtf8Bytes("feedback"));
            const tag = ethers.keccak256(ethers.toUtf8Bytes("TradeExecution"));
            
            // Call directly on soulboundResume to preserve msg.sender
            await soulboundResume.connect(employer).giveFeedback(
                1, 85, tag, ethers.ZeroHash, fileUri, fileHash, "0x"
            );
            
            const [count, avgScore] = await soulboundResume.getSummary(
                1, [], ethers.ZeroHash, ethers.ZeroHash
            );
            
            expect(count).to.equal(1);
            expect(avgScore).to.equal(85);
        });
        
        it("Should get feedback clients", async function () {
            const fileUri = "ipfs://QmFeedbackHash";
            const fileHash = ethers.keccak256(ethers.toUtf8Bytes("feedback"));
            const tag = ethers.keccak256(ethers.toUtf8Bytes("TradeExecution"));
            
            await soulboundResume.connect(employer).giveFeedback(
                1, 85, tag, ethers.ZeroHash, fileUri, fileHash, "0x"
            );
            await soulboundResume.connect(agent2).giveFeedback(
                1, 90, tag, ethers.ZeroHash, fileUri, fileHash, "0x"
            );
            
            const clients = await soulboundResume.getClients(1);
            expect(clients.length).to.equal(2);
        });
        
        it("Should revoke feedback", async function () {
            const fileUri = "ipfs://QmFeedbackHash";
            const fileHash = ethers.keccak256(ethers.toUtf8Bytes("feedback"));
            const tag = ethers.keccak256(ethers.toUtf8Bytes("TradeExecution"));
            
            await soulboundResume.connect(employer).giveFeedback(
                1, 85, tag, ethers.ZeroHash, fileUri, fileHash, "0x"
            );
            await soulboundResume.connect(employer).revokeFeedback(1, 0);
            
            const [score, , , isRevoked] = await soulboundResume.readFeedback(
                1, employer.address, 0
            );
            
            expect(isRevoked).to.be.true;
        });
    });
    
    // ================================================================
    // ADMIN FUNCTIONS TESTS
    // ================================================================
    
    describe("Admin Functions", function () {
        it("Should update verification fee", async function () {
            const newFee = ethers.parseEther("0.02");
            
            await protocol.connect(owner).setVerificationFee(newFee);
            
            expect(await protocol.getVerificationFee()).to.equal(newFee);
        });
        
        it("Should withdraw fees", async function () {
            // Register and add job to collect fees
            await protocol.connect(agent1)["registerAgent()"]();
            
            const proofUri = "ipfs://QmProofHash";
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("proof"));
            
            await protocol.connect(employer).addJobRecord(
                1, JobType.TradeExecution, "Test job", proofUri, proofHash, 0,
                { value: VERIFICATION_FEE }
            );
            
            const ownerBalanceBefore = await ethers.provider.getBalance(owner.address);
            
            await protocol.connect(owner).withdrawFees(owner.address);
            
            const ownerBalanceAfter = await ethers.provider.getBalance(owner.address);
            expect(ownerBalanceAfter).to.be.gt(ownerBalanceBefore);
        });
        
        it("Should pause and unpause protocol", async function () {
            await protocol.connect(owner).setPaused(true);
            
            await expect(
                protocol.connect(agent1)["registerAgent()"]()
            ).to.be.revertedWith("SynthNetProtocol: protocol is paused");
            
            await protocol.connect(owner).setPaused(false);
            
            await protocol.connect(agent1)["registerAgent()"]();
            expect(await protocol.isAgentRegistered(1)).to.be.true;
        });
    });
    
    // ================================================================
    // LAYER 1 IDENTITY TESTS
    // ================================================================
    
    describe("Layer 1 - Agent Identity", function () {
        it("Should store and retrieve metadata", async function () {
            const tokenUri = "ipfs://QmTestHash";
            const metadata = [
                { key: "name", value: ethers.toUtf8Bytes("TestAgent") }
            ];
            
            await protocol.connect(agent1).registerAgent(tokenUri, metadata);
            
            const name = await agentIdentity.getMetadata(1, "name");
            expect(ethers.toUtf8String(name)).to.equal("TestAgent");
        });
        
        it("Should allow agent owner to update metadata", async function () {
            await protocol.connect(agent1)["registerAgent()"]();
            
            await agentIdentity.connect(agent1).setMetadata(
                1,
                "description",
                ethers.toUtf8Bytes("Updated description")
            );
            
            const desc = await agentIdentity.getMetadata(1, "description");
            expect(ethers.toUtf8String(desc)).to.equal("Updated description");
        });
        
        it("Should return metadata keys", async function () {
            const metadata = [
                { key: "name", value: ethers.toUtf8Bytes("TestAgent") },
                { key: "model", value: ethers.toUtf8Bytes("GPT-4") }
            ];
            
            await protocol.connect(agent1).registerAgent("ipfs://test", metadata);
            
            const keys = await agentIdentity.getMetadataKeys(1);
            expect(keys).to.include("createdAt");
            expect(keys).to.include("name");
            expect(keys).to.include("model");
        });
        
        it("Should allow identity token transfer (Layer 1 is transferable)", async function () {
            await protocol.connect(agent1)["registerAgent()"]();
            
            await agentIdentity.connect(agent1).transferFrom(
                agent1.address,
                agent2.address,
                1
            );
            
            expect(await agentIdentity.ownerOf(1)).to.equal(agent2.address);
        });
    });
});
