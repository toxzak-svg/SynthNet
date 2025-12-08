const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AIAgentResumeSBT", function () {
  let aiAgentResumeSBT;
  let owner;
  let agent1;
  let agent2;
  let employer1;
  let employer2;
  let verifier;
  const VERIFICATION_FEE = ethers.parseEther("0.01");

  beforeEach(async function () {
    [owner, agent1, agent2, employer1, employer2, verifier] = await ethers.getSigners();
    
    const AIAgentResumeSBT = await ethers.getContractFactory("AIAgentResumeSBT");
    aiAgentResumeSBT = await AIAgentResumeSBT.deploy(VERIFICATION_FEE);
    await aiAgentResumeSBT.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await aiAgentResumeSBT.owner()).to.equal(owner.address);
    });

    it("Should set the correct verification fee", async function () {
      expect(await aiAgentResumeSBT.verificationFee()).to.equal(VERIFICATION_FEE);
    });
  });

  describe("Agent Registration", function () {
    it("Should register a new agent and mint SBT", async function () {
      await expect(aiAgentResumeSBT.registerAgent(agent1.address))
        .to.emit(aiAgentResumeSBT, "AgentRegistered")
        .withArgs(agent1.address, 1);

      expect(await aiAgentResumeSBT.isAgentRegistered(agent1.address)).to.be.true;
      expect(await aiAgentResumeSBT.getAgentTokenId(agent1.address)).to.equal(1);
      expect(await aiAgentResumeSBT.ownerOf(1)).to.equal(agent1.address);
    });

    it("Should not allow registering the same agent twice", async function () {
      await aiAgentResumeSBT.registerAgent(agent1.address);
      await expect(aiAgentResumeSBT.registerAgent(agent1.address))
        .to.be.revertedWith("Agent already registered");
    });

    it("Should not allow registering zero address", async function () {
      await expect(aiAgentResumeSBT.registerAgent(ethers.ZeroAddress))
        .to.be.revertedWith("Invalid agent address");
    });

    it("Should register multiple agents with different token IDs", async function () {
      await aiAgentResumeSBT.registerAgent(agent1.address);
      await aiAgentResumeSBT.registerAgent(agent2.address);

      expect(await aiAgentResumeSBT.getAgentTokenId(agent1.address)).to.equal(1);
      expect(await aiAgentResumeSBT.getAgentTokenId(agent2.address)).to.equal(2);
    });
  });

  describe("Job Record Management", function () {
    beforeEach(async function () {
      await aiAgentResumeSBT.registerAgent(agent1.address);
    });

    it("Should add a job record with correct fee", async function () {
      const jobType = 0; // TradeExecution
      const description = "Executed swap on Uniswap";
      const proofHash = ethers.id("proof-data");
      const value = ethers.parseEther("100");

      await expect(
        aiAgentResumeSBT.connect(employer1).addJobRecord(
          agent1.address,
          jobType,
          description,
          proofHash,
          value,
          { value: VERIFICATION_FEE }
        )
      ).to.emit(aiAgentResumeSBT, "JobAdded")
        .withArgs(1, 0, jobType);

      expect(await aiAgentResumeSBT.totalFeesCollected()).to.equal(VERIFICATION_FEE);
    });

    it("Should not add job record with insufficient fee", async function () {
      const jobType = 0;
      const description = "Test job";
      const proofHash = ethers.id("proof");
      const value = ethers.parseEther("100");
      const insufficientFee = ethers.parseEther("0.005");

      await expect(
        aiAgentResumeSBT.connect(employer1).addJobRecord(
          agent1.address,
          jobType,
          description,
          proofHash,
          value,
          { value: insufficientFee }
        )
      ).to.be.revertedWith("Insufficient verification fee");
    });

    it("Should not add job for unregistered agent", async function () {
      const jobType = 0;
      const description = "Test job";
      const proofHash = ethers.id("proof");
      const value = ethers.parseEther("100");

      await expect(
        aiAgentResumeSBT.connect(employer1).addJobRecord(
          agent2.address,
          jobType,
          description,
          proofHash,
          value,
          { value: VERIFICATION_FEE }
        )
      ).to.be.revertedWith("Agent not registered");
    });

    it("Should add multiple job records", async function () {
      const jobType1 = 0; // TradeExecution
      const jobType2 = 1; // TreasuryManagement
      const description = "Test job";
      const proofHash = ethers.id("proof");
      const value = ethers.parseEther("100");

      await aiAgentResumeSBT.connect(employer1).addJobRecord(
        agent1.address,
        jobType1,
        description,
        proofHash,
        value,
        { value: VERIFICATION_FEE }
      );

      await aiAgentResumeSBT.connect(employer2).addJobRecord(
        agent1.address,
        jobType2,
        description,
        proofHash,
        value,
        { value: VERIFICATION_FEE }
      );

      const jobs = await aiAgentResumeSBT.getAgentJobs(agent1.address);
      expect(jobs.length).to.equal(2);
      expect(jobs[0].jobType).to.equal(jobType1);
      expect(jobs[1].jobType).to.equal(jobType2);
    });
  });

  describe("Job Verification", function () {
    beforeEach(async function () {
      await aiAgentResumeSBT.registerAgent(agent1.address);
      await aiAgentResumeSBT.addVerifier(verifier.address);
      
      // Add a job record
      await aiAgentResumeSBT.connect(employer1).addJobRecord(
        agent1.address,
        0, // TradeExecution
        "Test job",
        ethers.id("proof"),
        ethers.parseEther("100"),
        { value: VERIFICATION_FEE }
      );
    });

    it("Should allow verifier to verify a job", async function () {
      await expect(
        aiAgentResumeSBT.connect(verifier).verifyJob(
          agent1.address,
          0,
          1, // Verified
          true // Success
        )
      ).to.emit(aiAgentResumeSBT, "JobVerified")
        .withArgs(1, 0, 1);

      const job = await aiAgentResumeSBT.getJobRecord(agent1.address, 0);
      expect(job.status).to.equal(1); // Verified
      expect(job.success).to.be.true;
    });

    it("Should allow owner to verify a job", async function () {
      await aiAgentResumeSBT.connect(owner).verifyJob(
        agent1.address,
        0,
        1, // Verified
        true
      );

      const job = await aiAgentResumeSBT.getJobRecord(agent1.address, 0);
      expect(job.status).to.equal(1);
    });

    it("Should not allow non-verifier to verify", async function () {
      await expect(
        aiAgentResumeSBT.connect(employer1).verifyJob(
          agent1.address,
          0,
          1,
          true
        )
      ).to.be.revertedWith("Not authorized to verify");
    });

    it("Should not verify already verified job", async function () {
      await aiAgentResumeSBT.connect(verifier).verifyJob(
        agent1.address,
        0,
        1,
        true
      );

      await expect(
        aiAgentResumeSBT.connect(verifier).verifyJob(
          agent1.address,
          0,
          1,
          true
        )
      ).to.be.revertedWith("Job already verified");
    });

    it("Should update reputation on successful verification", async function () {
      await aiAgentResumeSBT.connect(verifier).verifyJob(
        agent1.address,
        0,
        1, // Verified
        true
      );

      const reputation = await aiAgentResumeSBT.getReputationScore(agent1.address);
      expect(reputation).to.equal(10);
    });

    it("Should decrease reputation on failed verification", async function () {
      // First verify the job from beforeEach as successful
      await aiAgentResumeSBT.connect(verifier).verifyJob(
        agent1.address,
        0,
        1, // Verified
        true
      );

      // Now add a second job and verify it as failed
      await aiAgentResumeSBT.connect(employer1).addJobRecord(
        agent1.address,
        0,
        "Job 2",
        ethers.id("proof2"),
        ethers.parseEther("100"),
        { value: VERIFICATION_FEE }
      );

      await aiAgentResumeSBT.connect(verifier).verifyJob(
        agent1.address,
        1, // Second job has jobId 1
        2, // Failed
        false
      );

      const reputation = await aiAgentResumeSBT.getReputationScore(agent1.address);
      expect(reputation).to.equal(5); // 10 - 5
    });
  });

  describe("Agent Statistics", function () {
    beforeEach(async function () {
      await aiAgentResumeSBT.registerAgent(agent1.address);
      await aiAgentResumeSBT.addVerifier(verifier.address);
    });

    it("Should return correct statistics", async function () {
      // Add successful job
      await aiAgentResumeSBT.connect(employer1).addJobRecord(
        agent1.address,
        0,
        "Job 1",
        ethers.id("proof1"),
        ethers.parseEther("100"),
        { value: VERIFICATION_FEE }
      );
      
      await aiAgentResumeSBT.connect(verifier).verifyJob(
        agent1.address,
        0,
        1, // Verified
        true
      );

      // Add failed job
      await aiAgentResumeSBT.connect(employer1).addJobRecord(
        agent1.address,
        1,
        "Job 2",
        ethers.id("proof2"),
        ethers.parseEther("100"),
        { value: VERIFICATION_FEE }
      );
      
      await aiAgentResumeSBT.connect(verifier).verifyJob(
        agent1.address,
        1,
        2, // Failed
        false
      );

      const stats = await aiAgentResumeSBT.getAgentStats(agent1.address);
      expect(stats.totalJobs).to.equal(2);
      expect(stats.successfulJobs).to.equal(1);
      expect(stats.failedJobs).to.equal(1);
      expect(stats.reputation).to.equal(5); // 10 - 5
    });
  });

  describe("Soulbound Functionality", function () {
    beforeEach(async function () {
      await aiAgentResumeSBT.registerAgent(agent1.address);
    });

    it("Should not allow transferring SBT", async function () {
      const tokenId = await aiAgentResumeSBT.getAgentTokenId(agent1.address);
      
      await expect(
        aiAgentResumeSBT.connect(agent1).transferFrom(agent1.address, agent2.address, tokenId)
      ).to.be.revertedWith("Soulbound: Token is non-transferable");
    });

    it("Should not allow safe transferring SBT", async function () {
      const tokenId = await aiAgentResumeSBT.getAgentTokenId(agent1.address);
      
      await expect(
        aiAgentResumeSBT.connect(agent1)["safeTransferFrom(address,address,uint256)"](
          agent1.address,
          agent2.address,
          tokenId
        )
      ).to.be.revertedWith("Soulbound: Token is non-transferable");
    });
  });

  describe("Administrative Functions", function () {
    it("Should allow owner to update verification fee", async function () {
      const newFee = ethers.parseEther("0.02");
      
      await expect(aiAgentResumeSBT.setVerificationFee(newFee))
        .to.emit(aiAgentResumeSBT, "VerificationFeeUpdated")
        .withArgs(VERIFICATION_FEE, newFee);

      expect(await aiAgentResumeSBT.verificationFee()).to.equal(newFee);
    });

    it("Should not allow non-owner to update verification fee", async function () {
      const newFee = ethers.parseEther("0.02");
      
      await expect(
        aiAgentResumeSBT.connect(agent1).setVerificationFee(newFee)
      ).to.be.revertedWithCustomError(aiAgentResumeSBT, "OwnableUnauthorizedAccount");
    });

    it("Should allow owner to add verifier", async function () {
      await expect(aiAgentResumeSBT.addVerifier(verifier.address))
        .to.emit(aiAgentResumeSBT, "VerifierAdded")
        .withArgs(verifier.address);

      expect(await aiAgentResumeSBT.verifiers(verifier.address)).to.be.true;
    });

    it("Should allow owner to remove verifier", async function () {
      await aiAgentResumeSBT.addVerifier(verifier.address);
      
      await expect(aiAgentResumeSBT.removeVerifier(verifier.address))
        .to.emit(aiAgentResumeSBT, "VerifierRemoved")
        .withArgs(verifier.address);

      expect(await aiAgentResumeSBT.verifiers(verifier.address)).to.be.false;
    });

    it("Should allow owner to withdraw fees", async function () {
      await aiAgentResumeSBT.registerAgent(agent1.address);
      await aiAgentResumeSBT.connect(employer1).addJobRecord(
        agent1.address,
        0,
        "Test job",
        ethers.id("proof"),
        ethers.parseEther("100"),
        { value: VERIFICATION_FEE }
      );

      const ownerBalanceBefore = await ethers.provider.getBalance(owner.address);
      const tx = await aiAgentResumeSBT.withdrawFees();
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;
      const ownerBalanceAfter = await ethers.provider.getBalance(owner.address);

      expect(ownerBalanceAfter).to.equal(
        ownerBalanceBefore + VERIFICATION_FEE - gasUsed
      );
    });

    it("Should not allow withdrawing when no fees collected", async function () {
      await expect(aiAgentResumeSBT.withdrawFees())
        .to.be.revertedWith("No fees to withdraw");
    });
  });

  describe("Job Types", function () {
    beforeEach(async function () {
      await aiAgentResumeSBT.registerAgent(agent1.address);
    });

    it("Should handle TradeExecution job type", async function () {
      await aiAgentResumeSBT.connect(employer1).addJobRecord(
        agent1.address,
        0, // TradeExecution
        "Executed trade correctly",
        ethers.id("trade-proof"),
        ethers.parseEther("1000"),
        { value: VERIFICATION_FEE }
      );

      const job = await aiAgentResumeSBT.getJobRecord(agent1.address, 0);
      expect(job.jobType).to.equal(0);
    });

    it("Should handle TreasuryManagement job type", async function () {
      await aiAgentResumeSBT.connect(employer1).addJobRecord(
        agent1.address,
        1, // TreasuryManagement
        "Managed treasury without losses",
        ethers.id("treasury-proof"),
        ethers.parseEther("10000"),
        { value: VERIFICATION_FEE }
      );

      const job = await aiAgentResumeSBT.getJobRecord(agent1.address, 0);
      expect(job.jobType).to.equal(1);
    });

    it("Should handle ContentCompliance job type", async function () {
      await aiAgentResumeSBT.connect(employer1).addJobRecord(
        agent1.address,
        2, // ContentCompliance
        "Posted compliant content",
        ethers.id("content-proof"),
        0,
        { value: VERIFICATION_FEE }
      );

      const job = await aiAgentResumeSBT.getJobRecord(agent1.address, 0);
      expect(job.jobType).to.equal(2);
    });
  });
});
