import { upgrades, ethers } from "hardhat";
import hre from "hardhat";

const MUMBAI_DVD_ADDRESS = "0xAcd88F72B980ed144c7C037F6807E39026CFFd15";

async function main() {
  console.log("Upgrading DaoVsDao version...");
  const HookV2 = await ethers.getContractFactory("DaoVsDao");
  const hook = await upgrades.upgradeProxy(MUMBAI_DVD_ADDRESS, HookV2);

  const implementation = await upgrades.erc1967.getImplementationAddress(hook.address);
  console.log("DaoVsDao upgrade deployed to:", hook.address);
  console.log("New implementation address:", implementation);

  console.log("Verifying DaoVsDao");
  try {
    await hre.run("verify:verify", { address: implementation });
  } catch (error) {
    console.log(`DaoVsDao VERIFICATION FAILED`);
    console.log(error);
    return;
  }

  console.log(`DaoVsDao verified`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
