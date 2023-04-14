const { constants } = require("ethers");
const { deployments } = require("hardhat");
const { solidity } = require("ethereum-waffle");

const chai = require("chai");
chai.use(solidity);
const { expect } = chai;

const { MAX_UINT256, ZERO_ADDRESS } = require("../utils");

describe("DataStoreUtils", async () => {
  const emptyKey = ethers.utils.formatBytes32String("");
  const randomKey = ethers.utils.formatBytes32String("gsdgsdgfsdfd420gsa");
  const randomId = 85196543;
  const randomUint = 69;
  const randomBytes32 = 6969696969696969;
  const randomAddress = web3.eth.accounts.create().address;

  let testContract;
  let user1;

  const setupTest = deployments.createFixture(async (hre) => {
    ({ ethers, web3, Web3 } = hre);
    const signers = await ethers.getSigners();
    user1 = signers[1];

    await deployments.fixture();
    const DataStoreUtilsTest = await ethers.getContractFactory("TestDataStoreUtils");
    testContract = await DataStoreUtilsTest.deploy();
  });

  beforeEach(async () => {
    await setupTest();
  });

  describe("Initially", () => {
    describe("Returns UINT(0):", async () => {
      it("on empty ID", async () => {
        response = await testContract.readUint(0, randomKey);
        expect(response).to.eq(0);
      });
      it("on empty key", async () => {
        response = await testContract.readUint(randomId, emptyKey);
        expect(response).to.eq(0);
      });
    });

    describe("Returns BYTES(0)", async () => {
      it("on empty ID", async () => {
        response = await testContract.readBytes(0, randomKey);
        expect(response).to.eq("0x");
      });
      it("on empty key", async () => {
        response = await testContract.readBytes(randomId, emptyKey);
        expect(response).to.eq("0x");
      });
    });

    describe("Returns ADDRESS(0)", async () => {
      it("on empty ID", async () => {
        response = await testContract.readAddress(0, randomKey);
        expect(response).to.eq(ZERO_ADDRESS);
      });
      it("on empty key", async () => {
        response = await testContract.readAddress(randomId, emptyKey);
        expect(response).to.eq(ZERO_ADDRESS);
      });
    });
  });

  describe("generateId", () => {
    describe("returns keccak(abi.encodePacked())", async () => {
      it("empty", async () => {
        id = await testContract.generateId(emptyKey, 0);
        await expect(
          "78338746147236970124700731725183845421594913511827187288591969170390706184117"
        ).to.eq(id);
      });
      it("RANDOM", async () => {
        id = await testContract.generateId(randomKey, 4);
        await expect(
          "40061929241969488395957352914665827515181410255667031653971525362499870720754"
        ).to.eq(id);
      });
    });
  });

  describe("getKey", () => {
    describe("returns keccak(abi.encodePacked())", async () => {
      it("empty", async () => {
        id = await testContract.getKey(0, emptyKey);
        await expect("0xad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5").to.eq(
          id
        );
      });
      it("RANDOM", async () => {
        id = await testContract.getKey(4, randomKey);
        await expect("0x0a0ba7cd8743e92f5f05ba9d19002ed7550c60f84036fcd6dffa3cf57af9da06").to.eq(
          id
        );
      });
    });
  });

  describe("Write -> Read", () => {
    describe("UINT", async () => {
      describe("returns inputted values when:", async () => {
        it("0,''", async () => {
          await testContract.connect(user1).writeUint(0, emptyKey, 0);
          response = await testContract.readUint(0, emptyKey);
          expect(response).to.eq(0);

          await testContract.connect(user1).writeUint(0, emptyKey, 69);
          response = await testContract.readUint(0, emptyKey);
          expect(response).to.eq(69);

          await testContract.connect(user1).writeUint(0, emptyKey, MAX_UINT256);
          response = await testContract.readUint(0, emptyKey);
          expect(response).to.eq(MAX_UINT256);
        });
        it("random,random,", async () => {
          await testContract.connect(user1).writeUint(randomId, randomKey, 0);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(0);

          await testContract.connect(user1).writeUint(randomId, randomKey, randomUint);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(randomUint);

          await testContract.connect(user1).writeUint(randomId, randomKey, MAX_UINT256);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(MAX_UINT256);
        });
      });
      describe("returns correct results when:", async () => {
        it("0 -> ADD", async () => {
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(0);

          await testContract.connect(user1).addUint(randomId, randomKey, 0);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(0);

          await testContract.connect(user1).addUint(randomId, randomKey, randomUint);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(randomUint);

          await testContract.connect(user1).addUint(randomId, randomKey, randomUint * 3131);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(randomUint * 3132);
        });
        it("overflow: ADD reverts", async () => {
          await testContract.connect(user1).addUint(randomId, randomKey, 1);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(1);

          await expect(testContract.connect(user1).addUint(randomId, randomKey, MAX_UINT256)).to.be
            .reverted;
        });

        it("0->ADD->SUB->0", async () => {
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(0);

          await testContract.connect(user1).addUint(randomId, randomKey, 0);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(0);

          await testContract.connect(user1).addUint(randomId, randomKey, randomUint * 3131);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(randomUint * 3131);

          await testContract.connect(user1).subUint(randomId, randomKey, randomUint * 3111);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(randomUint * 20);
          await testContract.connect(user1).subUint(randomId, randomKey, randomUint * 20);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(0);
        });

        it("underflow: SUB reverts", async () => {
          await testContract.connect(user1).addUint(randomId, randomKey, randomUint);
          response = await testContract.readUint(randomId, randomKey);
          expect(response).to.eq(randomUint);

          await expect(testContract.connect(user1).subUint(randomId, randomKey, randomUint + 1)).to
            .be.reverted;
        });
      });
    });

    describe("BYTES", async () => {
      describe("returns inputted values when:", async () => {
        it("0,''", async () => {
          await testContract.connect(user1).writeBytes(0, emptyKey, constants.HashZero);
          response = await testContract.readBytes(0, emptyKey);
          expect(response).to.eq(constants.HashZero);
          for (let i = 1; i < 11; i++) {
            await testContract
              .connect(user1)
              .writeBytes(0, emptyKey, Web3.utils.asciiToHex(`${i}`));
            response = await testContract.readBytes(0, emptyKey);
            expect(response).to.eq(Web3.utils.asciiToHex(`${i}`));
          }
        });
        it("random,random,", async () => {
          await testContract.connect(user1).writeBytes(randomId, randomKey, constants.HashZero);
          response = await testContract.readBytes(randomId, randomKey);
          expect(response).to.eq(constants.HashZero);

          await testContract
            .connect(user1)
            .writeBytes(randomId, randomKey, Web3.utils.toHex(randomBytes32));
          response = await testContract.readBytes(randomId, randomKey);
          expect(response).to.eq(Web3.utils.toHex(randomBytes32));

          await testContract
            .connect(user1)
            .writeBytes(randomId, randomKey, Web3.utils.toHex(MAX_UINT256));
          response = await testContract.readBytes(randomId, randomKey);
          expect(response).to.eq(Web3.utils.toHex(MAX_UINT256));
        });
      });
    });

    describe("ADDRESS", async () => {
      describe("returns inputted values when:", async () => {
        it("0,''", async () => {
          await testContract.connect(user1).writeAddress(0, emptyKey, ZERO_ADDRESS);
          response = await testContract.readAddress(0, emptyKey);
          expect(response).to.eq(ZERO_ADDRESS);

          for (let i = 1; i < 11; i++) {
            address = web3.eth.accounts.create().address;
            await testContract.connect(user1).writeAddress(0, emptyKey, address);
            response = await testContract.readAddress(0, emptyKey);
            expect(Web3.utils.toChecksumAddress(response)).to.eq(address);
          }
        });

        it("random,random,", async () => {
          await testContract.connect(user1).writeAddress(randomId, randomKey, ZERO_ADDRESS);
          response = await testContract.readAddress(randomId, randomKey);
          expect(response).to.eq(ZERO_ADDRESS);

          await testContract.connect(user1).writeAddress(randomId, randomKey, randomAddress);
          response = await testContract.readAddress(randomId, randomKey);
          expect(response).to.eq(randomAddress);
        });
      });
    });

    it("UINT-ARRAY", async () => {
      await testContract.connect(user1).appendUintArray(randomId, randomKey, randomUint);

      response = await testContract.readUintArray(randomId, randomKey, 0);
      expect(response).to.eq(randomUint);
      response = await testContract.readUintArray(randomId, randomKey, 1);
      expect(response).to.eq(0);

      await testContract.connect(user1).appendUintArray(randomId, randomKey, randomUint - 69);

      response = await testContract.readUintArray(randomId, randomKey, 0);
      expect(response).to.eq(randomUint);
      response = await testContract.readUintArray(randomId, randomKey, 1);
      expect(response).to.eq(randomUint - 69);
      response = await testContract.readUintArray(randomId, randomKey, 2);
      expect(response).to.eq(0);
    });

    it("ADDRESS-ARRAY", async () => {
      await testContract.connect(user1).appendAddressArray(randomId, randomKey, randomAddress);

      response = await testContract.readAddressArray(randomId, randomKey, 0);
      expect(response).to.eq(randomAddress);
      response = await testContract.readAddressArray(randomId, randomKey, 1);
      expect(response).to.eq(ZERO_ADDRESS);

      const randomAddress2 = web3.eth.accounts.create().address;
      await testContract.connect(user1).appendAddressArray(randomId, randomKey, randomAddress2);

      response = await testContract.readAddressArray(randomId, randomKey, 0);
      expect(response).to.eq(randomAddress);
      response = await testContract.readAddressArray(randomId, randomKey, 1);
      expect(response).to.eq(randomAddress2);
      response = await testContract.readAddressArray(randomId, randomKey, 2);
      expect(response).to.eq(ZERO_ADDRESS);
    });

    it("BYTES-ARRAY", async () => {
      await testContract
        .connect(user1)
        .appendBytesArray(randomId, randomKey, Web3.utils.toHex(randomBytes32));

      response = await testContract.readBytesArray(randomId, randomKey, 0);
      expect(response).to.eq(Web3.utils.toHex(randomBytes32));
      response = await testContract.readBytesArray(randomId, randomKey, 1);
      expect(response).to.eq("0x");

      await testContract
        .connect(user1)
        .appendBytesArray(randomId, randomKey, Web3.utils.toHex(randomBytes32 - 69));

      response = await testContract.readBytesArray(randomId, randomKey, 0);
      expect(response).to.eq(Web3.utils.toHex(randomBytes32));
      response = await testContract.readBytesArray(randomId, randomKey, 1);
      expect(response).to.eq(Web3.utils.toHex(randomBytes32 - 69));
      response = await testContract.readBytesArray(randomId, randomKey, 2);
      expect(response).to.eq("0x");
    });

    it("UINT-ARRAY-BATCH", async () => {
      await testContract
        .connect(user1)
        .appendUintArrayBatch(randomId, randomKey, [randomUint, randomUint * 2, randomUint * 3]);

      response = await testContract.readUintArray(randomId, randomKey, 0);
      expect(response).to.eq(randomUint);
      response = await testContract.readUintArray(randomId, randomKey, 1);
      expect(response).to.eq(randomUint * 2);
      response = await testContract.readUintArray(randomId, randomKey, 2);
      expect(response).to.eq(randomUint * 3);

      response = await testContract.readUintArray(randomId, randomKey, 3);
      expect(response).to.eq(0);

      await testContract
        .connect(user1)
        .appendUintArrayBatch(randomId, randomKey, [randomUint - 42, (randomUint - 42) * 42]);

      await testContract
        .connect(user1)
        .appendUintArray(randomId, randomKey, (randomUint - 42) * 69);

      response = await testContract.readUintArray(randomId, randomKey, 0);
      expect(response).to.eq(randomUint);
      response = await testContract.readUintArray(randomId, randomKey, 1);
      expect(response).to.eq(randomUint * 2);
      response = await testContract.readUintArray(randomId, randomKey, 2);
      expect(response).to.eq(randomUint * 3);
      response = await testContract.readUintArray(randomId, randomKey, 3);
      expect(response).to.eq(randomUint - 42);
      response = await testContract.readUintArray(randomId, randomKey, 4);
      expect(response).to.eq((randomUint - 42) * 42);
      response = await testContract.readUintArray(randomId, randomKey, 5);
      expect(response).to.eq((randomUint - 42) * 69);
      response = await testContract.readUintArray(randomId, randomKey, 6);
      expect(response).to.eq(0);
    });

    it("ADDRESS-ARRAY", async () => {
      const randomAddress2 = web3.eth.accounts.create().address;
      const randomAddress3 = web3.eth.accounts.create().address;
      const randomAddress4 = web3.eth.accounts.create().address;
      const randomAddress5 = web3.eth.accounts.create().address;

      await testContract
        .connect(user1)
        .appendAddressArrayBatch(randomId, randomKey, [
          randomAddress,
          randomAddress2,
          randomAddress3,
        ]);

      response = await testContract.readAddressArray(randomId, randomKey, 0);
      expect(response).to.eq(randomAddress);
      response = await testContract.readAddressArray(randomId, randomKey, 1);
      expect(response).to.eq(randomAddress2);

      response = await testContract.readAddressArray(randomId, randomKey, 2);
      expect(response).to.eq(randomAddress3);

      response = await testContract.readAddressArray(randomId, randomKey, 3);
      expect(response).to.eq(ZERO_ADDRESS);

      await testContract.connect(user1).appendAddressArray(randomId, randomKey, randomAddress4);

      await testContract
        .connect(user1)
        .appendAddressArrayBatch(randomId, randomKey, [randomAddress5]);

      response = await testContract.readAddressArray(randomId, randomKey, 2);
      expect(response).to.eq(randomAddress3);
      response = await testContract.readAddressArray(randomId, randomKey, 3);
      expect(response).to.eq(randomAddress4);
      response = await testContract.readAddressArray(randomId, randomKey, 4);
      expect(response).to.eq(randomAddress5);
      response = await testContract.readAddressArray(randomId, randomKey, 5);
      expect(response).to.eq(ZERO_ADDRESS);
    });

    it("BYTES-ARRAY", async () => {
      await testContract
        .connect(user1)
        .appendBytesArrayBatch(randomId, randomKey, [
          Web3.utils.toHex(randomBytes32),
          Web3.utils.toHex(randomBytes32 - 69),
          Web3.utils.toHex(randomBytes32 + 69),
        ]);

      response = await testContract.readBytesArray(randomId, randomKey, 0);
      expect(response).to.eq(Web3.utils.toHex(randomBytes32));
      response = await testContract.readBytesArray(randomId, randomKey, 1);
      expect(response).to.eq(Web3.utils.toHex(randomBytes32 - 69));
      response = await testContract.readBytesArray(randomId, randomKey, 2);
      expect(response).to.eq(Web3.utils.toHex(randomBytes32 + 69));
      response = await testContract.readBytesArray(randomId, randomKey, 3);
      expect(response).to.eq("0x");

      await testContract
        .connect(user1)
        .appendBytesArray(randomId, randomKey, Web3.utils.toHex(randomBytes32 + 42));

      await testContract
        .connect(user1)
        .appendBytesArrayBatch(randomId, randomKey, [Web3.utils.toHex(randomBytes32 - 31)]);

      response = await testContract.readBytesArray(randomId, randomKey, 0);
      expect(response).to.eq(Web3.utils.toHex(randomBytes32));
      response = await testContract.readBytesArray(randomId, randomKey, 1);
      expect(response).to.eq(Web3.utils.toHex(randomBytes32 - 69));
      response = await testContract.readBytesArray(randomId, randomKey, 2);
      expect(response).to.eq(Web3.utils.toHex(randomBytes32 + 69));
      response = await testContract.readBytesArray(randomId, randomKey, 3);
      expect(response).to.eq(Web3.utils.toHex(randomBytes32 + 42));
      response = await testContract.readBytesArray(randomId, randomKey, 4);
      expect(response).to.eq(Web3.utils.toHex(randomBytes32 - 31));
      response = await testContract.readBytesArray(randomId, randomKey, 5);
      expect(response).to.eq("0x");
    });
  });
});
