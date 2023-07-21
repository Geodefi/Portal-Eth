const { expect } = require("chai");

const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const { expectRevert, expectEvent, constants, BN } = require("@openzeppelin/test-helpers");
const { ZERO_BYTES32, MAX_UINT256 } = constants;

const {
  getReceiptTimestamp,
  setTimestamp,
  DAY,
  strToBytes,
  strToBytes32,
} = require("../../../utils");

const gETH = artifacts.require("gETH");
const StakeModuleLib = artifacts.require("StakeModuleLib");
const OracleExtensionLib = artifacts.require("OracleExtensionLib");
const OracleExtensionLibMock = artifacts.require("$OracleExtensionLibMock");
const GeodeModuleLib = artifacts.require("GeodeModuleLib");
const WithdrawalContract = artifacts.require("WithdrawalContract");

const pubkeys = [
  "0x91efd3ce6694bc034ad4c23773877da916ed878ff8376610633a9ae4b4d826f4086a6b9b5b197b5e148be658c66c4e9a",
  "0xa3b3eb55b16999ffeff52e5a898af89e4194b7221b2eaf03cb85fd558a390dc042beba94f907db6091b4cf141b18d1f5",
  "0x986e1dee05f3a018bab83343b3b3d96dd573a50ffb03e8145b2964a389ceb14cb3780266b99ef7cf0e16ee34648e2151",
  "0xa0ff714a6911f6abe00efca9381195ea70d8d58d664423e27fa18e2ce12980706381ef1c9b9ddfc48c937c49a5a11e62",
  "0x73bf345524147e0c11efc815ed68236bc9f1cf3594c8db0e211d84c1cc5db245299b6331233982a5a8d723866577ee49",
  "0x8e71003f91b858bf87596364e8ffde2063488287df7cb3911a26b0f106c9d947d65ca3986fe373edc6f7c122dd152bca",
  "0xf3951090f055803abd6d8dc932b9fdec20ebfaa9e5996d2531c67f25ec8727985697121fc588c9845b019c8bb024523b",
  "0x178350fc55aed517bacea80cb23044f50327ac6281a9cadd57e2379ec87f8b5d4c5bf8390bafee7345a7d20decace524",
  "0x7a4cc4f22501b94187bd5927f561dbef269b8b28033496583040f29d5fea0a745b78e930c046cd4a5e684fb90d6728ff",
  "0xfe825a50b20cdb3f2bd2b03295a7e263a251ef49649cd206af07c53e5e14b240bcce50c2eac9249444efee1d937d2d8a",
];
const wrongPubkey =
  "0xef825a50b20cdb3f2bd2b03295a7e263a251ef49649cd206af07c53e5e14b240bcce50c2eac9249444efee1d937d2d8a";
const signature1 =
  "0x8bbeff59e3016c98d7daf05ddbd0c71309fae34bf3e544d56ebff030b97bccb83c5abfaab437ec7c652bbafa19eb30661979b82e79fa351d65a50e3a854c1ef0c8537f97ceaf0f334096509cd52f716150e67e17c8085d9622f376553da51181";

const signature31 =
  "0xa58af51205a996c87f23c80aeb3cb669001e3f919a88598d063ff6cee9b05fbb8a18dab15a4a5b85eabfd47c26d0f24f11f5f889f6a7fb8cbd5c4ccd7607c449b57a9f0703e1bb63b513cb3e9fcd1d79b0d8f269c7441173054b9284cfb7a13c";

