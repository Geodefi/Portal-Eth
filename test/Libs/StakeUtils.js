/**
 * 0	pubkey	bytes	0x91efd3ce6694bc034ad4c23773877da916ed878ff8376610633a9ae4b4d826f4086a6b9b5b197b5e148be658c66c4e9a
 * 1  withdrawal_credentials	bytes	0x004f58172d06b6d54c015d688511ad5656450933aff85dac123cd09410a0825c
 * 2  signature	bytes	0x8bbeff59e3016c98d7daf05ddbd0c71309fae34bf3e544d56ebff030b97bccb83c5abfaab437ec7c652bbafa19eb30661979b82e79fa351d65a50e3a854c1ef0c8537f97ceaf0f334096509cd52f716150e67e17c8085d9622f376553da51181
 * 3  deposit_data_root	bytes32	0xcf73f30d1a20e2af0446c2630acc4392f888dc0532a09592e00faf90b2976ab8
 */
/**
 * 0	pubkey	bytes	0xa3b3eb55b16999ffeff52e5a898af89e4194b7221b2eaf03cb85fd558a390dc042beba94f907db6091b4cf141b18d1f5
 * 1	withdrawal_credentials	bytes	0x00cfafe208762abcdd05339a6814cac749bb065cf762ed4fea2e0335cbdd08f0
 * 2	signature	bytes	0xa2e94c3def1e53d7d1b5a0f037f765868b4bbae3ee59de673bc7ab7b142b929e08f47c1c2a6cdc91aee9442468ab095406b8ce356aef42403febe385424f97d6d109f6423dcb1acc3def45af56e4407416f0773bd18e50d880cb7d3e00ca9932
 * 3	deposit_data_root	bytes32	0x47bd475f56dc4ae776b1fa445323fd0eee9be77fe20a790e7783c73450274dcb
 */
/**
 * 0	pubkey	bytes	0x986e1dee05f3a018bab83343b3b3d96dd573a50ffb03e8145b2964a389ceb14cb3780266b99ef7cf0e16ee34648e2151
 * 1	withdrawal_credentials	bytes	0x004f58172d06b6d54c015d688511ad5656450933aff85dac123cd09410a0825c
 * 2	signature	bytes	0xa58af51205a996c87f23c80aeb3cb669001e3f919a88598d063ff6cee9b05fbb8a18dab15a4a5b85eabfd47c26d0f24f11f5f889f6a7fb8cbd5c4ccd7607c449b57a9f0703e1bb63b513cb3e9fcd1d79b0d8f269c7441173054b9284cfb7a13c
 * 3	deposit_data_root	bytes32	0xb4282f23951b5bb3ead393f50dc9468e6166312a4e78f73cc649a8ae16f0d924
 */
/**
 * 0	pubkey	bytes	0x999c0efe0e07405164c9512f3fc949340ebca1ab6bacdca7c7242de871d957a86918b2d1055d1c3b4be0683b5c8719d7
 * 1	withdrawal_credentials	bytes	0x004f58172d06b6d54c015d688511ad5656450933aff85dac123cd09410a0825c
 * 2	signature	bytes	0xa7290722d0b9350504fd44cd166fabc85db76fab07fb2876bff51e0ede2856e6160e4288853cf713cbf3cd7a0541ab1d0ed5e0858c980870f3a4c791264d8b4ee090677f507b599409e86433590ee3a93cae5103d2e03c66bea623e3ccd590ae
 * 3	deposit_data_root	bytes32	0x2a902df8a7a8a1a5860d54ab73c87c1d1d2fcabe0b12106b5cbe42c3680c0000
 */

const pubkey1 =
  "0x91efd3ce6694bc034ad4c23773877da916ed878ff8376610633a9ae4b4d826f4086a6b9b5b197b5e148be658c66c4e9a";
const pubkey2 =
  "0xa3b3eb55b16999ffeff52e5a898af89e4194b7221b2eaf03cb85fd558a390dc042beba94f907db6091b4cf141b18d1f5";
const pubkey3 =
  "0x986e1dee05f3a018bab83343b3b3d96dd573a50ffb03e8145b2964a389ceb14cb3780266b99ef7cf0e16ee34648e2151";
const pubkey4 =
  "0x999c0efe0e07405164c9512f3fc949340ebca1ab6bacdca7c7242de871d957a86918b2d1055d1c3b4be0683b5c8719d7";
const signature1 =
  "0x8bbeff59e3016c98d7daf05ddbd0c71309fae34bf3e544d56ebff030b97bccb83c5abfaab437ec7c652bbafa19eb30661979b82e79fa351d65a50e3a854c1ef0c8537f97ceaf0f334096509cd52f716150e67e17c8085d9622f376553da51181";
const signature2 =
  "0xa2e94c3def1e53d7d1b5a0f037f765868b4bbae3ee59de673bc7ab7b142b929e08f47c1c2a6cdc91aee9442468ab095406b8ce356aef42403febe385424f97d6d109f6423dcb1acc3def45af56e4407416f0773bd18e50d880cb7d3e00ca9932";
const signature3 =
  "0xa58af51205a996c87f23c80aeb3cb669001e3f919a88598d063ff6cee9b05fbb8a18dab15a4a5b85eabfd47c26d0f24f11f5f889f6a7fb8cbd5c4ccd7607c449b57a9f0703e1bb63b513cb3e9fcd1d79b0d8f269c7441173054b9284cfb7a13c";
const signature4 =
  "0xa7290722d0b9350504fd44cd166fabc85db76fab07fb2876bff51e0ede2856e6160e4288853cf713cbf3cd7a0541ab1d0ed5e0858c980870f3a4c791264d8b4ee090677f507b599409e86433590ee3a93cae5103d2e03c66bea623e3ccd590ae";

const {
  MAX_UINT256,
  ZERO_ADDRESS,
  getCurrentBlockTimestamp,
  setTimestamp,
  // setTimestamp,
} = require("../testUtils");

const { solidity } = require("ethereum-waffle");
const chai = require("chai");
const { ethers } = require("hardhat");

