const chai = require("chai");
const { expect } = chai;
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { ZERO_ADDRESS, expectCustomError, expectEvent } = require("../../utils/helpers");

/**
 * TODO:  Could not Solve how to handle this tbh...
 * const { shouldBehaveLikeERC1155 } = require("../../utils/ERC1155.behavior");
 */

contract("ERC1155", function (accounts) {
  const initialURI = "https://token-cdn-domain/{id}.json";
  const fixture = async () => {
    const [
      operator,
      tokenHolder,
      tokenBatchHolder,
      minter,
      firstTokenHolder,
      secondTokenHolder,
      multiTokenHolder,
      recipient,
      proxy,
    ] = await ethers.getSigners();

    const token = await ethers.deployContract("$ERC1155", [initialURI], {
      from: operator,
    });

    return {
      operator,
      tokenHolder,
      tokenBatchHolder,
      minter,
      firstTokenHolder,
      secondTokenHolder,
      multiTokenHolder,
      recipient,
      proxy,
      token,
    };
  };

  beforeEach(async function () {
    Object.assign(this, await loadFixture(fixture));
  });

  describe("internal functions", function () {
    const tokenId = BigInt(1990);
    const mintValue = BigInt(9001);
    const burnValue = BigInt(3000);

    const tokenBatchIds = [BigInt(2000), BigInt(2010), BigInt(2020)];
    const mintValues = [BigInt(5000), BigInt(10000), BigInt(42195)];
    const burnValues = [BigInt(5000), BigInt(9001), BigInt(195)];

    const data = "0x12345678";

    describe("_mint", function () {
      it("reverts with a zero destination address", async function () {
        await expectCustomError(
          this.token.$_mint(ZERO_ADDRESS, tokenId, mintValue, data),
          this.token,
          "ERC1155InvalidReceiver",
          [ZERO_ADDRESS]
        );
      });

      context("with minted tokens", function () {
        beforeEach(async function () {
          this.tx = await this.token.$_mint(this.tokenHolder, tokenId, mintValue, data, {
            from: this.operator,
          });
        });

        it("emits a TransferSingle event", async function () {
          await expectEvent(this.tx, this.token, "TransferSingle");
        });

        it("credits the minted token value", async function () {
          expect(await this.token.balanceOf(this.tokenHolder, tokenId)).to.equal(mintValue);
        });
      });
    });

    describe("_mintBatch", function () {
      it("reverts with a zero destination address", async function () {
        await expectCustomError(
          this.token.$_mintBatch(ZERO_ADDRESS, tokenBatchIds, mintValues, data),
          this.token,
          "ERC1155InvalidReceiver",
          [ZERO_ADDRESS]
        );
      });

      it("reverts if length of inputs do not match", async function () {
        await expectCustomError(
          this.token.$_mintBatch(this.tokenBatchHolder, tokenBatchIds, mintValues.slice(1), data),
          this.token,
          "ERC1155InvalidArrayLength",
          [tokenBatchIds.length, mintValues.length - 1]
        );

        await expectCustomError(
          this.token.$_mintBatch(this.tokenBatchHolder, tokenBatchIds.slice(1), mintValues, data),
          this.token,
          "ERC1155InvalidArrayLength",
          [tokenBatchIds.length - 1, mintValues.length]
        );
      });

      context("with minted batch of tokens", function () {
        beforeEach(async function () {
          this.receipt = await this.token.$_mintBatch(
            this.tokenBatchHolder,
            tokenBatchIds,
            mintValues,
            data,
            {
              from: this.operator,
            }
          );
        });

        it("emits a TransferBatch event", async function () {
          await expectEvent(this.receipt, this.token, "TransferBatch", [
            this.operator.address,
            ZERO_ADDRESS,
            this.tokenBatchHolder.address,
            tokenBatchIds,
            mintValues,
          ]);
        });

        it("credits the minted batch of tokens", async function () {
          const holderBatchBalances = await this.token.balanceOfBatch(
            new Array(tokenBatchIds.length).fill(this.tokenBatchHolder),
            tokenBatchIds
          );

          for (let i = 0; i < holderBatchBalances.length; i++) {
            expect(holderBatchBalances[i]).to.equal(mintValues[i]);
          }
        });
      });
    });

    describe("_burn", function () {
      it("reverts when burning the zero account's tokens", async function () {
        await expectCustomError(
          this.token.$_burn(ZERO_ADDRESS, tokenId, mintValue),
          this.token,
          "ERC1155InvalidSender",
          [ZERO_ADDRESS]
        );
      });

      it("reverts when burning a non-existent token id", async function () {
        await expectCustomError(
          this.token.$_burn(this.tokenHolder, tokenId, mintValue),
          this.token,
          "ERC1155InsufficientBalance",
          [this.tokenHolder, 0, mintValue, tokenId]
        );
      });

      it("reverts when burning more than available tokens", async function () {
        await this.token.$_mint(this.tokenHolder, tokenId, mintValue, data, {
          from: this.operator,
        });

        await expectCustomError(
          this.token.$_burn(this.tokenHolder, tokenId, mintValue + 1n),
          this.token,
          "ERC1155InsufficientBalance",
          [this.tokenHolder, mintValue, mintValue + 1n, tokenId]
        );
      });

      context("with minted-then-burnt tokens", function () {
        beforeEach(async function () {
          await this.token.$_mint(this.tokenHolder, tokenId, mintValue, data);
          this.receipt = await this.token.$_burn(this.tokenHolder, tokenId, burnValue, {
            from: this.operator,
          });
        });

        it("emits a TransferSingle event", async function () {
          await expectEvent(this.receipt, this.token, "TransferSingle", [
            this.operator.address,
            this.tokenHolder.address,
            ZERO_ADDRESS,
            tokenId,
            burnValue,
          ]);
        });

        it("accounts for both minting and burning", async function () {
          expect(await this.token.balanceOf(this.tokenHolder, tokenId)).to.equal(
            mintValue - burnValue
          );
        });
      });
    });

    describe("_burnBatch", function () {
      it("reverts when burning the zero account's tokens", async function () {
        await expectCustomError(
          this.token.$_burnBatch(ZERO_ADDRESS, tokenBatchIds, burnValues),
          this.token,
          "ERC1155InvalidSender",
          [ZERO_ADDRESS]
        );
      });

      it("reverts if length of inputs do not match", async function () {
        await expectCustomError(
          this.token.$_burnBatch(this.tokenBatchHolder, tokenBatchIds, burnValues.slice(1)),
          this.token,
          "ERC1155InvalidArrayLength",
          [tokenBatchIds.length, burnValues.length - 1]
        );

        await expectCustomError(
          this.token.$_burnBatch(this.tokenBatchHolder, tokenBatchIds.slice(1), burnValues),
          this.token,
          "ERC1155InvalidArrayLength",
          [tokenBatchIds.length - 1, burnValues.length]
        );
      });

      it("reverts when burning a non-existent token id", async function () {
        await expectCustomError(
          this.token.$_burnBatch(this.tokenBatchHolder, tokenBatchIds, burnValues),
          this.token,
          "ERC1155InsufficientBalance",
          [this.tokenBatchHolder, 0, tokenBatchIds[0], burnValues[0]]
        );
      });

      context("with minted-then-burnt tokens", function () {
        beforeEach(async function () {
          await this.token.$_mintBatch(this.tokenBatchHolder, tokenBatchIds, mintValues, data);
          this.receipt = await this.token.$_burnBatch(
            this.tokenBatchHolder,
            tokenBatchIds,
            burnValues,
            {
              from: this.operator,
            }
          );
        });

        it("emits a TransferBatch event", async function () {
          await expectEvent(this.receipt, this.token, "TransferBatch", [
            this.operator.address,
            this.tokenBatchHolder.address,
            ZERO_ADDRESS,
            tokenBatchIds,
            burnValues,
          ]);
        });

        it("accounts for both minting and burning", async function () {
          const holderBatchBalances = await this.token.balanceOfBatch(
            new Array(tokenBatchIds.length).fill(this.tokenBatchHolder),
            tokenBatchIds
          );

          for (let i = 0; i < holderBatchBalances.length; i++) {
            expect(holderBatchBalances[i]).to.equal(mintValues[i] - burnValues[i]);
          }
        });
      });
    });
  });

  describe("ERC1155MetadataURI", function () {
    const firstTokenID = BigInt("42");
    const secondTokenID = BigInt("1337");

    // it("emits no URI event in constructor", async function () {
    //   await  expectEvent.notEmitted.inConstruction(this.token, "URI");
    // });

    it("sets the initial URI for all token types", async function () {
      expect(await this.token.uri(firstTokenID)).to.be.equal(initialURI);
      expect(await this.token.uri(secondTokenID)).to.be.equal(initialURI);
    });

    describe("_setURI", function () {
      const newURI = "https://token-cdn-domain/{locale}/{id}.json";

      // it("emits no URI event", async function () {
      //   const receipt = await this.token.$_setURI(newURI);

      //   await expectEvent.notEmitted(receipt, "URI");
      // });

      it("sets the new URI for all token types", async function () {
        await this.token.$_setURI(newURI);

        expect(await this.token.uri(firstTokenID)).to.be.equal(newURI);
        expect(await this.token.uri(secondTokenID)).to.be.equal(newURI);
      });
    });
  });
});