contract("OracleExtensionLib", function (accounts) {
  const [
    deployer,
    oracle,
    poolOwner,
    operatorOwner,
    yieldReceiver1,
    yieldReceiver2,
    yieldReceiver3,
    yieldReceiver4,
    yieldReceiver5,
  ] = accounts;

  const MIN_VALIDATOR_PERIOD = DAY.muln(90);

  const operatorNames = ["goodOperator", "badOperator"];
  const poolNames = ["myPool", "otherPool", "somePool", "bigPool", "smallPool"];
  const yieldReceivers = [
    yieldReceiver1,
    yieldReceiver2,
    yieldReceiver3,
    yieldReceiver4,
    yieldReceiver5,
  ];

  // eslint-disable-next-line prefer-const
  let operatorIds = [];
  // eslint-disable-next-line prefer-const
  let poolIds = [];

  const setWithdrawalPackage = async function () {
    const wc = await WithdrawalContract.new(this.gETH.address, this.contract.address);
    const packageType = new BN(10011);
    const packageName = "WithdrawalContract";

    const withdrawalPackageId = await this.contract.generateId(packageName, packageType);

    await this.contract.$writeUint(withdrawalPackageId, strToBytes32("TYPE"), packageType);
    await this.contract.$writeAddress(withdrawalPackageId, strToBytes32("CONTROLLER"), wc.address);

    await this.contract.$writeBytes(
      withdrawalPackageId,
      strToBytes32("NAME"),
      strToBytes("WithdrawalContract")
    );

    await this.contract.$set_package(packageType, withdrawalPackageId);
  };

  const createOperator = async function (name) {
    const operatorId = await this.contract.generateId(name, 4);

    await this.contract.$writeBytes(operatorId, strToBytes32("NAME"), strToBytes(name));
    await this.contract.$writeUint(operatorId, strToBytes32("TYPE"), 4);
    await this.contract.$writeAddress(operatorId, strToBytes32("CONTROLLER"), operatorOwner);

    await this.contract.initiateOperator(operatorId, 0, MIN_VALIDATOR_PERIOD, operatorOwner, {
      from: operatorOwner,
      value: new BN(String(1e18)).muln(10),
    });
    return operatorId;
  };

  const createPool = async function (name) {
    await this.contract.initiatePool(
      0,
      0,
      poolOwner,
      strToBytes(name),
      "0x",
      [false, false, false],
      {
        from: poolOwner,
        value: new BN(String(1e18)).muln(32),
      }
    );
    const id = await this.contract.generateId(name, 5);
    return id;
  };

  const proposeValidators = async function (poolId, operatorId, pubkeys) {
    await this.contract.delegate(poolId, [operatorId], [100], {
      from: poolOwner,
    });

    const amount = pubkeys.length;

    await this.contract.deposit(poolId, 0, [], 0, MAX_UINT256, deployer, {
      from: deployer,
      value: new BN(String(32e18)).muln(amount),
    });

    await this.contract.proposeStake(
      poolId,
      operatorId,
      pubkeys,
      new Array(amount).fill(signature1),
      new Array(amount).fill(signature31),
      {
        from: operatorOwner,
      }
    );
  };

  before(async function () {
    const SML = await StakeModuleLib.new();
    const OEL = await OracleExtensionLib.new();
    const GML = await GeodeModuleLib.new();

    await OracleExtensionLibMock.link(SML);
    await OracleExtensionLibMock.link(OEL);

    await WithdrawalContract.link(GML);

    this.setWithdrawalPackage = setWithdrawalPackage;
    this.createOperator = createOperator;
    this.createPool = createPool;
    this.proposeValidators = proposeValidators;
  });

  beforeEach(async function () {
    this.gETH = await gETH.new("name", "symbol", "uri", { from: deployer });

    this.contract = await OracleExtensionLibMock.new({ from: deployer });
    await this.contract.initialize(this.gETH.address, oracle);

    await this.gETH.transferMinterRole(this.contract.address);
    await this.gETH.transferOracleRole(this.contract.address);

    await this.setWithdrawalPackage();

    // create 3 operators
    operatorIds = [];

    for (const name of operatorNames) {
      operatorIds.push(await this.createOperator(name));
    }
    // create 5 pools
    poolIds = [];
    for (const name of poolNames) {
      poolIds.push(await this.createPool(name));
    }
    await this.contract.$set_MONOPOLY_THRESHOLD(new BN("50000"));

    for (const [i, pk] of pubkeys.entries()) {
      await this.proposeValidators(
        poolIds[i % poolIds.length],
        operatorIds[i % operatorIds.length],
        [pk]
      );
    }
  });

  context("proposal verification", function () {
    describe("_alienateValidator", function () {
      it("reverts if higher than VERIFICATION_INDEX", async function () {
        await expectRevert(this.contract.$_alienateValidator(pubkeys[6]), "OEL:unexpected index");
      });
      it("reverts if validator is not PROPOSED", async function () {
        await expectRevert(
          this.contract.$_alienateValidator(ZERO_BYTES32),
          "OEL:NOT all pubkeys are pending"
        );
        await expectRevert(
          this.contract.$_alienateValidator(wrongPubkey),
          "OEL:NOT all pubkeys are pending"
        );
      });
      context("success", function () {
        let preSurplus;
        let preSecured;
        let preProposedValidators;
        let preAlienValidators;

        let tx;
        beforeEach(async function () {
          preSurplus = await this.contract.readUint(poolIds[0], strToBytes("surplus"));

          preSecured = await this.contract.readUint(poolIds[0], strToBytes("secured"));

          preProposedValidators = await this.contract.readUint(
            poolIds[0],
            await this.contract.getKey(operatorIds[0], strToBytes32("proposedValidators"))
          );

          preAlienValidators = await this.contract.readUint(
            poolIds[0],
            await this.contract.getKey(operatorIds[0], strToBytes32("alienValidators"))
          );

          await this.contract.$set_VERIFICATION_INDEX(5);
          tx = await this.contract.$_alienateValidator(pubkeys[0]);
        });
        it("imprisons the operator", async function () {
          expect(await this.contract.isPrisoned(operatorIds[0])).to.be.equal(true);
        });
        it("fixes secured", async function () {
          expect(
            await this.contract.readUint(poolIds[0], strToBytes("surplus"))
          ).to.be.bignumber.equal(preSurplus.add(new BN(String(32e18))));
        });
        it("fixes surplus", async function () {
          expect(
            await this.contract.readUint(poolIds[0], strToBytes("secured"))
          ).to.be.bignumber.equal(preSecured.sub(new BN(String(32e18))));
        });
        it("fixes proposedValidators", async function () {
          expect(
            await this.contract.readUint(
              poolIds[0],
              await this.contract.getKey(operatorIds[0], strToBytes32("proposedValidators"))
            )
          ).to.be.bignumber.equal(preProposedValidators.subn(1));
        });
        it("fixes alienValidators", async function () {
          expect(
            await this.contract.readUint(
              poolIds[0],
              await this.contract.getKey(operatorIds[0], strToBytes32("alienValidators"))
            )
          ).to.be.bignumber.equal(preAlienValidators.addn(1));
        });
        it("changes validator state to ALIENATED", async function () {
          expect((await this.contract.getValidator(pubkeys[0])).state).to.be.bignumber.equal("69");
        });
        it("emits Alienated", async function () {
          await expectEvent(tx, "Alienated", { pubkey: pubkeys[0] });
        });
      });
    });
    describe("updateVerificationIndex", function () {
      it("reverts if not Oracle", async function () {
        await expectRevert(this.contract.updateVerificationIndex(10, []), "OEL:sender NOT ORACLE");
      });
      it("reverts if high verificationIndex", async function () {
        await expectRevert(
          this.contract.updateVerificationIndex(11, [], { from: oracle }),
          "OEL:high VERIFICATION_INDEX"
        );
      });
      it("reverts if low verificationIndex", async function () {
        await this.contract.$set_VERIFICATION_INDEX(5);
        await expectRevert(
          this.contract.updateVerificationIndex(4, [], { from: oracle }),
          "OEL:low VERIFICATION_INDEX"
        );
      });
      context("success", function () {
        let tx;
        beforeEach(async function () {
          tx = await this.contract.updateVerificationIndex(
            10,
            [pubkeys[0], pubkeys[2], pubkeys[4]],
            {
              from: oracle,
            }
          );
        });
        it("alienates", async function () {
          expect((await this.contract.getValidator(pubkeys[0])).state).to.be.bignumber.equal("69");
          expect((await this.contract.getValidator(pubkeys[2])).state).to.be.bignumber.equal("69");
          expect((await this.contract.getValidator(pubkeys[4])).state).to.be.bignumber.equal("69");
        });
        it("updates VERIFICATION_INDEX", async function () {
          expect((await this.contract.StakeParams()).verificationIndex).to.be.bignumber.equal("10");
        });
        it("emit VerificationIndexUpdated", async function () {
          await expectEvent(tx, "VerificationIndexUpdated", { validatorVerificationIndex: "10" });
        });
      });
    });
  });

  describe("regulateOperators", function () {
    it("reverts if not Oracle", async function () {
      await expectRevert(
        this.contract.regulateOperators([operatorIds[0]], ["0xffffff"]),
        "OEL:sender NOT ORACLE"
      );
    });
    it("reverts if lengths doesn't match", async function () {
      await expectRevert(
        this.contract.regulateOperators([operatorIds[0]], [], { from: oracle }),
        "OEL:invalid proofs"
      );
    });
    context("regulateOperators", function () {
      let tx;
      beforeEach(async function () {
        tx = await this.contract.regulateOperators([operatorIds[0]], ["0xffffff"], {
          from: oracle,
        });
      });

      it("imprisons the operators", async function () {
        expect(await this.contract.isPrisoned(operatorIds[0])).to.be.equal(true);
      });
      it("emits FeeTheft", async function () {
        expectEvent(tx, "FeeTheft", { id: operatorIds[0], proofs: "0xffffff" });
      });
    });
  });

  context("price updates", function () {
    let ts;
    const price = new BN(String(1e18));

    describe("_sanityCheck", function () {
      beforeEach(async function () {
        const tx = await this.contract.$set_PricePerShare(price, poolIds[0]);
        ts = new BN((await getReceiptTimestamp(tx)).toString());
      });

      it("reverts if not a pool", async function () {
        await expectRevert(this.contract.$_sanityCheck(operatorIds[0], 0), "OEL:not a pool?");
      });

      it("reverts if price higher than allowed for 0.5 days", async function () {
        const delay = DAY.divn(2);
        const newPrice = price.divn(100).muln(104);
        await setTimestamp(ts.add(delay).toNumber());
        await expectRevert(
          this.contract.$_sanityCheck(poolIds[0], newPrice),
          "OEL:price is insane, price update is halted"
        );
      });
      it("reverts if price higher than allowed for 1 days", async function () {
        const delay = DAY;
        const newPrice = price.divn(100).muln(108);
        await setTimestamp(ts.add(delay).toNumber());
        await expectRevert(
          this.contract.$_sanityCheck(poolIds[0], newPrice),
          "OEL:price is insane, price update is halted"
        );
      });
      it("reverts if price higher than allowed for 10 days", async function () {
        const delay = DAY.muln(10);
        const newPrice = price.divn(100).muln(171);
        await setTimestamp(ts.add(delay).toNumber());
        await expectRevert(
          this.contract.$_sanityCheck(poolIds[0], newPrice),
          "OEL:price is insane, price update is halted"
        );
      });
      it("reverts if price lower than allowed for 0.5 days", async function () {
        const delay = DAY.divn(2);
        const newPrice = price.divn(100).muln(96);
        await setTimestamp(ts.add(delay).toNumber());
        await expectRevert(
          this.contract.$_sanityCheck(poolIds[0], newPrice),
          "OEL:price is insane, price update is halted"
        );
      });
      it("reverts if price lower than allowed for 1 days", async function () {
        const delay = DAY;
        const newPrice = price.divn(100).muln(92);
        await setTimestamp(ts.add(delay).toNumber());
        await expectRevert(
          this.contract.$_sanityCheck(poolIds[0], newPrice),
          "OEL:price is insane, price update is halted"
        );
      });
      it("reverts if price lower than allowed for 10 days", async function () {
        const delay = DAY.muln(10);
        const newPrice = price.divn(100).muln(29);
        await setTimestamp(ts.add(delay).toNumber());
        await expectRevert(
          this.contract.$_sanityCheck(poolIds[0], newPrice),
          "OEL:price is insane, price update is halted"
        );
      });
    });

    describe("reportBeacon", function () {
      it("reverts if not Oracle", async function () {
        await expectRevert(
          this.contract.reportBeacon(
            strToBytes32("priceMerkleRoot"),
            strToBytes32("balanceMerkleRoot"),
            50000
          ),
          "OEL:sender NOT ORACLE"
        );
      });
      it("reverts if low allValidatorsCount", async function () {
        await expectRevert(
          this.contract.reportBeacon(
            strToBytes32("priceMerkleRoot"),
            strToBytes32("balanceMerkleRoot"),
            50000,
            {
              from: oracle,
            }
          ),
          "OEL:low validator count"
        );
      });
      context("success", function () {
        let tx;
        let ts;
        let params;
        beforeEach(async function () {
          tx = await this.contract.reportBeacon(
            strToBytes32("priceMerkleRoot"),
            strToBytes32("balanceMerkleRoot"),
            50500,
            {
              from: oracle,
            }
          );
          ts = new BN((await getReceiptTimestamp(tx)).toString());
          params = await this.contract.StakeParams();
        });

        it("updates PRICE_MERKLE_ROOT", async function () {
          expect(params.priceMerkleRoot).to.be.equal(strToBytes32("priceMerkleRoot"));
        });
        it("updates BALANCE_MERKLE_ROOT", async function () {
          expect(params.balanceMerkleRoot).to.be.equal(strToBytes32("balanceMerkleRoot"));
        });
        it("updates ORACLE_UPDATE_TIMESTAMP", async function () {
          expect(params.oracleUpdateTimestamp).to.be.bignumber.equal(ts);
        });
        it("emits OracleReported", async function () {
          await expectEvent(tx, "OracleReported", {
            priceMerkleRoot: strToBytes32("priceMerkleRoot"),
            balanceMerkleRoot: strToBytes32("balanceMerkleRoot"),
            monopolyThreshold: "505",
          });
        });
      });
    });

    describe("priceSync", function () {
      let ts;

      let tree;
      const prices = [String(97e16), String(99e16), String(101e16), String(104e16), String(106e16)];

      beforeEach(async function () {
        const values = [
          [poolIds[0].toString(), prices[0]],
          [poolIds[1].toString(), prices[1]],
          [poolIds[2].toString(), prices[2]],
          [poolIds[3].toString(), prices[3]],
          [poolIds[4].toString(), prices[4]],
        ];
        tree = StandardMerkleTree.of(values, ["uint256", "uint256"]);
      });
      context("priceSync without yield separation", function () {
        it("reverts if no price change since the last update", async function () {
          await expectRevert(
            this.contract.priceSync(poolIds[1], prices[1], tree.getProof(1)),
            "OEL:no price change"
          );
        });
        it("reverts if proofs are faulty", async function () {
          const tx = await this.contract.reportBeacon(
            tree.root,
            strToBytes32("not important"),
            50001,
            {
              from: oracle,
            }
          );
          ts = new BN((await getReceiptTimestamp(tx)).toString());
          await setTimestamp(ts.add(DAY).toNumber());
          await expectRevert(
            this.contract.priceSync(poolIds[1], prices[1], tree.getProof(2)),
            "OEL:NOT all proofs are valid"
          );
        });
        it("success: sets PricePerShare", async function () {
          const tx = await this.contract.reportBeacon(
            tree.root,
            strToBytes32("not important"),
            50001,
            {
              from: oracle,
            }
          );
          ts = new BN((await getReceiptTimestamp(tx)).toString());
          await setTimestamp(ts.add(DAY).toNumber());
          await this.contract.priceSync(poolIds[1], prices[1], tree.getProof(1));
          expect(await this.gETH.pricePerShare(poolIds[1])).to.be.bignumber.eq(prices[1]);
        });
      });
      context("priceSync with yield separation", function () {
        beforeEach(async function () {
          for (let i = 0; i < poolIds.length; i++) {
            await this.contract.setYieldReceiver(poolIds[i], yieldReceivers[i], {
              from: poolOwner,
            });
          }
        });

        it("success: sets PricePerShare for 0, 1 and mints and sends gETH for 2, 3 ,4", async function () {
          let prevPricePerShare;
          let prevgETHBalance;
          let requiredBalanceDiff;

          const tx = await this.contract.reportBeacon(
            tree.root,
            strToBytes32("not important"),
            50001,
            {
              from: oracle,
            }
          );
          ts = new BN((await getReceiptTimestamp(tx)).toString());
          await setTimestamp(ts.add(DAY).toNumber());

          // pool 0
          await this.contract.priceSync(poolIds[0], prices[0], tree.getProof(0));
          expect(await this.gETH.pricePerShare(poolIds[0])).to.be.bignumber.eq(prices[0]);

          // pool 1
          await this.contract.priceSync(poolIds[1], prices[1], tree.getProof(1));
          expect(await this.gETH.pricePerShare(poolIds[1])).to.be.bignumber.eq(prices[1]);

          // pool 2
          prevPricePerShare = await this.gETH.pricePerShare(poolIds[2]);
          prevgETHBalance = await this.gETH.balanceOf(yieldReceivers[2], poolIds[2]);
          requiredBalanceDiff =
            ((await this.gETH.totalSupply(poolIds[2])) * (prices[2] - prevPricePerShare)) /
            (await this.gETH.denominator()).subn(prevgETHBalance.toNumber());
          await this.contract.priceSync(poolIds[2], prices[2], tree.getProof(2));
          expect(await this.gETH.pricePerShare(poolIds[2])).to.be.bignumber.eq(prevPricePerShare);
          expect(await this.gETH.balanceOf(yieldReceivers[2], poolIds[2])).to.be.bignumber.eq(
            requiredBalanceDiff.toString()
          );
          console.log(
            "old",
            prevgETHBalance.toString(),
            "new",
            (await this.gETH.balanceOf(yieldReceivers[2], poolIds[2])).toString(),
            "diff found",
            requiredBalanceDiff.toString()
          );

          // pool 3
          prevPricePerShare = await this.gETH.pricePerShare(poolIds[3]);
          prevgETHBalance = await this.gETH.balanceOf(yieldReceivers[3], poolIds[3]);
          requiredBalanceDiff =
            ((await this.gETH.totalSupply(poolIds[3])) * (prices[3] - prevPricePerShare)) /
            (await this.gETH.denominator()).subn(prevgETHBalance.toNumber());
          await this.contract.priceSync(poolIds[3], prices[3], tree.getProof(3));
          expect(await this.gETH.pricePerShare(poolIds[3])).to.be.bignumber.eq(prevPricePerShare);
          expect(await this.gETH.balanceOf(yieldReceivers[3], poolIds[3])).to.be.bignumber.eq(
            requiredBalanceDiff.toString()
          );
          console.log(
            "old",
            prevgETHBalance.toString(),
            "new",
            (await this.gETH.balanceOf(yieldReceivers[3], poolIds[3])).toString(),
            "diff found",
            requiredBalanceDiff.toString()
          );

          // pool 4
          prevPricePerShare = await this.gETH.pricePerShare(poolIds[4]);
          prevgETHBalance = await this.gETH.balanceOf(yieldReceivers[4], poolIds[4]);
          requiredBalanceDiff =
            ((await this.gETH.totalSupply(poolIds[4])) * (prices[4] - prevPricePerShare)) /
            (await this.gETH.denominator()).subn(prevgETHBalance.toNumber());
          await this.contract.priceSync(poolIds[4], prices[4], tree.getProof(4));
          expect(await this.gETH.pricePerShare(poolIds[4])).to.be.bignumber.eq(prevPricePerShare);
          expect(await this.gETH.balanceOf(yieldReceivers[4], poolIds[4])).to.be.bignumber.eq(
            requiredBalanceDiff.toString()
          );
          console.log(
            "old",
            prevgETHBalance.toString(),
            "new",
            (await this.gETH.balanceOf(yieldReceivers[4], poolIds[4])).toString(),
            "diff found",
            requiredBalanceDiff.toString()
          );
        });
      });
      context("priceSyncBatch", function () {
        // eslint-disable-next-line prefer-const
        beforeEach(async function () {
          const tx = await this.contract.reportBeacon(
            tree.root,
            strToBytes32("not important"),
            50001,
            {
              from: oracle,
            }
          );
          ts = new BN((await getReceiptTimestamp(tx)).toString());
          await setTimestamp(ts.add(DAY).toNumber());
        });
        it("reverts if poolIds.length != prices.length", async function () {
          await expectRevert(
            this.contract.priceSyncBatch(poolIds, [], []),
            "OEL:array lengths not equal"
          );
        });
        it("reverts if poolIds.length != priceProofs.length", async function () {
          await expectRevert(
            this.contract.priceSyncBatch(poolIds, prices, []),
            "OEL:array lengths not equal"
          );
        });
        it("success", async function () {
          const ids = poolIds.map(function (e) {
            return e.toString();
          });

          // eslint-disable-next-line prefer-const
          let proofs = [];
          for (let i = 0; i < prices.length; i++) {
            proofs.push(tree.getProof(i));
          }

          await this.contract.priceSyncBatch(ids, prices, proofs);
        });
      });
    });
  });
});