chai.use(solidity);
const { expect } = chai;
const randId = 3131313131;
const operatorId = 420420420;
const planetId = 696969696969;
const cometId = 141;
const wrongId = 69;
const provider = waffle.provider;
const INITIAL_A_VALUE = 60;
const SWAP_FEE = 4e6; // 4bps
const ADMIN_FEE = 5e9; // 0
const PERIOD_PRICE_INCREASE_LIMIT = 2e7;
const PERIOD_PRICE_DECREASE_LIMIT = 2e7;
const BOOSTRAP_PERIOD = 3 * 30 * 24 * 60 * 60;
const MAX_MAINTAINER_FEE = 1e9;
describe("StakeUtils", () => {
  let gETH;
  let deployer;
  let oracle;
  let user1;
  let user2;
  let DEFAULT_DWP;
  let DEFAULT_LP_TOKEN;
  let DEFAULT_GETH_INTERFACE;

  const setupTest = deployments.createFixture(async ({ ethers }) => {
    await deployments.fixture(); // ensure you start from a fresh deployments
    const { get } = deployments;
    signers = await ethers.getSigners();

    deployer = signers[0];
    oracle = signers[1];
    planet = signers[2];
    operator = signers[3];
    user1 = signers[4];
    user2 = signers[5];

    gETH = await ethers.getContractAt("gETH", (await get("gETH")).address);
    DEFAULT_DWP = (await get("Swap")).address;
    DEFAULT_LP_TOKEN = (await get("LPToken")).address;
    DEFAULT_GETH_INTERFACE = (await get("ERC20InterfacePermitUpgradable"))
      .address;
    DEFAULT_MINI_GOVERNANCE = (await get("MiniGovernance")).address;
    const TestStakeUtils = await ethers.getContractFactory("TestStakeUtils", {
      libraries: {
        OracleUtils: (await get("OracleUtils")).address,
        MaintainerUtils: (await get("MaintainerUtils")).address,
        StakeUtils: (await get("StakeUtils")).address,
      },
    });

    testContract = await TestStakeUtils.deploy(
      gETH.address,
      deployer.address,
      DEFAULT_DWP,
      DEFAULT_LP_TOKEN,
      DEFAULT_GETH_INTERFACE,
      DEFAULT_MINI_GOVERNANCE,
      BOOSTRAP_PERIOD,
      oracle.address
    );

    await gETH.updateMinterRole(testContract.address);
    await gETH.updateOracleRole(testContract.address);

    // test for 10 am gmt so it doesn't fail when tested on gmt midnight :)
    // to find where settimestamp is used set 90000 to 110000 and test :)
    await setTimestamp(24 * 60 * 60 * 90000 + 60 * 60 * 10 + 10);
  });

  beforeEach(async () => {
    await setupTest();
  });

  describe("Initalization", () => {
    let stakepool;
    let telescope;
    beforeEach(async () => {
      stakepool = await testContract.getStakePoolParams();
      telescope = await testContract.getOracleParams();
    });
    it("correct ORACLE", async () => {
      expect(telescope.ORACLE).to.eq(oracle.address);
    });
    it("correct gETH", async () => {
      expect(stakepool.gETH).to.eq(gETH.address);
    });

    it("correct DEFAULT_DWP", async () => {
      expect(stakepool.DEFAULT_DWP).to.eq(DEFAULT_DWP);
    });

    it("correct DEFAULT_LP_TOKEN", async () => {
      expect(stakepool.DEFAULT_LP_TOKEN).to.eq(DEFAULT_LP_TOKEN);
    });
    it("correct PERIOD_PRICE_INCREASE_LIMIT", async () => {
      expect(telescope.PERIOD_PRICE_INCREASE_LIMIT).to.eq(
        PERIOD_PRICE_INCREASE_LIMIT
      );
    });
    it("correct PERIOD_PRICE_DECREASE_LIMIT", async () => {
      expect(telescope.PERIOD_PRICE_DECREASE_LIMIT).to.eq(
        PERIOD_PRICE_DECREASE_LIMIT
      );
    });
    it("correct MAX_MAINTAINER_FEE", async () => {
      expect(stakepool.MAX_MAINTAINER_FEE).to.eq(MAX_MAINTAINER_FEE);
    });
    it("correct VERIFICATION_INDEX", async () => {
      expect(telescope.VERIFICATION_INDEX).to.eq(String(0));
    });
    it("correct BOOSTRAP_PERIOD", async () => {
      expect(stakepool.BOOSTRAP_PERIOD).to.eq(BOOSTRAP_PERIOD);
    });
    it("correct VALIDATORS_INDEX", async () => {
      expect(telescope.VALIDATORS_INDEX).to.eq(String(0));
    });
  });

  describe("Helper functions", () => {
    describe("authenticate", async () => {
      beforeEach(async () => {
        await testContract.beController(operatorId);
        await testContract.beController(planetId);
        await testContract.beController(cometId);
        await testContract.beController(wrongId);

        await testContract.changeIdMaintainer(operatorId, operator.address);
        await testContract.changeIdMaintainer(planetId, planet.address);
        await testContract.changeIdMaintainer(cometId, user1.address);
        await testContract.changeIdMaintainer(wrongId, user2.address);

        await testContract.setType(operatorId, 4);
        await testContract.setType(planetId, 5);
        await testContract.setType(cometId, 6);
      });

      describe("switchMaintainerFee", () => {
        it("reverts if not maintainer", async () => {
          await expect(
            testContract.connect(planet).switchMaintainerFee(operatorId, 100)
          ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
        });
        it("reverts if type 0", async () => {
          await expect(
            testContract.connect(user2).switchMaintainerFee(wrongId, 100)
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
        });
      });

      describe("approveOperator", () => {
        it("reverts if not maintainer", async () => {
          await expect(
            testContract
              .connect(operator)
              .approveOperator(planetId, operatorId, 100)
          ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
        });
        it("reverts if _planetId or _operatorId type 0", async () => {
          await expect(
            testContract
              .connect(user2)
              .approveOperator(wrongId, operatorId, 100)
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
          await expect(
            testContract.connect(planet).approveOperator(planetId, wrongId, 100)
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
        });
        it("reverts if _planetId is an Operator", async () => {
          await expect(
            testContract
              .connect(operator)
              .approveOperator(operatorId, planetId, 100)
          ).to.be.revertedWith("MaintainerUtils: TYPE NOT allowed");
        });
        it("reverts if _operatorId is a Comet", async () => {
          await expect(
            testContract
              .connect(operator)
              .approveOperator(operatorId, cometId, 100)
          ).to.be.revertedWith("MaintainerUtils: TYPE NOT allowed");
        });
      });

      describe("increaseMaintainerWallet", () => {
        it("reverts if not maintainer", async () => {
          await expect(
            testContract.connect(operator).increaseMaintainerWallet(planetId, {
              value: String(1e17),
            })
          ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
        });
        it("reverts if type 0", async () => {
          await expect(
            testContract.connect(user2).increaseMaintainerWallet(wrongId, {
              value: String(1e17),
            })
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
        });
      });

      describe("decreaseMaintainerWallet", () => {
        it("reverts if not maintainer", async () => {
          await expect(
            testContract
              .connect(operator)
              .decreaseMaintainerWallet(planetId, String(1e2))
          ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
        });
        it("reverts if type 0", async () => {
          await expect(
            testContract
              .connect(user2)
              .decreaseMaintainerWallet(wrongId, String(1e2))
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
        });
      });

      describe("updateValidatorPeriod", () => {
        it("reverts if not maintainer", async () => {
          await expect(
            testContract.connect(operator).updateValidatorPeriod(planetId, 100)
          ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
        });
        it("reverts if type 0", async () => {
          await expect(
            testContract.connect(user2).updateValidatorPeriod(wrongId, 100)
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
        });
        it("reverts if _operatorId is a Comet", async () => {
          await expect(
            testContract.connect(user1).updateValidatorPeriod(cometId, 100)
          ).to.be.revertedWith("MaintainerUtils: TYPE NOT allowed");
        });
      });

      describe("pauseStakingForPool", () => {
        it("reverts if not maintainer", async () => {
          await expect(
            testContract.connect(planet).pauseStakingForPool(operatorId)
          ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
        });
        it("reverts if type 0", async () => {
          await expect(
            testContract.connect(user2).pauseStakingForPool(wrongId)
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
        });
      });

      describe("unpauseStakingForPool", () => {
        it("reverts if not maintainer", async () => {
          await expect(
            testContract.connect(operator).unpauseStakingForPool(planetId)
          ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
        });
        it("reverts if type 0", async () => {
          await expect(
            testContract.connect(user2).unpauseStakingForPool(wrongId)
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
        });
      });

      describe("proposeStake", () => {
        it("reverts if not maintainer of planetId", async () => {
          await expect(
            testContract
              .connect(operator)
              .proposeStake(planetId, planetId, [pubkey1], [signature1])
          ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
        });
        it("reverts if planetId or operatorId type 0", async () => {
          await expect(
            testContract
              .connect(user2)
              .proposeStake(operatorId, wrongId, [pubkey1], [signature1])
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
          await expect(
            testContract
              .connect(operator)
              .proposeStake(wrongId, operatorId, [pubkey1], [signature1])
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
        });
        it("reverts if planetId is an Operator", async () => {
          await expect(
            testContract
              .connect(operator)
              .proposeStake(operatorId, operatorId, [pubkey1], [signature1])
          ).to.be.revertedWith("MaintainerUtils: TYPE NOT allowed");
        });
        it("reverts if operatorId is a Comet", async () => {
          await expect(
            testContract
              .connect(user1)
              .proposeStake(operatorId, cometId, [pubkey1], [signature1])
          ).to.be.revertedWith("MaintainerUtils: TYPE NOT allowed");
        });
      });

      describe("beaconStake", () => {
        it("reverts if not maintainer", async () => {
          await expect(
            testContract.connect(planet).beaconStake(operatorId, [pubkey1])
          ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
        });
        it("reverts if type 0", async () => {
          await expect(
            testContract.connect(user2).beaconStake(wrongId, [pubkey1])
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
        });
        it("reverts if operatorId is a Comet", async () => {
          await expect(
            testContract.connect(user1).beaconStake(cometId, [pubkey1])
          ).to.be.revertedWith("MaintainerUtils: TYPE NOT allowed");
        });
      });

      describe("depositPlanet", () => {
        it("reverts if type 0", async () => {
          await expect(
            testContract.connect(user2).depositPlanet(wrongId, 0, 0)
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
        });
        it("reverts if poolId is an Operator", async () => {
          await expect(
            testContract.connect(user2).depositPlanet(operatorId, 0, 0)
          ).to.be.revertedWith("MaintainerUtils: TYPE NOT allowed");
        });
        it("reverts if poolId is a Comet", async () => {
          await expect(
            testContract.connect(user2).depositPlanet(cometId, 0, 0)
          ).to.be.revertedWith("MaintainerUtils: TYPE NOT allowed");
        });
      });

      describe("withdrawPlanet", () => {
        it("reverts if type 0", async () => {
          await expect(
            testContract.connect(user2).withdrawPlanet(wrongId, 0, 0, 0)
          ).to.be.revertedWith("MaintainerUtils: invalid TYPE");
        });
        it("reverts if poolId is an Operator", async () => {
          await expect(
            testContract.connect(user2).withdrawPlanet(operatorId, 0, 0, 0)
          ).to.be.revertedWith("MaintainerUtils: TYPE NOT allowed");
        });
        it("reverts if poolId is a Comet", async () => {
          await expect(
            testContract.connect(user2).withdrawPlanet(cometId, 0, 0, 0)
          ).to.be.revertedWith("MaintainerUtils: TYPE NOT allowed");
        });
      });
    });

    describe("interfaces", () => {
      beforeEach(async () => {
        await testContract.beController(operatorId);
        await testContract.beController(planetId);
        await testContract.beController(cometId);
        await testContract.beController(wrongId);

        await testContract.changeIdMaintainer(operatorId, operator.address);
        await testContract.changeIdMaintainer(planetId, planet.address);
        await testContract.changeIdMaintainer(cometId, user1.address);
        await testContract.changeIdMaintainer(wrongId, user2.address);

        await testContract.setType(operatorId, 4);
        await testContract.setType(planetId, 5);
        await testContract.setType(cometId, 6);
      });

      describe("setInterface", () => {
        it("reverts if already interface", async () => {
          await testContract
            .connect(planet)
            .setInterface(planetId, DEFAULT_GETH_INTERFACE);
          expect(
            testContract
              .connect(planet)
              .setInterface(planetId, DEFAULT_GETH_INTERFACE)
          ).to.be.revertedWith("StakeUtils: already interface");
        });

        describe("success", () => {
          beforeEach(async () => {
            await testContract
              .connect(planet)
              .setInterface(planetId, DEFAULT_GETH_INTERFACE);
          });
          it("gEth.isinterface=true", async () => {
            expect(
              await gETH.isInterface(DEFAULT_GETH_INTERFACE, planetId)
            ).to.eq(true);
          });
          it("added to interfaces", async () => {
            expect((await testContract.allInterfaces(planetId))[0]).to.eq(
              DEFAULT_GETH_INTERFACE
            );
          });
        });
      });
      describe("unsetInterface", () => {
        beforeEach(async () => {
          await testContract
            .connect(planet)
            .setInterface(planetId, DEFAULT_GETH_INTERFACE);
        });
        it("reverts if already NOT interface", async () => {
          await testContract.connect(planet).unsetInterface(planetId, 0);
          expect(
            testContract.connect(planet).unsetInterface(planetId, 0)
          ).to.be.revertedWith("StakeUtils: already NOT interface");
        });
        describe("success", () => {
          beforeEach(async () => {
            await testContract.connect(planet).unsetInterface(planetId, 0);
          });

          it("gEth.isinterface=false", async () => {
            expect(
              await gETH.isInterface(DEFAULT_GETH_INTERFACE, planetId)
            ).to.eq(false);
          });

          it("removed from to interfaces", async () => {
            expect((await testContract.allInterfaces(planetId))[0]).to.eq(
              ZERO_ADDRESS
            );
            await testContract
              .connect(planet)
              .setInterface(planetId, DEFAULT_GETH_INTERFACE);
            expect((await testContract.allInterfaces(planetId))[1]).to.eq(
              DEFAULT_GETH_INTERFACE
            );
            await testContract.connect(planet).unsetInterface(planetId, 1);
            expect((await testContract.allInterfaces(planetId))[0]).to.eq(
              ZERO_ADDRESS
            );
            expect((await testContract.allInterfaces(planetId))[1]).to.eq(
              ZERO_ADDRESS
            );
          });
        });
      });
    });
  });

  describe("Maintainer Logic", () => {
    beforeEach(async () => {
      await testContract.connect(user1).setType(randId, 4);
      await testContract.connect(user1).beController(randId);
      await testContract
        .connect(user1)
        .changeIdMaintainer(randId, user1.address);
    });

    describe("get/set MaintainerFee", () => {
      describe("Succeeds set", async () => {
        let effectTS;
        beforeEach(async () => {
          await testContract.connect(user1).switchMaintainerFee(randId, 12345);
          effectTS = (await getCurrentBlockTimestamp()) + 3 * 24 * 60 * 60 - 1;
        });
        it("returns old value", async () => {
          expect(await testContract.getMaintainerFee(randId)).to.be.eq(0);
        });
        it("switches after 3 days", async () => {
          await setTimestamp(effectTS);
          expect(await testContract.getMaintainerFee(randId)).to.be.eq(0);
          await setTimestamp(effectTS + 1);
          expect(await testContract.getMaintainerFee(randId)).to.be.eq(12345);
        });
      });
      it("Reverts if > MAX", async () => {
        await testContract.connect(user1).switchMaintainerFee(randId, 10 ** 9);
        await expect(
          testContract.connect(user1).switchMaintainerFee(randId, 10 ** 9 + 1)
        ).to.be.revertedWith("StakeUtils: MAX_MAINTAINER_FEE ERROR");
      });
      it("Reverts if not maintainer", async () => {
        await expect(
          testContract.switchMaintainerFee(randId, 10 ** 9 + 1)
        ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
      });
    });

    describe("changeMaintainer", () => {
      it("Succeeds", async () => {
        await testContract
          .connect(user1)
          .changeIdMaintainer(randId, user2.address);
        expect(await testContract.getMaintainerFromId(randId)).to.be.eq(
          user2.address
        );
      });
      it("Reverts if not controller", async () => {
        await expect(
          testContract.changeIdMaintainer(randId, user2.address)
        ).to.be.revertedWith("MaintainerUtils: sender NOT CONTROLLER");
      });
      it("Reverts if ZERO ADDRESS", async () => {
        await expect(
          testContract.connect(user1).changeIdMaintainer(randId, ZERO_ADDRESS)
        ).to.be.revertedWith("MaintainerUtils: maintainer can NOT be zero");
      });
    });
  });

  // TODO: this needs to be added in portal tests!

  // describe("updateGovernanceParams", () => {
  //   it("Reverts if sender not governance", async () => {
  //     await expect(
  //       testContract
  //         .connect(user1)
  //         .updateGovernanceParams(
  //           DEFAULT_GETH_INTERFACE,
  //           DEFAULT_DWP,
  //           DEFAULT_LP_TOKEN,
  //           MAX_MAINTAINER_FEE,
  //           BOOSTRAP_PERIOD,
  //           PERIOD_PRICE_INCREASE_LIMIT,
  //           PERIOD_PRICE_DECREASE_LIMIT
  //         )
  //     ).to.be.revertedWith("StakeUtils: sender NOT GOVERNANCE");
  //   });

  //   it("Reverts if DEFAULT_GETH_INTERFACE is 0 address", async () => {
  //     await expect(
  //       testContract
  //         .connect(deployer)
  //         .updateGovernanceParams(
  //           ZERO_ADDRESS,
  //           DEFAULT_DWP,
  //           DEFAULT_LP_TOKEN,
  //           MAX_MAINTAINER_FEE,
  //           BOOSTRAP_PERIOD,
  //           PERIOD_PRICE_INCREASE_LIMIT,
  //           PERIOD_PRICE_DECREASE_LIMIT
  //         )
  //     ).to.be.revertedWith("StakeUtils: DEFAULT_gETH_INTERFACE NOT contract");
  //   });

  //   it("Reverts if DEFAULT_gETH_INTERFACE is NOT contract", async () => {
  //     await expect(
  //       testContract
  //         .connect(deployer)
  //         .updateGovernanceParams(
  //           user2.address,
  //           DEFAULT_DWP,
  //           DEFAULT_LP_TOKEN,
  //           MAX_MAINTAINER_FEE,
  //           BOOSTRAP_PERIOD,
  //           PERIOD_PRICE_INCREASE_LIMIT,
  //           PERIOD_PRICE_DECREASE_LIMIT
  //         )
  //     ).to.be.revertedWith("StakeUtils: DEFAULT_gETH_INTERFACE NOT contract");
  //   });

  //   it("Reverts if DEFAULT_DWP is 0 address", async () => {
  //     await expect(
  //       testContract
  //         .connect(deployer)
  //         .updateGovernanceParams(
  //           DEFAULT_GETH_INTERFACE,
  //           ZERO_ADDRESS,
  //           DEFAULT_LP_TOKEN,
  //           MAX_MAINTAINER_FEE,
  //           BOOSTRAP_PERIOD,
  //           PERIOD_PRICE_INCREASE_LIMIT,
  //           PERIOD_PRICE_DECREASE_LIMIT
  //         )
  //     ).to.be.revertedWith("StakeUtils: DEFAULT_DWP NOT contract");
  //   });

  //   it("Reverts if DEFAULT_DWP is NOT contract", async () => {
  //     await expect(
  //       testContract
  //         .connect(deployer)
  //         .updateGovernanceParams(
  //           DEFAULT_GETH_INTERFACE,
  //           user2.address,
  //           DEFAULT_LP_TOKEN,
  //           MAX_MAINTAINER_FEE,
  //           BOOSTRAP_PERIOD,
  //           PERIOD_PRICE_INCREASE_LIMIT,
  //           PERIOD_PRICE_DECREASE_LIMIT
  //         )
  //     ).to.be.revertedWith("StakeUtils: DEFAULT_DWP NOT contract");
  //   });

  //   it("Reverts if DEFAULT_LP_TOKEN is 0 address", async () => {
  //     await expect(
  //       testContract
  //         .connect(deployer)
  //         .updateGovernanceParams(
  //           DEFAULT_GETH_INTERFACE,
  //           DEFAULT_DWP,
  //           ZERO_ADDRESS,
  //           MAX_MAINTAINER_FEE,
  //           BOOSTRAP_PERIOD,
  //           PERIOD_PRICE_INCREASE_LIMIT,
  //           PERIOD_PRICE_DECREASE_LIMIT
  //         )
  //     ).to.be.revertedWith("StakeUtils: DEFAULT_LP_TOKEN NOT contract");
  //   });

  //   it("Reverts if DEFAULT_LP_TOKEN is NOT contract", async () => {
  //     await expect(
  //       testContract
  //         .connect(deployer)
  //         .updateGovernanceParams(
  //           DEFAULT_GETH_INTERFACE,
  //           DEFAULT_DWP,
  //           user2.address,
  //           MAX_MAINTAINER_FEE,
  //           BOOSTRAP_PERIOD,
  //           PERIOD_PRICE_INCREASE_LIMIT,
  //           PERIOD_PRICE_DECREASE_LIMIT
  //         )
  //     ).to.be.revertedWith("StakeUtils: DEFAULT_LP_TOKEN NOT contract");
  //   });

  //   it("Reverts if Max Maintainer Fee > 100%", async () => {
  //     await expect(
  //       testContract
  //         .connect(deployer)
  //         .updateGovernanceParams(
  //           DEFAULT_GETH_INTERFACE,
  //           DEFAULT_DWP,
  //           DEFAULT_LP_TOKEN,
  //           10 ** 10 + 1,
  //           BOOSTRAP_PERIOD,
  //           PERIOD_PRICE_INCREASE_LIMIT,
  //           PERIOD_PRICE_DECREASE_LIMIT
  //         )
  //     ).to.be.revertedWith("StakeUtils: incorrect MAX_MAINTAINER_FEE");
  //   });

  //   it("Reverts if Max Maintainer Fee == 0", async () => {
  //     await expect(
  //       testContract
  //         .connect(deployer)
  //         .updateGovernanceParams(
  //           DEFAULT_GETH_INTERFACE,
  //           DEFAULT_DWP,
  //           DEFAULT_LP_TOKEN,
  //           0,
  //           BOOSTRAP_PERIOD,
  //           PERIOD_PRICE_INCREASE_LIMIT,
  //           PERIOD_PRICE_DECREASE_LIMIT
  //         )
  //     ).to.be.revertedWith("StakeUtils: incorrect MAX_MAINTAINER_FEE");
  //   });

  //   it("Reverts if PERIOD_PRICE_INCREASE_LIMIT is zero", async () => {
  //     await expect(
  //       testContract
  //         .connect(deployer)
  //         .updateGovernanceParams(
  //           DEFAULT_GETH_INTERFACE,
  //           DEFAULT_DWP,
  //           DEFAULT_LP_TOKEN,
  //           MAX_MAINTAINER_FEE,
  //           BOOSTRAP_PERIOD,
  //           0,
  //           PERIOD_PRICE_DECREASE_LIMIT
  //         )
  //     ).to.be.revertedWith("StakeUtils: incorrect PERIOD_PRICE_INCREASE_LIMIT");
  //   });
  //   it("Reverts if PERIOD_PRICE_DECREASE_LIMIT is zero", async () => {
  //     await expect(
  //       testContract
  //         .connect(deployer)
  //         .updateGovernanceParams(
  //           DEFAULT_GETH_INTERFACE,
  //           DEFAULT_DWP,
  //           DEFAULT_LP_TOKEN,
  //           MAX_MAINTAINER_FEE,
  //           BOOSTRAP_PERIOD,
  //           PERIOD_PRICE_INCREASE_LIMIT,
  //           0
  //         )
  //     ).to.be.revertedWith("StakeUtils: incorrect PERIOD_PRICE_DECREASE_LIMIT");
  //   });

  //   it("success, check params", async () => {
  //     const { get } = deployments;
  //     await testContract
  //       .connect(deployer)
  //       .updateGovernanceParams(
  //         DEFAULT_GETH_INTERFACE,
  //         DEFAULT_DWP,
  //         DEFAULT_LP_TOKEN,
  //         MAX_MAINTAINER_FEE,
  //         BOOSTRAP_PERIOD,
  //         PERIOD_PRICE_INCREASE_LIMIT,
  //         PERIOD_PRICE_DECREASE_LIMIT
  //       );

  //     const stakePoolParams = await testContract.getStakePoolParams();
  //     const telescopeParams = await testContract.getOracleParams();

  //     expect(stakePoolParams.DEFAULT_gETH_INTERFACE).to.be.eq(
  //       (await get("ERC20InterfacePermitUpgradable")).address
  //     );
  //     expect(stakePoolParams.DEFAULT_DWP).to.be.eq((await get("Swap")).address);
  //     expect(stakePoolParams.DEFAULT_LP_TOKEN).to.be.eq(
  //       (await get("LPToken")).address
  //     );
  //     expect(stakePoolParams.MAX_MAINTAINER_FEE).to.be.eq(1e9);
  //     expect(stakePoolParams.BOOSTRAP_PERIOD).to.be.eq(3 * 30 * 24 * 60 * 60);
  //     expect(telescopeParams.PERIOD_PRICE_INCREASE_LIMIT).to.be.eq(2e7);
  //     expect(telescopeParams.PERIOD_PRICE_DECREASE_LIMIT).to.be.eq(2e7);
  //   });
  // });

  describe("deployWithdrawalPool", () => {
    let wpoolContract;

    beforeEach(async () => {
      await testContract.deployWithdrawalPool(randId);
      const wpool = await testContract.withdrawalPoolById(randId);
      wpoolContract = await ethers.getContractAt("Swap", wpool);
    });

    describe("check params", () => {
      it("Returns correct A value", async () => {
        expect(await wpoolContract.getA()).to.eq(INITIAL_A_VALUE);
        expect(await wpoolContract.getAPrecise()).to.eq(INITIAL_A_VALUE * 100);
      });

      it("Returns correct fee value", async () => {
        expect((await wpoolContract.swapStorage()).swapFee).to.eq(SWAP_FEE);
      });

      it("Returns correct adminFee value", async () => {
        expect((await wpoolContract.swapStorage()).adminFee).to.eq(ADMIN_FEE);
      });

      describe("LPToken", () => {
        let LPcontract;
        it("init() fails with already init", async () => {
          LPcontract = await ethers.getContractAt(
            "LPToken",
            await testContract.LPTokenById(randId)
          );
          await expect(
            LPcontract.initialize("name", "symbol")
          ).to.be.revertedWith(
            "Initializable: contract is already initialized"
          );
        });

        it("Returns correct name", async () => {
          expect(await LPcontract.name()).to.eq("-Geode LP Token");
        });

        it("Returns correct symbol", async () => {
          expect(await LPcontract.symbol()).to.eq("-LP");
        });
      });
    });
  });

  describe("initiateOperator / initiator", () => {
    beforeEach(async () => {
      await testContract.connect(user1).beController(randId);
      await testContract.connect(user1).setType(randId, 4);
    });

    it("reverts if sender NOT CONTROLLER", async () => {
      await expect(
        testContract.connect(user2).initiateOperator(
          randId, // _id
          1e5, // _fee
          user1.address, // _maintainer
          1e8 // _ValidatorPeriod
        )
      ).to.be.revertedWith("MaintainerUtils: sender NOT CONTROLLER");
    });

    it("reverts if id should be Operator TYPE", async () => {
      await testContract.connect(user1).setType(randId, 5);
      await expect(
        testContract.connect(user1).initiateOperator(
          randId, // _id
          1e5, // _fee
          user1.address, // _maintainer
          1e8 // _ValidatorPeriod
        )
      ).to.be.revertedWith("MaintainerUtils: id NOT correct TYPE");
    });

    describe("success", () => {
      let timestamp;
      beforeEach(async () => {
        await testContract.connect(user1).initiateOperator(
          randId, // _id
          1e5, // _fee
          user1.address, // _maintainer
          1e8 // _ValidatorPeriod
        );
        timestamp = await getCurrentBlockTimestamp();
      });

      it("check initiated parameter is set as timestamp", async () => {
        expect(await testContract.whenInitiated(randId)).to.be.eq(timestamp);
      });

      it("check maintainer is set correctly", async () => {
        setMaintainer = await testContract.getMaintainerFromId(randId);
        expect(setMaintainer).to.be.eq(user1.address);
      });

      it("check fee is correct", async () => {
        setFee = await testContract.getMaintainerFee(randId);
        expect(setFee).to.be.eq(1e5);
      });

      it("check ValidatorPeriod is set correctly", async () => {
        setFee = await testContract.getValidatorPeriod(randId);
        expect(setFee).to.be.eq(1e8);
      });

      it("after success, reverts if already initiated", async () => {
        await expect(
          testContract.connect(user1).initiateOperator(
            randId, // _id
            1e5, // _fee
            user1.address, // _maintainer
            1e8 // _ValidatorPeriod
          )
        ).to.be.revertedWith("MaintainerUtils: already initiated");
      });
    });
  });

  describe("initiatePlanet", () => {
    let wPoolContract;

    describe("success", () => {
      beforeEach(async () => {
        await testContract.connect(user1).beController(randId);
        await testContract.connect(user1).setType(randId, 5);

        await testContract.connect(user1).initiatePlanet(
          randId, // _id
          1e6, // _fee
          user1.address, // _maintainer
          "beautiful-planet", // _interfaceName
          "BP" // _interfaceSymbol
        );
        const wpool = await testContract.withdrawalPoolById(randId);
        wPoolContract = await ethers.getContractAt("Swap", wpool);
      });

      it("who is the owner of DWP", async () => {
        expect(await wPoolContract.owner()).to.be.eq(deployer.address);
      });

      it("check given interface's name and symbol is correctly initialized", async () => {
        const currentInterface = (await testContract.allInterfaces(randId))[0];
        const erc20interface = await ethers.getContractAt(
          "ERC20InterfacePermitUpgradable",
          currentInterface
        );
        expect(await erc20interface.name()).to.be.eq("beautiful-planet");
        expect(await erc20interface.symbol()).to.be.eq("BP");
      });

      it("fee is correct", async () => {
        setFee = await testContract.getMaintainerFee(randId);
        expect(setFee).to.be.eq(1e6);
      });

      it("check WP is approvedForAll on gETH", async () => {
        expect(
          await gETH.isApprovedForAll(
            testContract.address,
            wPoolContract.address
          )
        ).to.be.eq(true);
      });

      it("check pricePerShare for randId is 1 ether", async () => {
        const currentPricePerShare = await gETH.pricePerShare(randId);
        expect(currentPricePerShare).to.be.eq(
          ethers.BigNumber.from(String(1e18))
        );
      });
    });
  });

  describe("Pause Pool functionality", () => {
    beforeEach(async () => {
      await testContract.connect(user1).beController(planetId);
      await testContract
        .connect(user1)
        .changeIdMaintainer(planetId, user1.address);
      await testContract.setType(planetId, 5);
      await testContract.connect(user1).initiatePlanet(
        planetId, // _id
        1e6, // _fee
        user1.address, // _maintainer
        "beautiful-planet", // _interfaceName
        "BP" // _interfaceSymbol
      );
    });

    it("canDeposit returns true in the beginning", async () => {
      expect(await testContract.canDeposit(planetId)).to.be.eq(true);
    });

    it("unpauseStakingForPool reverts in the beginning", async () => {
      await expect(
        testContract.connect(user1).unpauseStakingForPool(planetId)
      ).to.be.revertedWith("StakeUtils: staking already NOT paused");
    });

    describe("pauseStakingForPool functionality", () => {
      beforeEach(async () => {
        await testContract.setType(planetId, 5);
      });

      it("pauseStakingForPool reverts when it is NOT maintainer", async () => {
        await expect(
          testContract.connect(user2).pauseStakingForPool(planetId)
        ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
        expect(await testContract.canDeposit(planetId)).to.be.eq(true);
      });

      describe("pauseStakingForPool succeeds when it is maintainer", () => {
        beforeEach(async () => {
          await testContract.connect(user1).pauseStakingForPool(planetId);
          expect(await testContract.canDeposit(planetId)).to.be.eq(false);
        });

        it("pauseStakingForPool reverts when it is already paused", async () => {
          await expect(
            testContract.connect(user1).pauseStakingForPool(planetId)
          ).to.be.revertedWith("StakeUtils: staking already paused");
          expect(await testContract.canDeposit(planetId)).to.be.eq(false);
        });

        describe("unpauseStakingForPool when it is already paused", () => {
          it("unpauseStakingForPool reverts when it is NOT maintainer", async () => {
            await expect(
              testContract.connect(user2).unpauseStakingForPool(planetId)
            ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");

            expect(await testContract.canDeposit(planetId)).to.be.eq(false);
          });

          describe("unpauseStakingForPool succeeds when called by Maintainer", () => {
            beforeEach(async () => {
              await testContract.connect(user1).unpauseStakingForPool(planetId);

              expect(await testContract.canDeposit(planetId)).to.be.eq(true);
            });

            it("unpauseStakingForPool reverts when it is NOT paused", async () => {
              await expect(
                testContract.connect(user1).unpauseStakingForPool(planetId)
              ).to.be.revertedWith("StakeUtils: staking already NOT paused");
              expect(await testContract.canDeposit(planetId)).to.be.eq(true);
            });
          });
        });
      });
    });
  });

  describe("Operator-Pool cooperation", () => {
    beforeEach(async () => {
      await testContract.setType(operatorId, 4);
      await testContract.setType(planetId, 5);
      await testContract.connect(user1).beController(planetId);
      await testContract
        .connect(user1)
        .changeIdMaintainer(planetId, user1.address);
    });

    it("approveOperator reverts if NOT maintainer", async () => {
      await expect(
        testContract.connect(user2).approveOperator(planetId, operatorId, 69)
      ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
    });

    it("approveOperator succeeds if maintainer", async () => {
      await testContract
        .connect(user1)
        .approveOperator(planetId, operatorId, 69);
      expect(
        await testContract.operatorAllowance(planetId, operatorId)
      ).to.be.eq(69);
    });

    it("operatorAllowance returns correct value", async () => {
      expect(
        await testContract.operatorAllowance(planetId, operatorId)
      ).to.be.eq(0);

      await testContract
        .connect(user1)
        .approveOperator(planetId, operatorId, 69);
      expect(
        await testContract.operatorAllowance(planetId, operatorId)
      ).to.be.eq(69);

      await testContract
        .connect(user1)
        .approveOperator(planetId, operatorId, 31);
      expect(
        await testContract.operatorAllowance(planetId, operatorId)
      ).to.be.eq(31);
    });
  });

  describe("Maintainer Wallet", () => {
    beforeEach(async () => {
      await testContract.setType(operatorId, 4);
      await testContract.connect(user1).beController(operatorId);
      await testContract
        .connect(user1)
        .changeIdMaintainer(operatorId, user1.address);

      await testContract.setType(randId, 4);
      await testContract.connect(user2).beController(randId);
      await testContract
        .connect(user2)
        .changeIdMaintainer(randId, user2.address);
    });

    it("increaseMaintainerWallet reverts if NOT maintainer", async () => {
      await expect(
        testContract.connect(user2).increaseMaintainerWallet(operatorId, {
          value: String(1e17),
        })
      ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
    });

    it("increaseMaintainerWallet succeeds if maintainer", async () => {
      await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
        value: String(2e17),
      });
      expect(
        await testContract.getMaintainerWalletBalance(operatorId)
      ).to.be.eq(ethers.BigNumber.from(String(2e17)));
    });

    it("decreaseMaintainerWallet reverts if NOT maintainer", async () => {
      await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
        value: String(2e17),
      });

      await expect(
        testContract
          .connect(user2)
          .decreaseMaintainerWallet(
            operatorId,
            ethers.BigNumber.from(String(1e17))
          )
      ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
    });

    it("decreaseMaintainerWallet reverts if underflow", async () => {
      await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
        value: String(2e17),
      });

      await expect(
        testContract
          .connect(user1)
          .decreaseMaintainerWallet(operatorId, String(3e17))
      ).to.be.reverted;
    });

    it("decreaseMaintainerWallet reverts if Contract Balance is NOT sufficient", async () => {
      await expect(
        testContract
          .connect(user1)
          .decreaseMaintainerWallet(operatorId, String(3e17))
      ).to.be.revertedWith("StakeUtils: not enough balance in Portal (?)");
    });

    it("decreaseMaintainerWallet reverts if maintainerWallet balance is NOT sufficient", async () => {
      await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
        value: String(2e17),
      });

      await testContract.connect(user2).increaseMaintainerWallet(randId, {
        value: String(2e17),
      });

      await expect(
        testContract
          .connect(user1)
          .decreaseMaintainerWallet(operatorId, String(3e17))
      ).to.be.revertedWith("MaintainerUtils: NOT enough balance in wallet");
    });

    it("decreaseMaintainerWallet succeeds if maintainer", async () => {
      await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
        value: String(2e17),
      });

      await testContract
        .connect(user1)
        .decreaseMaintainerWallet(operatorId, String(1e17));
      expect(
        await testContract.getMaintainerWalletBalance(operatorId)
      ).to.be.eq(ethers.BigNumber.from(String(1e17)));
    });

    it("getMaintainerWalletBalance returns correct value", async () => {
      const prevContractBalance = await testContract.getContractBalance();
      expect(
        await testContract.getMaintainerWalletBalance(operatorId)
      ).to.be.eq(0);

      await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
        value: String(3e17),
      });
      expect(
        await testContract.getMaintainerWalletBalance(operatorId)
      ).to.be.eq(ethers.BigNumber.from(String(3e17)));
      expect(
        (await testContract.getContractBalance()).sub(prevContractBalance)
      ).to.be.eq(ethers.BigNumber.from(String(3e17)));

      await testContract
        .connect(user1)
        .decreaseMaintainerWallet(operatorId, String(1e17));
      expect(
        await testContract.getMaintainerWalletBalance(operatorId)
      ).to.be.eq(ethers.BigNumber.from(String(2e17)));
      expect(
        (await testContract.getContractBalance()).sub(prevContractBalance)
      ).to.be.eq(ethers.BigNumber.from(String(2e17)));
    });
  });

  // TODO: 4 is not comet; comet should not be updated, so this should change as operator "Update Operator Period"
  // TODO: note that comet revert check done somewhere else check "reverts if _operatorId is a Comet" !!!

  // TODO: should check MIN_VALIDATOR_PERIOD
  // TODO: should check MAX_VALIDATOR_PERIOD
  describe("Update Validator Period", () => {
    beforeEach(async () => {
      await testContract.setType(randId, 4);
      await testContract.beController(randId);
      await testContract.changeIdMaintainer(randId, user1.address);
    });
    it("reverts when not called by maintainer", async () => {
      await expect(
        testContract.updateValidatorPeriod(randId, String(1e18))
      ).to.be.revertedWith("MaintainerUtils: sender NOT maintainer");
    });

    it("succeeds", async () => {
      await testContract
        .connect(user1)
        .updateValidatorPeriod(randId, String(1e8));
      await expect(await testContract.getValidatorPeriod(randId)).to.be.eq(
        String(1e8)
      );
    });
  });

  describe("Staking Operations ", () => {
    let wpoolContract;
    let preContBal;
    let preContgETHBal;

    let preUsergETHBal;

    let preSurplus;
    let preTotSup;
    let debt;
    let preSwapBals;
    let preSwapFees;

    beforeEach(async () => {
      await testContract.connect(user1).beController(randId);
      await testContract
        .connect(user1)
        .changeIdMaintainer(randId, user1.address);
    });

    describe("depositPlanet", () => {
      beforeEach(async () => {
        await testContract.setType(randId, 5);
        await testContract.connect(user1).beController(randId);
        await testContract
          .connect(user1)
          .changeIdMaintainer(randId, user1.address);
        await testContract.connect(user1).initiatePlanet(
          randId, // _id
          1e5, // _fee
          user1.address, // _maintainer
          "beautiful-planet", // _interfaceName
          "BP" // _interfaceSymbol
        );
        await testContract.deployWithdrawalPool(randId);
        const wpool = await testContract.withdrawalPoolById(randId);
        wpoolContract = await ethers.getContractAt("Swap", wpool);

        await testContract.setPricePerShare(String(1e18), randId);

        await testContract
          .connect(deployer)
          .mintgETH(deployer.address, randId, String(1e20));

        await gETH.connect(deployer).setApprovalForAll(wpool, true);

        // initially there is no debt
        await wpoolContract
          .connect(deployer)
          .addLiquidity([String(1e20), String(1e20)], 0, MAX_UINT256, {
            value: String(1e20),
          });

        debt = await wpoolContract.getDebt();
        expect(debt).to.be.eq(0);
        preUserBal = await provider.getBalance(user1.address);
        preUsergETHBal = await gETH.balanceOf(user1.address, randId);

        preContBal = await provider.getBalance(testContract.address);
        preContgETHBal = await gETH.balanceOf(testContract.address, randId);

        preSurplus = ethers.BigNumber.from(
          await testContract.surplusById(randId)
        );
        preTotSup = await gETH.totalSupply(randId);

        preSwapBals = [
          await wpoolContract.getTokenBalance(0),
          await wpoolContract.getTokenBalance(1),
        ];
      });

      it("reverts when wrongId is given", async () => {
        await expect(
          testContract.connect(user1).depositPlanet(wrongId, 0, MAX_UINT256, {
            value: String(1e18),
          })
        ).to.be.reverted;
      });

      it("reverts when pool is paused", async () => {
        await testContract.connect(user1).pauseStakingForPool(randId);
        await expect(
          testContract.depositPlanet(randId, 0, MAX_UINT256, {
            value: String(2e18),
          })
        ).to.be.revertedWith("StakeUtils: minting paused");
      });

      describe("succeeds", () => {
        let gasUsed;

        describe("when NO buyback (no pause, no debt), and while oracle active", () => {
          beforeEach(async () => {
            await setTimestamp(24 * 60 * 60 * 100000 + 100);
            // ensure that it starts as zero.
            expect(await testContract.dailyMintBuffer(randId)).to.be.eq(0);

            const tx = await testContract
              .connect(user1)
              .depositPlanet(randId, 0, MAX_UINT256, {
                value: String(1e18),
              });
            const receipt = await tx.wait();
            gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);
          });

          it("user lost ether more than stake (+gas)", async () => {
            const newBal = await provider.getBalance(user1.address);
            expect(newBal.add(gasUsed)).to.be.eq(
              ethers.BigNumber.from(String(preUserBal)).sub(String(1e18))
            );
          });

          it("user gained gETH (mintedAmount)", async () => {
            const price = await testContract.getPricePerShare(randId);
            expect(price).to.be.eq(String(1e18));
            const mintedAmount = ethers.BigNumber.from(String(1e18))
              .div(price)
              .mul(String(1e18));
            const newBal = await gETH.balanceOf(user1.address, randId);
            expect(newBal).to.be.eq(preUsergETHBal.add(mintedAmount));
          });

          it("contract gained ether = minted gETH", async () => {
            const newBal = await provider.getBalance(testContract.address);
            expect(newBal).to.be.eq(String(preContBal.add(String(1e18))));
          });

          it("contract gEth bal did not change", async () => {
            const newBal = await gETH.balanceOf(testContract.address, randId);
            expect(newBal).to.be.eq(preContgETHBal);
          });

          it("id surplus increased", async () => {
            const newSur = await testContract.surplusById(randId);
            expect(newSur.toString()).to.be.eq(
              String(preSurplus.add(String(1e18)))
            );
          });

          it("mintBuffer increased = minted gETH ", async () => {
            const dailyMintBuffer = await testContract.dailyMintBuffer(randId);
            const price = await testContract.getPricePerShare(randId);
            expect(dailyMintBuffer).to.be.eq(
              ethers.BigNumber.from(String(1e18)).div(price).mul(String(1e18))
            );
          });

          it("gETH minted ", async () => {
            // minted amount from ORACLE PRICE
            const price = await testContract.getPricePerShare(randId);
            expect(price).to.be.eq(String(1e18));
            const mintedAmount = ethers.BigNumber.from(String(1e18))
              .div(price)
              .mul(String(1e18));
            const TotSup = await gETH.totalSupply(randId);
            expect(TotSup.toString()).to.be.eq(
              String(preTotSup.add(mintedAmount))
            );
          });

          it("swapContract gETH balances NOT changed", async () => {
            const swapBals = [
              await wpoolContract.getTokenBalance(0),
              await wpoolContract.getTokenBalance(1),
            ];
            expect(swapBals[0]).to.be.eq(preSwapBals[0]);
            expect(swapBals[1]).to.be.eq(preSwapBals[1]);
          });
        });

        describe("when paused pool is unpaused and not balanced", () => {
          let gasUsed;
          let newPreUserBal;

          beforeEach(async () => {
            await testContract.connect(user1).pauseStakingForPool(randId);
            await testContract.connect(user1).unpauseStakingForPool(randId);
            newPreUserBal = await provider.getBalance(user1.address);
            await testContract
              .connect(deployer)
              .depositPlanet(randId, 0, MAX_UINT256, {
                value: String(1e20),
              });
            await wpoolContract
              .connect(deployer)
              .addLiquidity([String(0), String(1e20)], 0, MAX_UINT256);
            debt = await wpoolContract.getDebt();
            preSwapBals = [
              await wpoolContract.getTokenBalance(0),
              await wpoolContract.getTokenBalance(1),
            ];
            preContBal = await provider.getBalance(testContract.address);
            preSurplus = ethers.BigNumber.from(
              await testContract.surplusById(randId)
            );
            const tx = await testContract
              .connect(user1)
              .depositPlanet(randId, 0, MAX_UINT256, {
                value: String(5e20),
              });
            const receipt = await tx.wait();
            gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);
          });

          it("user lost ether more than stake (+gas)", async () => {
            const newBal = await provider.getBalance(user1.address);
            expect(newBal).to.be.eq(
              ethers.BigNumber.from(String(newPreUserBal))
                .sub(String(5e20))
                .sub(gasUsed)
            );
          });

          it("user gained gether more than minted amount (+ wrapped) ", async () => {
            const price = await testContract.getPricePerShare(randId);
            expect(price).to.be.eq(String(1e18));
            const mintedAmount = ethers.BigNumber.from(String(1e18))
              .div(price)
              .mul(String(1e18));
            const newBal = await gETH.balanceOf(user1.address, randId);
            expect(newBal).to.be.gt(preUsergETHBal.add(mintedAmount));
          });

          it("contract gained ether = minted ", async () => {
            const newBal = await provider.getBalance(testContract.address);
            expect(newBal).to.be.eq(
              String(
                preContBal.add(ethers.BigNumber.from("450143212807943082239")) // lower than 5e20 since wp got its part
              )
            );
          });

          it("contract gEth bal did not change", async () => {
            const newBal = await gETH.balanceOf(testContract.address, randId);
            expect(newBal).to.be.eq(preContgETHBal);
          });

          it("id surplus increased", async () => {
            const newSur = await testContract.surplusById(randId);
            expect(newSur).to.be.eq(
              String(
                preSurplus.add(ethers.BigNumber.from("450143212807943082239")) // lower than 5e20 since wp got its part
              )
            );
          });

          it("swapContract gETH and Ether balance changed accordingly", async () => {
            const swapBals = [
              await wpoolContract.getTokenBalance(0),
              await wpoolContract.getTokenBalance(1),
            ];
            expect(swapBals[0]).to.be.eq(
              ethers.BigNumber.from(String(preSwapBals[0])).add(debt)
            );
            expect(swapBals[1]).to.be.lt(preSwapBals[1]); // gEth
          });
        });
      });
    });

    describe("Withdrawals", () => {
      beforeEach(async () => {
        await testContract.setType(randId, 5);

        await testContract.beController(randId);

        await testContract.initiatePlanet(
          randId, // _id
          1e5, // _fee
          user2.address, // _maintainer
          "beautiful-planet", // _interfaceName
          "BP" // _interfaceSymbol
        );

        const wpool = await testContract.withdrawalPoolById(randId);
        wpoolContract = await ethers.getContractAt("Swap", wpool);
        await gETH.connect(deployer).setApprovalForAll(wpool, true);
        await gETH.connect(user1).setApprovalForAll(wpool, true);

        await testContract
          .connect(deployer)
          .depositPlanet(randId, 0, MAX_UINT256, { value: String(1e20) });

        // initially there is no debt
        await wpoolContract
          .connect(deployer)
          .addLiquidity([String(1e19), String(1e19)], 0, MAX_UINT256, {
            value: String(1e19),
          });

        debt = await wpoolContract.getDebt();
        expect(debt).to.be.eq(0);
        preUserBal = await provider.getBalance(user1.address);
        preUsergETHBal = await gETH.balanceOf(user1.address, randId);
        expect(preUsergETHBal).to.be.eq(0);

        preContBal = await provider.getBalance(testContract.address);
        expect(preContBal).to.be.eq(String(1e20));
        preContgETHBal = await gETH.balanceOf(testContract.address, randId);
        expect(preContgETHBal).to.be.eq(0);

        preSurplus = ethers.BigNumber.from(
          await testContract.surplusById(randId)
        );
        expect(preSurplus).to.be.eq(String(1e20));
        preTotSup = await gETH.totalSupply(randId);
        expect(preTotSup).to.be.eq(String(1e20));

        preSwapBals = [
          await wpoolContract.getTokenBalance(0),
          await wpoolContract.getTokenBalance(1),
        ];
        expect(preSwapBals[0]).to.be.eq(String(1e19));
        expect(preSwapBals[1]).to.be.eq(String(1e19));

        preSwapFees = [
          await wpoolContract.getAdminBalance(0),
          await wpoolContract.getAdminBalance(1),
        ];
        expect(preSwapFees[0]).to.be.eq(0);
        expect(preSwapFees[1]).to.be.eq(0);
      });

      describe("donateBalancedFees", () => {
        it("reverts if not enough gETH", async () => {
          await expect(
            testContract
              .connect(user1)
              .donateBalancedFees(randId, String(1e19), String(1e19))
          ).to.be.revertedWith("ERC1155: insufficient balance for transfer");
        });
        it("reverts if burnSurplus, burnGeth doesn't respect the oracle price", async () => {
          await gETH.safeTransferFrom(
            deployer.address,
            testContract.address,
            randId,
            String(1e19),
            "0x"
          );
          await expect(
            testContract
              .connect(user1)
              .donateBalancedFees(randId, String(2e19), String(1e19))
          ).to.be.revertedWith("SwapUtils: MUST respect to derivative price");

          await testContract.setPricePerShare(String(2e18), randId);
          await expect(
            testContract
              .connect(user1)
              .donateBalancedFees(randId, String(1e19), String(1e19))
          ).to.be.revertedWith("SwapUtils: MUST respect to derivative price");
        });
        describe("success", () => {
          beforeEach(async () => {
            await gETH.safeTransferFrom(
              deployer.address,
              testContract.address,
              randId,
              String(1e19),
              "0x"
            );
            preContgETHBal = await gETH.balanceOf(testContract.address, randId);
            await testContract
              .connect(user1)
              .donateBalancedFees(randId, String(1e19), String(1e19));
            // 1e19 * 0.04% =
            // 4e15/4 => goes as Eth to LP,
            // 4e15/4 => goes as gEth to LP,
            // 4e15/4 => goes as Eth to admin,
            // 4e15/4 => goes as gEth to admin,
          });
          it("DWP balances increased accordingly", async () => {
            const postSwapBals = [
              await wpoolContract.getTokenBalance(0),
              await wpoolContract.getTokenBalance(1),
            ];
            expect(postSwapBals[0]).to.be.eq(preSwapBals[0].add(String(1e15)));
            expect(postSwapBals[1]).to.be.eq(preSwapBals[1].add(String(1e15)));
          });
          it("DWP fees increased accordingly", async () => {
            const postSwapFees = [
              await wpoolContract.getAdminBalance(0),
              await wpoolContract.getAdminBalance(1),
            ];
            expect(postSwapFees[0]).to.be.eq(preSwapFees[0].add(String(1e15)));
            expect(postSwapFees[1]).to.be.eq(preSwapFees[1].add(String(1e15)));
          });
          it("contract ETH balance decreased accordingly", async () => {
            expect(await provider.getBalance(testContract.address)).to.be.eq(
              preContBal.sub(String(2e15))
            );
          });
          it("contract gETH balance decreased accordingly", async () => {
            expect(await gETH.balanceOf(testContract.address, randId)).to.be.eq(
              preContgETHBal.sub(String(2e15))
            );
          });
          it("surplus stands still", async () => {
            expect(await testContract.surplusById(randId)).to.be.eq(preSurplus);
          });
          it("debt stands still", async () => {
            expect(await wpoolContract.getDebt()).to.be.eq(debt);
          });
        });
      });

      describe("burnSurplus", () => {
        let prevBurnBuffer;
        it("reverts if not enough gETH", async () => {
          await expect(
            testContract.connect(user1).burnSurplus(randId, String(1e19))
          ).to.be.revertedWith("ERC1155: insufficient balance for transfer");
        });
        describe("success", () => {
          beforeEach(async () => {
            await setTimestamp(100000 * 24 * 3600);
            expect(await testContract.isOracleActive()).to.be.eq(true);
          });
          describe("g-price = 1", () => {
            beforeEach(async () => {
              await gETH.safeTransferFrom(
                deployer.address,
                testContract.address,
                randId,
                String(1e19),
                "0x"
              );
              preContgETHBal = await gETH.balanceOf(
                testContract.address,
                randId
              );
              prevBurnBuffer = await testContract.dailyMintBuffer(randId);
              await testContract
                .connect(user1)
                .burnSurplus(randId, String(1e19));
            });
            it("decreased TS accordingly", async () => {
              expect(await gETH.totalSupply(randId)).to.be.eq(
                preTotSup.sub(String(1e19)).add(String(2e15))
              );
            });
            it("decreased contract gETH accordingly", async () => {
              expect(
                await gETH.balanceOf(testContract.address, randId)
              ).to.be.eq(preContgETHBal.sub(String(1e19)));
            });
            it("decreased surplus accordingly", async () => {
              expect(await testContract.surplusById(randId)).to.be.eq(
                preSurplus.sub(String(1e19))
              );
            });
            it("donated correct amount as fees", async () => {
              const postBals = [
                await wpoolContract.getTokenBalance(0),
                await wpoolContract.getTokenBalance(1),
              ];
              expect(postBals[0]).to.be.eq(preSwapBals[0].add(String(1e15)));
              expect(postBals[1]).to.be.eq(preSwapBals[1].add(String(1e15)));
            });
            it("increased burnBuffer accordingly", async () => {
              expect(await testContract.dailyBurnBuffer(randId)).to.be.eq(
                prevBurnBuffer.add(String(1e19))
              );
            });
          });
          describe("g-price = 5", async () => {
            beforeEach(async () => {
              await testContract.setPricePerShare(String(5e18), randId);
              await gETH.safeTransferFrom(
                deployer.address,
                testContract.address,
                randId,
                String(1e19),
                "0x"
              );
              preContgETHBal = await gETH.balanceOf(
                testContract.address,
                randId
              );
              await testContract
                .connect(user1)
                .burnSurplus(randId, String(1e19));
            });
            it("decreased TS accordingly", async () => {
              expect(await gETH.totalSupply(randId)).to.be.eq(
                preTotSup.sub(String(1e19)).add(String(2e15))
              );
            });
            it("decreased contract gETH accordingly", async () => {
              expect(
                await gETH.balanceOf(testContract.address, randId)
              ).to.be.eq(preContgETHBal.sub(String(1e19)));
            });
            it("decreased surplus accordingly", async () => {
              expect(await testContract.surplusById(randId)).to.be.eq(
                preSurplus.sub(String(5e19))
              );
            });
            it("donated correct amount as fees", async () => {
              const postBals = [
                await wpoolContract.getTokenBalance(0),
                await wpoolContract.getTokenBalance(1),
              ];
              expect(postBals[0]).to.be.eq(preSwapBals[0].add(String(5e15)));
              expect(postBals[1]).to.be.eq(preSwapBals[1].add(String(1e15)));
            });
            it("increased burnBuffer accordingly", async () => {
              expect(await testContract.dailyBurnBuffer(randId)).to.be.eq(
                prevBurnBuffer.add(String(1e19))
              );
            });
          });
        });
      });

      describe("withdrawPlanet", () => {
        it("reverts if deadline did not met", async () => {
          await expect(
            testContract.withdrawPlanet(randId, String(9e20), 0, 0)
          ).to.be.revertedWith("StakeUtils: deadline not met");
        });
        it("reverts if not allowed for gETH", async () => {
          await expect(
            testContract.withdrawPlanet(randId, String(1e18), 0, MAX_UINT256)
          ).to.be.revertedWith(
            "ERC1155: caller is not owner nor approved nor an allowed interface"
          );
        });
        it("reverts if not enough gETH", async () => {
          await gETH
            .connect(deployer)
            .setApprovalForAll(testContract.address, true);
          await expect(
            testContract.withdrawPlanet(randId, String(9e20), 0, MAX_UINT256)
          ).to.be.revertedWith("ERC1155: insufficient balance for transfer");
        });

        describe("before BOOSTRAP_PERIOD", async () => {
          it("reverts if minETH did not met", async () => {
            await gETH
              .connect(deployer)
              .setApprovalForAll(testContract.address, true);
            await expect(
              testContract.withdrawPlanet(
                randId,
                String(1e18),
                MAX_UINT256,
                MAX_UINT256
              )
            ).to.be.revertedWith("Swap didn't result in min tokens");
          });

          describe("success", () => {
            let calcPay;
            beforeEach(async () => {
              await gETH
                .connect(deployer)
                .setApprovalForAll(testContract.address, true);
              calcPay = await wpoolContract.calculateSwap(1, 0, String(1e18));
              preSurplus = await testContract.surplusById(randId);
              await testContract.withdrawPlanet(
                randId,
                String(1e18),
                0,
                MAX_UINT256
              );
            });
            it("correct EthToSend", async () => {
              expect(await testContract.lastEthToSend()).to.be.eq(calcPay);
            });
            it("surplus did not change", async () => {
              expect(await testContract.surplusById(randId)).to.be.eq(
                preSurplus
              );
            });
          });
        });

        describe("after BOOSTRAP_PERIOD", () => {
          beforeEach(async () => {
            await setTimestamp(
              (await getCurrentBlockTimestamp()) + BOOSTRAP_PERIOD + 30 * 60 + 1
            );
            expect(await testContract.isOracleActive()).to.be.eq(false);
            await testContract.mintgETH(user1.address, randId, String(2e20));
            await gETH
              .connect(user1)
              .setApprovalForAll(testContract.address, true);
          });

          describe("success: withdrawnGeth <= surplus", () => {
            beforeEach(async () => {
              await testContract
                .connect(user1)
                .withdrawPlanet(randId, String(1e18), 0, MAX_UINT256);
            });
            it("correct EthToSend", async () => {
              expect(await testContract.lastEthToSend()).to.be.eq(
                ethers.BigNumber.from(String(1e18))
                  .mul(String(9996))
                  .div(String(10000)) // sub fee
              );
            });
            it("surplus decreased", async () => {
              expect(await testContract.surplusById(randId)).to.be.eq(
                preSurplus.sub(String(1e18))
              );
            });
          });

          describe("success: withdrawnGeth > surplus", () => {
            let calcPay;
            beforeEach(async () => {
              calcPay = ethers.BigNumber.from(String(1e20))
                .mul(String(9996))
                .div(String(10000))
                .add(await wpoolContract.calculateSwap(1, 0, String(1e20)));
              await testContract
                .connect(user1)
                .withdrawPlanet(randId, String(2e20), 0, MAX_UINT256);
            });
            it("more Eth received than calculated in balanced pool", async () => {
              expect(await testContract.lastEthToSend()).to.be.gt(calcPay);
            });
            it("surplus drained", async () => {
              expect(await testContract.surplusById(randId)).to.be.eq(0);
            });
          });
        });
      });
    });

    describe("proposeStake", () => {
      beforeEach(async () => {
        await testContract.setMONOPOLY_THRESHOLD(1000);
        await testContract.setType(operatorId, 4);
        await testContract.beController(operatorId);
        await testContract.initiateOperator(
          operatorId, // _id
          1e5, // _fee
          user1.address, // _maintainer
          1e8
        );
        await testContract.setType(planetId, 5);
        await testContract.beController(planetId);
        await testContract.initiatePlanet(
          planetId, // _id
          1e5, // _fee
          user2.address, // _maintainer
          "beautiful-planet", // _interfaceName
          "BP" // _interfaceSymbol
        );
      });

      it("reverts if pubkeys and signatures are not same length", async () => {
        await expect(
          testContract
            .connect(user1)
            .proposeStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1]
            )
        ).to.be.revertedWith(
          "StakeUtils: pubkeys and signatures NOT same length"
        );
      });

      it("reverts if not enough surplus", async () => {
        await testContract.setSurplus(planetId, 0);
        await expect(
          testContract
            .connect(user1)
            .proposeStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1]
            )
        ).to.be.revertedWith(
          "StakeUtils: pubkeys and signatures NOT same length"
        );
      });

      it("1 to 64 nodes per transaction", async () => {
        await expect(
          testContract
            .connect(user1)
            .proposeStake(
              planetId,
              operatorId,
              Array(65).fill(pubkey1),
              Array(65).fill(signature1)
            )
        ).to.be.revertedWith("StakeUtils: MAX 64 nodes");

        await expect(
          testContract.connect(user1).proposeStake(planetId, operatorId, [], [])
        ).to.be.revertedWith("StakeUtils: MAX 64 nodes");
      });

      it("reverts if monopoly", async () => {
        await testContract.setMONOPOLY_THRESHOLD(1);
        await expect(
          testContract
            .connect(user1)
            .proposeStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1, signature2]
            )
        ).to.be.revertedWith("StakeUtils: IceBear does NOT like monopolies");
      });

      it("NOT enough allowance", async () => {
        await expect(
          testContract
            .connect(user1)
            .proposeStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1, signature2]
            )
        ).to.be.revertedWith("StakeUtils: NOT enough allowance");

        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 1);

        await expect(
          testContract
            .connect(user1)
            .proposeStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1, signature2]
            )
        ).to.be.revertedWith("StakeUtils: NOT enough allowance");
      });

      it("Pubkey is already alienated", async () => {
        await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
          value: String(2e18),
        });

        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 2);
        await testContract.alienatePubKey(pubkey2);
        await testContract.setSurplus(planetId, String(1e20));
        await testContract.Receive({ value: String(1e20) });
        await expect(
          testContract
            .connect(user1)
            .proposeStake(planetId, operatorId, [pubkey2], [signature2])
        ).to.be.revertedWith("StakeUtils: Pubkey already used or alienated");
      });

      it("PUBKEY_LENGTH ERROR", async () => {
        await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
          value: String(2e18),
        });

        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 2);
        await testContract.setSurplus(planetId, String(1e20));
        await testContract.Receive({ value: String(1e20) });
        await expect(
          testContract
            .connect(user1)
            .proposeStake(
              planetId,
              operatorId,
              [pubkey2 + "aefe"],
              [signature2]
            )
        ).to.be.revertedWith("StakeUtils: PUBKEY_LENGTH ERROR");
      });

      it("SIGNATURE_LENGTH ERROR", async () => {
        await testContract.setSurplus(planetId, String(1e20));
        await testContract.Receive({ value: String(1e20) });
        await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
          value: String(2e18),
        });

        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 2);

        await expect(
          testContract
            .connect(user1)
            .proposeStake(
              planetId,
              operatorId,
              [pubkey2],
              [signature2 + "aefe"]
            )
        ).to.be.revertedWith("StakeUtils: SIGNATURE_LENGTH ERROR");
      });

      describe("Success", () => {
        let prevSurplus;
        let prevSecured;
        let prevAllowance;
        let prevWalletBalance;
        let prevProposedValidators;
        let prevContractBalance;

        beforeEach(async () => {
          await setTimestamp(
            (await getCurrentBlockTimestamp()) + 24 * 60 * 60 * 7 + 1
          );
          await testContract
            .connect(user2)
            .approveOperator(planetId, operatorId, 3);

          await testContract
            .connect(user1)
            .increaseMaintainerWallet(operatorId, {
              value: String(5e18),
            });
          await testContract.setSurplus(planetId, String(64e18));
          await testContract.Receive({ value: String(64e18) });
          prevSurplus = await testContract.surplusById(planetId);
          prevSecured = await testContract.securedById(planetId);
          prevAllowance = await testContract.operatorAllowance(
            planetId,
            operatorId
          );
          prevWalletBalance = await testContract.getMaintainerWalletBalance(
            operatorId
          );
          prevProposedValidators = await testContract.proposedValidatorsById(
            planetId,
            operatorId
          );
          prevTotalProposedValidators =
            await testContract.totalProposedValidatorsById(operatorId);
          prevContractBalance = await testContract.getContractBalance();
          await testContract
            .connect(user1)
            .proposeStake(
              planetId,
              operatorId,
              [pubkey1, pubkey2],
              [signature1, signature2]
            );
        });

        describe("if prisoned", () => {
          let releaseTS;
          beforeEach(async () => {
            await testContract.setSurplus(planetId, String(64e18));
            await testContract.Receive({ value: String(64e18) });
            await testContract.connect(oracle).regulateOperators(
              [],
              [],
              [
                [operatorId, 12421],
                [planetId, 1312],
              ]
            );
            releaseTS = (await getCurrentBlockTimestamp()) + 30 * 24 * 60 * 60;
          });

          it("reverts", async () => {
            await expect(
              testContract
                .connect(user1)
                .proposeStake(planetId, operatorId, [pubkey4], [signature4])
            ).to.be.revertedWith(
              "StakeUtils: operator is in prison, get in touch with governance"
            );
          });
          it("success after released", async () => {
            await setTimestamp(releaseTS);
            await testContract
              .connect(user1)
              .proposeStake(planetId, operatorId, [pubkey4], [signature4]);
          });
        });

        it("Contract balance decreased accordingly (2 eth)", async () => {
          expect(String(2e18)).to.be.eq(
            prevContractBalance.sub(await testContract.getContractBalance())
          );
        });

        it("surplus decreased by 32 eth per pubkey", async () => {
          expect(String(64e18)).to.be.eq(
            prevSurplus.sub(await testContract.surplusById(planetId))
          );
        });

        it("secured increased by 32 eth per pubkey", async () => {
          expect(String(64e18)).to.be.eq(
            (await testContract.securedById(planetId)).sub(prevSecured)
          );
        });

        it("Allowance stays same", async () => {
          expect(
            await testContract.operatorAllowance(planetId, operatorId)
          ).to.be.eq(prevAllowance);
        });

        it("maintainerWallet decreased accordingly", async () => {
          expect(
            await testContract.getMaintainerWalletBalance(operatorId)
          ).to.be.eq(prevWalletBalance.sub(String(2e18)));
        });

        it("proposedValidators increased accordingly", async () => {
          expect(
            await testContract.proposedValidatorsById(planetId, operatorId)
          ).to.be.eq(prevProposedValidators + 2);
        });

        it("reverts if pubKey is already created", async () => {
          await testContract.setSurplus(planetId, String(100e18));
          await testContract.Receive({ value: String(64e18) });
          await expect(
            testContract
              .connect(user1)
              .proposeStake(planetId, operatorId, [pubkey1], [signature1])
          ).to.be.revertedWith("StakeUtils: Pubkey already used or alienated");
        });

        it("reverts if allowance is not enough after success", async () => {
          await expect(
            testContract
              .connect(user1)
              .proposeStake(
                planetId,
                operatorId,
                [pubkey3, pubkey4],
                [signature3, signature4]
              )
          ).to.be.revertedWith("StakeUtils: NOT enough allowance");
        });

        it("VALIDATORS_INDEX correct", async () => {
          expect(
            (await testContract.getOracleParams()).VALIDATORS_INDEX
          ).to.be.eq(String(2));
        });

        it("validator params are correct", async () => {
          const val1 = await testContract.getValidatorData(pubkey1);
          const val2 = await testContract.getValidatorData(pubkey2);
          const signatures = [signature1, signature2];
          [val1, val2].forEach(function (vd, i) {
            expect(vd.poolId).to.be.eq(planetId);
            expect(vd.operatorId).to.be.eq(operatorId);
            expect(vd.poolFee).to.be.eq(1e5);
            expect(vd.operatorFee).to.be.eq(1e5);
            expect(vd.index).to.be.eq(i + 1);
            expect(vd.state).to.be.eq(1);
            expect(vd.signature).to.be.eq(signatures[i]);
          });
        });
      });
    });

    describe("canStake", () => {
      beforeEach(async () => {
        await testContract.setMONOPOLY_THRESHOLD(1000);
        await testContract.setType(operatorId, 4);
        await testContract.beController(operatorId);
        await testContract.initiateOperator(
          operatorId, // _id
          1e5, // _fee
          user1.address, // _maintainer
          1e8
        );
        await testContract.setType(planetId, 5);
        await testContract.beController(planetId);
        await testContract.initiatePlanet(
          planetId, // _id
          1e5, // _fee
          user2.address, // _maintainer
          "beautiful-planet", // _interfaceName
          "BP" // _interfaceSymbol
        );

        await testContract.setSurplus(planetId, String(1e20));
        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 3);

        await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
          value: String(5e18),
        });

        await testContract
          .connect(user1)
          .proposeStake(
            planetId,
            operatorId,
            [pubkey1, pubkey2],
            [signature1, signature2]
          );
      });

      it("returns false if state is not pending", async () => {
        expect(await testContract.canStake(pubkey3)).to.be.eq(false);
      });

      it("returns false if VERIFICATION_INDEX is smaller than validator's index", async () => {
        await testContract.connect(oracle).updateVerificationIndex(5000, 1, []);
        expect(await testContract.canStake(pubkey2)).to.be.eq(false);
      });

      it("returns true if verified", async () => {
        await testContract.connect(oracle).updateVerificationIndex(5000, 2, []);
        expect(await testContract.canStake(pubkey2)).to.be.eq(true);
      });
    });

    describe("beaconStake", () => {
      let prevSecured;
      let prevActiveValidators;
      let prevMaintainerWallet;
      let prevContractBalance;
      beforeEach(async () => {
        await testContract.setMONOPOLY_THRESHOLD(1000);
        await testContract.setType(operatorId, 4);
        await testContract.beController(operatorId);
        await testContract.initiateOperator(
          operatorId, // _id
          1e5, // _fee
          user1.address, // _maintainer
          1e8
        );
        await testContract.setType(planetId, 5);
        await testContract.beController(planetId);
        await testContract.initiatePlanet(
          planetId, // _id
          1e5, // _fee
          user2.address, // _maintainer
          "beautiful-planet", // _interfaceName
          "BP" // _interfaceSymbol
        );
        await testContract.setPricePerShare(String(1e18), planetId);
        await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
          value: String(6e18),
        });
        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 5);
        await testContract.setSurplus(planetId, String(1e20));
        await testContract.Receive({ value: String(1e20) });
        await testContract
          .connect(user1)
          .proposeStake(
            planetId,
            operatorId,
            [pubkey1, pubkey2, pubkey3],
            [signature1, signature2, signature3]
          );
        prevActiveValidators = await testContract.activeValidatorsById(
          planetId,
          operatorId
        );
        prevMaintainerWallet = await testContract
          .connect(user1)
          .getMaintainerWalletBalance(operatorId);
      });

      it("reverts if Oracle is active", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 + 10);
        await expect(
          testContract
            .connect(user1)
            .beaconStake(operatorId, Array(1).fill(pubkey1))
        ).to.be.revertedWith("StakeUtils: ORACLE is active");
      });

      it("1 to 64 nodes per transaction", async () => {
        await expect(
          testContract
            .connect(user1)
            .beaconStake(operatorId, Array(65).fill(pubkey1))
        ).to.be.revertedWith("StakeUtils: MAX 64 nodes");

        await expect(
          testContract.connect(user1).beaconStake(operatorId, [])
        ).to.be.revertedWith("StakeUtils: MAX 64 nodes");
      });

      describe("success, check params", () => {
        beforeEach(async () => {
          await testContract
            .connect(user1)
            .depositPlanet(planetId, 0, MAX_UINT256, {
              value: String(1e20),
            });
          prevSecured = await testContract.securedById(planetId);

          await testContract
            .connect(oracle)
            .updateVerificationIndex(5000, 3, []);

          prevContractBalance = await testContract.getContractBalance();
          await testContract
            .connect(user1)
            .beaconStake(operatorId, [pubkey1, pubkey2]);
        });

        it("MaintainerWalletBalance", async () => {
          const currentMaintainerWallet = await testContract
            .connect(user1)
            .getMaintainerWalletBalance(operatorId);
          expect(String(2e18)).to.be.eq(
            currentMaintainerWallet.sub(prevMaintainerWallet)
          );
        });

        it("Contract balance decreased accordingly (64 eth)", async () => {
          expect(String(62e18)).to.be.eq(
            prevContractBalance.sub(await testContract.getContractBalance())
          );
        });

        it("Secured", async () => {
          expect(String(64e18)).to.be.eq(
            prevSecured.sub(await testContract.securedById(planetId))
          );
        });

        it("ActiveValidators", async () => {
          const currentActiveValidators =
            await testContract.activeValidatorsById(planetId, operatorId);
          expect(String(2)).to.be.eq(
            currentActiveValidators.sub(prevActiveValidators)
          );
        });

        it("validator state = 2", async () => {
          const val1 = await testContract.getValidatorData(pubkey1);
          const val2 = await testContract.getValidatorData(pubkey2);
          [val1, val2].forEach(function (vd, i) {
            expect(vd.state).to.be.eq(2);
          });
        });
      });
    });
  });

  describe("Oracle Operations", () => {
    it("_setPricePerShare", async () => {
      await testContract.setPricePerShare(String(1e20), randId);
      expect(await gETH.pricePerShare(randId)).to.eq(String(1e20));
      await testContract.setPricePerShare(String(2e19), randId);
      expect(await gETH.pricePerShare(randId)).to.eq(String(2e19));
    });

    it("_getPricePerShare", async () => {
      await testContract.connect(user1).changeOracle();
      await gETH.connect(user1).setPricePerShare(String(1e20), randId);
      expect(await testContract.getPricePerShare(randId)).to.eq(String(1e20));
      await gETH.connect(user1).setPricePerShare(String(2e19), randId);
      expect(await testContract.getPricePerShare(randId)).to.eq(String(2e19));
    });

    describe("updateVerificationIndex", () => {
      beforeEach(async () => {
        await testContract.setMONOPOLY_THRESHOLD(1000);
        await testContract.setType(operatorId, 4);
        await testContract.beController(operatorId);
        await testContract.initiateOperator(
          operatorId, // _id
          1e5, // _fee
          user1.address, // _maintainer
          1e8
        );
        await testContract.setType(planetId, 5);
        await testContract.beController(planetId);
        await testContract.initiatePlanet(
          planetId, // _id
          1e5, // _fee
          user2.address, // _maintainer
          "beautiful-planet", // _interfaceName
          "BP" // _interfaceSymbol
        );
        await testContract.setSurplus(planetId, String(1e20));
        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 3);

        await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
          value: String(5e18),
        });
      });

      it("reverts if low validator count", async () => {
        await expect(
          testContract.connect(oracle).updateVerificationIndex(4999, 1, [])
        ).to.be.revertedWith("OracleUtils: low validator count");
      });

      it("reverts if VALIDATORS_INDEX is smaller than new index point", async () => {
        await expect(
          testContract
            .connect(oracle)
            .updateVerificationIndex(5000, 2, [pubkey3, pubkey4])
        ).to.be.revertedWith("OracleUtils: high VERIFICATION_INDEX");
      });

      it("reverts if VERIFICATION_INDEX is bigger than new index point", async () => {
        await testContract.setMONOPOLY_THRESHOLD(1000);
        await testContract
          .connect(user1)
          .proposeStake(
            planetId,
            operatorId,
            [pubkey1, pubkey2, pubkey3],
            [signature1, signature2, signature3]
          );
        await testContract.connect(oracle).updateVerificationIndex(5000, 2, []);

        await expect(
          testContract.connect(oracle).updateVerificationIndex(5000, 1, [])
        ).to.be.revertedWith("OracleUtils: low VERIFICATION_INDEX");
      });

      it("reverts if not pending validator tried to be alienated", async () => {
        await testContract.setMONOPOLY_THRESHOLD(1000);
        await testContract
          .connect(user1)
          .proposeStake(
            planetId,
            operatorId,
            [pubkey1, pubkey2],
            [signature1, signature2]
          );

        await expect(
          testContract
            .connect(oracle)
            .updateVerificationIndex(5000, 2, [pubkey3])
        ).to.be.revertedWith("OracleUtils: NOT all alienPubkeys are pending");
      });

      describe("success", () => {
        let surplus;
        let secured;
        beforeEach(async () => {
          await testContract.setMONOPOLY_THRESHOLD(1000);
          await testContract
            .connect(user1)
            .proposeStake(planetId, operatorId, [pubkey1], [signature1]);
          expect(await testContract.getVALIDATORS_INDEX()).to.be.eq(1);
          surplus = await testContract.surplusById(planetId);
          secured = await testContract.securedById(planetId);
        });
        describe("Alienated", () => {
          beforeEach(async () => {
            await testContract
              .connect(oracle)
              .updateVerificationIndex(5000, 1, [pubkey1]);
            expect(await testContract.getVERIFICATION_INDEX()).to.be.eq(1);
          });
          it("check validator.state", async () => {
            expect(
              (await testContract.getValidatorData(pubkey1)).state
            ).to.be.eq(69);
          });
          it("check surplus", async () => {
            expect(await testContract.surplusById(planetId)).to.be.eq(
              surplus.add(String(32e18))
            );
          });
          it("check secured", async () => {
            expect(await testContract.securedById(planetId)).to.be.eq(
              secured.sub(String(32e18))
            );
          });
        });
      });
    });

    describe("isOracleActive", () => {
      it("false when inactive", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 - 10);
        await expect(await testContract.isOracleActive()).to.be.eq(false);
      });

      it("true when active", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 + 1);
        await expect(await testContract.isOracleActive()).to.be.eq(true);
      });

      it("true when active in 30min", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 + 30 * 60 - 10);
        await expect(await testContract.isOracleActive()).to.be.eq(true);
      });

      it("false when inactive after 30min", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 + 30 * 60 + 1);
        await expect(await testContract.isOracleActive()).to.be.eq(false);
      });

      it("false after oracle update", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 + 5);
        await testContract.setORACLE_UPDATE_TIMESTAMP(
          24 * 60 * 60 * 100000 + 0 * 60 + 1
        );
        expect(await testContract.isOracleActive()).to.be.eq(false);
      });
    });

    describe("_sanityCheck", () => {
      beforeEach(async () => {
        await testContract.setPricePerShare(String(1e18), planetId);
        await testContract.setORACLE_UPDATE_TIMESTAMP(
          24 * 60 * 60 * 100000 + 0 * 60 + 1
        );
      });

      it("reverts if price is increasing insane after 1 day", async () => {
        await setTimestamp(24 * 60 * 60 * 100001 + 0 * 60 + 5);
        await expect(
          testContract.sanityCheck(planetId, String(1.003e18))
        ).to.be.revertedWith("OracleUtils: price is insane");
      });

      it("success increase after 1 day", async () => {
        await setTimestamp(24 * 60 * 60 * 100001 + 0 * 60 + 5);
        await testContract.sanityCheck(planetId, String(1.001e18));
      });

      it("reverts if price is increasing insane after one 10 day", async () => {
        await setTimestamp(24 * 60 * 60 * 100010 + 0 * 60 + 5);
        await expect(
          testContract.sanityCheck(planetId, String(1.021e18))
        ).to.be.revertedWith("OracleUtils: price is insane");
      });

      it("success increase after 10 day", async () => {
        await setTimestamp(24 * 60 * 60 * 100010 + 0 * 60 + 5);
        await testContract.sanityCheck(planetId, String(1.019e18));
      });

      it("reverts if price is increasing insane after 100 day", async () => {
        await setTimestamp(24 * 60 * 60 * 100100 + 0 * 60 + 5);
        await expect(
          testContract.sanityCheck(planetId, String(1.201e18))
        ).to.be.revertedWith("OracleUtils: price is insane");
      });

      it("success increase after 100 day", async () => {
        await setTimestamp(24 * 60 * 60 * 100100 + 0 * 60 + 5);
        await testContract.sanityCheck(planetId, String(1.199e18));
      });
    });

    // describe("_priceSync", () => {
    //   describe("needs update with merkle", () => {
    //     const isThisPartUpdated = false;
    //     beforeEach(async () => {
    //       // continue here and make isThisPartUpdated when done.
    //       // ----
    //       //
    //       // ----
    //     });
    //     it("needs update with merkle", async () => {
    //       expect(isThisPartUpdated).to.be.eq(true);
    //     });
    //   });
    // });

    describe("_findPrices_ClearBuffer", () => {
      beforeEach(async () => {
        await testContract.setMONOPOLY_THRESHOLD(1000);
        await testContract.setType(operatorId, 4);
        await testContract.beController(operatorId);
        await testContract.initiateOperator(
          operatorId, // _id
          1e5, // _fee
          user1.address, // _maintainer
          1e8
        );
        await testContract.setType(planetId, 5);
        await testContract.beController(planetId);
        await testContract.initiatePlanet(
          planetId, // _id
          1e5, // _fee
          user2.address, // _maintainer
          "beautiful-planet", // _interfaceName
          "BP" // _interfaceSymbol
        );
        await testContract
          .connect(user2)
          .approveOperator(planetId, operatorId, 4);
        await testContract.deployWithdrawalPool(planetId);
        await testContract.connect(user1).increaseMaintainerWallet(operatorId, {
          value: String(6e18),
        });
        await testContract
          .connect(user1)
          .depositPlanet(planetId, 0, MAX_UINT256, {
            value: String(160e18),
          });
        await testContract
          .connect(user1)
          .proposeStake(
            planetId,
            operatorId,
            [pubkey1, pubkey2, pubkey3, pubkey4],
            [signature1, signature2, signature3, signature4]
          );

        await testContract.connect(oracle).updateVerificationIndex(5000, 4, []);

        await testContract.setORACLE_UPDATE_TIMESTAMP(
          24 * 60 * 60 * 100000 + 0 * 60 + 1
        );

        await testContract.setPricePerShare(String(2e18), planetId);

        await setTimestamp(24 * 60 * 60 * 100000 + 30 * 60 + 10);

        await testContract
          .connect(user1)
          .beaconStake(operatorId, [pubkey1, pubkey2]);

        await setTimestamp(24 * 60 * 60 * 100001 + 0 * 60 + 10);

        // do macig: mint buffer increase
        await testContract
          .connect(user1)
          .depositPlanet(planetId, 0, MAX_UINT256, {
            value: String(32e18),
          });
      });

      it("works when oracle not missed", async () => {
        await setTimestamp(24 * 60 * 60 * 100001 + 0 * 60 + 30);
        await testContract.setORACLE_UPDATE_TIMESTAMP(
          24 * 60 * 60 * 100001 + 0 * 60 + 30
        );

        await testContract.findPrices(planetId, String(64e18));
        const results = await testContract.getLastPrices();
        const settedPrice = results[0];
        const unbufferedPrice = results[1];

        expect(settedPrice).to.be.eq(
          ethers.BigNumber.from(String(192e18)).div(String(176e18))
        ); // totalETH div getgETH(self).totalSupply(poolId) -> 160 + 32/2 = 176
        expect(unbufferedPrice).to.be.eq(
          ethers.BigNumber.from(String(160e18)).div(String(160e18))
        ); // unbufferedSupply div (getgETH(self).totalSupply(poolId) - calculation) -> 176 - 16
      });

      it("works when oracle missed 1 day", async () => {
        await setTimestamp(24 * 60 * 60 * 100001 + 30 * 60 + 10);

        await testContract
          .connect(user1)
          .beaconStake(operatorId, [pubkey3, pubkey4]);

        await testContract
          .connect(user1)
          .depositPlanet(planetId, 0, MAX_UINT256, {
            value: String(32e18),
          });

        await setTimestamp(24 * 60 * 60 * 100002 + 0 * 60 + 10);

        // do macig: mint buffer increase
        await testContract
          .connect(user1)
          .depositPlanet(planetId, 0, MAX_UINT256, {
            value: String(64e18),
          });

        await setTimestamp(24 * 60 * 60 * 100002 + 0 * 60 + 30);

        await testContract.setORACLE_UPDATE_TIMESTAMP(
          24 * 60 * 60 * 100002 + 0 * 60 + 30
        );

        await testContract.findPrices(planetId, String(128e18));
        const results = await testContract.getLastPrices();
        const settedPrice = results[0];
        const unbufferedPrice = results[1];

        expect(settedPrice).to.be.eq(
          ethers.BigNumber.from(String(256e18)).div(String(224e18))
        ); // totalETH div getgETH(self).totalSupply(poolId) -> 176 + 32/2 + 64/2 = 224
        expect(unbufferedPrice).to.be.eq(
          ethers.BigNumber.from(String(192e18)).div(String(192e18))
        ); // unbufferedSupply div (getgETH(self).totalSupply(poolId) - calculation) -> 224 - 32
      });
      it("works when oracle missed 20 days", async () => {
        await setTimestamp(24 * 60 * 60 * 100001 + 30 * 60 + 10);

        await testContract
          .connect(user1)
          .beaconStake(operatorId, [pubkey3, pubkey4]);

        await testContract
          .connect(user1)
          .depositPlanet(planetId, 0, MAX_UINT256, {
            value: String(32e18),
          });

        await setTimestamp(24 * 60 * 60 * 100021 + 0 * 60 + 10);

        // do macig: mint buffer increase
        await testContract
          .connect(user1)
          .depositPlanet(planetId, 0, MAX_UINT256, {
            value: String(64e18),
          });

        await setTimestamp(24 * 60 * 60 * 100021 + 0 * 60 + 30);

        await testContract.setORACLE_UPDATE_TIMESTAMP(
          24 * 60 * 60 * 100003 + 0 * 60 + 30
        );

        await testContract.findPrices(planetId, String(128e18));
        const results = await testContract.getLastPrices();
        const settedPrice = results[0];
        const unbufferedPrice = results[1];

        expect(settedPrice).to.be.eq(
          ethers.BigNumber.from(String(256e18)).div(String(224e18))
        ); // totalETH div getgETH(self).totalSupply(poolId) -> 176 + 32/2 + 64/2 = 224
        expect(unbufferedPrice).to.be.eq(
          ethers.BigNumber.from(String(192e18)).div(String(192e18))
        ); // unbufferedSupply div (getgETH(self).totalSupply(poolId) - calculation) -> 224 - 32
      });
    });

    describe("reportOracle", () => {
      const someBytes32 = ethers.utils.formatBytes32String("some");
      beforeEach(async () => {});
      it("reverts when caller is not oracle ", async () => {
        await expect(
          testContract.reportOracle(
            someBytes32,
            [String(1), String(1)],
            [
              [someBytes32, someBytes32],
              [someBytes32, someBytes32],
            ]
          )
        ).to.be.revertedWith("OracleUtils: sender NOT ORACLE");
      });
      it("reverts when oracle is not active", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 - 30);
        await expect(
          testContract.connect(oracle).reportOracle(
            someBytes32,
            [String(1), String(1)],
            [
              [someBytes32, someBytes32],
              [someBytes32, someBytes32],
            ]
          )
        ).to.be.revertedWith("OracleUtils: oracle is NOT active");
        await setTimestamp(24 * 60 * 60 * 100000 + 1 * 60 * 60 + 30);
        await expect(
          testContract.connect(oracle).reportOracle(
            someBytes32,
            [String(1), String(1)],
            [
              [someBytes32, someBytes32],
              [someBytes32, someBytes32],
            ]
          )
        ).to.be.revertedWith("OracleUtils: oracle is NOT active");
      });
      it("reverts when beaconBalances.length doesn't match ", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 + 10 * 60);
        await expect(
          testContract.connect(oracle).reportOracle(
            someBytes32,
            [String(1), String(1)],
            [
              [someBytes32, someBytes32],
              [someBytes32, someBytes32],
            ]
          )
        ).to.be.revertedWith("OracleUtils: incorrect beaconBalances length");
      });
      it("reverts when priceProofs.length doesn't match ", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 + 10 * 60);
        await expect(
          testContract.connect(oracle).reportOracle(
            someBytes32,
            [],
            [
              [someBytes32, someBytes32],
              [someBytes32, someBytes32],
            ]
          )
        ).to.be.revertedWith("OracleUtils: incorrect priceProofs length");
      });
      // describe("success => needs update with merkle", async () => {
      //   beforeEach(async () => {
      //     // continue here and make isThisPartUpdated when done.
      //     // ----
      //     //
      //     // ----
      //     const isThisPartUpdated = false;
      //     expect(isThisPartUpdated).to.be.eq(true);
      //   });
      //   it("updated all pricePerShares", async () => {
      //     expect().to.be.eq();
      //   });
      //   it("correct ORACLE_UPDATE_TIMESTAMP", async () => {
      //     expect().to.be.eq();
      //   });
      //   it("", async () => {
      //     expect().to.be.eq();
      //   });
      // });
    });
  });
});
