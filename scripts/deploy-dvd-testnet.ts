import { upgrades, ethers } from "hardhat";
import hre from "hardhat";

// Dao-Vs-Dao implementation deployed to: 0x696D0C3B7440633377ED5F8b214C57434BfDDd36
// Dao-Vs-Dao proxy deployed to: 0xAcd88F72B980ed144c7C037F6807E39026CFFd15

async function main() {
  console.log("Deploying DvD proxy and implementation...");
  const DVDContract = await ethers.getContractFactory("DaoVsDao");
  const daoVsDao = await upgrades.deployProxy(DVDContract, [], {
    kind: "uups"
  });
  await daoVsDao.deployed();

  const implementation = await upgrades.erc1967.getImplementationAddress(daoVsDao.address);
  console.log("Dao-Vs-Dao implementation deployed to:", implementation);
  console.log("Dao-Vs-Dao proxy deployed to:", daoVsDao.address);

  console.log("Verifying Dao-Vs-Dao");
  try {
    await hre.run("verify:verify", { address: implementation });
  } catch (error) {
    console.log(`Dao-Vs-Dao VERIFICATION FAILED`);
    console.log(error);
    return;
  }

  console.log(`Dao-Vs-Dao verified`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
