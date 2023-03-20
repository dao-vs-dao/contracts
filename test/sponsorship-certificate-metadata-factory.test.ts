import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, Contract } from "ethers";
import { parseEther } from "ethers/lib/utils";

describe("SponsorshipCertificateMetadataFactory", function () {
  let metadataFactory: Contract;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let manager: SignerWithAddress;

  this.beforeEach(async () => {
    [owner, user1, user2, manager] = await ethers.getSigners();

    const Contract = await ethers.getContractFactory("SponsorshipCertificateMetadataFactory");
    metadataFactory = await upgrades.deployProxy(Contract, [], { kind: "uups" });
  });

  it("will initialize the contract with the expected values", async () => {
    const id = 1;
    const data = {
      receiver: user2.address,
      amount: parseEther("5"),
      redeemed: parseEther("0"),
      shares: BigNumber.from(5000),
      closed: false
    };

    const metadata = await metadataFactory.createCertificateMetadata(id, data);
    console.log(metadata);
  });
});
