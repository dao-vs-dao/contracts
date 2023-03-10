import { upgrades, ethers } from "hardhat";
import hre from "hardhat";

// SponsorshipCertificate implementation deployed to: 0x4D301f21eD0107A89360f66e79b3628f740ebbEE
// SponsorshipCertificate proxy deployed to: 0x3EB16b38DfE7725e699e0A76Cf668a690ca0C34C

async function main() {
  console.log("Deploying SponsorshipCertificate proxy and implementation...");
  const SponsorshipCertificateContract = await ethers.getContractFactory("SponsorshipCertificate");
  const sponsorshipCertificate = await upgrades.deployProxy(SponsorshipCertificateContract, [], {
    kind: "uups"
  });
  await sponsorshipCertificate.deployed();

  const implementation = await upgrades.erc1967.getImplementationAddress(
    sponsorshipCertificate.address
  );
  console.log("SponsorshipCertificate implementation deployed to:", implementation);
  console.log("SponsorshipCertificate proxy deployed to:", sponsorshipCertificate.address);

  console.log("Verifying SponsorshipCertificate");
  try {
    await hre.run("verify:verify", { address: implementation });
  } catch (error) {
    console.log(`SponsorshipCertificate VERIFICATION FAILED`);
    console.log(error);
    return;
  }

  console.log(`SponsorshipCertificate verified`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
