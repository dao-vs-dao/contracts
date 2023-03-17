import { upgrades, ethers } from "hardhat";
import hre from "hardhat";
import { FormatTypes, Interface } from "ethers/lib/utils";

const abi: any[] = [];

async function main() {
  const iface = new Interface(abi);
  console.log(iface.format(FormatTypes.full));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
