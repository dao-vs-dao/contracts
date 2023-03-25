import { upgrades, ethers } from "hardhat";
import hre from "hardhat";

const MUMBAI_SC_ADDRESS = "0x3EB16b38DfE7725e699e0A76Cf668a690ca0C34C";
const sleep = (ms: number)  => new Promise(resolve => setTimeout(resolve, ms));


async function main() {
  console.log("Upgrading SponsorshipCertificate version...");
  const HookV2 = await ethers.getContractFactory("SponsorshipCertificate");
  const hook = await upgrades.upgradeProxy(MUMBAI_SC_ADDRESS, HookV2);

  const implementation = await upgrades.erc1967.getImplementationAddress(hook.address);
  console.log("SponsorshipCertificate upgrade deployed to:", hook.address);
  console.log("New implementation address:", implementation);

  console.log("Wait a bit for the contract to settle...");
  await sleep(5000);

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
