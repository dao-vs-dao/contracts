import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import itParam from "mocha-param";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, Contract } from "ethers";
import { parseEther } from "ethers/lib/utils";

const zeroAddress = "0x0000000000000000000000000000000000000000";
const countEventsOfType = (receipt: any, eventType: string): number =>
  receipt.events?.filter((evt: any) => evt.event === eventType).length;
const getEventOfType = (receipt: any, eventType: string): any =>
  receipt.events?.find((evt: any) => evt.event === eventType);

describe("DaoVsDao", function () {
  let daoVsDao: Contract;
  let sponsorshipCertificate: Contract;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let mrNobody: SignerWithAddress;

  this.beforeEach(async () => {
    [owner, user1, user2, user3, mrNobody] = await ethers.getSigners();

    // deploy DVD contract
    const DVDContract = await ethers.getContractFactory("DaoVsDao");
    daoVsDao = await upgrades.deployProxy(DVDContract, [], { kind: "uups" });

    // deploy Sponsorship Certificate contract and connect the two
    const DVDSCContract = await ethers.getContractFactory("TestSponsorshipCertificate");
    sponsorshipCertificate = await DVDSCContract.deploy();
    await daoVsDao.setSponsorshipCertificateEmitter(sponsorshipCertificate.address);
  });

  describe("Base functionalities", function () {
    it("will initialize the contract with the expected values", async () => {
      expect(await daoVsDao.name()).to.equal("DaoVsDao Token");
      expect(await daoVsDao.symbol()).to.equal("DVD");
      expect(await daoVsDao.owner()).to.equal(owner.address);

      expect(await daoVsDao.slashingPercentage()).to.equal(20);
      expect(await daoVsDao.slashingTax()).to.equal(10);
      expect(await daoVsDao.sponsorshipCertificateEmitter()).to.equal(
        sponsorshipCertificate.address
      );

      // the owner will get 1DVD when the contract is initialized
      expect(await daoVsDao.balanceOf(owner.address)).to.equal(parseEther("1"));
    });

    it("is possible to add new realms", async () => {
      await daoVsDao.addRealm();
      await daoVsDao.addRealm();

      const gameData = await daoVsDao.getGameData();
      expect(gameData.lands).to.deep.equal([[[zeroAddress]], [[zeroAddress]]]);
      expect(gameData.players).to.deep.equal([]);
    });

    it("random user adding a realm will throw an error", async () => {
      await expect(daoVsDao.connect(user1).addRealm()).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });
  });

  describe("Setters", function () {
    describe("setSponsorshipCertificateEmitter", function () {
      it("can set the certificate emitter", async () => {
        const emitter = "0x388C818CA8B9251b393131C08a736A67ccB19297";
        await daoVsDao.setSponsorshipCertificateEmitter(emitter);
        expect(await daoVsDao.sponsorshipCertificateEmitter()).to.equal(emitter);
      });

      it("setting the certificate emitter to address(0) throw an error", async () => {
        await expect(daoVsDao.setSponsorshipCertificateEmitter(zeroAddress)).to.be.revertedWith(
          "Invalid emitter"
        );
      });

      it("random user setting the certificate emitter will throw an error", async () => {
        await expect(
          daoVsDao.connect(user1).setSponsorshipCertificateEmitter(zeroAddress)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("updating the certificate emitter triggers an event", async () => {
        const emitter = "0x388C818CA8B9251b393131C08a736A67ccB19297";
        const tx = await daoVsDao.setSponsorshipCertificateEmitter(emitter);
        const receipt = await tx.wait();

        expect(countEventsOfType(receipt, "SponsorshipCertificateEmitterUpdated")).to.equal(1);
      });
    });

    describe("setSlashingPercentage", function () {
      it("can update the slashing percentage", async () => {
        await daoVsDao.setSlashingPercentage(99);
        expect(await daoVsDao.slashingPercentage()).to.equal(99);
      });

      it("setting the slashing percentage to an invalid value throw an error", async () => {
        await expect(daoVsDao.setSlashingPercentage(150)).to.be.revertedWith(
          "Invalid slashing % value"
        );
      });

      it("random user setting the slashing percentage will throw an error", async () => {
        await expect(daoVsDao.connect(user1).setSlashingPercentage(99)).to.be.revertedWith(
          "Ownable: caller is not the owner"
        );
      });

      it("updating the slashing percentage triggers an event", async () => {
        const tx = await daoVsDao.setSlashingPercentage(99);
        const receipt = await tx.wait();

        expect(countEventsOfType(receipt, "SlashingPercentageUpdated")).to.equal(1);
      });
    });

    describe("setSlashingTax", function () {
      it("can update the slashing tax", async () => {
        await daoVsDao.setSlashingTax(99);
        expect(await daoVsDao.slashingTax()).to.equal(99);
      });

      it("setting the slashing tax to an invalid value throw an error", async () => {
        await expect(daoVsDao.setSlashingTax(150)).to.be.revertedWith("Invalid slashing tax value");
      });

      it("random user setting the slashing tax will throw an error", async () => {
        await expect(daoVsDao.connect(user1).setSlashingTax(99)).to.be.revertedWith(
          "Ownable: caller is not the owner"
        );
      });

      it("updating the slashing tax triggers an event", async () => {
        const tx = await daoVsDao.setSlashingTax(99);
        const receipt = await tx.wait();

        expect(countEventsOfType(receipt, "SlashingTaxUpdated")).to.equal(1);
      });
    });

    describe("setParticipationFee", function () {
      it("can set the participation fee", async () => {
        await daoVsDao.setParticipationFee(parseEther("10"));
        expect(await daoVsDao.participationFee()).to.equal(parseEther("10"));
      });

      it("random user setting the participation fee will throw an error", async () => {
        await expect(daoVsDao.connect(user1).setParticipationFee(0)).to.be.revertedWith(
          "Ownable: caller is not the owner"
        );
      });

      it("updating the participation fee triggers an event", async () => {
        const tx = await daoVsDao.setParticipationFee(99);
        const receipt = await tx.wait();

        expect(countEventsOfType(receipt, "ParticipationFeeUpdated")).to.equal(1);
      });
    });

    describe("setPercentageForReferrer", function () {
      it("can update the percentage for referrers", async () => {
        await daoVsDao.setPercentageForReferrer(99);
        expect(await daoVsDao.percentageForReferrer()).to.equal(99);
      });

      it("setting the percentage for referrers to an invalid value throw an error", async () => {
        await expect(daoVsDao.setPercentageForReferrer(150)).to.be.revertedWith(
          "Invalid % for referrers value"
        );
      });

      it("random user setting the percentage for referrers will throw an error", async () => {
        await expect(daoVsDao.connect(user1).setPercentageForReferrer(99)).to.be.revertedWith(
          "Ownable: caller is not the owner"
        );
      });

      it("updating the percentage for referrers triggers an event", async () => {
        const tx = await daoVsDao.setPercentageForReferrer(99);
        const receipt = await tx.wait();

        expect(countEventsOfType(receipt, "PercentageForReferrerUpdated")).to.equal(1);
      });
    });
  });

  describe("placeUser ", function () {
    it("will add the user in the expected location", async () => {
      await daoVsDao.addRealm();

      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      expect(await daoVsDao.nrPlayers()).to.equal(1);

      const gameData = await daoVsDao.getGameData();
      expect(gameData.lands).to.deep.equal([[[user1.address], [zeroAddress, zeroAddress]]]);
    });

    it("will automatically add a row if the pyramid is full", async () => {
      const allSigners = await ethers.getSigners();
      await daoVsDao.addRealm();

      // fist user is added, pyramid is full, new row is added
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      expect((await daoVsDao.getGameData()).lands).to.deep.equal([
        [[user1.address], [zeroAddress, zeroAddress]]
      ]);

      // second user is added, pyramid is NOT full, new row is NOT added
      await daoVsDao
        .connect(user2)
        .placeUser({ realm: 0, row: 1, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      expect((await daoVsDao.getGameData()).lands).to.deep.equal([
        [[user1.address], [user2.address, zeroAddress]]
      ]);

      // third user is added, pyramid is full, new row is added
      await daoVsDao
        .connect(user3)
        .placeUser({ realm: 0, row: 1, column: 1 }, zeroAddress, { value: parseEther("0.5") });
      expect((await daoVsDao.getGameData()).lands).to.deep.equal([
        [[user1.address], [user2.address, user3.address], [zeroAddress, zeroAddress, zeroAddress]]
      ]);

      // forth and fifth users are added, pyramid is NOT full, new row is NOT added
      await daoVsDao
        .connect(allSigners[4])
        .placeUser({ realm: 0, row: 2, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(allSigners[5])
        .placeUser({ realm: 0, row: 2, column: 2 }, zeroAddress, { value: parseEther("0.5") });
      expect((await daoVsDao.getGameData()).lands).to.deep.equal([
        [
          [user1.address],
          [user2.address, user3.address],
          [allSigners[4].address, zeroAddress, allSigners[5].address]
        ]
      ]);

      // sixth user is added, pyramid is full, new row is added
      await daoVsDao
        .connect(allSigners[6])
        .placeUser({ realm: 0, row: 2, column: 1 }, zeroAddress, { value: parseEther("0.5") });
      expect((await daoVsDao.getGameData()).lands).to.deep.equal([
        [
          [user1.address],
          [user2.address, user3.address],
          [allSigners[4].address, allSigners[6].address, allSigners[5].address],
          [zeroAddress, zeroAddress, zeroAddress, zeroAddress]
        ]
      ]);
    });

    it("updates the user's variables after the addition", async () => {
      await daoVsDao.addRealm();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });

      const gameData = await daoVsDao.getGameData();
      console.log(gameData.players[0]);
      expect(gameData.players.length).to.equal(1);
      expect(gameData.players[0].userAddress).to.equal(user1.address);
      expect(gameData.players[0].coords.realm).to.equal(0);
      expect(gameData.players[0].coords.row).to.equal(0);
      expect(gameData.players[0].coords.column).to.equal(0);
      expect(gameData.players[0].balance).to.equal(0);
      expect(gameData.players[0].sponsorships).to.equal(0);
      expect(gameData.players[0].claimable).to.equal(0);
    });

    it("sends all participation fee to `owner` if referrer is not a player", async () => {
      await daoVsDao.addRealm();

      const initialOwnerBalance = await owner.getBalance();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      const receivedByOwner = (await owner.getBalance()).sub(initialOwnerBalance);

      expect(receivedByOwner).to.equal(parseEther("0.5"));
    });

    it("will throw if the user paid less than the participation fee", async () => {
      await daoVsDao.addRealm();
      await expect(
        daoVsDao
          .connect(user1)
          .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.1") })
      ).to.be.revertedWith("Need to pay participation fee");
    });

    it("will throw if the user is already a player", async () => {
      await daoVsDao.addRealm();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });

      await expect(
        daoVsDao
          .connect(user1)
          .placeUser({ realm: 0, row: 1, column: 0 }, zeroAddress, { value: parseEther("0.5") })
      ).to.be.revertedWith("User is already a player");
    });

    it("will throw if the selected area is not empty", async () => {
      await daoVsDao.addRealm();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });

      await expect(
        daoVsDao
          .connect(user2)
          .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") })
      ).to.be.revertedWith("Area not empty");
    });
  });

  describe("swap", function () {
    this.beforeEach(async () => {
      // add a realm and three users in it
      await daoVsDao.addRealm();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user2)
        .placeUser({ realm: 0, row: 1, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user3)
        .placeUser({ realm: 0, row: 1, column: 1 }, zeroAddress, { value: parseEther("0.5") });
    });

    itParam(
      "will throw an error if trying to swap with out of bound coordinates: ${JSON.stringify(value)}",
      [
        { realm: 3, row: 0, column: 0, error: "Realm out of bound" },
        { realm: 0, row: 3, column: 0, error: "Row out of bound" },
        { realm: 0, row: 0, column: 3, error: "Column out of bound" }
      ],
      async ({ realm, row, column, error }) => {
        const coord = { realm, row, column };
        await expect(daoVsDao.connect(user2).swap(coord)).to.be.revertedWith(error);
      }
    );

    it("will throw if user isn't a player", async () => {
      const user1Coordinates = { realm: 0, row: 0, column: 0 };
      await expect(daoVsDao.connect(mrNobody).swap(user1Coordinates)).to.be.revertedWith(
        "User isn't a player"
      );
    });

    it("will throw if user is too far", async () => {
      // let's add an extra row and a player on it
      await daoVsDao.addRow(0);
      await daoVsDao
        .connect(mrNobody)
        .placeUser({ realm: 0, row: 2, column: 0 }, zeroAddress, { value: parseEther("0.5") });

      const user1Coordinates = { realm: 0, row: 0, column: 0 };
      await expect(daoVsDao.connect(mrNobody).swap(user1Coordinates)).to.be.revertedWith(
        "Swap too far from user coords"
      );
    });

    it("will throw if user tries to swap with a user in a higher row", async () => {
      const user2Coordinates = { realm: 0, row: 1, column: 0 };
      await expect(daoVsDao.connect(user1).swap(user2Coordinates)).to.be.revertedWith(
        "Cannot swap with a higher row"
      );
    });

    it("will throw if user tries to swap with a user with a higher worth", async () => {
      await daoVsDao.transfer(user1.address, parseEther("0.50"));
      await daoVsDao.transfer(user2.address, parseEther("0.25"));

      const user1Coordinates = { realm: 0, row: 0, column: 0 };
      await expect(daoVsDao.connect(user2).swap(user1Coordinates)).to.be.revertedWith(
        "User has higher worth"
      );
    });

    it("will throw if user tries to swap while in attack cool-down", async () => {
      // let's add an extra row and a player on it
      await daoVsDao
        .connect(mrNobody)
        .placeUser({ realm: 0, row: 2, column: 0 }, zeroAddress, { value: parseEther("0.5") });

      // first swap
      await daoVsDao.connect(mrNobody).swap({ realm: 0, row: 2, column: 1 });

      // second swap fails as user is in attack cool down
      await expect(
        daoVsDao.connect(mrNobody).swap({ realm: 0, row: 2, column: 2 })
      ).to.be.revertedWith("Cannot attack yet");
    });

    it("will throw if user tries to swap with other user while in recovery cool-down", async () => {
      await daoVsDao.transfer(user2.address, parseEther("0.50"));
      await daoVsDao.transfer(user3.address, parseEther("0.50"));

      // first swap (user2 => user1)
      await daoVsDao.connect(user2).swap({ realm: 0, row: 0, column: 0 });

      // second swap (user3 => user1) fails as user1 is in recovery cool down
      await expect(
        daoVsDao.connect(user3).swap({ realm: 0, row: 1, column: 0 })
      ).to.be.revertedWith("Cannot be attacked yet");
    });

    it("will allow users to swap to empty lands", async () => {
      // let's add an extra row and a player on it
      await daoVsDao
        .connect(mrNobody)
        .placeUser({ realm: 0, row: 2, column: 0 }, zeroAddress, { value: parseEther("0.5") });

      // initial check
      let lastRow = await daoVsDao.getLastRow(0);
      expect(lastRow).to.deep.equal([mrNobody.address, zeroAddress, zeroAddress]);

      const emptyCoordinates = { realm: 0, row: 2, column: 1 };
      await daoVsDao.connect(mrNobody).swap(emptyCoordinates);

      // verify positions have been swapped
      lastRow = await daoVsDao.getLastRow(0);
      expect(lastRow).to.deep.equal([zeroAddress, mrNobody.address, zeroAddress]);
    });

    it("will successfully swap users", async () => {
      await daoVsDao.transfer(user1.address, parseEther("0.25"));
      await daoVsDao.transfer(user2.address, parseEther("0.50"));

      const user1Coordinates = { realm: 0, row: 0, column: 0 };
      await daoVsDao.connect(user2).swap(user1Coordinates);

      // verify positions have been swapped
      const gameData = await daoVsDao.getGameData();
      expect(gameData.lands).to.deep.equal([
        [[user2.address], [user1.address, user3.address], [zeroAddress, zeroAddress, zeroAddress]]
      ]);
    });

    it("will slash the attacked user on swap", async () => {
      await daoVsDao.transfer(user1.address, parseEther("0.25"));
      await daoVsDao.transfer(user2.address, parseEther("0.50"));
      await daoVsDao.transfer(user3.address, parseEther("0.25"));

      const user1Coordinates = { realm: 0, row: 0, column: 0 };
      const tx = await daoVsDao.connect(user2).swap(user1Coordinates);
      const receipt = await tx.wait();

      // all the slashing info is in the emitted event
      const slashing = getEventOfType(receipt, "Slashed");
      expect(slashing.args.subtractedFromAttackedBalance.toString()).equals("50000304414003044");
      expect(slashing.args.subtractedFromAttackedSponsorships.toString()).equals("0");
      expect(slashing.args.slashingTaxes.toString()).equals("5000030441400304");
      expect(slashing.args.addedToAttackerBalance.toString()).equals("45000273972602740");
      expect(slashing.args.addedToAttackerSponsorships.toString()).equals("0");

      // verify balances (also to owner to check the tax has been paid)
      const user1Data = await daoVsDao.getPlayerData(user1.address);
      const user2Data = await daoVsDao.getPlayerData(user2.address);
      expect(user1Data.balance.toString()).to.equal("200001217656012176");
      expect(user2Data.balance.toString()).to.equal("545000908168442415");
      expect((await daoVsDao.balanceOf(owner.address)).toString()).to.equal("5000030441400304");
    });
  });

  describe("sponsor", function () {
    this.beforeEach(async () => {
      // add a realm and three users in it
      await daoVsDao.addRealm();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user2)
        .placeUser({ realm: 0, row: 1, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user3)
        .placeUser({ realm: 0, row: 1, column: 1 }, zeroAddress, { value: parseEther("0.5") });
    });

    it("will throw if the amount is 0", async () => {
      await expect(daoVsDao.connect(user1).sponsor(user2.address, 0)).to.be.revertedWith(
        "Amount must be greater than 0"
      );
    });

    it("will throw if user isn't a player", async () => {
      await expect(daoVsDao.connect(user1).sponsor(mrNobody.address, 1000)).to.be.revertedWith(
        "User isn't a player"
      );
    });

    it("will throw if the sponsorship exceeds the balance", async () => {
      const amount = await parseEther("199");
      await expect(daoVsDao.connect(user1).sponsor(user2.address, amount)).to.be.revertedWith(
        "Insufficient balance to sponsor"
      );
    });

    it("will successfully sponsor a user", async () => {
      await daoVsDao.transfer(user1.address, parseEther("0.25"));
      await daoVsDao.transfer(user2.address, parseEther("0.50"));
      await daoVsDao.transfer(user3.address, parseEther("0.25"));

      const amount = parseEther("0.2");
      await daoVsDao.connect(user2).sponsor(user3.address, amount);

      // verify balance of sponsor
      const user2Data = await daoVsDao.getPlayerData(user2.address);
      expect(user2Data.balance).to.equal(parseEther("0.3")); // balance has decreased

      // verify balance of sponsored
      const user3Data = await daoVsDao.getPlayerData(user3.address);
      const user3Shares = await daoVsDao.sponsorshipShares(user3.address);
      expect(user3Data.balance).to.equal(parseEther("0.25")); // balance stays the same
      expect(user3Data.sponsorships).to.equal(parseEther("0.2")); // sponsorship balance has increased
      expect(user3Shares).to.equal(parseEther("0.2")); // shares == amount (as it was the first sponsorship)
    });

    it("will successfully calculate the shares", async () => {
      await daoVsDao.transfer(user1.address, parseEther("0.25"));
      await daoVsDao.transfer(user2.address, parseEther("0.50"));
      await daoVsDao.transfer(user3.address, parseEther("0.25"));

      // first sponsorship, shares equal amount
      await daoVsDao.connect(user2).sponsor(user3.address, parseEther("0.2"));
      expect(await daoVsDao.sponsorshipShares(user3.address)).to.equal(parseEther("0.2"));

      // other sponsorships, shares are proportional
      await daoVsDao.connect(user2).sponsor(user3.address, parseEther("0.2"));
      expect(await daoVsDao.sponsorshipShares(user3.address)).to.equal(parseEther("0.4"));

      // other sponsorships, shares are proportional
      await daoVsDao.connect(user2).sponsor(user3.address, parseEther("0.05"));
      expect(await daoVsDao.sponsorshipShares(user3.address)).to.equal(parseEther("0.45"));
    });
  });

  describe("redeemSponsorshipShares", function () {
    let fakeEmitter: SignerWithAddress;

    this.beforeEach(async () => {
      // add a realm and three users in it
      await daoVsDao.addRealm();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user2)
        .placeUser({ realm: 0, row: 1, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user3)
        .placeUser({ realm: 0, row: 1, column: 1 }, zeroAddress, { value: parseEther("0.5") });

      // add a sponsorship
      const amount = parseEther("0.2");
      await daoVsDao.transfer(user2.address, amount);
      await daoVsDao.connect(user2).sponsor(user3.address, amount);

      // set the emitter as an address we control, so we can impersonate it
      fakeEmitter = (await ethers.getSigners())[10];
      await daoVsDao.setSponsorshipCertificateEmitter(fakeEmitter.address);
    });

    it("will throw if caller isn't emitter contract", async () => {
      await expect(
        daoVsDao.connect(user1).redeemSponsorshipShares(user1.address, user2.address, 1000)
      ).to.be.revertedWith("Only emitter can revoke sponsor");
    });

    it("will throw if trying re redeem 0 shares", async () => {
      await expect(
        daoVsDao.connect(fakeEmitter).redeemSponsorshipShares(user1.address, user2.address, 0)
      ).to.be.revertedWith("Cannot reimburse 0 shares");
    });

    it("will successfully redeem some shares and end the sponsorship", async () => {
      // redeem sponsorship certificate
      const amount = parseEther("0.2");
      await daoVsDao
        .connect(fakeEmitter)
        .redeemSponsorshipShares(user2.address, user3.address, amount);

      // verify balance of sponsor
      const user2Data = await daoVsDao.getPlayerData(user2.address);
      expect(user2Data.balance).to.equal(parseEther("0.2")); // balance has increased

      // verify balance of sponsored
      const user3Data = await daoVsDao.getPlayerData(user3.address);
      const user3Shares = await daoVsDao.sponsorshipShares(user3.address);
      expect(user3Data.sponsorships).to.equal(parseEther("0")); // sponsorship balance has decreased
      expect(user3Shares).to.equal(parseEther("0")); // shares are back to 0
    });

    it("will allow anyone to redeem the certificate (as long as they own the NFT)", async () => {
      // redeem sponsorship certificate
      // even though the sponsorship started from user2, user1 can redeem it if they
      // bought the certificate from them
      const amount = parseEther("0.2");
      await daoVsDao
        .connect(fakeEmitter)
        .redeemSponsorshipShares(user1.address, user3.address, amount);

      // verify balance of sponsor
      const user1Data = await daoVsDao.getPlayerData(user1.address);
      expect(user1Data.balance).to.equal(parseEther("0.2")); // balance has increased
    });

    it("will successfully calculate the shares", async () => {
      // partially redeem sponsorship certificate
      await daoVsDao
        .connect(fakeEmitter)
        .redeemSponsorshipShares(user2.address, user3.address, parseEther("0.05"));

      // verify balances
      let user2Data = await daoVsDao.getPlayerData(user2.address);
      expect(user2Data.balance).to.equal(parseEther("0.05")); // balance has increased
      let user3Shares = await daoVsDao.sponsorshipShares(user3.address);
      expect(user3Shares).to.equal(parseEther("0.15")); // shares are updated

      // partially redeem sponsorship certificate
      await daoVsDao
        .connect(fakeEmitter)
        .redeemSponsorshipShares(user2.address, user3.address, parseEther("0.15"));

      // verify balances
      user2Data = await daoVsDao.getPlayerData(user2.address);
      expect(user2Data.balance).to.equal(parseEther("0.2")); // balance has increased
      user3Shares = await daoVsDao.sponsorshipShares(user3.address);
      expect(user3Shares).to.equal(parseEther("0")); // shares are updated
    });
  });

  describe("swap with active sponsorship", function () {
    this.beforeEach(async () => {
      // add a realm and three users in it
      await daoVsDao.addRealm();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user2)
        .placeUser({ realm: 0, row: 1, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user3)
        .placeUser({ realm: 0, row: 1, column: 1 }, zeroAddress, { value: parseEther("0.5") });

      // add some funds
      await daoVsDao.transfer(user1.address, parseEther("0.25"));
      await daoVsDao.transfer(user2.address, parseEther("0.50"));
      await daoVsDao.transfer(user3.address, parseEther("0.25"));
    });

    it("will slash the attacked user on swap and add funds to the sponsorship pool", async () => {
      // sponsor a user (user3 sponsoring fully user2, so it has 0.75 total worth)
      const amount = parseEther("0.25");
      await daoVsDao.connect(user3).sponsor(user2.address, amount);

      // swap and trigger slash
      const user1Coordinates = { realm: 0, row: 0, column: 0 };
      const tx = await daoVsDao.connect(user2).swap(user1Coordinates);
      const receipt = await tx.wait();

      // all the slashing info is in the emitted event
      const slashing = getEventOfType(receipt, "Slashed");
      expect(slashing.args.subtractedFromAttackedBalance.toString()).equals("50000355149670218");
      expect(slashing.args.subtractedFromAttackedSponsorships.toString()).equals("0");
      expect(slashing.args.slashingTaxes.toString()).equals("5000035514967021");
      expect(slashing.args.addedToAttackerBalance.toString()).equals("29700210958904110");
      expect(slashing.args.addedToAttackerSponsorships.toString()).equals("15300108675799086");

      // no tokens were lost on the way
      const distributed = slashing.args.slashingTaxes
        .add(slashing.args.addedToAttackerBalance)
        .add(slashing.args.addedToAttackerSponsorships);
      const delta = slashing.args.subtractedFromAttackedBalance.sub(distributed);
      expect(delta.toNumber()).to.be.lessThanOrEqual(2); // possible rounding error

      // verify balances (also to owner to check the tax has been paid)
      const user1Data = await daoVsDao.getPlayerData(user1.address);
      const user2Data = await daoVsDao.getPlayerData(user2.address);
      expect(user1Data.balance.toString()).to.equal("200001420598680872");
      expect(user2Data.balance.toString()).to.equal("529700971993911720");
      expect((await daoVsDao.balanceOf(owner.address)).toString()).to.equal("5000035514967021");
    });
  });

  describe("Cost control (see console)", function () {
    const avgGasPrice = 150;
    const WEIToETH = (n: BigNumber) =>
      n.mul(avgGasPrice).div(BigNumber.from(10).pow(13)).toNumber() / 100000;

    it("adding a row", async () => {
      // initialize
      await daoVsDao.addRealm();

      let initialBalance = await owner.getBalance();
      await daoVsDao.addRow(0);
      let spentAmount = initialBalance.sub(await owner.getBalance());
      console.log(`ROW1: Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`);

      initialBalance = await owner.getBalance();
      await daoVsDao.addRow(0);
      spentAmount = initialBalance.sub(await owner.getBalance());
      console.log(`ROW2: Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`);

      initialBalance = await owner.getBalance();
      await daoVsDao.addRow(0);
      spentAmount = initialBalance.sub(await owner.getBalance());
      console.log(`ROW3: Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`);

      await daoVsDao.addRow(0);
      await daoVsDao.addRow(0);
      await daoVsDao.addRow(0);
      await daoVsDao.addRow(0);

      initialBalance = await owner.getBalance();
      await daoVsDao.addRow(0);
      spentAmount = initialBalance.sub(await owner.getBalance());
      console.log(`ROW8: Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`);

      await daoVsDao.addRow(0);
      await daoVsDao.addRow(0);
      await daoVsDao.addRow(0);
      await daoVsDao.addRow(0);
      await daoVsDao.addRow(0);
      await daoVsDao.addRow(0);

      initialBalance = await owner.getBalance();
      await daoVsDao.addRow(0);
      spentAmount = initialBalance.sub(await owner.getBalance());
      console.log(`ROW15: Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`);
    });

    it("placing a user", async () => {
      // initialize
      await daoVsDao.addRealm();

      let initialBalance = await user1.getBalance();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      let spentAmount = initialBalance.sub(await user1.getBalance());
      console.log(`User1: Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`);

      initialBalance = await user2.getBalance();
      await daoVsDao
        .connect(user2)
        .placeUser({ realm: 0, row: 1, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      spentAmount = initialBalance.sub(await user2.getBalance());
      console.log(`User2: Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`);

      initialBalance = await user3.getBalance();
      await daoVsDao
        .connect(user3)
        .placeUser({ realm: 0, row: 1, column: 1 }, zeroAddress, { value: parseEther("0.5") });
      spentAmount = initialBalance.sub(await user3.getBalance());
      console.log(`User3: Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`);

      initialBalance = await mrNobody.getBalance();
      await daoVsDao
        .connect(mrNobody)
        .placeUser({ realm: 0, row: 2, column: 1 }, zeroAddress, { value: parseEther("0.5") });
      spentAmount = initialBalance.sub(await mrNobody.getBalance());
      console.log(`User4: Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`);
    });

    it("swap with an empty cell", async () => {
      // initialize
      await daoVsDao.addRealm();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user2)
        .placeUser({ realm: 0, row: 1, column: 0 }, zeroAddress, { value: parseEther("0.5") });

      const initialBalance = await user2.getBalance();

      const emptyCoordinates = { realm: 0, row: 1, column: 1 };
      await daoVsDao.connect(user2).swap(emptyCoordinates);

      const spentAmount = initialBalance.sub(await user2.getBalance());
      console.log(
        `Swapping (empty): Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`
      );
    });

    it("swap with a non-empty cell", async () => {
      // initialize
      await daoVsDao.addRealm();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user2)
        .placeUser({ realm: 0, row: 1, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao.transfer(user1.address, parseEther("0.25"));
      await daoVsDao.transfer(user2.address, parseEther("0.50"));

      const initialBalance = await user2.getBalance();

      const user1Coordinates = { realm: 0, row: 0, column: 0 };
      await daoVsDao.connect(user2).swap(user1Coordinates);

      const spentAmount = initialBalance.sub(await user2.getBalance());
      console.log(
        `Swapping (non-empty): Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`
      );
    });

    it("sponsor", async () => {
      // initialize
      await daoVsDao.addRealm();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user2)
        .placeUser({ realm: 0, row: 1, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao.transfer(user1.address, parseEther("0.25"));
      await daoVsDao.transfer(user2.address, parseEther("0.50"));

      const initialBalance = await user2.getBalance();

      const amount = parseEther("0.2");
      await daoVsDao.connect(user2).sponsor(user1.address, amount);

      const spentAmount = initialBalance.sub(await user2.getBalance());
      console.log(`Sponsoring: Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`);
    });

    it("redeem sponsorship", async () => {
      // initialize
      await daoVsDao.addRealm();
      await daoVsDao
        .connect(user1)
        .placeUser({ realm: 0, row: 0, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao
        .connect(user2)
        .placeUser({ realm: 0, row: 1, column: 0 }, zeroAddress, { value: parseEther("0.5") });
      await daoVsDao.transfer(user1.address, parseEther("0.25"));
      await daoVsDao.transfer(user2.address, parseEther("0.50"));
      const amount = parseEther("0.2");
      await daoVsDao.connect(user2).sponsor(user1.address, amount);
      const fakeEmitter = (await ethers.getSigners())[10];
      await daoVsDao.setSponsorshipCertificateEmitter(fakeEmitter.address);

      const initialBalance = await fakeEmitter.getBalance();

      await daoVsDao
        .connect(fakeEmitter)
        .redeemSponsorshipShares(user2.address, user1.address, amount);

      const spentAmount = initialBalance.sub(await fakeEmitter.getBalance());
      console.log(
        `Redeem sponsorship: Spent ${WEIToETH(spentAmount)} MATIC (gas price: ${avgGasPrice})`
      );
    });
  });
});
