const { constants } = require("ethers");
const { deployments } = require("hardhat");
const { solidity } = require("ethereum-waffle");

const chai = require("chai");
chai.use(solidity);
const { expect } = chai;

const { ZERO_ADDRESS } = require("../testUtils");

describe("DataStore", async () => {
  let testContract;
  let user1;

  const setupTest = deployments.createFixture(async (hre) => {
    ({ ethers, web3, Web3 } = hre);
    const { get } = deployments;
    const signers = await ethers.getSigners();
    user1 = signers[1];

    await deployments.fixture(); // ensure you start from a fresh deployments
    const DataStoreUtilsTest = await ethers.getContractFactory(
      "DataStoreUtilsTest",
      {
        libraries: {
          DataStoreUtils: (await get("DataStoreUtils")).address,
        },
      }
    );
    testContract = await DataStoreUtilsTest.deploy();
  });

  beforeEach(async () => {
    await setupTest();
  });

  describe("ZERO", () => {
    describe("Returns UINT(0):", async () => {
      it("on empty ID", async () => {
        response = await testContract.readUintForId(
          0,
          ethers.utils.formatBytes32String("RANDOM")
        );
        expect(response).to.eq(0);
      });
      it("on empty key", async () => {
        response = await testContract.readUintForId(
          85196543,
          ethers.utils.formatBytes32String("")
        );
        expect(response).to.eq(0);
      });
    });

    describe("Returns BYTES(0)", async () => {
      it("on empty ID", async () => {
        response = await testContract.readBytesForId(
          0,
          ethers.utils.formatBytes32String("RANDOM")
        );
        expect(response).to.eq("0x");
      });
      it("on empty key", async () => {
        response = await testContract.readBytesForId(
          85196543,
          ethers.utils.formatBytes32String("")
        );
        expect(response).to.eq("0x");
      });
    });

    describe("Returns ADDRESS(0)", async () => {
      it("on empty ID", async () => {
        response = await testContract.readAddressForId(
          0,
          ethers.utils.formatBytes32String("RANDOM")
        );
        expect(response).to.eq(ZERO_ADDRESS);
      });
      it("on empty key", async () => {
        response = await testContract.readAddressForId(
          85196543,
          ethers.utils.formatBytes32String("")
        );
        expect(response).to.eq(ZERO_ADDRESS);
      });
    });
  });

  describe("Write -> Read", () => {
    randomId = 52531125332432;
    randomKey = ethers.utils.formatBytes32String("gsdgsdgfsdfd420gsa");
    describe("UINT", async () => {
      describe("returns inputted values when:", async () => {
        it("0,''", async () => {
          await testContract
            .connect(user1)
            .writeUintForId(0, ethers.utils.formatBytes32String(""), 0);
          response = await testContract.readUintForId(
            0,
            ethers.utils.formatBytes32String("")
          );
          expect(response).to.eq(0);

          await testContract
            .connect(user1)
            .writeUintForId(0, ethers.utils.formatBytes32String(""), 69);
          response = await testContract.readUintForId(
            0,
            ethers.utils.formatBytes32String("")
          );
          expect(response).to.eq(69);

          await testContract
            .connect(user1)
            .writeUintForId(
              0,
              ethers.utils.formatBytes32String(""),
              MAX_UINT256
            );
          response = await testContract.readUintForId(
            0,
            ethers.utils.formatBytes32String("")
          );
          expect(response).to.eq(MAX_UINT256);
        });
        it("random,random,", async () => {
          randomdata = 69;
          await testContract
            .connect(user1)
            .writeUintForId(randomId, randomKey, 0);
          response = await testContract.readUintForId(randomId, randomKey);
          expect(response).to.eq(0);

          await testContract
            .connect(user1)
            .writeUintForId(randomId, randomKey, randomdata);
          response = await testContract.readUintForId(randomId, randomKey);
          expect(response).to.eq(randomdata);

          await testContract
            .connect(user1)
            .writeUintForId(randomId, randomKey, MAX_UINT256);
          response = await testContract.readUintForId(randomId, randomKey);
          expect(response).to.eq(MAX_UINT256);
        });
      });
    });

    describe("BYTES", async () => {
      describe("returns inputted values when:", async () => {
        it("0,''", async () => {
          await testContract
            .connect(user1)
            .writeBytesForId(
              0,
              ethers.utils.formatBytes32String(""),
              constants.HashZero
            );
          response = await testContract.readBytesForId(
            0,
            ethers.utils.formatBytes32String("")
          );
          expect(response).to.eq(constants.HashZero);
          for (let i = 1; i < 11; i++) {
            await testContract
              .connect(user1)
              .writeBytesForId(
                0,
                ethers.utils.formatBytes32String(""),
                Web3.utils.asciiToHex(`${i}`)
              );
            response = await testContract.readBytesForId(
              0,
              ethers.utils.formatBytes32String("")
            );
            expect(response).to.eq(Web3.utils.asciiToHex(`${i}`));
          }
        });
        it("random,random,", async () => {
          randomId = 52531125332432;
          randomKey = ethers.utils.formatBytes32String("gsdgsdgfsdfd420gsa");
          randomdata = 6969696969696969;
          await testContract
            .connect(user1)
            .writeBytesForId(randomId, randomKey, constants.HashZero);
          response = await testContract.readBytesForId(randomId, randomKey);
          expect(response).to.eq(constants.HashZero);

          await testContract
            .connect(user1)
            .writeBytesForId(randomId, randomKey, Web3.utils.toHex(randomdata));
          response = await testContract.readBytesForId(randomId, randomKey);
          expect(response).to.eq(Web3.utils.toHex(randomdata));

          await testContract
            .connect(user1)
            .writeBytesForId(
              randomId,
              randomKey,
              Web3.utils.toHex(MAX_UINT256)
            );
          response = await testContract.readBytesForId(randomId, randomKey);
          expect(response).to.eq(Web3.utils.toHex(MAX_UINT256));
        });
      });
    });

    describe("ADDRESS", async () => {
      describe("returns inputted values when:", async () => {
        it("0,''", async () => {
          await testContract
            .connect(user1)
            .writeAddressForId(
              0,
              ethers.utils.formatBytes32String(""),
              ZERO_ADDRESS
            );
          response = await testContract.readAddressForId(
            0,
            ethers.utils.formatBytes32String("")
          );
          expect(response).to.eq(ZERO_ADDRESS);
          for (let i = 1; i < 11; i++) {
            address = web3.eth.accounts.create().address;
            await testContract
              .connect(user1)
              .writeAddressForId(
                0,
                ethers.utils.formatBytes32String(""),
                address
              );
            response = await testContract.readAddressForId(
              0,
              ethers.utils.formatBytes32String("")
            );
            expect(Web3.utils.toChecksumAddress(response)).to.eq(address);
          }
        });
        it("random,random,", async () => {
          randomId = 52531125332432;
          randomKey = ethers.utils.formatBytes32String("gsdgsdgfsdfd420gsa");
          randomAddress = web3.eth.accounts.create().address;
          await testContract
            .connect(user1)
            .writeAddressForId(randomId, randomKey, ZERO_ADDRESS);
          response = await testContract.readAddressForId(randomId, randomKey);
          expect(response).to.eq(ZERO_ADDRESS);

          await testContract
            .connect(user1)
            .writeAddressForId(randomId, randomKey, randomAddress);
          response = await testContract.readAddressForId(randomId, randomKey);
          expect(response).to.eq(randomAddress);
        });
      });
    });
  });
});
