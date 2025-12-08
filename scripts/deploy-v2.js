// scripts/deploy-v2.js
// Deployment script for SynthNet Protocol v2.0 (Layered Architecture)

const hre = require("hardhat");

async function main() {
    console.log("=".repeat(60));
    console.log("SynthNet Protocol v2.0 - Layered Architecture Deployment");
    console.log("=".repeat(60));
    console.log("");

    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    
    const balance = await hre.ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", hre.ethers.formatEther(balance), "ETH");
    console.log("");

    // Configuration
    const VERIFICATION_FEE = hre.ethers.parseEther("0.01"); // 0.01 ETH
    
    console.log("Configuration:");
    console.log("  - Verification Fee:", hre.ethers.formatEther(VERIFICATION_FEE), "ETH");
    console.log("");

    // ============================================================
    // FRESH DEPLOY - No legacy contract
    // ============================================================
    
    console.log("Deploying SynthNetProtocol (deploys all layers internally)...");
    
    const SynthNetProtocol = await hre.ethers.getContractFactory("SynthNetProtocol");
    const protocol = await SynthNetProtocol.deploy(
        deployer.address,  // initialOwner
        VERIFICATION_FEE   // verificationFee
    );
    
    await protocol.waitForDeployment();
    const protocolAddress = await protocol.getAddress();
    
    console.log("✓ SynthNetProtocol deployed to:", protocolAddress);
    console.log("");

    // Get layer addresses
    const [layer1Address, layer2Address, layer3Address] = await protocol.getLayerAddresses();
    
    console.log("Layer Contract Addresses:");
    console.log("  Layer 1 (AgentIdentity):", layer1Address);
    console.log("  Layer 2 (SoulboundResume):", layer2Address);
    console.log("  Layer 3 (VerificationRegistry):", layer3Address);
    console.log("");

    // ============================================================
    // OPTIONAL: Add initial verifiers
    // ============================================================
    
    // Uncomment to add verifiers
    // const verifier1 = "0x...";
    // const verifier2 = "0x...";
    // 
    // console.log("Adding initial verifiers...");
    // await protocol.addVerifier(verifier1);
    // await protocol.addVerifier(verifier2);
    // console.log("✓ Verifiers added");
    // console.log("");

    // ============================================================
    // Verification Summary
    // ============================================================
    
    console.log("=".repeat(60));
    console.log("Deployment Complete!");
    console.log("=".repeat(60));
    console.log("");
    console.log("Contract Addresses for verification:");
    console.log("");
    console.log("Main Protocol:");
    console.log(`  SynthNetProtocol: ${protocolAddress}`);
    console.log("");
    console.log("Layer Contracts (deployed by SynthNetProtocol):");
    console.log(`  AgentIdentity (L1): ${layer1Address}`);
    console.log(`  SoulboundResume (L2): ${layer2Address}`);
    console.log(`  VerificationRegistry (L3): ${layer3Address}`);
    console.log("");
    console.log("Verify on Etherscan:");
    console.log(`  npx hardhat verify --network <network> ${protocolAddress} ${deployer.address} ${VERIFICATION_FEE}`);
    console.log("");

    // Return addresses for testing
    return {
        protocol: protocolAddress,
        agentIdentity: layer1Address,
        soulboundResume: layer2Address,
        verificationRegistry: layer3Address
    };
}

// ============================================================
// Migration Deployment (when migrating from legacy contract)
// ============================================================

async function deployWithMigration(legacyContractAddress, legacyProofBaseUri) {
    console.log("=".repeat(60));
    console.log("SynthNet Protocol v2.0 - Migration Deployment");
    console.log("=".repeat(60));
    console.log("");

    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("");

    // Configuration
    const VERIFICATION_FEE = hre.ethers.parseEther("0.01");
    
    // Default IPFS gateway for legacy proofs
    const proofBaseUri = legacyProofBaseUri || "ipfs://";

    console.log("Configuration:");
    console.log("  - Legacy Contract:", legacyContractAddress);
    console.log("  - Proof Base URI:", proofBaseUri);
    console.log("  - Verification Fee:", hre.ethers.formatEther(VERIFICATION_FEE), "ETH");
    console.log("");

    // Deploy new protocol
    console.log("Step 1: Deploying SynthNetProtocol...");
    const SynthNetProtocol = await hre.ethers.getContractFactory("SynthNetProtocol");
    const protocol = await SynthNetProtocol.deploy(deployer.address, VERIFICATION_FEE);
    await protocol.waitForDeployment();
    const protocolAddress = await protocol.getAddress();
    console.log("✓ SynthNetProtocol deployed to:", protocolAddress);
    console.log("");

    // Deploy migration contract
    console.log("Step 2: Deploying VampireMigration...");
    const VampireMigration = await hre.ethers.getContractFactory("VampireMigration");
    const migration = await VampireMigration.deploy(
        legacyContractAddress,
        protocolAddress,
        proofBaseUri
    );
    await migration.waitForDeployment();
    const migrationAddress = await migration.getAddress();
    console.log("✓ VampireMigration deployed to:", migrationAddress);
    console.log("");

    // Get layer addresses
    const [layer1Address, layer2Address, layer3Address] = await protocol.getLayerAddresses();

    console.log("=".repeat(60));
    console.log("Migration Deployment Complete!");
    console.log("=".repeat(60));
    console.log("");
    console.log("Contract Addresses:");
    console.log(`  SynthNetProtocol: ${protocolAddress}`);
    console.log(`  VampireMigration: ${migrationAddress}`);
    console.log(`  AgentIdentity (L1): ${layer1Address}`);
    console.log(`  SoulboundResume (L2): ${layer2Address}`);
    console.log(`  VerificationRegistry (L3): ${layer3Address}`);
    console.log("");
    console.log("Next Steps:");
    console.log("  1. Fund the migration contract with ETH for verification fees");
    console.log("  2. Call migrateAgent() or selfMigrate() for each agent");
    console.log("  3. Verify all data migrated correctly");
    console.log("  4. Call finalizeMigration() when complete");
    console.log("");

    return {
        protocol: protocolAddress,
        migration: migrationAddress,
        agentIdentity: layer1Address,
        soulboundResume: layer2Address,
        verificationRegistry: layer3Address
    };
}

// ============================================================
// Run deployment
// ============================================================

// Check for migration mode
const args = process.argv.slice(2);
const migrationMode = args.includes("--migrate");
const legacyAddress = args.find(arg => arg.startsWith("--legacy="))?.split("=")[1];
const proofUri = args.find(arg => arg.startsWith("--proofUri="))?.split("=")[1];

if (migrationMode && legacyAddress) {
    deployWithMigration(legacyAddress, proofUri)
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
} else {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { main, deployWithMigration };
