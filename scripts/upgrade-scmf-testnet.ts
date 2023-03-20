import { upgrades, ethers } from "hardhat";
import hre from "hardhat";

const MUMBAI_DVD_ADDRESS = "0x5412526e8130188168F8548576A7A5DA0aC3f391";
const sleep = (ms: number)  => new Promise(resolve => setTimeout(resolve, ms));


async function main() {
  console.log("Upgrading SponsorshipCertificateMetadataFactory version...");
  const HookV2 = await ethers.getContractFactory("SponsorshipCertificateMetadataFactory");
  const hook = await upgrades.upgradeProxy(MUMBAI_DVD_ADDRESS, HookV2);

  const implementation = await upgrades.erc1967.getImplementationAddress(hook.address);
  console.log("SponsorshipCertificateMetadataFactory upgrade deployed to:", hook.address);
  console.log("New implementation address:", implementation);

  console.log("Wait a bit for the contract to settle...");
  await sleep(5000);

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
