const { BigNumber } = require("ethers");
const { ZERO_ADDRESS } = require("../testUtils");
const { solidity } = require("ethereum-waffle");
const { deployments } = require("hardhat");
const web3 = require("web3");

const chai = require("chai");
// const { shouldSupportInterfaces } = require("./SupportsInterface");

chai.use(solidity);
const { expect } = chai;
const initialURI = "https://token-cdn-domain/{id}.json";
let signers;
let minter;
let deployer;
let tokenHolder;
let firstTokenHolder;
let secondTokenHolder;
let multiTokenHolder;
let recipient;
let proxy;
let tokenContract;
let ERC1155ReceiverMock;
let ERC20Interface;

const firstTokenId = BigNumber.from(1);
const secondTokenId = BigNumber.from(2);
const unknownTokenId = BigNumber.from(6969696);

const firstAmount = BigNumber.from(1000);
const secondAmount = BigNumber.from(2000);

const DEFAULT_ADMIN_ROLE =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const MINTER_ROLE = web3.utils.soliditySha3("MINTER_ROLE");
const PAUSER_ROLE = web3.utils.soliditySha3("PAUSER_ROLE");
const ORACLE_ROLE = web3.utils.soliditySha3("ORACLE_ROLE");

describe("gETH ", async function () {
  const setupTest = deployments.createFixture(async function ({
    deployments,
    ethers,
  }) {
    await deployments.fixture(); // ensure you start from fresh deployments
    signers = await ethers.getSigners();
    deployer = minter = signers[0].address;
    tokenHolder = signers[1].address;
    firstTokenHolder = signers[2].address;
    secondTokenHolder = signers[3].address;
    multiTokenHolder = signers[4].address;
    recipient = signers[5].address;
    proxy = signers[6].address;
    const gETH = await ethers.getContractFactory("gETH");
    ERC1155ReceiverMock = await ethers.getContractFactory(
      "ERC1155ReceiverMock"
    );
    tokenContract = await gETH.deploy(initialURI);
    await tokenContract.updateMinterRole(deployer);
    await tokenContract.updateOracleRole(deployer);
    await tokenContract.updatePauserRole(deployer);
  });

  beforeEach(async function () {
    await setupTest();
  });

  describe("behaves like ERC1155", function () {
    const RECEIVER_SINGLE_MAGIC_VALUE = "0xf23a6e61";
    const RECEIVER_BATCH_MAGIC_VALUE = "0xbc197c81";

    describe("balanceOf", function () {
      it("reverts when queried about the zero address", async function () {
        await expect(
          tokenContract.balanceOf(ZERO_ADDRESS, firstTokenId)
        ).to.be.revertedWith("ERC1155: address zero is not a valid owner");
      });

      context("when accounts don't own tokens", function () {
        it("returns zero for given addresses", async function () {
          expect(
            await tokenContract.balanceOf(firstTokenHolder, firstTokenId)
          ).to.be.eq(BigNumber.from("0"));

          expect(
            await tokenContract.balanceOf(secondTokenHolder, secondTokenId)
          ).to.be.eq(BigNumber.from("0"));

          expect(
            await tokenContract.balanceOf(firstTokenHolder, unknownTokenId)
          ).to.be.eq(BigNumber.from("0"));
        });
      });

      context("when accounts own some tokens", function () {
        beforeEach(async function () {
          await tokenContract
            .connect(signers[0])
            .mint(firstTokenHolder, firstTokenId, firstAmount, "0x");
          await tokenContract
            .connect(signers[0])
            .mint(secondTokenHolder, secondTokenId, secondAmount, "0x");
        });

        it("returns the amount of tokens owned by the given addresses", async function () {
          expect(
            await tokenContract.balanceOf(firstTokenHolder, firstTokenId)
          ).to.be.eq(BigNumber.from(firstAmount));

          expect(
            await tokenContract.balanceOf(secondTokenHolder, secondTokenId)
          ).to.be.eq(BigNumber.from(secondAmount));

          expect(
            await tokenContract.balanceOf(firstTokenHolder, unknownTokenId)
          ).to.be.eq(BigNumber.from("0"));
        });
      });
    });

    describe("balanceOfBatch", function () {
      it("reverts when input arrays don't match up", async function () {
        await expect(
          tokenContract.balanceOfBatch(
            [
              firstTokenHolder,
              secondTokenHolder,
              firstTokenHolder,
              secondTokenHolder,
            ],
            [firstTokenId, secondTokenId, unknownTokenId]
          )
        ).to.be.revertedWith("ERC1155: accounts and ids length mismatch");

        await expect(
          tokenContract.balanceOfBatch(
            [firstTokenHolder, secondTokenHolder],
            [firstTokenId, secondTokenId, unknownTokenId]
          )
        ).to.be.revertedWith("ERC1155: accounts and ids length mismatch");
      });

      it("reverts when one of the addresses is the zero address", async function () {
        await expect(
          tokenContract.balanceOfBatch(
            [firstTokenHolder, secondTokenHolder, ZERO_ADDRESS],
            [firstTokenId, secondTokenId, unknownTokenId]
          )
        ).to.be.revertedWith("ERC1155: address zero is not a valid owner");
      });

      context("when accounts don't own tokens", function () {
        it("returns zeros for each account", async function () {
          const result = await tokenContract.balanceOfBatch(
            [firstTokenHolder, secondTokenHolder, firstTokenHolder],
            [firstTokenId, secondTokenId, unknownTokenId]
          );
          expect(result).to.be.an("array");
          expect(result[0]).to.be.eq(BigNumber.from("0"));
          expect(result[1]).to.be.eq(BigNumber.from("0"));
          expect(result[2]).to.be.eq(BigNumber.from("0"));
        });
      });

      context("when accounts own some tokens", function () {
        beforeEach(async function () {
          await tokenContract
            .connect(signers[0])
            .mint(firstTokenHolder, firstTokenId, firstAmount, "0x");
          await tokenContract
            .connect(signers[0])
            .mint(secondTokenHolder, secondTokenId, secondAmount, "0x");
        });

        it("returns amounts owned by each account in order passed", async function () {
          const result = await tokenContract.balanceOfBatch(
            [secondTokenHolder, firstTokenHolder, firstTokenHolder],
            [secondTokenId, firstTokenId, unknownTokenId]
          );
          expect(result).to.be.an("array");
          expect(result[0]).to.be.eq(BigNumber.from(secondAmount));
          expect(result[1]).to.be.eq(BigNumber.from(firstAmount));
          expect(result[2]).to.be.eq(BigNumber.from("0"));
        });

        it("returns multiple times the balance of the same address when asked", async function () {
          const result = await tokenContract.balanceOfBatch(
            [firstTokenHolder, secondTokenHolder, firstTokenHolder],
            [firstTokenId, secondTokenId, firstTokenId]
          );
          expect(result).to.be.an("array");
          expect(result[0]).to.be.eq(BigNumber.from(result[2]));
          expect(result[0]).to.be.eq(BigNumber.from(firstAmount));
          expect(result[1]).to.be.eq(BigNumber.from(secondAmount));
          expect(result[2]).to.be.eq(BigNumber.from(firstAmount));
        });
      });
    });

    describe("setApprovalForAll", function () {
      beforeEach(async function () {
        await tokenContract.connect(signers[4]).setApprovalForAll(proxy, true);
      });

      it("sets approval status which can be queried via isApprovedForAll", async function () {
        expect(
          await tokenContract.isApprovedForAll(multiTokenHolder, proxy)
        ).to.be.equal(true);
      });

      it("emits an ApprovalForAll log", function () {
        expect(
          tokenContract.connect(signers[4]).setApprovalForAll(proxy, true)
        ).to.emit("ApprovalForAll", {
          account: multiTokenHolder,
          operator: proxy,
          approved: true,
        });
      });

      it("can unset approval for an operator", async function () {
        await tokenContract.connect(signers[4]).setApprovalForAll(proxy, false);
        expect(
          await tokenContract.isApprovedForAll(multiTokenHolder, proxy)
        ).to.be.equal(false);
      });

      it("reverts if attempting to approve self as an operator", async function () {
        await expect(
          tokenContract
            .connect(signers[4])
            .setApprovalForAll(multiTokenHolder, true)
        ).to.be.revertedWith("ERC1155: setting approval status for self");
      });
    });

    describe("safeTransferFrom", function () {
      beforeEach(async function () {
        await tokenContract
          .connect(signers[0])
          .mint(multiTokenHolder, firstTokenId, firstAmount, "0x");
        await tokenContract.mint(
          multiTokenHolder,
          secondTokenId,
          secondAmount,
          "0x"
        );
      });

      it("reverts when transferring more than balance", async function () {
        await expect(
          tokenContract
            .connect(signers[4])
            .safeTransferFrom(
              multiTokenHolder,
              recipient,
              firstTokenId,
              firstAmount.add(1),
              "0x"
            )
        ).to.be.revertedWith("ERC1155: insufficient balance for transfer");
      });

      it("reverts when transferring to zero address", async function () {
        await expect(
          tokenContract
            .connect(signers[4])
            .safeTransferFrom(
              multiTokenHolder,
              ZERO_ADDRESS,
              firstTokenId,
              firstAmount,
              "0x"
            )
        ).to.be.revertedWith("ERC1155: transfer to the zero address");
      });

      function transferWasSuccessful(operator, from, id, value) {
        it("debits transferred balance from sender", async function () {
          const newBalance = await tokenContract.balanceOf(from, id);
          expect(newBalance).to.be.eq(BigNumber.from("0"));
        });

        it("credits transferred balance to receiver", async function () {
          const newBalance = await tokenContract.balanceOf(this.toWhom, id);
          expect(newBalance).to.be.eq(BigNumber.from(value));
        });
      }

      context("when called by the multiTokenHolder", async function () {
        beforeEach(async function () {
          this.toWhom = recipient;
          ({ logs: this.transferLogs } = await tokenContract
            .connect(signers[4])
            .safeTransferFrom(
              multiTokenHolder,
              recipient,
              firstTokenId,
              firstAmount,
              "0x"
            ));
        });

        it("transferWasSuccessful", async function () {
          transferWasSuccessful(
            multiTokenHolder,
            multiTokenHolder,
            firstTokenId,
            firstAmount
          );
        });

        it("preserves existing balances which are not transferred by multiTokenHolder", async function () {
          const balance1 = await tokenContract.balanceOf(
            multiTokenHolder,
            secondTokenId
          );
          expect(balance1).to.be.eq(BigNumber.from(secondAmount));

          const balance2 = await tokenContract.balanceOf(
            recipient,
            secondTokenId
          );
          expect(balance2).to.be.eq(BigNumber.from("0"));
        });
      });

      context(
        "when called by an operator on behalf of the multiTokenHolder",
        function () {
          context(
            "when operator is not approved by multiTokenHolder",
            function () {
              beforeEach(async function () {
                await tokenContract
                  .connect(signers[4])
                  .setApprovalForAll(proxy, false);
              });

              it("reverts", async function () {
                await expect(
                  tokenContract
                    .connect(signers[6])
                    .safeTransferFrom(
                      multiTokenHolder,
                      recipient,
                      firstTokenId,
                      firstAmount,
                      "0x"
                    )
                ).to.be.revertedWith(
                  "ERC1155: caller is not owner nor approved nor an allowed interface"
                );
              });
            }
          );

          context("when operator is approved by multiTokenHolder", function () {
            beforeEach(async function () {
              this.toWhom = recipient;
              await tokenContract
                .connect(signers[4])
                .setApprovalForAll(proxy, true);
              ({ logs: this.transferLogs } = await tokenContract
                .connect(signers[6])
                .safeTransferFrom(
                  multiTokenHolder,
                  recipient,
                  firstTokenId,
                  firstAmount,
                  "0x"
                ));
            });

            it("transferWasSuccessful", async function () {
              transferWasSuccessful(
                proxy,
                multiTokenHolder,
                firstTokenId,
                firstAmount
              );
            });

            it("preserves operator's balances not involved in the transfer", async function () {
              const balance1 = await tokenContract.balanceOf(
                proxy,
                firstTokenId
              );
              expect(balance1).to.be.eq(BigNumber.from("0"));

              const balance2 = await tokenContract.balanceOf(
                proxy,
                secondTokenId
              );
              expect(balance2).to.be.eq(BigNumber.from("0"));
            });
          });
        }
      );

      context("when sending to a valid receiver", function () {
        beforeEach(async function () {
          this.receiver = await ERC1155ReceiverMock.deploy(
            RECEIVER_SINGLE_MAGIC_VALUE,
            false,
            RECEIVER_BATCH_MAGIC_VALUE,
            false
          );
        });

        context("without data", function () {
          beforeEach(async function () {
            this.toWhom = this.receiver.address;
            this.transferReceipt = await tokenContract
              .connect(signers[4])
              .safeTransferFrom(
                multiTokenHolder,
                this.receiver.address,
                firstTokenId,
                firstAmount,
                "0x"
              );
            ({ logs: this.transferLogs } = this.transferReceipt);
          });

          it("transferWasSuccessful", async function () {
            transferWasSuccessful(
              multiTokenHolder,
              multiTokenHolder,
              firstTokenId,
              firstAmount
            );
          });
        });

        context("with data", function () {
          const data = "0xf00dd00d";
          beforeEach(async function () {
            this.toWhom = this.receiver.address;
            this.transferReceipt = await tokenContract
              .connect(signers[4])
              .safeTransferFrom(
                multiTokenHolder,
                this.receiver.address,
                firstTokenId,
                firstAmount,
                data
              );
            ({ logs: this.transferLogs } = this.transferReceipt);
          });

          it("transferWasSuccessful", async function () {
            transferWasSuccessful(
              multiTokenHolder,
              multiTokenHolder,
              firstTokenId,
              firstAmount
            );
          });
        });
      });

      context("to a receiver contract returning unexpected value", function () {
        beforeEach(async function () {
          this.receiver = await ERC1155ReceiverMock.deploy(
            "0x00c0ffee",
            false,
            RECEIVER_BATCH_MAGIC_VALUE,
            false
          );
        });

        it("reverts", async function () {
          await expect(
            tokenContract
              .connect(signers[4])
              .safeTransferFrom(
                multiTokenHolder,
                this.receiver.address,
                firstTokenId,
                firstAmount,
                "0x"
              )
          ).to.be.revertedWith("ERC1155: ERC1155Receiver rejected tokens");
        });
      });

      context("to a receiver contract that reverts", function () {
        beforeEach(async function () {
          this.receiver = await ERC1155ReceiverMock.deploy(
            RECEIVER_SINGLE_MAGIC_VALUE,
            true,
            RECEIVER_BATCH_MAGIC_VALUE,
            false
          );
        });

        it("reverts", async function () {
          await expect(
            tokenContract
              .connect(signers[4])
              .safeTransferFrom(
                multiTokenHolder,
                this.receiver.address,
                firstTokenId,
                firstAmount,
                "0x"
              )
          ).to.be.revertedWith("ERC1155ReceiverMock: reverting on receive");
        });
      });

      context(
        "to a contract that does not implement the required function",
        function () {
          it("reverts", async function () {
            const invalidReceiver = tokenContract;
            await expect(
              tokenContract
                .connect(signers[4])
                .safeTransferFrom(
                  multiTokenHolder,
                  invalidReceiver.address,
                  firstTokenId,
                  firstAmount,
                  "0x"
                )
            ).to.be.reverted;
          });
        }
      );
    });

    describe("safeBatchTransferFrom", function () {
      beforeEach(async function () {
        await tokenContract
          .connect(signers[0])
          .mint(multiTokenHolder, firstTokenId, firstAmount, "0x");
        await tokenContract
          .connect(signers[0])
          .mint(multiTokenHolder, secondTokenId, secondAmount, "0x");
      });

      it("reverts when transferring amount more than any of balances", async function () {
        await expect(
          tokenContract
            .connect(signers[4])
            .safeBatchTransferFrom(
              multiTokenHolder,
              recipient,
              [firstTokenId, secondTokenId],
              [firstAmount, secondAmount.add(1)],
              "0x"
            )
        ).to.be.revertedWith("ERC1155: insufficient balance for transfer");
      });

      it("reverts when ids array length doesn't match amounts array length", async function () {
        await expect(
          tokenContract
            .connect(signers[4])
            .safeBatchTransferFrom(
              multiTokenHolder,
              recipient,
              [firstTokenId],
              [firstAmount, secondAmount],
              "0x"
            )
        ).to.be.revertedWith("ERC1155: ids and amounts length mismatch");

        await expect(
          tokenContract
            .connect(signers[4])
            .safeBatchTransferFrom(
              multiTokenHolder,
              recipient,
              [firstTokenId, secondTokenId],
              [firstAmount],
              "0x"
            )
        ).to.be.revertedWith("ERC1155: ids and amounts length mismatch");
      });

      it("reverts when transferring to zero address", async function () {
        await expect(
          tokenContract
            .connect(signers[4])
            .safeBatchTransferFrom(
              multiTokenHolder,
              ZERO_ADDRESS,
              [firstTokenId, secondTokenId],
              [firstAmount, secondAmount],
              "0x"
            )
        ).to.be.revertedWith("ERC1155: transfer to the zero address");
      });

      function batchTransferWasSuccessful({ operator, from, ids, values }) {
        it("debits transferred balances from sender", async function () {
          const newBalances = await tokenContract.balanceOfBatch(
            new Array(ids.length).fill(from),
            ids
          );
          for (const newBalance of newBalances) {
            expect(newBalance).to.be.eq(BigNumber.from("0"));
          }
        });

        it("credits transferred balances to receiver", async function () {
          const newBalances = await tokenContract.balanceOfBatch(
            new Array(ids.length).fill(this.toWhom),
            ids
          );
          for (let i = 0; i < newBalances.length; i++) {
            expect(newBalances[i]).to.be.eq(BigNumber.from(values[i]));
          }
        });
      }

      context("when called by the multiTokenHolder", async function () {
        beforeEach(async function () {
          this.toWhom = recipient;
          ({ logs: this.transferLogs } = await tokenContract
            .connect(signers[4])
            .safeBatchTransferFrom(
              multiTokenHolder,
              recipient,
              [firstTokenId, secondTokenId],
              [firstAmount, secondAmount],
              "0x"
            ));
        });
        it("batchTransferWasSuccessful", async function () {
          batchTransferWasSuccessful({
            operator: multiTokenHolder,
            from: multiTokenHolder,
            ids: [firstTokenId, secondTokenId],
            values: [firstAmount, secondAmount],
          });
        });
      });

      context(
        "when called by an operator on behalf of the multiTokenHolder",
        function () {
          context(
            "when operator is not approved by multiTokenHolder",
            function () {
              beforeEach(async function () {
                await tokenContract
                  .connect(signers[4])
                  .setApprovalForAll(proxy, false);
              });

              it("reverts", async function () {
                await expect(
                  tokenContract
                    .connect(signers[6])
                    .safeBatchTransferFrom(
                      multiTokenHolder,
                      recipient,
                      [firstTokenId, secondTokenId],
                      [firstAmount, secondAmount],
                      "0x"
                    )
                ).to.be.revertedWith(
                  "ERC1155: caller is not token owner nor approved"
                );
              });
            }
          );

          context("when operator is approved by multiTokenHolder", function () {
            beforeEach(async function () {
              this.toWhom = recipient;
              await tokenContract
                .connect(signers[4])
                .setApprovalForAll(proxy, true);
              ({ logs: this.transferLogs } = await tokenContract
                .connect(signers[6])
                .safeBatchTransferFrom(
                  multiTokenHolder,
                  recipient,
                  [firstTokenId, secondTokenId],
                  [firstAmount, secondAmount],
                  "0x"
                ));
            });

            it("batchTransferWasSuccessful", async function () {
              batchTransferWasSuccessful({
                operator: proxy,
                from: multiTokenHolder,
                ids: [firstTokenId, secondTokenId],
                values: [firstAmount, secondAmount],
              });
            });

            it("preserves operator's balances not involved in the transfer", async function () {
              const balance1 = await tokenContract.balanceOf(
                proxy,
                firstTokenId
              );
              expect(balance1).to.be.eq(BigNumber.from("0"));
              const balance2 = await tokenContract.balanceOf(
                proxy,
                secondTokenId
              );
              expect(balance2).to.be.eq(BigNumber.from("0"));
            });
          });
        }
      );

      context("when sending to a valid receiver", function () {
        beforeEach(async function () {
          this.receiver = await ERC1155ReceiverMock.deploy(
            RECEIVER_SINGLE_MAGIC_VALUE,
            false,
            RECEIVER_BATCH_MAGIC_VALUE,
            false
          );
        });

        context("without data", function () {
          beforeEach(async function () {
            this.toWhom = this.receiver.address;
            this.transferReceipt = await tokenContract
              .connect(signers[4])
              .safeBatchTransferFrom(
                multiTokenHolder,
                this.receiver.address,
                [firstTokenId, secondTokenId],
                [firstAmount, secondAmount],
                "0x"
              );
            ({ logs: this.transferLogs } = this.transferReceipt);
          });

          it("batchTransferWasSuccessful", async function () {
            batchTransferWasSuccessful({
              operator: multiTokenHolder,
              from: multiTokenHolder,
              ids: [firstTokenId, secondTokenId],
              values: [firstAmount, secondAmount],
            });
          });
        });

        context("with data", function () {
          const data = "0xf00dd00d";
          beforeEach(async function () {
            this.toWhom = this.receiver.address;
            this.transferReceipt = await tokenContract
              .connect(signers[4])
              .safeBatchTransferFrom(
                multiTokenHolder,
                this.receiver.address,
                [firstTokenId, secondTokenId],
                [firstAmount, secondAmount],
                data
              );
            ({ logs: this.transferLogs } = this.transferReceipt);
          });

          it("batchTransferWasSuccessful", async function () {
            batchTransferWasSuccessful({
              operator: multiTokenHolder,
              from: multiTokenHolder,
              ids: [firstTokenId, secondTokenId],
              values: [firstAmount, secondAmount],
            });
          });
        });
      });

      context("to a receiver contract returning unexpected value", function () {
        beforeEach(async function () {
          this.receiver = await ERC1155ReceiverMock.deploy(
            RECEIVER_SINGLE_MAGIC_VALUE,
            false,
            RECEIVER_SINGLE_MAGIC_VALUE,
            false
          );
        });

        it("reverts", async function () {
          await expect(
            tokenContract
              .connect(signers[4])
              .safeBatchTransferFrom(
                multiTokenHolder,
                this.receiver.address,
                [firstTokenId, secondTokenId],
                [firstAmount, secondAmount],
                "0x"
              )
          ).to.be.revertedWith("ERC1155: ERC1155Receiver rejected tokens");
        });
      });

      context("to a receiver contract that reverts", function () {
        beforeEach(async function () {
          this.receiver = await ERC1155ReceiverMock.deploy(
            RECEIVER_SINGLE_MAGIC_VALUE,
            false,
            RECEIVER_BATCH_MAGIC_VALUE,
            true
          );
        });

        it("reverts", async function () {
          await expect(
            tokenContract
              .connect(signers[4])
              .safeBatchTransferFrom(
                multiTokenHolder,
                this.receiver.address,
                [firstTokenId, secondTokenId],
                [firstAmount, secondAmount],
                "0x"
              )
          ).to.be.revertedWith(
            "ERC1155ReceiverMock: reverting on batch receive"
          );
        });
      });

      context(
        "to a receiver contract that reverts only on single transfers",
        function () {
          beforeEach(async function () {
            this.receiver = await ERC1155ReceiverMock.deploy(
              RECEIVER_SINGLE_MAGIC_VALUE,
              true,
              RECEIVER_BATCH_MAGIC_VALUE,
              false
            );

            this.toWhom = this.receiver.address;
            this.transferReceipt = await tokenContract
              .connect(signers[4])
              .safeBatchTransferFrom(
                multiTokenHolder,
                this.receiver.address,
                [firstTokenId, secondTokenId],
                [firstAmount, secondAmount],
                "0x"
              );
            ({ logs: this.transferLogs } = this.transferReceipt);
          });

          it("batchTransferWasSuccessful", async function () {
            batchTransferWasSuccessful({
              operator: multiTokenHolder,
              from: multiTokenHolder,
              ids: [firstTokenId, secondTokenId],
              values: [firstAmount, secondAmount],
            });
          });
        }
      );

      context(
        "to a contract that does not implement the required function",
        function () {
          it("reverts", async function () {
            const invalidReceiver = tokenContract;
            await expect(
              tokenContract
                .connect(signers[4])
                .safeBatchTransferFrom(
                  multiTokenHolder,
                  invalidReceiver.address,
                  [firstTokenId, secondTokenId],
                  [firstAmount, secondAmount],
                  "0x"
                )
            ).to.be.reverted;
          });
        }
      );
    });
  });

  describe("ERC1155 specific", function () {
    describe("internal functions", function () {
      const tokenId = BigNumber.from(1990);
      const mintAmount = BigNumber.from(9001);
      const burnAmount = BigNumber.from(3000);

      const tokenBatchIds = [
        BigNumber.from(2000),
        BigNumber.from(2010),
        BigNumber.from(2020),
      ];
      const mintAmounts = [
        BigNumber.from(5000),
        BigNumber.from(10000),
        BigNumber.from(42195),
      ];
      const burnAmounts = [
        BigNumber.from(5000),
        BigNumber.from(9001),
        BigNumber.from(195),
      ];

      const data = "0x12345678";

      describe("_mint", function () {
        it("reverts with a zero destination address", async function () {
          await expect(
            tokenContract.mint(ZERO_ADDRESS, tokenId, mintAmount, data)
          ).to.be.revertedWith("ERC1155: mint to the zero address");
        });

        context("with minted tokens", function () {
          beforeEach(async function () {
            ({ logs: this.logs } = await tokenContract
              .connect(signers[0])
              .mint(tokenHolder, tokenId, mintAmount, data));
          });

          it("credits the minted amount of tokens", async function () {
            expect(
              await tokenContract.balanceOf(tokenHolder, tokenId)
            ).to.be.eq(BigNumber.from(mintAmount));
          });
        });
      });

      describe("_mintBatch", function () {
        it("reverts with a zero destination address", async function () {
          await expect(
            tokenContract.mintBatch(
              ZERO_ADDRESS,
              tokenBatchIds,
              mintAmounts,
              data
            )
          ).to.be.revertedWith("ERC1155: mint to the zero address");
        });

        it("reverts if length of inputs do not match", async function () {
          await expect(
            tokenContract.mintBatch(
              multiTokenHolder,
              tokenBatchIds,
              mintAmounts.slice(1),
              data
            )
          ).to.be.revertedWith("ERC1155: ids and amounts length mismatch");

          await expect(
            tokenContract.mintBatch(
              multiTokenHolder,
              tokenBatchIds.slice(1),
              mintAmounts,
              data
            )
          ).to.be.revertedWith("ERC1155: ids and amounts length mismatch");
        });

        context("with minted batch of tokens", function () {
          beforeEach(async function () {
            ({ logs: this.logs } = await tokenContract
              .connect(signers[0])
              .mintBatch(multiTokenHolder, tokenBatchIds, mintAmounts, data));
          });

          it("credits the minted batch of tokens", async function () {
            const holderBatchBalances = await tokenContract.balanceOfBatch(
              new Array(tokenBatchIds.length).fill(multiTokenHolder),
              tokenBatchIds
            );

            for (let i = 0; i < holderBatchBalances.length; i++) {
              expect(holderBatchBalances[i]).to.be.eq(
                BigNumber.from(mintAmounts[i])
              );
            }
          });
        });
      });

      describe("_burn", function () {
        it("reverts when burning a non-existent token id", async function () {
          await expect(
            tokenContract
              .connect(signers[1])
              .burn(tokenHolder, tokenId, mintAmount)
          ).to.be.revertedWith("ERC1155: burn amount exceeds totalSupply");
        });

        it("reverts when burning more than available tokens", async function () {
          await tokenContract
            .connect(signers[0])
            .mint(signers[0].address, tokenId, mintAmount, data);

          await tokenContract
            .connect(signers[0])
            .mint(tokenHolder, tokenId, mintAmount, data);

          await expect(
            tokenContract
              .connect(signers[1])
              .burn(tokenHolder, tokenId, mintAmount.add(1))
          ).to.be.revertedWith("ERC1155: burn amount exceeds balance");
        });

        context("with minted-then-burnt tokens", function () {
          beforeEach(async function () {
            await tokenContract
              .connect(signers[0])
              .mint(tokenHolder, tokenId, mintAmount, data);
            ({ logs: this.logs } = await tokenContract
              .connect(signers[1])
              .burn(tokenHolder, tokenId, burnAmount));
          });
          it("accounts for both minting and burning", async function () {
            expect(
              await tokenContract.balanceOf(tokenHolder, tokenId)
            ).to.be.eq(BigNumber.from(mintAmount.sub(burnAmount)));
          });
        });
      });

      describe("_burnBatch", function () {
        it("reverts if length of inputs do not match", async function () {
          await expect(
            tokenContract
              .connect(signers[4])
              .burnBatch(multiTokenHolder, tokenBatchIds, burnAmounts.slice(1))
          ).to.be.revertedWith("ERC1155: ids and amounts length mismatch");

          await expect(
            tokenContract
              .connect(signers[4])
              .burnBatch(multiTokenHolder, tokenBatchIds.slice(1), burnAmounts)
          ).to.be.revertedWith("ERC1155: ids and amounts length mismatch");
        });

        it("reverts when burning a non-existent token id", async function () {
          await expect(
            tokenContract
              .connect(signers[4])
              .burnBatch(multiTokenHolder, tokenBatchIds, burnAmounts)
          ).to.be.revertedWith("ERC1155: burn amount exceeds totalSupply");
        });

        context("with minted-then-burnt tokens", function () {
          beforeEach(async function () {
            await tokenContract.mintBatch(
              multiTokenHolder,
              tokenBatchIds,
              mintAmounts,
              data
            );
            ({ logs: this.logs } = await tokenContract
              .connect(signers[4])
              .burnBatch(multiTokenHolder, tokenBatchIds, burnAmounts));
          });

          it("accounts for both minting and burning", async function () {
            const holderBatchBalances = await tokenContract.balanceOfBatch(
              new Array(tokenBatchIds.length).fill(multiTokenHolder),
              tokenBatchIds
            );

            for (let i = 0; i < holderBatchBalances.length; i++) {
              expect(holderBatchBalances[i]).to.be.eq(
                BigNumber.from(mintAmounts[i].sub(burnAmounts[i]))
              );
            }
          });
        });
      });
    });

    describe("ERC1155MetadataURI", function () {
      const firstTokenID = BigNumber.from("42");
      const secondTokenID = BigNumber.from("1337");

      it("sets the initial URI for all token types", async function () {
        expect(await tokenContract.uri(firstTokenID)).to.be.equal(initialURI);
        expect(await tokenContract.uri(secondTokenID)).to.be.equal(initialURI);
      });
    });
  });

  describe("ERC1155Supply specific", function () {
    context("before mint", function () {
      it("exist", async function () {
        expect(await tokenContract.exists(firstTokenId)).to.be.equal(false);
      });

      it("totalSupply", async function () {
        expect(await tokenContract.totalSupply(firstTokenId)).to.be.eq(
          BigNumber.from("0")
        );
      });
    });

    context("after mint", function () {
      context("single", function () {
        beforeEach(async function () {
          await tokenContract.mint(
            tokenHolder,
            firstTokenId,
            firstAmount,
            "0x"
          );
        });

        it("exist", async function () {
          expect(await tokenContract.exists(firstTokenId)).to.be.equal(true);
        });

        it("totalSupply", async function () {
          expect(await tokenContract.totalSupply(firstTokenId)).to.be.eq(
            firstAmount
          );
        });
      });

      context("batch", function () {
        beforeEach(async function () {
          await tokenContract.mintBatch(
            tokenHolder,
            [firstTokenId, secondTokenId],
            [firstAmount, secondAmount],
            "0x"
          );
        });

        it("exist", async function () {
          expect(await tokenContract.exists(firstTokenId)).to.be.equal(true);
          expect(await tokenContract.exists(secondTokenId)).to.be.equal(true);
        });

        it("totalSupply", async function () {
          expect(await tokenContract.totalSupply(firstTokenId)).to.be.eq(
            firstAmount
          );
          expect(await tokenContract.totalSupply(secondTokenId)).to.be.eq(
            secondAmount
          );
        });
      });
    });

    context("after burn", function () {
      context("single", function () {
        beforeEach(async function () {
          await tokenContract.mint(
            tokenHolder,
            firstTokenId,
            firstAmount,
            "0x"
          );
          await tokenContract
            .connect(signers[1])
            .burn(tokenHolder, firstTokenId, firstAmount);
        });

        it("exist", async function () {
          expect(await tokenContract.exists(firstTokenId)).to.be.equal(false);
        });

        it("totalSupply", async function () {
          expect(await tokenContract.totalSupply(firstTokenId)).to.be.eq("0");
        });
      });

      context("batch", function () {
        beforeEach(async function () {
          await tokenContract.mintBatch(
            tokenHolder,
            [firstTokenId, secondTokenId],
            [firstAmount, secondAmount],
            "0x"
          );
          await tokenContract
            .connect(signers[1])
            .burnBatch(
              tokenHolder,
              [firstTokenId, secondTokenId],
              [firstAmount, secondAmount]
            );
        });

        it("exist", async function () {
          expect(await tokenContract.exists(firstTokenId)).to.be.equal(false);
          expect(await tokenContract.exists(secondTokenId)).to.be.equal(false);
        });

        it("totalSupply", async function () {
          expect(await tokenContract.totalSupply(firstTokenId)).to.be.eq("0");
          expect(await tokenContract.totalSupply(secondTokenId)).to.be.eq("0");
        });
      });
    });
  });

  describe("ERC1155PresetMinterPauser specific", function () {
    it("deployer has the default admin role", async function () {
      expect(
        await tokenContract.getRoleMemberCount(DEFAULT_ADMIN_ROLE)
      ).to.be.eq("1");
      expect(await tokenContract.getRoleMember(DEFAULT_ADMIN_ROLE, 0)).to.equal(
        deployer
      );
    });

    it("deployer has the minter role", async function () {
      expect(await tokenContract.getRoleMemberCount(MINTER_ROLE)).to.be.eq("1");
      expect(await tokenContract.getRoleMember(MINTER_ROLE, 0)).to.equal(
        deployer
      );
    });

    it("deployer has the pauser role", async function () {
      expect(await tokenContract.getRoleMemberCount(PAUSER_ROLE)).to.be.eq("1");
      expect(await tokenContract.getRoleMember(PAUSER_ROLE, 0)).to.equal(
        deployer
      );
    });

    it("minter and pauser role admin is the default admin", async function () {
      expect(await tokenContract.getRoleAdmin(MINTER_ROLE)).to.equal(
        DEFAULT_ADMIN_ROLE
      );
      expect(await tokenContract.getRoleAdmin(PAUSER_ROLE)).to.equal(
        DEFAULT_ADMIN_ROLE
      );
    });

    describe("minting", function () {
      it("deployer can mint tokens", async function () {
        await tokenContract.mint(tokenHolder, firstTokenId, firstAmount, "0x", {
          from: deployer,
        });

        expect(
          await tokenContract.balanceOf(tokenHolder, firstTokenId)
        ).to.be.eq(firstAmount);
      });

      it("tokenHolder accounts cannot mint tokens", async function () {
        await expect(
          tokenContract
            .connect(signers[1])
            .mint(tokenHolder, firstTokenId, firstAmount, "0x", {
              from: tokenHolder,
            })
        ).to.be.revertedWith(
          "ERC1155PresetMinterPauser: must have minter role to mint"
        );
      });
    });

    describe("batched minting", function () {
      it("deployer can batch mint tokens", async function () {
        await tokenContract.mintBatch(
          tokenHolder,
          [firstTokenId, secondTokenId],
          [firstAmount, secondAmount],
          "0x",
          { from: deployer }
        );

        expect(
          await tokenContract.balanceOf(tokenHolder, firstTokenId)
        ).to.be.eq(firstAmount);
      });

      it("tokenHolder accounts cannot batch mint tokens", async function () {
        await expect(
          tokenContract
            .connect(signers[1])
            .mintBatch(
              tokenHolder,
              [firstTokenId, secondTokenId],
              [firstAmount, secondAmount],
              "0x"
            )
        ).to.be.revertedWith(
          "ERC1155PresetMinterPauser: must have minter role to mint"
        );
      });
    });

    describe("pausing", function () {
      it("deployer can pause", async function () {
        await tokenContract.pause({ from: deployer });

        expect(await tokenContract.paused()).to.equal(true);
      });

      it("deployer can unpause", async function () {
        await tokenContract.pause({ from: deployer });

        await tokenContract.unpause({ from: deployer });

        expect(await tokenContract.paused()).to.equal(false);
      });

      it("cannot mint while paused", async function () {
        await tokenContract.pause({ from: deployer });

        await expect(
          tokenContract.mint(tokenHolder, firstTokenId, firstAmount, "0x", {
            from: deployer,
          })
        ).to.be.revertedWith("ERC1155Pausable: token transfer while paused");
      });

      it("tokenHolder accounts cannot pause", async function () {
        await expect(
          tokenContract.connect(signers[1]).pause({ from: tokenHolder })
        ).to.be.revertedWith(
          "ERC1155PresetMinterPauser: must have pauser role to pause"
        );
      });

      it("tokenHolder accounts cannot unpause", async function () {
        await tokenContract.pause({ from: deployer });

        await expect(
          tokenContract.connect(signers[1]).unpause({ from: tokenHolder })
        ).to.be.revertedWith(
          "ERC1155PresetMinterPauser: must have pauser role to unpause"
        );
      });
    });

    describe("burning", function () {
      it("holders can burn their tokens", async function () {
        await tokenContract
          .connect(signers[0])
          .mint(tokenHolder, firstTokenId, firstAmount, "0x");

        await tokenContract
          .connect(signers[1])
          .burn(tokenHolder, firstTokenId, firstAmount.sub(1));

        expect(
          await tokenContract.balanceOf(tokenHolder, firstTokenId)
        ).to.be.eq("1");
      });
    });
  });

  describe("gETH specific", function () {
    describe("setMinterPauserOracle", function () {
      describe("on creation", function () {
        it("deployer has the oracle role", async function () {
          expect(await tokenContract.getRoleMemberCount(ORACLE_ROLE)).to.be.eq(
            "1"
          );
          expect(await tokenContract.getRoleMember(ORACLE_ROLE, 0)).to.equal(
            deployer
          );
        });
        it("oracle role admin is the default admin", async function () {
          expect(await tokenContract.getRoleAdmin(ORACLE_ROLE)).to.equal(
            DEFAULT_ADMIN_ROLE
          );
        });
      });
      describe("after new MinterPauserOracle set", function () {
        beforeEach(async () => {
          minter = signers[7].address;
          await tokenContract.updateMinterRole(minter);
          await tokenContract.updateOracleRole(minter);
          await tokenContract.updatePauserRole(minter);
        });
        it("new minter has the minter role", async function () {
          expect(await tokenContract.getRoleMemberCount(ORACLE_ROLE)).to.be.eq(
            "1"
          );
          expect(await tokenContract.getRoleMember(ORACLE_ROLE, 0)).to.equal(
            minter
          );
        });
        it("new minter has the pauser role", async function () {
          expect(await tokenContract.getRoleMemberCount(ORACLE_ROLE)).to.be.eq(
            "1"
          );
          expect(await tokenContract.getRoleMember(ORACLE_ROLE, 0)).to.equal(
            minter
          );
        });
        it("new minter has the oracle role", async function () {
          expect(await tokenContract.getRoleMemberCount(ORACLE_ROLE)).to.be.eq(
            "1"
          );
          expect(await tokenContract.getRoleMember(ORACLE_ROLE, 0)).to.equal(
            minter
          );
        });
      });
    });

    describe("setPricePerShare", function () {
      beforeEach(async () => {
        minter = signers[7].address;
        await tokenContract.updateMinterRole(minter);
        await tokenContract.updateOracleRole(minter);
      });

      it("ZERO at the beginning", async function () {
        it("id = 0", async function () {
          const price = await tokenContract.pricePerShare("0");
          expect(price).to.be.eq("0");
        });
        it("id = 1", async function () {
          price = await tokenContract.pricePerShare(firstTokenId);
          expect(price).to.be.eq("0");
        });
        it("any id", async function () {
          price = await tokenContract.pricePerShare(unknownTokenId);
          expect(price).to.be.eq("0");
        });
      });

      describe("ORACLE_ROLE can set", async function () {
        it("id = 0", async function () {
          await tokenContract
            .connect(signers[7])
            .setPricePerShare(firstAmount, 0);
          const price = await tokenContract.pricePerShare(0);
          expect(price).to.be.eq(firstAmount);
        });
        it("id = 1", async function () {
          await tokenContract
            .connect(signers[7])
            .setPricePerShare(firstAmount, firstTokenId);
          const price = await tokenContract.pricePerShare(firstTokenId);
          expect(price).to.be.eq(firstAmount);
        });
        it("any id", async function () {
          await tokenContract
            .connect(signers[7])
            .setPricePerShare(firstAmount, unknownTokenId);
          const price = await tokenContract.pricePerShare(unknownTokenId);
          expect(price).to.be.eq(firstAmount);
        });
      });

      describe("previous ORACLE_ROLE can NOT set", async function () {
        it("id = 0", async function () {
          await expect(
            tokenContract.connect(signers[0]).setPricePerShare(firstAmount, 0)
          ).to.be.revertedWith("gETH: must have ORACLE to set");
        });
        it("id = 1", async function () {
          await expect(
            tokenContract
              .connect(signers[0])
              .setPricePerShare(firstAmount, firstTokenId)
          ).to.be.revertedWith("gETH: must have ORACLE to set");
        });
        it("any id", async function () {
          await expect(
            tokenContract
              .connect(signers[0])
              .setPricePerShare(firstAmount, unknownTokenId)
          ).to.be.revertedWith("gETH: must have ORACLE to set");
        });
      });

      describe("others can NOT set", async function () {
        it("id = 0", async function () {
          await expect(
            tokenContract.connect(signers[4]).setPricePerShare(firstAmount, 0)
          ).to.be.revertedWith("gETH: must have ORACLE to set");
        });
        it("id = 1", async function () {
          await expect(
            tokenContract
              .connect(signers[4])
              .setPricePerShare(firstAmount, firstTokenId)
          ).to.be.revertedWith("gETH: must have ORACLE to set");
        });
        it("any id", async function () {
          await expect(
            tokenContract
              .connect(signers[4])
              .setPricePerShare(firstAmount, unknownTokenId)
          ).to.be.revertedWith("gETH: must have ORACLE to set");
        });
      });
    });

    describe("setInterface", function () {
      beforeEach(async () => {
        await tokenContract
          .connect(signers[0])
          .mint(firstTokenHolder, unknownTokenId, firstAmount, "0x");

        ERC20InterfaceFac = await ethers.getContractFactory(
          "ERC20InterfacePermitUpgradable"
        );
        ERC20Interface = await ERC20InterfaceFac.deploy();
        await ERC20Interface.initialize(
          unknownTokenId,
          "name",
          "SYMBOL",
          tokenContract.address
        );
        // IMPORTANT LINE BELOW
        ERC20Interface.connect(signers[2]).approve(proxy, firstAmount);

        await tokenContract
          .connect(signers[0])
          .setInterface(ERC20Interface.address, unknownTokenId, true);
      });

      describe("ERC20InterfacePermitUpgradable", async function () {
        it("returns the correct totalSupply", async function () {
          expect(await ERC20Interface.totalSupply()).to.be.eq(firstAmount);
        });
        it("returns the correct balance", async function () {
          expect(await ERC20Interface.balanceOf(firstTokenHolder)).to.be.eq(
            firstAmount
          );
        });
      });

      describe("interfaces can transfer without asking", async function () {
        it("succeeds as a token holder", async function () {
          await ERC20Interface.connect(signers[2]).transfer(
            secondTokenHolder,
            firstAmount
          );
          expect(await ERC20Interface.balanceOf(firstTokenHolder)).to.be.eq(
            "0"
          );
          expect(await ERC20Interface.balanceOf(secondTokenHolder)).to.be.eq(
            firstAmount
          );
        });
        it("succeeds as approved", async function () {
          await tokenContract.connect(signers[2]).avoidInterfaces(true);
          await tokenContract.connect(signers[2]).avoidInterfaces(false);
          await ERC20Interface.connect(signers[6]).transferFrom(
            firstTokenHolder,
            secondTokenHolder,
            firstAmount
          );
          expect(await ERC20Interface.balanceOf(firstTokenHolder)).to.be.eq(
            "0"
          );
          expect(await ERC20Interface.balanceOf(secondTokenHolder)).to.be.eq(
            firstAmount
          );
        });
        it("reverts if not approved", async function () {
          await expect(
            ERC20Interface.connect(signers[5]).transferFrom(
              firstTokenHolder,
              secondTokenHolder,
              firstAmount
            )
          ).to.be.revertedWith("ERC20: insufficient allowance");
        });
        it("reverts: approved, but user avoided", async function () {
          await tokenContract.connect(signers[2]).avoidInterfaces(true);
          expect(
            ERC20Interface.connect(signers[6]).transferFrom(
              firstTokenHolder,
              secondTokenHolder,
              firstAmount
            )
          ).to.be.revertedWith(
            "ERC1155: caller is not owner nor approved nor an allowed interface"
          );
          expect(await ERC20Interface.balanceOf(firstTokenHolder)).to.be.eq(
            firstAmount
          );
          expect(await ERC20Interface.balanceOf(secondTokenHolder)).to.be.eq(
            "0"
          );
        });
      });

      describe("can burn underlying tokens ", async function () {
        let nonERC1155Receiver;
        beforeEach(async () => {
          const nonERC1155ReceiverFac = await ethers.getContractFactory(
            "nonERC1155Receiver"
          );
          nonERC1155Receiver = await nonERC1155ReceiverFac.deploy(
            firstTokenId,
            tokenContract.address
          );
          await tokenContract
            .connect(signers[0])
            .setInterface(nonERC1155Receiver.address, firstTokenId, true);

          await tokenContract
            .connect(signers[0])
            .mint(tokenHolder, firstTokenId, firstAmount, "0x");
        });

        it("succeeds", async function () {
          await tokenContract.connect(signers[1]).avoidInterfaces(true);
          await tokenContract.connect(signers[1]).avoidInterfaces(false);

          expect(
            await tokenContract.balanceOf(tokenHolder, firstTokenId)
          ).to.be.eq(firstAmount.toString());
          await nonERC1155Receiver.connect(signers[1]).burn(firstAmount);
          expect(
            await tokenContract.balanceOf(tokenHolder, firstTokenId)
          ).to.be.eq(BigNumber.from(0));
        });
        it("reverts if avoided", async function () {
          await tokenContract.connect(signers[1]).avoidInterfaces(true);
          expect(
            await tokenContract.balanceOf(tokenHolder, firstTokenId)
          ).to.be.eq(firstAmount.toString());
          await expect(
            nonERC1155Receiver.connect(signers[1]).burn(firstAmount)
          ).to.be.revertedWith(
            "ERC1155: caller is not owner nor approved nor an allowed interface"
          );
          expect(
            await tokenContract.balanceOf(tokenHolder, firstTokenId)
          ).to.be.eq(firstAmount.toString());
        });
      });

      describe("can not burn OTHER underlying tokens", async function () {
        let nonERC1155Receiver;
        beforeEach(async () => {
          const nonERC1155ReceiverFac = await ethers.getContractFactory(
            "nonERC1155Receiver"
          );
          nonERC1155Receiver = await nonERC1155ReceiverFac.deploy(
            unknownTokenId,
            tokenContract.address
          );
          await tokenContract
            .connect(signers[0])
            .setInterface(nonERC1155Receiver.address, 6969, true);

          await tokenContract
            .connect(signers[0])
            .mint(tokenHolder, firstTokenId, firstAmount, "0x");
        });

        it("fails", async function () {
          await expect(
            nonERC1155Receiver.connect(signers[1]).burn(firstAmount)
          ).to.be.revertedWith(
            "ERC1155: caller is not owner nor approved nor an allowed interface"
          );
        });
      });

      it("interfaces must be a contract", async function () {
        await expect(
          tokenContract
            .connect(signers[0])
            .setInterface(ZERO_ADDRESS, unknownTokenId, true)
        ).to.be.revertedWith("gETH: _Interface must be a contract");
      });

      it("interfaces can conduct transfers between non-erc1155Receiver contracts", async function () {
        const nonERC1155ReceiverFac = await ethers.getContractFactory(
          "nonERC1155Receiver"
        );
        const nonERC1155Receiver = await nonERC1155ReceiverFac.deploy(
          unknownTokenId,
          tokenContract.address
        );
        await ERC20Interface.connect(signers[2]).transfer(
          nonERC1155Receiver.address,
          firstAmount
        );
        expect(await ERC20Interface.balanceOf(firstTokenHolder)).to.be.eq("0");
        expect(
          await ERC20Interface.balanceOf(nonERC1155Receiver.address)
        ).to.be.eq(firstAmount);
      });

      it("interfaces can NOT transfer other ids", async function () {
        const nonERC1155ReceiverFac = await ethers.getContractFactory(
          "nonERC1155Receiver"
        );
        const nonERC1155Receiver = await nonERC1155ReceiverFac.deploy(
          unknownTokenId,
          tokenContract.address
        );
        await tokenContract
          .connect(signers[0])
          .setInterface(nonERC1155Receiver.address, 69696, true);

        await expect(
          nonERC1155Receiver
            .connect(signers[5])
            .transfer(secondTokenHolder, firstAmount)
        ).to.be.revertedWith(
          "ERC1155: caller is not owner nor approved nor an allowed interface"
        );
      });

      it("can not transfer if not interface ", async function () {
        const nonERC1155ReceiverFac = await ethers.getContractFactory(
          "nonERC1155Receiver"
        );
        const nonERC1155Receiver = await nonERC1155ReceiverFac.deploy(
          unknownTokenId,
          tokenContract.address
        );
        await expect(
          nonERC1155Receiver
            .connect(signers[5])
            .transfer(secondTokenHolder, firstAmount)
        ).to.be.revertedWith(
          "ERC1155: caller is not owner nor approved nor an allowed interface"
        );
      });

      it("unset(old) interfaces can NOT act", async function () {
        await tokenContract
          .connect(signers[0])
          .setInterface(ERC20Interface.address, unknownTokenId, false);
        await expect(
          ERC20Interface.connect(signers[6]).transferFrom(
            firstTokenHolder,
            secondTokenHolder,
            firstAmount
          )
        ).to.be.revertedWith(
          "ERC1155: caller is not owner nor approved nor an allowed interface"
        );
      });
    });
  });

  // openzeppelin checks, so we don't need.
  //   shouldSupportInterfaces([
  //     "ERC165",
  //     "ERC1155",
  //     "AccessControl",
  //     "AccessControlEnumerable",
  //   ]);
});
