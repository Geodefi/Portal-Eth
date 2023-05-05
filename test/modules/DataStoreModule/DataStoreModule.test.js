const { expect } = require("chai");
const { expectRevert, constants, BN } = require("@openzeppelin/test-helpers");

const { strToBytes, strToBytes32, generateAddress } = require("../../utils");
const { ZERO_BYTES32, ZERO_ADDRESS, MAX_UINT256 } = constants;

const DataStoreModule = artifacts.require("$DataStoreModule");
const DataStoreModuleLib = artifacts.require("$DataStoreModuleLib");

contract("DataStoreModule", function (accounts) {
  const [deployer] = accounts;

  const randomInt = new BN("6942031517209");
  const randomStr = "random";
  const randomBytes = strToBytes(randomStr);
  const randomBytes32 = strToBytes32(randomStr);

  // a pointer for the "self" instance of the IsolatedStorage object
  // needed for hardhat-expose and its value does not matter.
  const self = new BN("123456");

  beforeEach(async function () {
    this.contract = await DataStoreModule.new({ from: deployer });
    this.library = await DataStoreModuleLib.new({ from: deployer });
  });

  context("contract", function () {
    describe("generateId", function () {
      describe("returns keccak(abi.encodePacked(bytes,uint256))", async function () {
        it("(0,0)", async function () {
          const id = await this.contract.generateId("", 0);
          const expId = web3.utils.soliditySha3(
            web3.utils.encodePacked({ value: "", type: "string" }, { value: 0, type: "uint256" })
          );
          await expect(id).to.be.bignumber.equal(expId);
        });
        it("(random,random)", async function () {
          const id = await this.contract.generateId(randomStr, randomInt);
          const expId = web3.utils.soliditySha3(
            web3.utils.encodePacked(
              { value: randomStr, type: "string" },
              { value: randomInt, type: "uint256" }
            )
          );
          await expect(id).to.be.bignumber.equal(expId);
        });
      });
      describe("same with library", async function () {
        it("(0,0)", async function () {
          const id = await this.contract.generateId("", 0);
          const expId = await this.library.$generateId("0x", 0);
          await expect(id).to.be.bignumber.equal(expId);
        });
        it("(random,random)", async function () {
          const id = await this.contract.generateId(randomStr, randomInt);
          const expId = await this.library.$generateId(randomBytes, randomInt);
          await expect(id).to.be.bignumber.equal(expId);
        });
      });
    });
  });

  context("library", function () {
    describe("getKey", function () {
      describe("returns keccak(abi.encodePacked(uint256,bytes32))", async function () {
        it("(0,0)", async function () {
          const key = await this.library.$getKey(0, "0x");
          const expKey = web3.utils.soliditySha3(
            web3.utils.encodePacked({ value: 0, type: "uint256" }, { value: "", type: "bytes32" })
          );
          await expect(key).to.be.bignumber.equal(expKey);
        });
        it("(random,random)", async function () {
          const key = await this.library.$getKey(randomInt, randomBytes32);
          const expKey = web3.utils.soliditySha3(
            web3.utils.encodePacked(
              { value: randomInt, type: "uint256" },
              { value: randomBytes32, type: "bytes32" }
            )
          );
          await expect(key).to.be.bignumber.equal(expKey);
        });
      });
    });

    context("data", function () {
      context("uint", function () {
        const values = [new BN(0), new BN(69), new BN(420), new BN(0)];

        describe("write", async function () {
          it("(0,0) : 0->69->420->0", async function () {
            for (let i = 0; i < values.length; i++) {
              await this.library.$writeUint(self, 0, ZERO_BYTES32, values[i]);
              expect(await this.library.$readUint(self, 0, ZERO_BYTES32)).to.be.bignumber.equal(
                values[i]
              );
            }
          });

          it("(random,random) : 0->69->420->0", async function () {
            for (let i = 0; i < values.length; i++) {
              await this.library.$writeUint(self, randomInt, randomBytes32, values[i]);
              expect(
                await this.library.$readUint(self, randomInt, randomBytes32)
              ).to.be.bignumber.equal(values[i]);
            }
          });
        });

        describe("add", async function () {
          it("(random,random) : 0; +0,+69,+420,+0 = 489", async function () {
            let sum = new BN(0);
            for (let i = 0; i < values.length; i++) {
              sum = sum.add(values[i]);
              await this.library.$addUint(self, randomInt, randomBytes32, values[i]);
              expect(
                await this.library.$readUint(self, randomInt, randomBytes32)
              ).to.be.bignumber.equal(sum);
            }
          });
          it("overflow: reverts", async function () {
            await this.library.$addUint(self, randomInt, randomBytes32, MAX_UINT256);
            await expectRevert(
              this.library.$addUint(self, randomInt, randomBytes32, 1),
              "VM Exception while processing transaction"
            );
          });
        });

        describe("sub", async function () {
          it("(random,random) : 489; -0,-69,-420,-0 = 0", async function () {
            let sum = new BN(489);
            await this.library.$addUint(self, randomInt, randomBytes32, sum);

            for (let i = 0; i < values.length; i++) {
              sum = sum.sub(values[i]);
              await this.library.$subUint(self, randomInt, randomBytes32, values[i]);
              expect(
                await this.library.$readUint(self, randomInt, randomBytes32)
              ).to.be.bignumber.equal(sum);
            }
          });
          it("underflow: reverts", async function () {
            await expectRevert(
              this.library.$subUint(self, randomInt, randomBytes32, 1),
              "VM Exception while processing transaction"
            );
          });
        });
      });

      context("bytes", function () {
        const values = [ZERO_BYTES32, randomBytes, ZERO_BYTES32, randomBytes32];
        describe("write", async function () {
          it("(0,0) : 0->random->0->random32", async function () {
            for (let i = 0; i < values.length; i++) {
              await this.library.$writeBytes(self, 0, ZERO_BYTES32, values[i]);
              expect(await this.library.$readBytes(self, 0, ZERO_BYTES32)).to.be.bignumber.equal(
                values[i]
              );
            }
          });

          it("(random,random) : 0->random->0->random32", async function () {
            for (let i = 0; i < values.length; i++) {
              await this.library.$writeBytes(self, randomInt, randomBytes32, values[i]);
              expect(
                await this.library.$readBytes(self, randomInt, randomBytes32)
              ).to.be.bignumber.equal(values[i]);
            }
          });
        });
      });

      context("address", function () {
        const values = [ZERO_ADDRESS, generateAddress(), ZERO_ADDRESS];
        describe("write", async function () {
          it("(0,0) : 0->random->0", async function () {
            for (let i = 0; i < values.length; i++) {
              await this.library.$writeAddress(self, 0, ZERO_BYTES32, values[i]);
              expect(await this.library.$readAddress(self, 0, ZERO_BYTES32)).to.be.bignumber.equal(
                values[i]
              );
            }
          });

          it("(random,random) :  0->random->0", async function () {
            for (let i = 0; i < values.length; i++) {
              await this.library.$writeAddress(self, randomInt, randomBytes32, values[i]);
              expect(
                await this.library.$readAddress(self, randomInt, randomBytes32)
              ).to.be.bignumber.equal(values[i]);
            }
          });
        });
      });
    });

    context("array", function () {
      it("uint", async function () {
        const values = [
          randomInt,
          randomInt.mul(new BN("3")),
          randomInt.mul(new BN("69")),
          randomInt.mul(new BN("420")),
        ];

        for (let i = 0; i < values.length; i++) {
          await this.library.$appendUintArray(self, randomInt, randomBytes32, values[i]);

          // check its length
          const len = await this.library.$readUint(self, randomInt, randomBytes32);
          expect(len).to.be.bignumber.equal(new BN(i + 1));

          // check the previous element' value
          if (i > 0) {
            expect(
              await this.library.$readUintArray(self, randomInt, randomBytes32, i - 1)
            ).to.be.bignumber.equal(values[i - 1]);
          }

          // check the current element' value
          expect(
            await this.library.$readUintArray(self, randomInt, randomBytes32, i)
          ).to.be.bignumber.equal(values[i]);

          // check the next element' value
          expect(
            await this.library.$readUintArray(self, randomInt, randomBytes32, i + 1)
          ).to.be.bignumber.equal(new BN("0"));
        }
      });

      it("address", async function () {
        const values = [generateAddress(), generateAddress(), generateAddress(), generateAddress()];

        for (let i = 0; i < values.length; i++) {
          await this.library.$appendAddressArray(self, randomInt, randomBytes32, values[i]);

          // check its length
          const len = await this.library.$readUint(self, randomInt, randomBytes32);
          expect(len).to.be.bignumber.equal(new BN(i + 1));

          // check the previous element' value
          if (i > 0) {
            expect(
              await this.library.$readAddressArray(self, randomInt, randomBytes32, i - 1)
            ).to.be.equal(values[i - 1]);
          }

          // check the current element' value
          expect(
            await this.library.$readAddressArray(self, randomInt, randomBytes32, i)
          ).to.be.equal(values[i]);

          // check the next element' value
          expect(
            await this.library.$readAddressArray(self, randomInt, randomBytes32, i + 1)
          ).to.be.equal(ZERO_ADDRESS);
        }
      });
      it("bytes", async function () {
        const values = [randomBytes, ZERO_BYTES32, randomBytes32, ZERO_BYTES32];

        for (let i = 0; i < values.length; i++) {
          await this.library.$appendBytesArray(self, randomInt, randomBytes32, values[i]);

          // check its length
          const len = await this.library.$readUint(self, randomInt, randomBytes32);
          expect(len).to.be.bignumber.equal(new BN(i + 1));

          // check the previous element' value
          if (i > 0) {
            expect(
              await this.library.$readBytesArray(self, randomInt, randomBytes32, i - 1)
            ).to.be.equal(values[i - 1]);
          }

          // check the current element' value
          expect(await this.library.$readBytesArray(self, randomInt, randomBytes32, i)).to.be.equal(
            values[i]
          );

          // check the next element' value
          expect(
            await this.library.$readBytesArray(self, randomInt, randomBytes32, i + 1)
          ).to.be.equal(null);
        }
      });
    });

    context("array-batch", function () {
      it("uint", async function () {
        const values = [
          [randomInt],
          [randomInt.mul(new BN("69")), randomInt.mul(new BN("420"))],
          [randomInt.mul(new BN("10")), randomInt.mul(new BN("3")), randomInt.mul(new BN("31"))],
        ];
        const valuesFlat = values.flat(1);

        prevLen = 0;
        nextLen = 0;
        for (let i = 0; i < values.length; i++) {
          await this.library.$appendUintArrayBatch(self, randomInt, randomBytes32, values[i]);

          // check lengths
          nextLen = prevLen + values[i].length;
          const len = await this.library.$readUint(self, randomInt, randomBytes32);
          expect(len).to.be.bignumber.equal(new BN(nextLen));

          // for every new element
          for (let k = prevLen; k < nextLen; k++) {
            // check the previous element' value
            if (k > 0) {
              expect(
                await this.library.$readUintArray(self, randomInt, randomBytes32, k - 1)
              ).to.be.bignumber.equal(valuesFlat[k - 1]);
            }

            // check the current element' value
            expect(
              await this.library.$readUintArray(self, randomInt, randomBytes32, k)
            ).to.be.bignumber.equal(valuesFlat[k]);

            // check the last element' value
            if (k === nextLen - 1) {
              expect(
                await this.library.$readUintArray(self, randomInt, randomBytes32, k + 1)
              ).to.be.bignumber.equal(new BN("0"));
            }

            prevLen = nextLen;
          }
        }
      });

      it("address", async function () {
        const values = [
          [generateAddress()],
          [generateAddress(), generateAddress()],
          [generateAddress(), generateAddress(), generateAddress()],
        ];
        const valuesFlat = values.flat(1);

        prevLen = 0;
        nextLen = 0;
        for (let i = 0; i < values.length; i++) {
          await this.library.$appendAddressArrayBatch(self, randomInt, randomBytes32, values[i]);

          // check lengths
          nextLen = prevLen + values[i].length;
          const len = await this.library.$readUint(self, randomInt, randomBytes32);
          expect(len).to.be.bignumber.equal(new BN(nextLen));

          // for every new element
          for (let k = prevLen; k < nextLen; k++) {
            // check the previous element' value
            if (k > 0) {
              expect(
                await this.library.$readAddressArray(self, randomInt, randomBytes32, k - 1)
              ).to.be.equal(valuesFlat[k - 1]);
            }

            // check the current element' value
            expect(
              await this.library.$readAddressArray(self, randomInt, randomBytes32, k)
            ).to.be.equal(valuesFlat[k]);

            // check the last element' value
            if (k === nextLen - 1) {
              expect(
                await this.library.$readAddressArray(self, randomInt, randomBytes32, k + 1)
              ).to.be.equal(ZERO_ADDRESS);
            }

            prevLen = nextLen;
          }
        }
      });
      it("bytes", async function () {
        const values = [
          [strToBytes(randomStr)],
          [strToBytes(randomStr + "r"), strToBytes(randomStr + "n")],
          [
            strToBytes(randomStr + "d"),
            strToBytes(randomStr + "m"),
            strToBytes(randomStr + randomStr),
          ],
        ];
        const valuesFlat = values.flat(1);

        prevLen = 0;
        nextLen = 0;
        for (let i = 0; i < values.length; i++) {
          await this.library.$appendBytesArrayBatch(self, randomInt, randomBytes32, values[i]);

          // check lengths
          nextLen = prevLen + values[i].length;
          const len = await this.library.$readUint(self, randomInt, randomBytes32);
          expect(len).to.be.bignumber.equal(new BN(nextLen));

          // for every new element
          for (let k = prevLen; k < nextLen; k++) {
            // check the previous element' value
            if (k > 0) {
              expect(
                await this.library.$readBytesArray(self, randomInt, randomBytes32, k - 1)
              ).to.be.equal(valuesFlat[k - 1]);
            }

            // check the current element' value
            expect(
              await this.library.$readBytesArray(self, randomInt, randomBytes32, k)
            ).to.be.equal(valuesFlat[k]);

            // check the last element' value
            if (k === nextLen - 1) {
              expect(
                await this.library.$readBytesArray(self, randomInt, randomBytes32, k + 1)
              ).to.be.equal(null);
            }

            prevLen = nextLen;
          }
        }
      });
    });
  });
});
