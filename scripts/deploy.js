const hre = require("hardhat");

async function main() {
  console.log("Deploying AIAgentResumeSBT contract...");

  // Set verification fee to 0.01 ETH
  const verificationFee = hre.ethers.parseEther("0.01");

  const AIAgentResumeSBT = await hre.ethers.getContractFactory("AIAgentResumeSBT");
  const aiAgentResumeSBT = await AIAgentResumeSBT.deploy(verificationFee);

  await aiAgentResumeSBT.waitForDeployment();

  const address = await aiAgentResumeSBT.getAddress();
  console.log(`AIAgentResumeSBT deployed to: ${address}`);
  console.log(`Verification fee set to: ${hre.ethers.formatEther(verificationFee)} ETH`);

  // Optional: Add initial verifiers
  // const verifierAddress = "0x...";
  // await aiAgentResumeSBT.addVerifier(verifierAddress);
  // console.log(`Added verifier: ${verifierAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
