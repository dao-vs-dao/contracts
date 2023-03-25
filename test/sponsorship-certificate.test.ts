import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract } from "ethers";
import { parseEther } from "ethers/lib/utils";

const zeroAddress = "0x0000000000000000000000000000000000000000";
const countEventsOfType = (receipt: any, eventType: string): number =>
  receipt.events?.filter((evt: any) => evt.event === eventType).length;

describe("SponsorshipCertificate", function () {
  let sponsorshipCertificate: Contract;
  let redeemer: Contract;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let manager: SignerWithAddress;

  this.beforeEach(async () => {
    [owner, user1, user2, user3, manager] = await ethers.getSigners();

    const Contract = await ethers.getContractFactory("SponsorshipCertificate");
    sponsorshipCertificate = await upgrades.deployProxy(Contract, [], { kind: "uups" });

    // set the test redeemer so the function can be safely called
    const TestCertificateRedeemer = await ethers.getContractFactory("TestCertificateRedeemer");
    redeemer = await TestCertificateRedeemer.deploy();
    await sponsorshipCertificate.setSponsorshipCertificateManager(redeemer.address);
  });

  describe("Base functionalities", function () {
    it("will initialize the contract with the expected values", async () => {
      expect(await sponsorshipCertificate.name()).to.equal("DVD - Sponsorship Certificate");
      expect(await sponsorshipCertificate.symbol()).to.equal("DVD-SC");
      expect(await sponsorshipCertificate.owner()).to.equal(owner.address);
    });

    it("can update the certificate manager", async () => {
      const manager = "0x388C818CA8B9251b393131C08a736A67ccB19297";
      await sponsorshipCertificate.setSponsorshipCertificateManager(manager);
      expect(await sponsorshipCertificate.sponsorshipManager()).to.equal(manager);
    });

    it("setting the certificate manager to address(0) throw an error", async () => {
      await expect(
        sponsorshipCertificate.setSponsorshipCertificateManager(zeroAddress)
      ).to.be.revertedWith("Invalid manager");
    });

    it("random user setting the certificate manager will throw an error", async () => {
      await expect(
        sponsorshipCertificate.connect(user1).setSponsorshipCertificateManager(zeroAddress)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("updating the certificate manager triggers an event", async () => {
      const manager = "0x388C818CA8B9251b393131C08a736A67ccB19297";
      const tx = await sponsorshipCertificate.setSponsorshipCertificateManager(manager);
      const receipt = await tx.wait();

      expect(countEventsOfType(receipt, "SponsorshipManagerUpdated")).to.equal(1);
    });

    it("can update the certificate metadata factory", async () => {
      const factory = "0x388C818CA8B9251b393131C08a736A67ccB19297";
      await sponsorshipCertificate.setSponsorshipCertificateMetadataFactory(factory);
      expect(await sponsorshipCertificate.sponsorshipCertificateMetadataFactory()).to.equal(
        factory
      );
    });

    it("setting the certificate metadata factory to address(0) throw an error", async () => {
      await expect(
        sponsorshipCertificate.setSponsorshipCertificateMetadataFactory(zeroAddress)
      ).to.be.revertedWith("Invalid factory");
    });

    it("random user setting the certificate metadata factory will throw an error", async () => {
      await expect(
        sponsorshipCertificate.connect(user1).setSponsorshipCertificateMetadataFactory(zeroAddress)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("updating the certificate metadata factory triggers an event", async () => {
      const factory = "0x388C818CA8B9251b393131C08a736A67ccB19297";
      const tx = await sponsorshipCertificate.setSponsorshipCertificateMetadataFactory(factory);
      const receipt = await tx.wait();

      expect(countEventsOfType(receipt, "SponsorshipMetadataFactoryUpdated")).to.equal(1);
    });
  });

  describe("Certificate emission", function () {
    it("will create a certificate for the user", async () => {
      await sponsorshipCertificate.setSponsorshipCertificateManager(manager.address);

      // create certificate
      await sponsorshipCertificate
        .connect(manager)
        .emitCertificate(user1.address, user2.address, 15000, 9000);

      // verify NFT has been given to user1
      expect(await sponsorshipCertificate.balanceOf(user1.address)).to.equal(1);
      const certificateData = await sponsorshipCertificate.certificateData(1); // we are sure the id is 1
      expect(certificateData.receiver).to.equal(user2.address);
      expect(certificateData.amount).to.equal(15000);
      expect(certificateData.redeemed).to.equal(0);
      expect(certificateData.shares).to.equal(9000);
      expect(certificateData.closed).to.equal(false);
    });

    it("will throw if a random user tries to add a certificate", async () => {
      await expect(
        sponsorshipCertificate
          .connect(user1)
          .emitCertificate(user1.address, user2.address, 15000, 9000)
      ).to.be.revertedWith("Only manager can emit certs");
    });
  });

  describe("Certificate redeem", function () {
    this.beforeEach(async () => {
      // set manager, so we can impersonate it to trigger the certificate creation
      await sponsorshipCertificate.setSponsorshipCertificateManager(manager.address);

      // create certificate
      await sponsorshipCertificate
        .connect(manager)
        .emitCertificate(user1.address, user2.address, 15000, 9000);

      // set back redeemer
      await sponsorshipCertificate.setSponsorshipCertificateManager(redeemer.address);
    });

    it("will throw if a random user tries to add a certificate", async () => {
      await expect(sponsorshipCertificate.connect(user2).redeemCertificate(1)).to.be.revertedWith(
        "Not the owner"
      );
    });

    it("will update the certificate data", async () => {
      //redeem certificate
      await sponsorshipCertificate.connect(user1).redeemCertificate(1);

      // check the updated data
      const certificateData = await sponsorshipCertificate.certificateData(1);
      expect(certificateData.redeemed).to.equal(1000); // coming from redeemer mock
      expect(certificateData.closed).to.equal(true);
    });

    it("triggers a MetadataUpdate event", async () => {
      const tx = await sponsorshipCertificate.connect(user1).redeemCertificate(1);
      const receipt = await tx.wait();

      expect(countEventsOfType(receipt, "MetadataUpdate")).to.equal(1);
    });

    it("triggers a CertificateRedeemed event", async () => {
      const tx = await sponsorshipCertificate.connect(user1).redeemCertificate(1);
      const receipt = await tx.wait();

      expect(countEventsOfType(receipt, "CertificateRedeemed")).to.equal(1);
    });
  });

  describe("getUserCertificates", function () {
    it("will correctly detect owned certificates", async () => {
      await sponsorshipCertificate.setSponsorshipCertificateManager(manager.address);

      // create certificates
      await sponsorshipCertificate
        .connect(manager)
        .emitCertificate(user1.address, user2.address, 15000, 9000);
      await sponsorshipCertificate
        .connect(manager)
        .emitCertificate(user1.address, user3.address, 15000, 9000);
      await sponsorshipCertificate
        .connect(manager)
        .emitCertificate(user2.address, user3.address, 15000, 9000);

      // set back redeemer
      await sponsorshipCertificate.setSponsorshipCertificateManager(redeemer.address);

      // verify certificates for each user
      const user1Certs = await sponsorshipCertificate.getUserCertificates(user1.address);
      const user2Certs = await sponsorshipCertificate.getUserCertificates(user2.address);
      const user3Certs = await sponsorshipCertificate.getUserCertificates(user3.address);

      // user1 owns 2 and is beneficiary of 0
      expect(user1Certs.owned.length).to.equal(2);
      expect(user1Certs.beneficiary.length).to.equal(0);
      // user2 owns 1 and is beneficiary of 1
      expect(user2Certs.owned.length).to.equal(1);
      expect(user2Certs.beneficiary.length).to.equal(1);
      // user3 owns 0 and is beneficiary of 2
      expect(user3Certs.owned.length).to.equal(0);
      expect(user3Certs.beneficiary.length).to.equal(2);
    });

    it("will correctly detect owned certificates also when they are redeemed", async () => {
      await sponsorshipCertificate.setSponsorshipCertificateManager(manager.address);

      // create certificates
      await sponsorshipCertificate
        .connect(manager)
        .emitCertificate(user1.address, user2.address, 15000, 9000);
      await sponsorshipCertificate
        .connect(manager)
        .emitCertificate(user1.address, user2.address, 30000, 18000);
      await sponsorshipCertificate
        .connect(manager)
        .emitCertificate(user1.address, user2.address, 45000, 27000);

      // set back redeemer
      await sponsorshipCertificate.setSponsorshipCertificateManager(redeemer.address);

      // redeem multiple certificate
      await sponsorshipCertificate.connect(user1).redeemCertificate(1);
      await sponsorshipCertificate.connect(user1).redeemCertificate(3);

      // verify users certificates
      const user1Certs = await sponsorshipCertificate.getUserCertificates(user1.address);
      const user2Certs = await sponsorshipCertificate.getUserCertificates(user2.address);

      // user1 owns 3 and is beneficiary of 0
      // >> redeemed certificates are still shown in the owned list
      expect(user1Certs.owned.length).to.equal(3);
      expect(user1Certs.beneficiary.length).to.equal(0);
      // user2 owns 0 and is beneficiary of 1
      // >> redeemed certificates are NOT shown anymore in the beneficiary list
      expect(user2Certs.owned.length).to.equal(0);
      expect(user2Certs.beneficiary.length).to.equal(1);
    });
  });
});
