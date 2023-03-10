import { upgrades, ethers } from "hardhat";
import hre from "hardhat";

// SponsorshipCertificateMetadataFactory implementation deployed to: 0xe7B1745A1AB8297a4D1994C929E729c08Adb39D2
// SponsorshipCertificateMetadataFactory proxy deployed to: 0x5412526e8130188168F8548576A7A5DA0aC3f391

async function main() {
  console.log("Deploying SponsorshipCertificateMetadataFactory proxy and implementation...");
  const SponsorshipCertificateMetadataFactoryContract = await ethers.getContractFactory(
    "SponsorshipCertificateMetadataFactory"
  );
  const metadataFactory = await upgrades.deployProxy(
    SponsorshipCertificateMetadataFactoryContract,
    [],
    {
      kind: "uups"
    }
  );
  await metadataFactory.deployed();

  const implementation = await upgrades.erc1967.getImplementationAddress(metadataFactory.address);
  console.log("SponsorshipCertificateMetadataFactory implementation deployed to:", implementation);
  console.log("SponsorshipCertificateMetadataFactory proxy deployed to:", metadataFactory.address);

  console.log("Verifying SponsorshipCertificateMetadataFactory");
  try {
    await hre.run("verify:verify", { address: implementation });
  } catch (error) {
    console.log(`SponsorshipCertificateMetadataFactory VERIFICATION FAILED`);
    console.log(error);
    return;
  }

  console.log(`SponsorshipCertificateMetadataFactory verified`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
