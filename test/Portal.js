const {
  MAX_UINT256,
  ZERO_ADDRESS,
  getCurrentBlockTimestamp,
  setTimestamp,
} = require("./testUtils");
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const { BigNumber } = require("ethers");
const { solidity } = require("ethereum-waffle");
const { deployments, upgrades } = require("hardhat");
const { get } = deployments;
const chai = require("chai");
chai.use(solidity);
const { expect } = chai;
const provider = waffle.provider;

const pubkey0 =
  "0x91efd3ce6694bc034ad4c23773877da916ed878ff8376610633a9ae4b4d826f4086a6b9b5b197b5e148be658c66c4e9a";
const pubkey1 =
  "0xa3b3eb55b16999ffeff52e5a898af89e4194b7221b2eaf03cb85fd558a390dc042beba94f907db6091b4cf141b18d1f5";
const pubkey2 =
  "0x986e1dee05f3a018bab83343b3b3d96dd573a50ffb03e8145b2964a389ceb14cb3780266b99ef7cf0e16ee34648e2151";
const signature01 =
  "0x8bbeff59e3016c98d7daf05ddbd0c71309fae34bf3e544d56ebff030b97bccb83c5abfaab437ec7c652bbafa19eb30661979b82e79fa351d65a50e3a854c1ef0c8537f97ceaf0f334096509cd52f716150e67e17c8085d9622f376553da51181";
const signature11 =
  "0xa2e94c3def1e53d7d1b5a0f037f765868b4bbae3ee59de673bc7ab7b142b929e08f47c1c2a6cdc91aee9442468ab095406b8ce356aef42403febe385424f97d6d109f6423dcb1acc3def45af56e4407416f0773bd18e50d880cb7d3e00ca9932";
const signature031 =
  "0xa58af51205a996c87f23c80aeb3cb669001e3f919a88598d063ff6cee9b05fbb8a18dab15a4a5b85eabfd47c26d0f24f11f5f889f6a7fb8cbd5c4ccd7607c449b57a9f0703e1bb63b513cb3e9fcd1d79b0d8f269c7441173054b9284cfb7a13c";
const signature131 =
  "0xa7290722d0b9350504fd44cd166fabc85db76fab07fb2876bff51e0ede2856e6160e4288853cf713cbf3cd7a0541ab1d0ed5e0858c980870f3a4c791264d8b4ee090677f507b599409e86433590ee3a93cae5103d2e03c66bea623e3ccd590ae";

describe("Portal", async () => {
  const DAY = 24 * 60 * 60;
  const WEEK = 7 * DAY;
  const MIN_PROPOSAL_DURATION = DAY;
  const MAX_PROPOSAL_DURATION = 4 * WEEK;
  const MIN_VALIDATOR_PERIOD = 90 * DAY;
  const MAX_VALIDATOR_PERIOD = 1825 * DAY;
  const GOVERNANCE_FEE = (2 * 10 ** 10) / 100; // 2%
  const MAX_GOVERNANCE_FEE = 5 * 10 ** 8;
  const SWITCH_LATENCY = 3 * DAY;
  const MAX_SENATE_PERIOD = 365 * DAY;

  let PortalFac;
  let gETH;
  let PORTAL;
  let GOVERNANCE;
  let ORACLE;
  let SENATE;

  let operatorOwner;
  let operatorName;
  const operatorFee = 9 * 10 ** 8;
  let operatorId;

  let poolOwner;
  let poolId;
  let poolName;
  let interfaceData;
  const poolFee = 8 * 10 ** 8;

  let wrongName;
  let wrongId;

  let randomName;
  let randomId;

  let extraName1;
  let extraName2;
  let extraName3;
  let extraId1;
  let extraId2;
  let extraId3;

  let attacker;
  let user;

  let creationTime;

  const getBytes = (key) => {
    return Web3.utils.toHex(key);
  };

  const getBytes32 = (key) => {
    return ethers.utils.formatBytes32String(key);
  };

  const intToBytes32 = (x) => {
    return ethers.utils.hexZeroPad(ethers.utils.hexlify(x), 32);
  };
  const setupTest = deployments.createFixture(async (hre) => {
    ({ ethers, web3, Web3 } = hre);

    const signers = await ethers.getSigners();
    deployer = signers[0];
    GOVERNANCE = signers[1];
    SENATE = signers[2];
    ORACLE = signers[3];
    operatorOwner = signers[4];
    poolOwner = signers[5];
    attacker = signers[6];
    user = signers[7];

    await deployments.fixture();
    gETH = await ethers.getContractAt("gETH", (await get("gETH")).address);

    PortalFac = await ethers.getContractFactory("Portal", {
      libraries: {
        GeodeUtils: (await get("GeodeUtils")).address,
        StakeUtils: (await get("StakeUtils")).address,
        OracleUtils: (await get("OracleUtils")).address,
      },
    });

    PORTAL = await upgrades.deployProxy(
      PortalFac,
      [
        GOVERNANCE.address,
        SENATE.address,
        gETH.address,
        ORACLE.address,
        (await get("WithdrawalContract")).address,
        (await get("Swap")).address,
        (await get("LPToken")).address,
        [
          (await get("ERC20InterfaceUpgradable")).address,
          (await get("ERC20InterfacePermitUpgradable")).address,
        ],
        [getBytes("ERC20"), getBytes("ERC20Permit")],
        GOVERNANCE_FEE,
      ],
      {
        kind: "uups",
        unsafeAllow: ["external-library-linking"],
      }
    );
    await PORTAL.deployed();
    creationTime = await getCurrentBlockTimestamp();

    await gETH.updateMinterRole(PORTAL.address);
    await gETH.updateOracleRole(PORTAL.address);
    await gETH.updatePauserRole(PORTAL.address);

    senateName = getBytes("newSenate");
    senateId = await PORTAL.generateId("newSenate", 1);

    operatorName = getBytes("myOperator");
    operatorId = await PORTAL.generateId("myOperator", 4);

    poolName = getBytes("myPool");
    poolId = await PORTAL.generateId("myPool", 5);

    wrongName = getBytes("wrong");
    wrongId = await PORTAL.generateId("wrong", 5);

    randomName = getBytes("random");
    randomId = await PORTAL.generateId("random", 5);

    extraName1 = getBytes("extra1");
    extraName2 = getBytes("extra2");
    extraName3 = getBytes("extra3");
    extraId1 = await PORTAL.generateId("extra1", 5);
    extraId2 = await PORTAL.generateId("extra2", 5);
    extraId3 = await PORTAL.generateId("extra3", 5);

    interfaceId = await PORTAL.generateId("ERC20Permit", 31);

    const nameBytes = getBytes("myPool Ether").substr(2);
    const symbolBytes = getBytes("mpETH").substr(2);
    interfaceData = intToBytes32(nameBytes.length / 2) + nameBytes + symbolBytes;
  });

  beforeEach(async () => {
    await setupTest();
  });

  describe("initialize", async () => {
    describe("initialize", async () => {
      it("_GOVERNANCE can NOT be ZERO", async () => {
        await expect(
          upgrades.deployProxy(
            PortalFac,
            [
              ZERO_ADDRESS,
              SENATE.address,
              gETH.address,
              ORACLE.address,
              (await get("WithdrawalContract")).address,
              (await get("Swap")).address,
              (await get("LPToken")).address,
              [
                (await get("ERC20InterfaceUpgradable")).address,
                (await get("ERC20InterfacePermitUpgradable")).address,
              ],
              [getBytes("ERC20"), getBytes("ERC20Permit")],
              GOVERNANCE_FEE,
            ],
            {
              kind: "uups",
              unsafeAllow: ["external-library-linking"],
            }
          )
        ).to.be.revertedWith("PORTAL: GOVERNANCE can NOT be ZERO");
      });
      it("_SENATE can NOT be ZERO", async () => {
        await expect(
          upgrades.deployProxy(
            PortalFac,
            [
              GOVERNANCE.address,
              ZERO_ADDRESS,
              gETH.address,
              ORACLE.address,
              (await get("WithdrawalContract")).address,
              (await get("Swap")).address,
              (await get("LPToken")).address,
              [
                (await get("ERC20InterfaceUpgradable")).address,
                (await get("ERC20InterfacePermitUpgradable")).address,
              ],
              [getBytes("ERC20"), getBytes("ERC20Permit")],
              GOVERNANCE_FEE,
            ],
            {
              kind: "uups",
              unsafeAllow: ["external-library-linking"],
            }
          )
        ).to.be.revertedWith("PORTAL: SENATE can NOT be ZERO");
      });
      it("_gETH can NOT be ZERO", async () => {
        await expect(
          upgrades.deployProxy(
            PortalFac,
            [
              GOVERNANCE.address,
              SENATE.address,
              ZERO_ADDRESS,
              ORACLE.address,
              (await get("WithdrawalContract")).address,
              (await get("Swap")).address,
              (await get("LPToken")).address,
              [
                (await get("ERC20InterfaceUpgradable")).address,
                (await get("ERC20InterfacePermitUpgradable")).address,
              ],
              [getBytes("ERC20"), getBytes("ERC20Permit")],
              GOVERNANCE_FEE,
            ],
            {
              kind: "uups",
              unsafeAllow: ["external-library-linking"],
            }
          )
        ).to.be.revertedWith("PORTAL: gETH can NOT be ZERO");
      });
      it("_ORACLE_POSITION can NOT be ZERO", async () => {
        await expect(
          upgrades.deployProxy(
            PortalFac,
            [
              GOVERNANCE.address,
              SENATE.address,
              gETH.address,
              ZERO_ADDRESS,
              (await get("WithdrawalContract")).address,
              (await get("Swap")).address,
              (await get("LPToken")).address,
              [
                (await get("ERC20InterfaceUpgradable")).address,
                (await get("ERC20InterfacePermitUpgradable")).address,
              ],
              [getBytes("ERC20"), getBytes("ERC20Permit")],
              GOVERNANCE_FEE,
            ],
            {
              kind: "uups",
              unsafeAllow: ["external-library-linking"],
            }
          )
        ).to.be.revertedWith("PORTAL: ORACLE_POSITION can NOT be ZERO");
      });
      it("wrong _ALLOWED_GETH_INTERFACE_MODULES", async () => {
        await expect(
          upgrades.deployProxy(
            PortalFac,
            [
              GOVERNANCE.address,
              SENATE.address,
              gETH.address,
              ORACLE.address,
              (await get("WithdrawalContract")).address,
              (await get("Swap")).address,
              (await get("LPToken")).address,
              [(await get("ERC20InterfacePermitUpgradable")).address],
              [getBytes("ERC20"), getBytes("ERC20Permit")],
              GOVERNANCE_FEE,
            ],
            {
              kind: "uups",
              unsafeAllow: ["external-library-linking"],
            }
          )
        ).to.be.revertedWith("PORTAL: wrong _ALLOWED_GETH_INTERFACE_MODULES");
      });
      it("_WITHDRAWAL_CONTRACT_POSITION can NOT be ZERO", async () => {
        await expect(
          upgrades.deployProxy(
            PortalFac,
            [
              GOVERNANCE.address,
              SENATE.address,
              gETH.address,
              ORACLE.address,
              (await get("WithdrawalContract")).address,
              (await get("Swap")).address,
              (await get("LPToken")).address,
              [ZERO_ADDRESS, (await get("ERC20InterfacePermitUpgradable")).address],
              [getBytes("ERC20"), getBytes("ERC20Permit")],
              GOVERNANCE_FEE,
            ],
            {
              kind: "uups",
              unsafeAllow: ["external-library-linking"],
            }
          )
        ).to.be.revertedWith("PORTAL: GETH_INTERFACE_MODULE can NOT be ZERO");
      });
      it("_DEFAULT_LP can NOT be ZERO", async () => {
        await expect(
          upgrades.deployProxy(
            PortalFac,
            [
              GOVERNANCE.address,
              SENATE.address,
              gETH.address,
              ORACLE.address,
              (await get("WithdrawalContract")).address,
              ZERO_ADDRESS,
              (await get("LPToken")).address,
              [
                (await get("ERC20InterfaceUpgradable")).address,
                (await get("ERC20InterfacePermitUpgradable")).address,
              ],
              [getBytes("ERC20"), getBytes("ERC20Permit")],
              GOVERNANCE_FEE,
            ],
            {
              kind: "uups",
              unsafeAllow: ["external-library-linking"],
            }
          )
        ).to.be.revertedWith("PORTAL: DEFAULT_LP can NOT be ZERO");
      });
      it("_DEFAULT_LP_TOKEN can NOT be ZERO", async () => {
        await expect(
          upgrades.deployProxy(
            PortalFac,
            [
              GOVERNANCE.address,
              SENATE.address,
              gETH.address,
              ORACLE.address,
              (await get("WithdrawalContract")).address,
              (await get("Swap")).address,
              ZERO_ADDRESS,
              [
                (await get("ERC20InterfaceUpgradable")).address,
                (await get("ERC20InterfacePermitUpgradable")).address,
              ],
              [getBytes("ERC20"), getBytes("ERC20Permit")],
              GOVERNANCE_FEE,
            ],
            {
              kind: "uups",
              unsafeAllow: ["external-library-linking"],
            }
          )
        ).to.be.revertedWith("PORTAL: DEFAULT_LP_TOKEN can NOT be ZERO");
      });
      it("_WITHDRAWAL_CONTRACT_POSITION can NOT be ZERO", async () => {
        await expect(
          upgrades.deployProxy(
            PortalFac,
            [
              GOVERNANCE.address,
              SENATE.address,
              gETH.address,
              ORACLE.address,
              ZERO_ADDRESS,
              (await get("Swap")).address,
              (await get("LPToken")).address,
              [
                (await get("ERC20InterfaceUpgradable")).address,
                (await get("ERC20InterfacePermitUpgradable")).address,
              ],
              [getBytes("ERC20"), getBytes("ERC20Permit")],
              GOVERNANCE_FEE,
            ],
            {
              kind: "uups",
              unsafeAllow: ["external-library-linking"],
            }
          )
        ).to.be.revertedWith("PORTAL: WITHDRAWAL_CONTRACT_POSITION can NOT be ZERO");
      });
    });

    it("gETH", async () => {
      expect(await PORTAL.gETH()).to.be.eq(gETH.address);
    });

    describe("GeodeParams", async () => {
      let geodeParams;

      beforeEach(async () => {
        geodeParams = await PORTAL.GeodeParams();
      });

      it("SENATE", async () => {
        expect(geodeParams.SENATE).to.be.eq(SENATE.address);
      });

      it("GOVERNANCE", async () => {
        expect(geodeParams.GOVERNANCE).to.be.eq(GOVERNANCE.address);
      });

      it("SENATE_EXPIRY", async () => {
        expect(geodeParams.SENATE_EXPIRY).to.be.eq(creationTime + MAX_SENATE_PERIOD);
      });

      it("GOVERNANCE_FEE", async () => {
        expect(geodeParams.GOVERNANCE_FEE).to.be.eq(0);
      });
    });

    describe("StakingParams", async () => {
      let StakingParams;

      beforeEach(async () => {
        StakingParams = await PORTAL.StakingParams();
      });

      it("VALIDATORS_INDEX", async () => {
        expect(StakingParams.VALIDATORS_INDEX).to.be.eq(0);
      });

      it("VERIFICATION_INDEX", async () => {
        expect(StakingParams.VERIFICATION_INDEX).to.be.eq(0);
      });

      it("MONOPOLY_THRESHOLD", async () => {
        expect(StakingParams.MONOPOLY_THRESHOLD).to.be.eq(MAX_UINT256);
      });
      it("ORACLE_POSITION", async () => {
        expect(StakingParams.ORACLE_POSITION).to.be.eq(ORACLE.address);
      });

      it("PRICE_MERKLE_ROOT", async () => {
        expect(StakingParams.PRICE_MERKLE_ROOT).to.be.eq(getBytes32(""));
      });

      it("ORACLE_UPDATE_TIMESTAMP", async () => {
        expect(StakingParams.ORACLE_UPDATE_TIMESTAMP).to.be.eq(0);
      });

      it("DAILY_PRICE_INCREASE_LIMIT", async () => {
        expect(StakingParams.DAILY_PRICE_INCREASE_LIMIT).to.be.eq(700000000);
      });

      it("DAILY_PRICE_DECREASE_LIMIT", async () => {
        expect(StakingParams.DAILY_PRICE_DECREASE_LIMIT).to.be.eq(700000000);
      });

      describe("DEFAULT_WITHDRAWAL_CONTRACT_MODULE", async () => {
        let proposal;

        beforeEach(async () => {
          proposal = await PORTAL.getProposal(await PORTAL.generateId("v1", 21));
        });

        it("correct CONTROLLER", async () => {
          expect(proposal.CONTROLLER).to.be.eq((await get("WithdrawalContract")).address);
        });

        it("correct TYPE", async () => {
          expect(proposal.TYPE).to.be.eq(21);
        });

        it("correct NAME", async () => {
          expect(proposal.NAME).to.be.eq(getBytes("v1"));
        });

        it("correct deadline", async () => {
          expect(proposal.deadline).to.be.eq(creationTime);
        });

        it("added in defaultModules", async () => {
          expect(await PORTAL.getDefaultModule(21)).to.be.eq(await PORTAL.generateId("v1", 21));
        });
      });

      describe("DEFAULT_LP_MODULE", async () => {
        let proposal;

        beforeEach(async () => {
          proposal = await PORTAL.getProposal(await PORTAL.generateId("v1", 41));
        });

        it("correct CONTROLLER", async () => {
          expect(proposal.CONTROLLER).to.be.eq((await get("Swap")).address);
        });

        it("correct TYPE", async () => {
          expect(proposal.TYPE).to.be.eq(41);
        });

        it("correct NAME", async () => {
          expect(proposal.NAME).to.be.eq(getBytes("v1"));
        });

        it("correct deadline", async () => {
          expect(proposal.deadline).to.be.eq(creationTime);
        });

        it("added in defaultModules", async () => {
          expect(await PORTAL.getDefaultModule(41)).to.be.eq(await PORTAL.generateId("v1", 41));
        });
      });

      describe("DEFAULT_LP_TOKEN_MODULE", async () => {
        let proposal;

        beforeEach(async () => {
          proposal = await PORTAL.getProposal(await PORTAL.generateId("v1", 42));
        });

        it("correct CONTROLLER", async () => {
          expect(proposal.CONTROLLER).to.be.eq((await get("LPToken")).address);
        });

        it("correct TYPE", async () => {
          expect(proposal.TYPE).to.be.eq(42);
        });

        it("correct NAME", async () => {
          expect(proposal.NAME).to.be.eq(getBytes("v1"));
        });

        it("correct deadline", async () => {
          expect(proposal.deadline).to.be.eq(creationTime);
        });

        it("added in defaultModules", async () => {
          expect(await PORTAL.getDefaultModule(42)).to.be.eq(await PORTAL.generateId("v1", 42));
        });
      });

      describe("ALLOWED_GETH_INTERFACE_MODULES", async () => {
        let proposal1;
        let proposal2;

        beforeEach(async () => {
          proposal1 = await PORTAL.getProposal(await PORTAL.generateId("ERC20", 31));
          proposal2 = await PORTAL.getProposal(await PORTAL.generateId("ERC20Permit", 31));
        });

        it("correct CONTROLLER", async () => {
          expect(proposal1.CONTROLLER).to.be.eq((await get("ERC20InterfaceUpgradable")).address);
          expect(proposal2.CONTROLLER).to.be.eq(
            (await get("ERC20InterfacePermitUpgradable")).address
          );
        });

        it("correct TYPE", async () => {
          expect(proposal1.TYPE).to.be.eq(31);
          expect(proposal2.TYPE).to.be.eq(31);
        });

        it("correct NAME", async () => {
          expect(proposal1.NAME).to.be.eq(getBytes("ERC20"));
          expect(proposal2.NAME).to.be.eq(getBytes("ERC20Permit"));
        });

        it("correct deadline", async () => {
          expect(proposal1.deadline).to.be.eq(creationTime);
          expect(proposal2.deadline).to.be.eq(creationTime);
        });

        it("added in defaultModules", async () => {
          expect(await PORTAL.isAllowedModule(31, await PORTAL.generateId("ERC20", 31))).to.be.eq(
            true
          );

          expect(
            await PORTAL.isAllowedModule(31, await PORTAL.generateId("ERC20Permit", 31))
          ).to.be.eq(true);
        });
      });
    });

    describe("Contract Version", async () => {
      let proposal;

      beforeEach(async () => {
        proposal = await PORTAL.getProposal(await PORTAL.getContractVersion());
      });

      it("correct CONTROLLER", async () => {
        expect(proposal.CONTROLLER).to.be.eq(PORTAL.address);
      });

      it("correct TYPE", async () => {
        expect(proposal.TYPE).to.be.eq(2);
      });

      it("correct NAME", async () => {
        expect(proposal.NAME).to.be.eq(Web3.utils.toHex("v1"));
      });

      it("correct deadline", async () => {
        expect(proposal.deadline).to.be.eq(creationTime);
      });
    });

    describe("isUpgradeAllowed", async () => {
      it("returns false on ZERO_ADDRESS", async () => {
        expect(await PORTAL.isUpgradeAllowed(ZERO_ADDRESS)).to.be.eq(false);
      });
      it("returns false on current implementation", async () => {
        expect(
          await PORTAL.isUpgradeAllowed(
            await upgrades.erc1967.getImplementationAddress(PORTAL.address)
          )
        ).to.be.eq(false);
      });
    });
  });

  describe("modifiers", async () => {
    describe("onlyGovernance", async () => {
      it("pause", async () => {
        await PORTAL.connect(GOVERNANCE).pause();
        await expect(PORTAL.pause()).to.be.revertedWith("Portal: ONLY GOVERNANCE");
      });
      it("unpause", async () => {
        await PORTAL.connect(GOVERNANCE).pause();
        await expect(PORTAL.unpause()).to.be.revertedWith("Portal: ONLY GOVERNANCE");
        await PORTAL.connect(GOVERNANCE).unpause();
      });
      it("pausegETH", async () => {
        await PORTAL.connect(GOVERNANCE).pause();
        await expect(PORTAL.pausegETH()).to.be.revertedWith("Portal: ONLY GOVERNANCE");
      });
      it("unpausegETH", async () => {
        await PORTAL.connect(GOVERNANCE).pause();
        await expect(PORTAL.unpausegETH()).to.be.revertedWith("Portal: ONLY GOVERNANCE");
        await PORTAL.connect(GOVERNANCE).unpause();
      });
      it("releasePrisoned", async () => {
        await expect(PORTAL.releasePrisoned(operatorId)).to.be.revertedWith(
          "Portal: ONLY GOVERNANCE"
        );
      });
      it("setEarlyExitFee", async () => {
        await expect(PORTAL.setEarlyExitFee(operatorId)).to.be.revertedWith(
          "Portal: ONLY GOVERNANCE"
        );
      });
    });

    describe("whenNotPaused", async () => {
      beforeEach(async () => {
        await PORTAL.connect(GOVERNANCE).pause();
      });

      it("changeIdCONTROLLER", async () => {
        await expect(PORTAL.changeIdCONTROLLER(poolId, ZERO_ADDRESS)).to.be.revertedWith(
          "Pausable: paused"
        );
      });
      it("initiateOperator", async () => {
        await expect(PORTAL.initiateOperator(operatorId, 0, 0, ZERO_ADDRESS)).to.be.revertedWith(
          "Pausable: paused"
        );
      });
      it("initiatePool", async () => {
        await expect(
          PORTAL.initiatePool(0, interfaceId, poolOwner.address, getBytes("pk"), "0x", [1, 0, 0], {
            value: String(32e18),
          })
        ).to.be.revertedWith("Pausable: paused");
      });
      it("setPoolVisibility", async () => {
        await expect(PORTAL.setPoolVisibility(poolId, false)).to.be.revertedWith(
          "Pausable: paused"
        );
      });
      it("setWhitelist", async () => {
        await expect(PORTAL.setWhitelist(poolId, ZERO_ADDRESS)).to.be.revertedWith(
          "Pausable: paused"
        );
      });
      it("deployLiquidityPool", async () => {
        await expect(PORTAL.deployLiquidityPool(poolId)).to.be.revertedWith("Pausable: paused");
      });
      it("changeMaintainer", async () => {
        await expect(PORTAL.changeMaintainer(poolId, ZERO_ADDRESS)).to.be.revertedWith(
          "Pausable: paused"
        );
      });
      it("switchMaintenanceFee", async () => {
        await expect(PORTAL.switchMaintenanceFee(poolId, 0)).to.be.revertedWith("Pausable: paused");
      });
      it("decreaseWalletBalance", async () => {
        await expect(PORTAL.decreaseWalletBalance(poolId, 0)).to.be.revertedWith(
          "Pausable: paused"
        );
      });
      it("switchValidatorPeriod", async () => {
        await expect(PORTAL.switchValidatorPeriod(operatorId, 0)).to.be.revertedWith(
          "Pausable: paused"
        );
      });
      it("blameOperator", async () => {
        await expect(PORTAL.blameOperator(getBytes("pool"))).to.be.revertedWith("Pausable: paused");
      });
      it("setEarlyExitFee", async () => {
        await expect(PORTAL.blameOperator(getBytes("pool"))).to.be.revertedWith("Pausable: paused");
      });
      it("approveOperators", async () => {
        await expect(PORTAL.approveOperators(poolId, [operatorId], [0])).to.be.revertedWith(
          "Pausable: paused"
        );
      });
      it("deposit", async () => {
        await expect(PORTAL.deposit(poolId, 0, 0, 0, [], user.address)).to.be.revertedWith(
          "Pausable: paused"
        );
      });
      it("proposeStake", async () => {
        await expect(PORTAL.proposeStake(poolId, operatorId, [], [], [])).to.be.revertedWith(
          "Pausable: paused"
        );
      });
      it("beaconStake", async () => {
        await expect(PORTAL.beaconStake(operatorId, [])).to.be.revertedWith("Pausable: paused");
      });
      it("updateVerificationIndex", async () => {
        await expect(PORTAL.updateVerificationIndex(0, [])).to.be.revertedWith("Pausable: paused");
      });
      it("regulateOperators", async () => {
        await expect(PORTAL.regulateOperators([], [])).to.be.revertedWith("Pausable: paused");
      });
      it("reportOracle", async () => {
        await expect(PORTAL.reportOracle(getBytes32(""), 0)).to.be.revertedWith("Pausable: paused");
      });
      it("priceSync", async () => {
        await expect(PORTAL.priceSync(poolId, 0, [])).to.be.revertedWith("Pausable: paused");
      });
      it("priceSyncBatch", async () => {
        await expect(PORTAL.priceSyncBatch([poolId], [0], [[]])).to.be.revertedWith(
          "Pausable: paused"
        );
      });
    });
  });

  describe("GeodeUtils", async () => {
    describe("setGovernanceFee", async () => {
      it("reverts when NOT GOVERNANCE", async () => {
        await expect(PORTAL.setGovernanceFee(MAX_GOVERNANCE_FEE)).to.be.revertedWith(
          "GU: GOVERNANCE role needed"
        );
      });
      it("reverts when > MAX_GOVERNANCE_FEE", async () => {
        await expect(
          PORTAL.connect(GOVERNANCE).setGovernanceFee(MAX_GOVERNANCE_FEE + 1)
        ).to.be.revertedWith("GU: > MAX_GOVERNANCE_FEE");
      });

      describe("success", async () => {
        beforeEach(async () => {
          await PORTAL.connect(GOVERNANCE).setGovernanceFee(MAX_GOVERNANCE_FEE);
        });
        it("doesn't change GOVERNANCE_FEE", async () => {
          expect((await PORTAL.GeodeParams()).GOVERNANCE_FEE).to.be.eq(0);
        });
        it("GOVERNANCE_FEE effective after cooldown", async () => {
          await setTimestamp((await getCurrentBlockTimestamp()) + 1000 * DAY);
          expect((await PORTAL.GeodeParams()).GOVERNANCE_FEE).to.be.eq(MAX_GOVERNANCE_FEE);
        });
        it("emits GovernanceFeeUpdated", async () => {
          await expect(PORTAL.connect(GOVERNANCE).setGovernanceFee(MAX_GOVERNANCE_FEE)).to.emit(
            PORTAL,
            "GovernanceFeeUpdated"
          );
        });
      });
    });

    describe("changeIdCONTROLLER", async () => {
      beforeEach(async () => {
        await PORTAL.connect(GOVERNANCE).newProposal(operatorOwner.address, 4, operatorName, WEEK);
        await PORTAL.connect(SENATE).approveProposal(operatorId);
      });

      it("reverts when NOT CONTROLLER", async () => {
        await expect(
          PORTAL.connect(attacker).changeIdCONTROLLER(operatorId, attacker.address)
        ).to.be.revertedWith("GU: CONTROLLER role needed");
      });
      it("reverts when ZERO_ADDRESS", async () => {
        await expect(
          PORTAL.connect(operatorOwner).changeIdCONTROLLER(operatorId, ZERO_ADDRESS)
        ).to.be.revertedWith("GU: CONTROLLER can not be zero");
      });

      describe("success", async () => {
        beforeEach(async () => {
          await PORTAL.connect(operatorOwner).changeIdCONTROLLER(operatorId, attacker.address);
        });
        it("changed CONTROLLER", async () => {
          expect(await PORTAL.readAddressForId(operatorId, getBytes32("CONTROLLER"))).to.be.eq(
            attacker.address
          );
        });
      });

      it("emits ControllerChanged", async () => {
        await expect(
          PORTAL.connect(operatorOwner).changeIdCONTROLLER(operatorId, attacker.address)
        ).to.emit(PORTAL, "ControllerChanged");
      });
    });

    describe("newProposal", async () => {
      it("reverts when NOT GOVERNANCE", async () => {
        await expect(
          PORTAL.connect(attacker).newProposal(
            operatorOwner.address,
            4,
            operatorName,
            MIN_PROPOSAL_DURATION
          )
        ).to.be.revertedWith("GU: GOVERNANCE role needed");
      });
      it("reverts CONTROLLER = ZERO_ADDRESS", async () => {
        await expect(
          PORTAL.connect(GOVERNANCE).newProposal(
            ZERO_ADDRESS,
            4,
            operatorName,
            MIN_PROPOSAL_DURATION
          )
        ).to.be.revertedWith("GU: CONTROLLER can NOT be ZERO");
      });
      it("reverts TYPE = 0 or 3 or 5", async () => {
        await expect(
          PORTAL.connect(GOVERNANCE).newProposal(
            operatorOwner.address,
            0,
            operatorName,
            MIN_PROPOSAL_DURATION
          )
        ).to.be.revertedWith("GU: TYPE is NONE, GAP or POOL");
        await expect(
          PORTAL.connect(GOVERNANCE).newProposal(
            operatorOwner.address,
            3,
            operatorName,
            MIN_PROPOSAL_DURATION
          )
        ).to.be.revertedWith("GU: TYPE is NONE, GAP or POOL");
        await expect(
          PORTAL.connect(GOVERNANCE).newProposal(
            poolOwner.address,
            5,
            poolName,
            MIN_PROPOSAL_DURATION
          )
        ).to.be.revertedWith("GU: TYPE is NONE, GAP or POOL");
      });
      it("reverts if already proposed", async () => {
        await PORTAL.connect(GOVERNANCE).newProposal(
          operatorOwner.address,
          4,
          operatorName,
          MIN_PROPOSAL_DURATION
        );
        await expect(
          PORTAL.connect(GOVERNANCE).newProposal(
            operatorOwner.address,
            4,
            operatorName,
            MIN_PROPOSAL_DURATION
          )
        ).to.be.revertedWith("GU: NAME already proposed");
      });
      it("reverts < MIN_PROPOSAL_DURATION", async () => {
        await expect(
          PORTAL.connect(GOVERNANCE).newProposal(
            operatorOwner.address,
            4,
            operatorName,
            MIN_PROPOSAL_DURATION - 1
          )
        ).to.be.revertedWith("GU: invalid proposal duration");
      });
      it("reverts > MAX_PROPOSAL_DURATION", async () => {
        await expect(
          PORTAL.connect(GOVERNANCE).newProposal(
            operatorOwner.address,
            4,
            operatorName,
            MAX_PROPOSAL_DURATION + 1
          )
        ).to.be.revertedWith("GU: invalid proposal duration");
      });

      describe("success", async () => {
        let ts;
        beforeEach(async () => {
          await PORTAL.connect(GOVERNANCE).newProposal(
            operatorOwner.address,
            4,
            operatorName,
            MAX_PROPOSAL_DURATION
          );
          ts = await getCurrentBlockTimestamp();
        });
        it("correct Proposal params", async () => {
          const params = await PORTAL.getProposal(operatorId);
          expect(params.CONTROLLER).to.be.eq(operatorOwner.address);
          expect(params.TYPE).to.be.eq(4);
          expect(params.NAME).to.be.eq(operatorName);
          expect(params.deadline).to.be.eq(ts + MAX_PROPOSAL_DURATION);
        });
      });
      it("emits Proposed", async () => {
        await expect(
          PORTAL.connect(GOVERNANCE).newProposal(
            operatorOwner.address,
            4,
            operatorName,
            MAX_PROPOSAL_DURATION
          )
        ).to.emit(PORTAL, "Proposed");
      });
    });

    describe("approveProposal", async () => {
      beforeEach(async () => {
        await PORTAL.connect(GOVERNANCE).newProposal(
          operatorOwner.address,
          4,
          operatorName,
          MIN_PROPOSAL_DURATION
        );
      });
      it("reverts when NOT SENATE", async () => {
        await expect(PORTAL.connect(attacker).approveProposal(operatorId)).to.be.revertedWith(
          "GU: SENATE role needed"
        );
      });
      it("reverts when deadline expired", async () => {
        await setTimestamp((await getCurrentBlockTimestamp()) + MIN_PROPOSAL_DURATION + 1);
        await expect(PORTAL.connect(SENATE).approveProposal(operatorId)).to.be.revertedWith(
          "GU: NOT an active proposal"
        );
      });

      describe("success", async () => {
        let ts;
        beforeEach(async () => {
          await PORTAL.connect(SENATE).approveProposal(operatorId);
          ts = await getCurrentBlockTimestamp();
        });

        it("correct CONTROLLER", async () => {
          expect(await PORTAL.readAddressForId(operatorId, getBytes32("CONTROLLER"))).to.be.eq(
            operatorOwner.address
          );
        });
        it("correct NAME", async () => {
          expect(await PORTAL.readBytesForId(operatorId, getBytes32("NAME"))).to.be.eq(
            operatorName
          );
        });
        it("correct TYPE", async () => {
          expect(await PORTAL.readUintForId(operatorId, getBytes32("TYPE"))).to.be.eq(4);
        });
        it("changed the deadline", async () => {
          expect((await PORTAL.getProposal(operatorId)).deadline).to.be.eq(ts);
        });
        it("added to allIdsByType", async () => {
          expect(await PORTAL.allIdsByType(4, 0)).to.be.eq(operatorId);
        });
      });

      it("change SENATE if TYPE 1", async () => {
        await PORTAL.connect(GOVERNANCE).newProposal(
          user.address,
          1,
          getBytes("newSenate"),
          MIN_PROPOSAL_DURATION
        );
        await PORTAL.connect(SENATE).approveProposal(await PORTAL.generateId("newSenate", 1));
        const params = await PORTAL.GeodeParams();
        expect(params.SENATE).to.be.eq(user.address);
        expect(params.SENATE_EXPIRY).to.be.eq(
          (await getCurrentBlockTimestamp()) + MAX_SENATE_PERIOD
        );
      });

      it("approved upgrade if TYPE 2", async () => {
        expect(await PORTAL.isUpgradeAllowed(gETH.address)).to.be.eq(false);
        await PORTAL.connect(GOVERNANCE).newProposal(
          gETH.address,
          2,
          getBytes("v2"),
          MIN_PROPOSAL_DURATION
        );
        await setTimestamp((await getCurrentBlockTimestamp()) + 60);
        await PORTAL.connect(SENATE).approveProposal(await PORTAL.generateId("v2", 2));
        expect(await PORTAL.isUpgradeAllowed(gETH.address)).to.be.eq(true);
      });

      it("emits ProposalApproved", async () => {
        await expect(PORTAL.connect(SENATE).approveProposal(operatorId)).to.emit(
          PORTAL,
          "ProposalApproved"
        );
      });
    });

    // TODO: This test should be inside the withdrawalContract tests!

    // describe("changeSenate", async () => {
    //   it("reverts when NOT SENATE", async () => {
    //     await expect(
    //       PORTAL.connect(attacker).changeSenate(attacker.address)
    //     ).to.be.revertedWith("GU: SENATE role needed");
    //   });

    //   describe("success", async () => {
    //     it("changes SENATE", async () => {
    //       await PORTAL.connect(SENATE).changeSenate(attacker.address);
    //       expect((await PORTAL.GeodeParams()).SENATE).to.be.eq(
    //         attacker.address
    //       );
    //     });
    //     it("does NOT change SENATE_EXPIRY", async () => {
    //       await PORTAL.connect(SENATE).changeSenate(attacker.address);
    //       expect((await PORTAL.GeodeParams()).SENATE).to.be.eq(
    //         attacker.address
    //       );
    //     });
    //     it("emits NewSenate", async () => {
    //       await expect(
    //         PORTAL.connect(SENATE).changeSenate(attacker.address)
    //       ).to.emit(PORTAL, "NewSenate");
    //     });
    //   });
    // });

    describe("rescueSenate", async () => {
      it("before SENATE_EXPIRY", async () => {
        await expect(PORTAL.connect(GOVERNANCE).rescueSenate(attacker.address)).to.be.revertedWith(
          "GU: cannot rescue yet"
        );
      });
      describe("later", async () => {
        beforeEach(async () => {
          const tmstmp = (await getCurrentBlockTimestamp()) + MAX_SENATE_PERIOD + 1;
          await setTimestamp(tmstmp);
        });
        it("reverts when NOT GOVERNANCE", async () => {
          await expect(PORTAL.connect(attacker).rescueSenate(attacker.address)).to.be.revertedWith(
            "GU: GOVERNANCE role needed"
          );
        });
        describe("success", async () => {
          it("changes SENATE", async () => {
            await PORTAL.connect(GOVERNANCE).rescueSenate(attacker.address);
            expect((await PORTAL.GeodeParams()).SENATE).to.be.eq(attacker.address);
          });
          it("changes SENATE_EXPIRY", async () => {
            await PORTAL.connect(GOVERNANCE).rescueSenate(attacker.address);
            expect((await PORTAL.GeodeParams()).SENATE_EXPIRY).to.be.eq(
              (await getCurrentBlockTimestamp()) + MAX_SENATE_PERIOD
            );
          });
          it("emits NewSenate", async () => {
            await expect(PORTAL.connect(GOVERNANCE).rescueSenate(attacker.address)).to.emit(
              PORTAL,
              "NewSenate"
            );
          });
        });
      });
    });
  });

  describe("StakeUtils", async () => {
    beforeEach(async () => {
      await PORTAL.connect(GOVERNANCE).newProposal(operatorOwner.address, 4, operatorName, WEEK);
      await PORTAL.connect(SENATE).approveProposal(operatorId);
    });

    describe("initiateOperator", async () => {
      it("reverts if TYPE is not OPERATOR", async () => {
        await PORTAL.connect(GOVERNANCE).newProposal(operatorOwner.address, 10, wrongName, WEEK);
        await PORTAL.connect(SENATE).approveProposal(await PORTAL.generateId("wrong", 10));
        await expect(
          PORTAL.connect(attacker).initiateOperator(
            await PORTAL.generateId("wrong", 10),
            0,
            0,
            ZERO_ADDRESS
          )
        ).to.be.revertedWith("SU: TYPE NOT allowed");
      });
      it("reverts if not CONTROLLER", async () => {
        await expect(
          PORTAL.connect(attacker).initiateOperator(operatorId, 0, 0, ZERO_ADDRESS)
        ).to.be.revertedWith("SU: sender NOT CONTROLLER");
      });

      describe("success", async () => {
        beforeEach(async () => {
          await PORTAL.connect(operatorOwner).initiateOperator(
            operatorId,
            operatorFee,
            MIN_VALIDATOR_PERIOD,
            operatorOwner.address
          );
        });
        it("sets maintainer", async () => {
          expect(await PORTAL.readAddressForId(operatorId, getBytes32("maintainer"))).to.be.eq(
            operatorOwner.address
          );
        });
        it("sets MaintenanceFee", async () => {
          expect(await PORTAL.readUintForId(operatorId, getBytes32("fee"))).to.be.eq(operatorFee);
        });
        it("sets validatorPeriod", async () => {
          expect(await PORTAL.readUintForId(operatorId, getBytes32("validatorPeriod"))).to.be.eq(
            MIN_VALIDATOR_PERIOD
          );
        });
        it("sets initiated", async () => {
          expect(await PORTAL.readUintForId(operatorId, getBytes32("initiated"))).to.be.gt(1);
        });
        it("reverts if already initiated", async () => {
          await expect(
            PORTAL.connect(operatorOwner).initiateOperator(
              operatorId,
              0,
              MIN_VALIDATOR_PERIOD,
              operatorOwner.address
            )
          ).to.be.revertedWith("SU: already initiated");
        });
      });

      it("emits IdInitiated", async () => {
        await expect(
          PORTAL.connect(operatorOwner).initiateOperator(
            operatorId,
            operatorFee,
            MIN_VALIDATOR_PERIOD,
            operatorOwner.address
          )
        ).to.emit(PORTAL, "IdInitiated");
      });
    });

    describe("initiatePool", async () => {
      it("reverts if 32 ETH NOT given", async () => {
        await expect(
          PORTAL.initiatePool(
            poolFee,
            interfaceId,
            poolOwner.address,
            poolName,
            interfaceData,
            [0, 1, 1]
          )
        ).to.be.revertedWith("SU: need 1 validator worth of funds");
      });

      describe("success", async () => {
        beforeEach(async () => {
          await PORTAL.connect(poolOwner).initiatePool(
            poolFee,
            interfaceId,
            poolOwner.address,
            poolName,
            interfaceData,
            [0, 1, 1],
            { value: String(32e18) }
          );
        });

        it("sets NAME", async () => {
          expect(await PORTAL.readBytesForId(poolId, getBytes32("NAME"))).to.be.eq(poolName);
        });
        it("sets CONTROLLER", async () => {
          expect(await PORTAL.readAddressForId(poolId, getBytes32("CONTROLLER"))).to.be.eq(
            poolOwner.address
          );
        });
        it("sets TYPE", async () => {
          expect(await PORTAL.readUintForId(poolId, getBytes32("TYPE"))).to.be.eq(5);
        });
        it("added to allIdsByType", async () => {
          expect(await PORTAL.allIdsByType(5, 0)).to.be.eq(poolId);
        });
        it("sets maintainer", async () => {
          expect(await PORTAL.readAddressForId(poolId, getBytes32("maintainer"))).to.be.eq(
            poolOwner.address
          );
        });

        it("sets MaintenanceFee", async () => {
          expect(await PORTAL.readUintForId(poolId, getBytes32("fee"))).to.be.eq(poolFee);
        });
        it("sets gETH price to 1 ETH", async () => {
          expect(await gETH.pricePerShare(poolId)).to.be.eq(String(1e18));
        });
        it("sets initiated", async () => {
          expect(await PORTAL.readUintForId(poolId, getBytes32("initiated"))).to.be.gt(1);
        });

        describe("makes PublicPool", async () => {
          it("correct implementation address", async () => {
            expect(await PORTAL.readUintForId(poolId, getBytes32("private"))).to.be.eq(0);
          });
        });

        describe("_deployWithdrawalContract", async () => {
          let wc;
          beforeEach(async () => {
            wc = await PORTAL.readAddressForId(poolId, getBytes32("withdrawalContract"));
          });
          it("withdrawalContract = withdrawalCredential", async () => {
            expect(
              await PORTAL.readBytesForId(poolId, getBytes32("withdrawalCredential"))
            ).to.be.eq("0x010000000000000000000000" + wc.substr(2).toLowerCase());
          });
          it("correct implementation address", async () => {
            expect(await upgrades.erc1967.getImplementationAddress(wc)).to.be.eq(
              (await get("WithdrawalContract")).address
            );
          });
        });

        describe("_deployInterface", async () => {
          it("reverts if interface is not allowed", async () => {
            await expect(
              PORTAL.connect(poolOwner).initiatePool(
                poolFee,
                wrongId,
                poolOwner.address,
                extraName1,
                interfaceData,
                [0, 1, 1],
                { value: String(32e18) }
              )
            ).to.be.revertedWith("SU: not an interface");
          });
          describe("_setInterface", async () => {
            it("added to interfaces array", async () => {
              expect(await PORTAL.readUintForId(poolId, getBytes32("interfaces"))).to.be.eq(1);
              const gETHInterface = await PORTAL.readAddressArrayForId(
                poolId,
                getBytes32("interfaces"),
                0
              );
              expect(await PORTAL.gETHInterfaces(poolId, 0)).to.be.eq(gETHInterface);
            });
            it("added by gETH", async () => {
              expect(
                await gETH.isInterface(await PORTAL.gETHInterfaces(poolId, 0), poolId)
              ).to.be.eq(true);
            });
          });
        });

        describe("deployLiquidityPool", async () => {
          let liquidityPool;
          beforeEach(async () => {
            liquidityPool = await PORTAL.readAddressForId(poolId, getBytes32("liquidityPool"));
          });
          it("sets liquidityPool", async () => {
            expect().to.be.not.eq(ZERO_ADDRESS);
          });
          it("transfers Ownership to GOVERNANCE", async () => {
            const LP = await ethers.getContractAt("Swap", liquidityPool);
            await expect(LP.setSwapFee(12)).to.be.revertedWith("Ownable: caller is not the owner");
            await LP.connect(GOVERNANCE).setSwapFee(12);
            expect(await LP.getSwapFee()).to.be.eq(12);
          });

          it("sets approval", async () => {
            expect(await gETH.isApprovedForAll(PORTAL.address, liquidityPool)).to.be.eq(true);
          });
        });

        it("reverts if already initiated", async () => {
          await expect(
            PORTAL.connect(poolOwner).initiatePool(
              poolFee,
              wrongId,
              poolOwner.address,
              poolName,
              interfaceData,
              [1, 1, 1],
              { value: String(32e18) }
            )
          ).to.be.revertedWith("SU: already initiated'");
        });
      });

      describe("later > make Public Pool", async () => {
        beforeEach(async () => {
          await PORTAL.connect(poolOwner).initiatePool(
            poolFee,
            interfaceId,
            poolOwner.address,
            poolName,
            interfaceData,
            [1, 1, 1],
            { value: String(32e18) }
          );
        });
        it("reverts if not CONTROLLER", async () => {
          await expect(PORTAL.setPoolVisibility(poolId, false)).to.be.revertedWith(
            "SU: sender NOT CONTROLLER"
          );
        });
        it("reverts if TYPE is not POOL", async () => {
          await PORTAL.connect(operatorOwner).initiateOperator(
            operatorId,
            operatorFee,
            MIN_VALIDATOR_PERIOD,
            operatorOwner.address
          );
          await expect(
            PORTAL.connect(operatorOwner).setPoolVisibility(operatorId, false)
          ).to.be.revertedWith("SU: TYPE NOT allowed'");
        });
        it("reverts if already a public pool", async () => {
          await PORTAL.connect(poolOwner).setPoolVisibility(poolId, false);
          await expect(
            PORTAL.connect(poolOwner).setPoolVisibility(poolId, false)
          ).to.be.revertedWith("SU: already set");
        });
        it("isPrivatePool returns false", async () => {
          await PORTAL.connect(poolOwner).setPoolVisibility(poolId, false);
          expect(await PORTAL.isPrivatePool(poolId)).to.be.eq(false);
        });
        describe("later > makePrivatePool", async () => {
          beforeEach(async () => {
            await PORTAL.connect(poolOwner).setPoolVisibility(poolId, false);
          });
          it("reverts if not CONTROLLER", async () => {
            await expect(PORTAL.setPoolVisibility(poolId, true)).to.be.revertedWith(
              "SU: sender NOT CONTROLLER"
            );
          });
          it("reverts if TYPE is not POOL", async () => {
            await PORTAL.connect(operatorOwner).initiateOperator(
              operatorId,
              operatorFee,
              MIN_VALIDATOR_PERIOD,
              operatorOwner.address
            );
            await expect(
              PORTAL.connect(operatorOwner).setPoolVisibility(operatorId, true)
            ).to.be.revertedWith("SU: TYPE NOT allowed'");
          });
          it("reverts if already a private pool", async () => {
            await PORTAL.connect(poolOwner).setPoolVisibility(poolId, true);
            await expect(
              PORTAL.connect(poolOwner).setPoolVisibility(poolId, true)
            ).to.be.revertedWith("SU: already set");
          });
          it("isPrivatePool returns false", async () => {
            await PORTAL.connect(poolOwner).setPoolVisibility(poolId, true);
            expect(await PORTAL.isPrivatePool(poolId)).to.be.eq(true);
          });
        });
      });

      describe("later > deployLiquidityPool", async () => {
        beforeEach(async () => {
          await PORTAL.connect(poolOwner).initiatePool(
            poolFee,
            interfaceId,
            poolOwner.address,
            poolName,
            interfaceData,
            [1, 1, 0],
            { value: String(32e18) }
          );
        });
        it("reverts if not CONTROLLER", async () => {
          await expect(PORTAL.deployLiquidityPool(poolId)).to.be.revertedWith(
            "SU: sender NOT CONTROLLER"
          );
        });
        it("reverts if TYPE is not POOL", async () => {
          await PORTAL.connect(operatorOwner).initiateOperator(
            operatorId,
            operatorFee,
            MIN_VALIDATOR_PERIOD,
            operatorOwner.address
          );
          await expect(
            PORTAL.connect(operatorOwner).deployLiquidityPool(operatorId)
          ).to.be.revertedWith("SU: TYPE NOT allowed'");
        });
        it("reverts if already deployed", async () => {
          await PORTAL.connect(poolOwner).deployLiquidityPool(poolId);
          await expect(PORTAL.connect(poolOwner).deployLiquidityPool(poolId)).to.be.revertedWith(
            "SU: already latest version"
          );
        });
      });

      it("emits IdInitiated", async () => {
        await expect(
          PORTAL.connect(poolOwner).initiatePool(
            poolFee,
            interfaceId,
            poolOwner.address,
            poolName,
            interfaceData,
            [0, 1, 1],
            { value: String(32e18) }
          )
        ).to.emit(PORTAL, "IdInitiated");
      });
    });

    describe("initiated operator", async () => {
      beforeEach(async () => {
        await PORTAL.connect(operatorOwner).initiateOperator(
          operatorId,
          operatorFee,
          MIN_VALIDATOR_PERIOD,
          operatorOwner.address
        );
      });

      describe("changeMaintainer", async () => {
        it("reverts if not CONTROLLER", async () => {
          await expect(
            PORTAL.connect(attacker).changeMaintainer(operatorId, attacker.address)
          ).to.be.revertedWith("SU: sender NOT CONTROLLER'");
        });
        describe("_setMaintainer", async () => {
          it("reverts if ZERO_ADDRESS", async () => {
            await expect(
              PORTAL.connect(operatorOwner).changeMaintainer(operatorId, ZERO_ADDRESS)
            ).to.be.revertedWith("SU: maintainer can NOT be zero");
          });
          it("reverts if old is new", async () => {
            await expect(
              PORTAL.connect(operatorOwner).changeMaintainer(operatorId, operatorOwner.address)
            ).to.be.revertedWith("SU: provided the current maintainer");
          });
          describe("success", async () => {
            it("changes maintainer", async () => {
              await PORTAL.connect(operatorOwner).changeMaintainer(operatorId, attacker.address);
              expect(await PORTAL.readAddressForId(operatorId, getBytes32("maintainer"))).to.be.eq(
                attacker.address
              );
            });
            it("emits MaintainerChanged", async () => {
              await expect(
                PORTAL.connect(operatorOwner).changeMaintainer(operatorId, attacker.address)
              ).to.emit(PORTAL, "MaintainerChanged");
            });
          });
        });
      });
      describe("switchMaintenanceFee", async () => {
        it("reverts if not CONTROLLER", async () => {
          await expect(
            PORTAL.connect(attacker).switchMaintenanceFee(operatorId, 0)
          ).to.be.revertedWith("SU: sender NOT CONTROLLER'");
        });

        describe("_setMaintenanceFee", async () => {
          it("reverts > MAX_MAINTAINER_FEE", async () => {
            await expect(
              PORTAL.connect(operatorOwner).switchMaintenanceFee(operatorId, MAX_GOVERNANCE_FEE * 3)
            ).to.be.revertedWith("SU: > MAX_MAINTENANCE_FEE");
          });
        });

        describe("success", async () => {
          let ts;
          beforeEach(async () => {
            await PORTAL.connect(operatorOwner).switchMaintenanceFee(operatorId, 100);
            ts = await getCurrentBlockTimestamp();
          });
          it("sets priorFee", async () => {
            expect(await PORTAL.readUintForId(operatorId, getBytes32("priorFee"))).to.be.eq(
              operatorFee
            );
          });
          it("sets fee", async () => {
            expect(await PORTAL.readUintForId(operatorId, getBytes32("fee"))).to.be.eq(100);
          });
          it("sets feeSwitch", async () => {
            expect(await PORTAL.readUintForId(operatorId, getBytes32("feeSwitch"))).to.be.eq(
              ts + SWITCH_LATENCY
            );
          });
          it("getMaintenanceFee returns the old fee", async () => {
            expect(await PORTAL.getMaintenanceFee(operatorId)).to.be.eq(operatorFee);
          });
          it("getMaintenanceFee returns the new fee after 3 days", async () => {
            await setTimestamp((await getCurrentBlockTimestamp()) + 4 * DAY);
            expect(await PORTAL.getMaintenanceFee(operatorId)).to.be.eq(100);
          });
          it("reverts if already switching", async () => {
            await expect(
              PORTAL.connect(operatorOwner).switchMaintenanceFee(operatorId, 100)
            ).to.be.revertedWith("SU: fee is currently switching");
          });
        });
        it("emits FeeSwitched", async () => {
          await expect(PORTAL.connect(operatorOwner).switchMaintenanceFee(operatorId, 100)).to.emit(
            PORTAL,
            "FeeSwitched"
          );
        });
      });

      describe("increaseWalletBalance", async () => {
        describe("success: not maintainer or controller", async () => {
          describe("_increaseWalletBalance", async () => {
            it("increases wallet", async () => {
              expect(await PORTAL.readUintForId(operatorId, getBytes32("wallet"))).to.be.eq(
                String(0)
              );
              await PORTAL.increaseWalletBalance(operatorId, {
                value: String(1e17),
              });
              expect(await PORTAL.readUintForId(operatorId, getBytes32("wallet"))).to.be.eq(
                String(1e17)
              );
            });
          });
        });
      });

      describe("decreaseWalletBalance", async () => {
        beforeEach(async () => {
          await PORTAL.connect(operatorOwner).increaseWalletBalance(operatorId, {
            value: String(1e17),
          });
        });

        it("reverts if not CONTROLLER", async () => {
          await expect(
            PORTAL.connect(attacker).decreaseWalletBalance(operatorId, String(1e17))
          ).to.be.revertedWith("SU: sender NOT CONTROLLER");
        });
        it("reverts if not enough funds in portal", async () => {
          await expect(
            PORTAL.connect(operatorOwner).decreaseWalletBalance(operatorId, String(1e18))
          ).to.be.revertedWith("SU: not enough funds in Portal ?");
        });
        describe("_decreaseWalletBalance", async () => {
          it("reverts if not enough funds in wallet", async () => {
            await operatorOwner.sendTransaction({
              to: PORTAL.address,
              value: ethers.utils.parseEther("1.0"), // Sends exactly 1.0 ether
            });
            await expect(
              PORTAL.connect(operatorOwner).decreaseWalletBalance(operatorId, String(1e18))
            ).to.be.revertedWith("SU: NOT enough funds in wallet");
          });
        });
        describe("success", async () => {
          describe("_decreaseWalletBalance", async () => {
            it("decreases wallet", async () => {
              expect(await PORTAL.readUintForId(operatorId, getBytes32("wallet"))).to.be.eq(
                String(1e17)
              );
              await PORTAL.connect(operatorOwner).decreaseWalletBalance(operatorId, String(2e16));
              expect(await PORTAL.readUintForId(operatorId, getBytes32("wallet"))).to.be.eq(
                String(8e16)
              );
            });
          });
          it("sends it to CONTROLLER", async () => {
            await PORTAL.connect(operatorOwner).changeMaintainer(operatorId, user.address);
            const preBal = await provider.getBalance(operatorOwner.address);
            const tx = await PORTAL.connect(operatorOwner).decreaseWalletBalance(
              operatorId,
              String(2e16)
            );
            const receipt = await tx.wait();
            const gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);

            expect(await provider.getBalance(operatorOwner.address)).to.be.eq(
              BigNumber.from(preBal).add(String(2e16)).sub(gasUsed)
            );
          });
        });
      });

      describe("switchValidatorPeriod", async () => {
        it("reverts if not maintainer", async () => {
          await expect(
            PORTAL.connect(attacker).switchValidatorPeriod(operatorId, MIN_VALIDATOR_PERIOD)
          ).to.be.revertedWith("SU: sender NOT maintainer");
        });
        it("reverts if not operator", async () => {
          await PORTAL.connect(attacker).initiatePool(
            poolFee,
            interfaceId,
            poolOwner.address,
            wrongName,
            interfaceData,
            [1, 1, 1],
            { value: String(32e18) }
          );

          await expect(
            PORTAL.connect(attacker).switchValidatorPeriod(wrongId, MIN_VALIDATOR_PERIOD)
          ).to.be.revertedWith("SU: TYPE NOT allowed");
        });
        it("reverts if still switching", async () => {
          await PORTAL.connect(operatorOwner).switchValidatorPeriod(
            operatorId,
            MIN_VALIDATOR_PERIOD
          );
          await expect(
            PORTAL.connect(operatorOwner).switchValidatorPeriod(operatorId, MIN_VALIDATOR_PERIOD)
          ).to.be.revertedWith("SU: period is currently switching");
        });
        describe("_setValidatorPeriod", async () => {
          it("reverts if < MIN_VALIDATOR_PERIOD", async () => {
            await expect(
              PORTAL.connect(operatorOwner).switchValidatorPeriod(
                operatorId,
                MIN_VALIDATOR_PERIOD - 1
              )
            ).to.be.revertedWith("SU: < MIN_VALIDATOR_PERIOD");
          });
          it("reverts if > MAX_VALIDATOR_PERIOD", async () => {
            await expect(
              PORTAL.connect(operatorOwner).switchValidatorPeriod(
                operatorId,
                MAX_VALIDATOR_PERIOD + 1
              )
            ).to.be.revertedWith("SU: > MAX_VALIDATOR_PERIOD");
          });
        });
        describe("success", async () => {
          let ts;
          beforeEach(async () => {
            await PORTAL.connect(operatorOwner).switchValidatorPeriod(
              operatorId,
              MAX_VALIDATOR_PERIOD
            );
            ts = await getCurrentBlockTimestamp();
          });
          it("sets priorPeriod", async () => {
            expect(await PORTAL.readUintForId(operatorId, getBytes32("priorPeriod"))).to.be.eq(
              MIN_VALIDATOR_PERIOD
            );
          });
          it("sets validatorPeriod", async () => {
            expect(await PORTAL.readUintForId(operatorId, getBytes32("validatorPeriod"))).to.be.eq(
              MAX_VALIDATOR_PERIOD
            );
          });
          it("sets periodSwitch", async () => {
            expect(await PORTAL.readUintForId(operatorId, getBytes32("periodSwitch"))).to.be.eq(
              ts + SWITCH_LATENCY
            );
          });
        });
        it("emits ValidatorPeriodSwitched", async () => {
          await expect(
            PORTAL.connect(operatorOwner).switchValidatorPeriod(operatorId, MAX_VALIDATOR_PERIOD)
          ).to.emit(PORTAL, "ValidatorPeriodSwitched");
        });
      });

      describe("initiated pool", async () => {
        beforeEach(async () => {
          await PORTAL.connect(poolOwner).initiatePool(
            poolFee,
            interfaceId,
            poolOwner.address,
            poolName,
            interfaceData,
            [1, 0, 0],
            { value: String(32e18) }
          );
        });

        describe("approveOperators", async () => {
          it("reverts if not maintainer", async () => {
            await expect(
              PORTAL.connect(attacker).approveOperators(poolId, [operatorId], [0])
            ).to.be.revertedWith("SU: sender NOT maintainer");
          });
          it("reverts if poolId is not POOL", async () => {
            await expect(
              PORTAL.connect(operatorOwner).approveOperators(operatorId, [poolId], [0])
            ).to.be.revertedWith("SU: TYPE NOT allowed");
          });
          it("reverts if wrong length array", async () => {
            await expect(
              PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [0, 1])
            ).to.be.revertedWith("SU: allowances should match");
          });
          it("reverts if operatorId is not OPERATOR", async () => {
            await PORTAL.connect(attacker).initiatePool(
              poolFee,
              interfaceId,
              poolOwner.address,
              wrongName,
              interfaceData,
              [0, 0, 0],
              { value: String(32e18) }
            );
            await expect(
              PORTAL.connect(poolOwner).approveOperators(poolId, [wrongId], [0])
            ).to.be.revertedWith("SU: TYPE NOT allowed");
          });
          describe("success", async () => {
            it("sets allowance", async () => {
              await PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [10]);
              expect(
                await PORTAL.readUintForId(
                  poolId,
                  await PORTAL.getKey(operatorId, getBytes32("allowance"))
                )
              ).to.be.eq(10);
            });
            it("emits OperatorApproval", async () => {
              await expect(
                PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [10])
              ).to.emit(PORTAL, "OperatorApproval");
            });
          });
        });

        describe("deposit", async () => {
          describe("Private Pool", async () => {
            it("allows CONTROLLER to deposit", async () => {
              await PORTAL.connect(poolOwner).deposit(
                poolId,
                0,
                (await getCurrentBlockTimestamp()) + WEEK,
                0,
                [],
                user.address,
                {
                  value: String(1e18),
                }
              );
            });
            describe("setWhitelist", async () => {
              it("reverts if not pool", async () => {
                await expect(
                  PORTAL.connect(operatorOwner).setWhitelist(operatorId, ZERO_ADDRESS)
                ).to.be.revertedWith("SU: TYPE NOT allowed");
              });
              it("reverts if not CONTROLLER", async () => {
                await expect(
                  PORTAL.connect(attacker).setWhitelist(poolId, ZERO_ADDRESS)
                ).to.be.revertedWith("SU: sender NOT CONTROLLER");
              });
              it("reverts if public pool", async () => {
                await PORTAL.connect(poolOwner).setPoolVisibility(poolId, false);
                await expect(
                  PORTAL.connect(poolOwner).setWhitelist(poolId, ZERO_ADDRESS)
                ).to.be.revertedWith("SU: must be private pool");
              });
              describe("success", async () => {
                let whitelist;
                beforeEach(async () => {
                  const whitelistFactory = await ethers.getContractFactory("Whitelist");
                  whitelist = await whitelistFactory.connect(poolOwner).deploy();
                  await PORTAL.connect(poolOwner).setWhitelist(poolId, whitelist.address);
                  await whitelist.connect(poolOwner).setAddress(user.address, true);
                });
                it("allows stakers to deposit", async () => {
                  await PORTAL.connect(user).deposit(
                    poolId,
                    0,
                    (await getCurrentBlockTimestamp()) + WEEK,
                    0,
                    [],
                    user.address,
                    {
                      value: String(1e18),
                    }
                  );
                });
                it("remove afterwards from whitelist to prevent", async () => {
                  await whitelist.connect(poolOwner).setAddress(user.address, false);

                  await expect(
                    PORTAL.connect(attacker).deposit(
                      poolId,
                      0,
                      (await getCurrentBlockTimestamp()) + WEEK,
                      0,
                      [],
                      user.address,
                      {
                        value: String(1e18),
                      }
                    )
                  ).to.be.revertedWith("SU: sender NOT whitelisted");
                });
              });
            });
          });

          describe("Public Pool", async () => {
            beforeEach(async () => {
              await PORTAL.connect(poolOwner).setPoolVisibility(poolId, false);
            });
            it("reverts if poolId is NOT POOL", async () => {
              await expect(
                PORTAL.deposit(operatorId, 0, 0, 0, [], user.address)
              ).to.be.revertedWith("SU: TYPE NOT allowed");
            });
            it("reverts if ZERO_ADDRESS is receiver", async () => {
              await expect(
                PORTAL.deposit(
                  poolId,
                  0,
                  (await getCurrentBlockTimestamp()) + WEEK,
                  0,
                  [],
                  ZERO_ADDRESS
                )
              ).to.be.revertedWith("SU: receiver is zero address");
            });
            it("reverts if already expired", async () => {
              await expect(PORTAL.deposit(poolId, 0, 0, 0, [], user.address)).to.be.revertedWith(
                "SU: deadline not met"
              );
            });

            it("reverts if less than minimum", async () => {
              await expect(
                PORTAL.connect(user).deposit(
                  poolId,
                  MAX_UINT256,
                  (await getCurrentBlockTimestamp()) + WEEK,
                  0,
                  [],
                  user.address,
                  {
                    value: String(69e17),
                  }
                )
              ).to.be.revertedWith("SU: less than minimum");
            });

            describe("_mintgETH", async () => {
              describe("isMintingAllowed", async () => {
                it("initially true", async () => {
                  expect(await PORTAL.isPriceValid(poolId)).to.be.eq(true);
                  expect(await PORTAL.isMintingAllowed(poolId)).to.be.eq(true);
                });
                it("false if isPriceValid is false, reverts deposit", async () => {
                  const later = (await getCurrentBlockTimestamp()) + 2 * DAY + 1;
                  await setTimestamp(later);

                  const values = [[poolId.toString(), String(1e18)]];
                  tree = StandardMerkleTree.of(values, ["uint256", "uint256"]);

                  await PORTAL.connect(ORACLE).reportOracle(tree.root, 50001);

                  expect(await PORTAL.isPriceValid(poolId)).to.be.eq(false);
                  expect(await PORTAL.isMintingAllowed(poolId)).to.be.eq(false);
                  await expect(
                    PORTAL.connect(user).deposit(
                      poolId,
                      0,
                      (await getCurrentBlockTimestamp()) + WEEK,
                      0,
                      [],
                      user.address,
                      {
                        value: String(69e17),
                      }
                    )
                  ).to.be.revertedWith("OU: NOT all proofs are valid");
                });
                it("false if recoveryMode is true, reverts deposit", async () => {
                  await (
                    await ethers.getContractAt(
                      "WithdrawalContract",
                      await PORTAL.readAddressForId(poolId, getBytes32("withdrawalContract"))
                    )
                  )
                    .connect(poolOwner)
                    .pause();
                  expect(await PORTAL.isMintingAllowed(poolId)).to.be.eq(false);
                  await expect(
                    PORTAL.connect(user).deposit(
                      poolId,
                      0,
                      (await getCurrentBlockTimestamp()) + WEEK,
                      0,
                      [],
                      user.address,
                      {
                        value: String(69e17),
                      }
                    )
                  ).to.be.revertedWith("SU: minting is not allowed");
                });
              });
            });

            describe("Success: No liquidity pool", async () => {
              let surplus;
              let portalEth;
              let portalgEth;
              let totSup;
              let usergETH;
              beforeEach(async () => {
                portalEth = await provider.getBalance(PORTAL.address);
                portalgEth = await gETH.balanceOf(PORTAL.address, poolId);
                totSup = await gETH.totalSupply(poolId);
                usergETH = await gETH.balanceOf(user.address, poolId);
                surplus = await PORTAL.readUintForId(poolId, getBytes32("surplus"));

                await PORTAL.connect(user).deposit(
                  poolId,
                  0,
                  (await getCurrentBlockTimestamp()) + WEEK,
                  0,
                  [],
                  user.address,
                  {
                    value: String(69e17),
                  }
                );
              });

              it("total supply increased accordingly", async () => {
                expect(await gETH.totalSupply(poolId)).to.be.eq(
                  BigNumber.from(totSup).add(String(69e17))
                );
              });
              it("surplus increased accordingly", async () => {
                expect(await PORTAL.readUintForId(poolId, getBytes32("surplus"))).to.be.eq(
                  BigNumber.from(surplus).add(String(69e17))
                );
              });
              it("portal Ether increased accordingly", async () => {
                expect(await provider.getBalance(PORTAL.address)).to.be.eq(
                  BigNumber.from(portalEth).add(String(69e17))
                );
              });
              it("portal gETH no change", async () => {
                expect(await gETH.balanceOf(PORTAL.address, poolId)).to.be.eq(portalgEth);
              });
              it("receiver gETH increased accordingly", async () => {
                expect(await gETH.balanceOf(user.address, poolId)).to.be.eq(
                  BigNumber.from(usergETH).add(String(69e17))
                );
              });
            });

            describe("With liquidity pool", async () => {
              let liqPool;
              let surplus;
              let portalEth;
              let portalgEth;
              let totSup;
              let usergETH;
              let receivergETH;

              beforeEach(async () => {
                await PORTAL.connect(poolOwner).deployLiquidityPool(poolId);

                await PORTAL.deposit(
                  poolId,
                  0,
                  (await getCurrentBlockTimestamp()) + WEEK,
                  0,
                  [],
                  deployer.address,
                  {
                    value: String(2e20),
                  }
                );

                const lpAddress = await PORTAL.readAddressForId(
                  poolId,
                  getBytes32("liquidityPool")
                );
                await gETH.setApprovalForAll(lpAddress, true);
                liqPool = await ethers.getContractAt("Swap", lpAddress);

                await liqPool.addLiquidity([String(1e20), String(1e20)], 0, MAX_UINT256, {
                  value: String(1e20),
                });

                portalEth = await provider.getBalance(PORTAL.address);
                portalgEth = await gETH.balanceOf(PORTAL.address, poolId);
                totSup = await gETH.totalSupply(poolId);
                usergETH = await gETH.balanceOf(user.address, poolId);
                receivergETH = await gETH.balanceOf(attacker.address, poolId);
                surplus = await PORTAL.readUintForId(poolId, getBytes32("surplus"));
              });

              describe("debt < IGNORABLE_DEBT (0)", async () => {
                beforeEach(async () => {
                  await PORTAL.connect(user).deposit(
                    poolId,
                    0,
                    (await getCurrentBlockTimestamp()) + WEEK,
                    0,
                    [],
                    attacker.address,
                    {
                      value: String(69e17),
                    }
                  );
                });

                it("correct mint amount from totalSupply", async () => {
                  expect(await gETH.totalSupply(poolId)).to.be.eq(
                    BigNumber.from(totSup).add(String(69e17))
                  );
                });
                it("surplus increased accordingly", async () => {
                  expect(await PORTAL.readUintForId(poolId, getBytes32("surplus"))).to.be.eq(
                    BigNumber.from(surplus).add(String(69e17))
                  );
                });
                it("Portal gETH not changed", async () => {
                  expect(await provider.getBalance(PORTAL.address)).to.be.eq(
                    BigNumber.from(portalEth).add(String(69e17))
                  );
                });
                it("portal Ether increased accordingly", async () => {
                  expect(await gETH.balanceOf(PORTAL.address, poolId)).to.be.eq(portalgEth);
                });
                it("receiver gETH increased accordingly", async () => {
                  expect(await gETH.balanceOf(attacker.address, poolId)).to.be.eq(
                    BigNumber.from(receivergETH).add(String(69e17))
                  );
                });
              });

              describe("debt > msg.value", async () => {
                let debt;
                let expBuy;
                beforeEach(async () => {
                  await liqPool.swap(1, 0, BigNumber.from(String(9e19)), 0, MAX_UINT256);
                  debt = await liqPool.getDebt();
                  console.log("debt: ", debt.div(String(1e18)).toString());

                  expBuy = await liqPool.calculateSwap(0, 1, String(69e17));
                  await PORTAL.connect(user).deposit(
                    poolId,
                    0,
                    (await getCurrentBlockTimestamp()) + WEEK,
                    0,
                    [],
                    attacker.address,
                    {
                      value: String(69e17),
                    }
                  );
                });
                it("no mint amount from totalSupply", async () => {
                  expect(await gETH.totalSupply(poolId)).to.be.eq(totSup);
                });
                it("surplus not increased", async () => {
                  expect(await PORTAL.readUintForId(poolId, getBytes32("surplus"))).to.be.eq(
                    BigNumber.from(surplus)
                  );
                });
                it("portal gEth not changed ", async () => {
                  expect(await gETH.balanceOf(PORTAL.address, poolId)).to.be.eq(portalgEth);
                });
                it("portal Ether not changed", async () => {
                  expect(await provider.getBalance(PORTAL.address)).to.be.eq(portalEth);
                });
                it("receiver gETH increased accordingly", async () => {
                  expect(await gETH.balanceOf(attacker.address, poolId)).to.be.eq(
                    BigNumber.from(usergETH).add(expBuy)
                  );
                });
              });

              describe("msg.value > debt", async () => {
                let debt;
                let expMint;
                let expBuy;
                beforeEach(async () => {
                  await liqPool.swap(1, 0, BigNumber.from(String(9e19)), 0, MAX_UINT256);
                  debt = await liqPool.getDebt();
                  console.log("debt: ", debt.div(String(1e18)).toString());

                  expBuy = await liqPool.calculateSwap(0, 1, debt);
                  expMint = BigNumber.from(String(1e20)).sub(debt);

                  await PORTAL.connect(user).deposit(
                    poolId,
                    0,
                    (await getCurrentBlockTimestamp()) + WEEK,
                    0,
                    [],
                    attacker.address,
                    {
                      value: String(1e20),
                    }
                  );
                });
                it("correct mint amount, from totalSupply", async () => {
                  expect(await gETH.totalSupply(poolId)).to.be.eq(totSup.add(expMint));
                });
                it("surplus increased accordingly", async () => {
                  expect(await PORTAL.readUintForId(poolId, getBytes32("surplus"))).to.be.eq(
                    BigNumber.from(surplus).add(expMint)
                  );
                });
                it("portal gEth not changed ", async () => {
                  expect(await gETH.balanceOf(PORTAL.address, poolId)).to.be.eq(portalgEth);
                });
                it("portal Ether changed accordingly", async () => {
                  expect(await provider.getBalance(PORTAL.address)).to.be.eq(
                    portalEth.add(expMint)
                  );
                });
                it("receiver gETH increased accordingly", async () => {
                  expect(await gETH.balanceOf(attacker.address, poolId)).to.be.eq(
                    BigNumber.from(usergETH).add(expMint).add(expBuy)
                  );
                });
              });
            });

            it("emits Deposit", async () => {
              await expect(
                PORTAL.connect(user).deposit(
                  poolId,
                  0,
                  (await getCurrentBlockTimestamp()) + WEEK,
                  0,
                  [],
                  attacker.address,
                  {
                    value: String(1e20),
                  }
                )
              ).to.emit(PORTAL, "Deposit");
            });
          });
        });

        describe("proposeStake", async () => {
          beforeEach(async () => {
            await PORTAL.connect(poolOwner).setPoolVisibility(poolId, false);
          });
          describe("initial tests", async () => {
            it("reverts if operatorId is not operator", async () => {
              await PORTAL.connect(attacker).initiatePool(
                poolFee,
                interfaceId,
                poolOwner.address,
                wrongName,
                interfaceData,
                [0, 0, 0],
                { value: String(32e18) }
              );
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  wrongId,
                  [pubkey0, pubkey1],
                  [signature01, signature11],
                  [signature031, signature131]
                )
              ).to.be.revertedWith("SU: TYPE NOT allowed");
            });
            it("reverts if caller is not maintainer", async () => {
              await expect(
                PORTAL.connect(attacker).proposeStake(
                  poolId,
                  operatorId,
                  [pubkey0, pubkey1],
                  [signature01, signature11],
                  [signature031, signature131]
                )
              ).to.be.revertedWith("SU: sender NOT maintainer");
            });
            it("reverts if poolId is not pool", async () => {
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  operatorId,
                  operatorId,
                  [pubkey0, pubkey1],
                  [signature01, signature11],
                  [signature031, signature131]
                )
              ).to.be.revertedWith("SU: TYPE NOT allowed");
            });
            it("reverts if not 1 to 50 pubkey given ", async () => {
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(poolId, operatorId, [], [], [])
              ).to.be.revertedWith("SU: 0 - 50 validators");
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  operatorId,
                  new Array(51).fill(pubkey0),
                  new Array(51).fill(signature01),
                  new Array(51).fill(signature031)
                )
              ).to.be.revertedWith("SU: 0 - 50 validators");
            });
            it("reverts if length != signatures1.length", async () => {
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  operatorId,
                  [pubkey0, pubkey1],
                  [signature01],
                  [signature031, signature131]
                )
              ).to.be.revertedWith("SU: invalid signatures1 length");
            });
            it("reverts if length != signatures31.length", async () => {
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  operatorId,
                  [pubkey0, pubkey1],
                  [signature01, signature11],
                  [signature031]
                )
              ).to.be.revertedWith("SU: invalid signatures31 length");
            });
            it("reverts if not enought allowance", async () => {
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  operatorId,
                  [pubkey0, pubkey1],
                  [signature01, signature11],
                  [signature031, signature131]
                )
              ).to.be.revertedWith("SU: NOT enough allowance");
            });
            it("reverts if not enought surplus", async () => {
              await PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [10]);
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  operatorId,
                  [pubkey0, pubkey1],
                  [signature01, signature11],
                  [signature031, signature131]
                )
              ).to.be.revertedWith("SU: NOT enough surplus");
            });
            it("reverts if not enought funds in wallet", async () => {
              await PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [10]);
              await PORTAL.connect(poolOwner).deposit(
                poolId,
                0,
                (await getCurrentBlockTimestamp()) + WEEK,
                0,
                [],
                user.address,
                {
                  value: String(64e18),
                }
              );
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  operatorId,
                  [pubkey0, pubkey1],
                  [signature01, signature11],
                  [signature031, signature131]
                )
              ).to.be.revertedWith("SU: NOT enough funds in wallet");
            });
          });
          describe("validator specific tests", async () => {
            beforeEach(async () => {
              await PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [10]);
              await PORTAL.connect(user).deposit(
                poolId,
                0,
                (await getCurrentBlockTimestamp()) + WEEK,
                0,
                [],
                user.address,
                {
                  value: String(64e18),
                }
              );
              await PORTAL.increaseWalletBalance(operatorId, {
                value: String(2e18),
              });
            });
            it("reverts if already used", async () => {
              await PORTAL.connect(operatorOwner).proposeStake(
                poolId,
                operatorId,
                [pubkey0],
                [signature01],
                [signature031]
              );
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  operatorId,
                  [pubkey0],
                  [signature01],
                  [signature031]
                )
              ).to.be.revertedWith("SU: Pubkey already used or alienated");
            });
            it("reverts if already alienated", async () => {
              await PORTAL.connect(operatorOwner).proposeStake(
                poolId,
                operatorId,
                [pubkey0],
                [signature01],
                [signature031]
              );
              await PORTAL.connect(ORACLE).updateVerificationIndex(1, [pubkey0]);
              await PORTAL.connect(GOVERNANCE).releasePrisoned(operatorId);
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  operatorId,
                  [pubkey0],
                  [signature01],
                  [signature031]
                )
              ).to.be.revertedWith("SU: Pubkey already used or alienated");
            });
            it("reverts if pubkey is not correct", async () => {
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  operatorId,
                  [pubkey0 + getBytes("error").substr(2)],
                  [signature01],
                  [signature031]
                )
              ).to.be.revertedWith("SU: PUBKEY_LENGTH ERROR");
            });
            it("reverts if signatures1 is not correct", async () => {
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  operatorId,
                  [pubkey0],
                  [signature01 + getBytes("error").substr(2)],
                  [signature031]
                )
              ).to.be.revertedWith("SU: SIGNATURE_LENGTH ERROR");
            });
            it("reverts if signatures31 is not correct", async () => {
              await expect(
                PORTAL.connect(operatorOwner).proposeStake(
                  poolId,
                  operatorId,
                  [pubkey0],
                  [signature01],
                  [signature031 + getBytes("error").substr(2)]
                )
              ).to.be.revertedWith("SU: SIGNATURE_LENGTH ERROR");
            });
          });
          describe("success", async () => {
            let wallet;
            let surplus;
            let secured;
            let proposedValidators;
            let totalProposedValidators;
            let contractBalance;
            let validatorIndex;
            beforeEach(async () => {
              await PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [10]);
              await PORTAL.connect(user).deposit(
                poolId,
                0,
                (await getCurrentBlockTimestamp()) + WEEK,
                0,
                [],
                user.address,
                {
                  value: String(64e18),
                }
              );
              await PORTAL.increaseWalletBalance(operatorId, {
                value: String(3e18),
              });

              wallet = await PORTAL.readUintForId(operatorId, getBytes32("wallet"));
              surplus = await PORTAL.readUintForId(poolId, getBytes32("surplus"));
              secured = await PORTAL.readUintForId(poolId, getBytes32("secured"));
              proposedValidators = await PORTAL.readUintForId(
                poolId,
                await PORTAL.getKey(operatorId, getBytes32("proposedValidators"))
              );
              totalProposedValidators = await PORTAL.readUintForId(
                operatorId,
                getBytes32("totalProposedValidators")
              );
              contractBalance = await provider.getBalance(PORTAL.address);
              validatorIndex = (await PORTAL.StakingParams()).VALIDATORS_INDEX;

              await PORTAL.connect(operatorOwner).proposeStake(
                poolId,
                operatorId,
                [pubkey0, pubkey1],
                [signature01, signature11],
                [signature031, signature131]
              );
            });
            it("wallet decreased", async () => {
              expect(wallet.sub(String(2e18))).to.be.eq(
                await PORTAL.readUintForId(operatorId, getBytes32("wallet"))
              );
            });
            it("surplus decreased", async () => {
              expect(surplus.sub(String(64e18))).to.be.eq(
                await PORTAL.readUintForId(poolId, getBytes32("surplus"))
              );
            });
            it("secured increased", async () => {
              expect(secured.add(String(64e18))).to.be.eq(
                await PORTAL.readUintForId(poolId, getBytes32("secured"))
              );
            });
            it("proposedValidators increased", async () => {
              expect(proposedValidators.add(2)).to.be.eq(
                await PORTAL.readUintForId(
                  poolId,
                  await PORTAL.getKey(operatorId, getBytes32("proposedValidators"))
                )
              );
            });
            it("totalProposedValidators increased", async () => {
              expect(totalProposedValidators.add(2)).to.be.eq(
                await PORTAL.readUintForId(operatorId, getBytes32("totalProposedValidators"))
              );
            });
            it("Contract balance decreased accordingly", async () => {
              expect(contractBalance.sub(String(2e18))).to.be.eq(
                await provider.getBalance(PORTAL.address)
              );
            });
            it("VALIDATORS_INDEX updated", async () => {
              expect(validatorIndex.add(2)).to.be.eq(
                (await PORTAL.StakingParams()).VALIDATORS_INDEX
              );
            });
            it("validator parameters", async () => {
              const vd0 = await PORTAL.getValidator(pubkey0);
              expect(vd0.poolId).to.be.eq(poolId);
              expect(vd0.operatorId).to.be.eq(operatorId);
              expect(vd0.poolFee).to.be.eq(poolFee);
              expect(vd0.operatorFee).to.be.eq(operatorFee);
              expect(vd0.index).to.be.eq(1);
              expect(vd0.state).to.be.eq(1);
              expect(vd0.signature31).to.be.eq(signature031);

              const vd1 = await PORTAL.getValidator(pubkey1);
              expect(vd1.poolId).to.be.eq(poolId);
              expect(vd1.operatorId).to.be.eq(operatorId);
              expect(vd1.poolFee).to.be.eq(poolFee);
              expect(vd1.operatorFee).to.be.eq(operatorFee);
              expect(vd1.index).to.be.eq(2);
              expect(vd1.state).to.be.eq(1);
              expect(vd1.signature31).to.be.eq(signature131);
            });
          });
          it("emits ProposalStaked", async () => {
            await PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [10]);
            await PORTAL.connect(user).deposit(
              poolId,
              0,
              (await getCurrentBlockTimestamp()) + WEEK,
              0,
              [],
              user.address,
              {
                value: String(64e18),
              }
            );
            await PORTAL.increaseWalletBalance(operatorId, {
              value: String(3e18),
            });

            await expect(
              PORTAL.connect(operatorOwner).proposeStake(
                poolId,
                operatorId,
                [pubkey0, pubkey1],
                [signature01, signature11],
                [signature031, signature131]
              )
            ).to.emit(PORTAL, "ProposalStaked");
          });
        });

        describe("canStake", async () => {
          beforeEach(async () => {
            await PORTAL.connect(poolOwner).setPoolVisibility(poolId, false);
          });
          it("false if NOT PROPOSED", async () => {
            expect(await PORTAL.canStake(pubkey0)).to.be.eq(false);
          });
          it("false if NOT verified yet", async () => {
            await PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [10]);
            await PORTAL.connect(user).deposit(
              poolId,
              0,
              (await getCurrentBlockTimestamp()) + WEEK,
              0,
              [],
              user.address,
              {
                value: String(64e18),
              }
            );
            await PORTAL.increaseWalletBalance(operatorId, {
              value: String(3e18),
            });

            await PORTAL.connect(operatorOwner).proposeStake(
              poolId,
              operatorId,
              [pubkey0],
              [signature01],
              [signature031]
            );
            expect(await PORTAL.canStake(pubkey0)).to.be.eq(false);
          });
          it("false if recoveryMode is active", async () => {
            await (
              await ethers.getContractAt(
                "WithdrawalContract",
                await PORTAL.readAddressForId(poolId, getBytes32("withdrawalContract"))
              )
            )
              .connect(poolOwner)
              .pause();
            expect(await PORTAL.canStake(pubkey0)).to.be.eq(false);
          });
          it("true", async () => {
            await PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [10]);
            await PORTAL.connect(user).deposit(
              poolId,
              0,
              (await getCurrentBlockTimestamp()) + WEEK,
              0,
              [],
              user.address,
              {
                value: String(64e18),
              }
            );
            await PORTAL.increaseWalletBalance(operatorId, {
              value: String(3e18),
            });
            await PORTAL.connect(operatorOwner).proposeStake(
              poolId,
              operatorId,
              [pubkey0],
              [signature01],
              [signature031]
            );
            await PORTAL.connect(ORACLE).updateVerificationIndex(1, []);
            expect(await PORTAL.canStake(pubkey0)).to.be.eq(true);
          });
        });

        describe("proposeStaked", async () => {
          beforeEach(async () => {
            await PORTAL.connect(poolOwner).initiatePool(
              poolFee,
              interfaceId,
              poolOwner.address,
              extraName1,
              interfaceData,
              [0, 0, 0],
              { value: String(32e18) }
            );
            await PORTAL.connect(poolOwner).approveOperators(extraId1, [operatorId], [10]);
            await PORTAL.connect(user).deposit(
              extraId1,
              0,
              (await getCurrentBlockTimestamp()) + WEEK,
              0,
              [],
              user.address,
              {
                value: String(2e20),
              }
            );

            await PORTAL.connect(poolOwner).setPoolVisibility(poolId, false);
            await PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [10]);
            await PORTAL.connect(user).deposit(
              poolId,
              0,
              (await getCurrentBlockTimestamp()) + WEEK,
              0,
              [],
              user.address,
              {
                value: String(2e20),
              }
            );
            await PORTAL.increaseWalletBalance(operatorId, {
              value: String(3e18),
            });

            await PORTAL.connect(operatorOwner).proposeStake(
              poolId,
              operatorId,
              [pubkey0, pubkey1],
              [signature01, signature11],
              [signature031, signature131]
            );
            await PORTAL.connect(operatorOwner).proposeStake(
              extraId1,
              operatorId,
              [pubkey2],
              [signature11],
              [signature131]
            );
          });

          describe("beaconStake", async () => {
            it("reverts if not an operator", async () => {
              await expect(
                PORTAL.connect(operatorOwner).beaconStake(wrongId, [pubkey0, pubkey1])
              ).to.be.revertedWith("SU: ID is not initiated'");
            });
            it("reverts if not maintainer", async () => {
              await expect(
                PORTAL.connect(attacker).beaconStake(operatorId, [pubkey0, pubkey1])
              ).to.be.revertedWith("SU: sender NOT maintainer");
            });
            it("reverts if not verified", async () => {
              await expect(
                PORTAL.connect(operatorOwner).beaconStake(operatorId, [pubkey0, pubkey1])
              ).to.be.revertedWith("SU: NOT all pubkeys are stakeable");
            });
            it("reverts if >= 50 nodes", async () => {
              await expect(
                PORTAL.connect(operatorOwner).beaconStake(operatorId, [])
              ).to.be.revertedWith("SU: 0 - 50 validators'");
              await expect(
                PORTAL.connect(operatorOwner).beaconStake(operatorId, new Array(51).fill(pubkey0))
              ).to.be.revertedWith("SU: 0 - 50 validators'");
            });

            describe("success", async () => {
              let secured;
              let proposedValidators;
              let activeValidators;
              let totalProposedValidators;
              let totalActiveValidators;
              let wallet;

              beforeEach(async () => {
                await PORTAL.connect(ORACLE).updateVerificationIndex(3, []);

                secured = await PORTAL.readUintForId(poolId, getBytes32("secured"));
                proposedValidators = await PORTAL.readUintForId(
                  poolId,
                  await PORTAL.getKey(operatorId, getBytes32("proposedValidators"))
                );
                activeValidators = await PORTAL.readUintForId(
                  poolId,
                  await PORTAL.getKey(operatorId, getBytes32("activeValidators"))
                );
                totalActiveValidators = await PORTAL.readUintForId(
                  operatorId,
                  getBytes32("totalActiveValidators")
                );
                totalProposedValidators = await PORTAL.readUintForId(
                  operatorId,
                  getBytes32("totalProposedValidators")
                );
                wallet = await PORTAL.readUintForId(operatorId, getBytes32("wallet"));

                await PORTAL.connect(operatorOwner).beaconStake(operatorId, [
                  pubkey0,
                  pubkey1,
                  pubkey2,
                ]);
              });
              it("adds to validators array", async () => {
                expect(await PORTAL.getValidatorByPool(poolId, 0)).to.be.eq(pubkey0);
                expect(await PORTAL.getValidatorByPool(poolId, 1)).to.be.eq(pubkey1);
                expect(await PORTAL.getValidatorByPool(extraId1, 0)).to.be.eq(pubkey2);
              });
              it("sets state to active", async () => {
                const v0 = await PORTAL.getValidator(pubkey0);
                const v1 = await PORTAL.getValidator(pubkey1);
                const v2 = await PORTAL.getValidator(pubkey2);
                expect(v0.state).to.be.eq(2);
                expect(v1.state).to.be.eq(2);
                expect(v2.state).to.be.eq(2);
              });
              it("secured decreased", async () => {
                expect(secured.sub(String(64e18))).to.be.eq(
                  await PORTAL.readUintForId(poolId, getBytes32("secured"))
                );
              });
              it("proposedValidators decreased", async () => {
                expect(proposedValidators.sub(2)).to.be.eq(
                  await PORTAL.readUintForId(
                    poolId,
                    await PORTAL.getKey(operatorId, getBytes32("proposedValidators"))
                  )
                );
              });
              it("activeValidators increased", async () => {
                expect(activeValidators.add(2)).to.be.eq(
                  await PORTAL.readUintForId(
                    poolId,
                    await PORTAL.getKey(operatorId, getBytes32("activeValidators"))
                  )
                );
              });
              it("totalActiveValidators increased", async () => {
                expect(totalActiveValidators.add(3)).to.be.eq(
                  await PORTAL.readUintForId(operatorId, getBytes32("totalActiveValidators"))
                );
              });
              it("totalProposedValidators decreased", async () => {
                expect(totalProposedValidators.sub(3)).to.be.eq(
                  await PORTAL.readUintForId(operatorId, getBytes32("totalProposedValidators"))
                );
              });
              it("refunded maintainer", async () => {
                expect(wallet.add(String(3e18))).to.be.eq(
                  await PORTAL.readUintForId(operatorId, getBytes32("wallet"))
                );
              });

              describe("blameOperator", async () => {
                it("reverts if validator is never activated", async () => {
                  await expect(PORTAL.blameOperator(getBytes("sample"))).to.be.revertedWith(
                    "SU: validator is never activated"
                  );
                });
                it("reverts if validator is still active", async () => {
                  await expect(PORTAL.blameOperator(pubkey2)).to.be.revertedWith(
                    "SU: validator is active"
                  );
                });
                describe("success", async () => {
                  beforeEach(async () => {
                    await setTimestamp((await getCurrentBlockTimestamp()) + 300 * WEEK);
                    await PORTAL.blameOperator(pubkey2);
                  });
                  describe("_imprison", async () => {
                    it("isPrisoned returns true", async () => {
                      expect(await PORTAL.isPrisoned(operatorId)).to.be.eq(true);
                    });
                    it("can not use when prisoned", async () => {
                      await expect(
                        PORTAL.decreaseWalletBalance(operatorId, String(0))
                      ).to.be.revertedWith(
                        "SU: operator is in prison, get in touch with governance"
                      );
                    });
                    describe("releasePrisoned", async () => {
                      beforeEach(async () => {
                        await PORTAL.connect(GOVERNANCE).releasePrisoned(operatorId);
                      });
                      it("isPrisoned returns false", async () => {
                        expect(await PORTAL.isPrisoned(operatorId)).to.be.eq(false);
                      });
                      it("emits Released", async () => {
                        await PORTAL.blameOperator(pubkey1);
                        await expect(
                          PORTAL.connect(GOVERNANCE).releasePrisoned(operatorId)
                        ).to.emit(PORTAL, "Released");
                      });
                    });
                  });
                });
              });
            });
          });
        });
      });
    });
  });

  describe("Oracleutils", async () => {
    beforeEach(async () => {
      await PORTAL.connect(GOVERNANCE).newProposal(operatorOwner.address, 4, operatorName, WEEK);
      await PORTAL.connect(SENATE).approveProposal(operatorId);
      await PORTAL.connect(operatorOwner).initiateOperator(
        operatorId,
        operatorFee,
        MIN_VALIDATOR_PERIOD,
        operatorOwner.address
      );
      await PORTAL.connect(poolOwner).initiatePool(
        poolFee,
        interfaceId,
        poolOwner.address,
        poolName,
        interfaceData,
        [0, 0, 0],
        { value: String(32e18) }
      );
      await PORTAL.connect(poolOwner).approveOperators(poolId, [operatorId], [10]);
      await PORTAL.connect(user).deposit(
        poolId,
        0,
        (await getCurrentBlockTimestamp()) + WEEK,
        0,
        [],
        user.address,
        {
          value: String(69e19),
        }
      );
      await PORTAL.connect(operatorOwner).increaseWalletBalance(operatorId, {
        value: String(2e18),
      });
      await PORTAL.connect(operatorOwner).proposeStake(
        poolId,
        operatorId,
        [pubkey0, pubkey1],
        [signature01, signature11],
        [signature031, signature131]
      );
    });

    describe("updateVerificationIndex", async () => {
      it("reverts when NOT ORACLE", async () => {
        await expect(PORTAL.updateVerificationIndex(0, [])).to.be.revertedWith(
          "OU: sender NOT ORACLE"
        );
      });
      it("reverts when validators < verification", async () => {
        await expect(PORTAL.connect(ORACLE).updateVerificationIndex(3, [])).to.be.revertedWith(
          "OU: high VERIFICATION_INDEX"
        );
      });
      it("reverts when new <= old ", async () => {
        await PORTAL.connect(ORACLE).updateVerificationIndex(1, []);
        await expect(PORTAL.connect(ORACLE).updateVerificationIndex(0, [])).to.be.revertedWith(
          "OU: low VERIFICATION_INDEX"
        );
      });

      describe("success", async () => {
        it("changes VERIFICATION_INDEX", async () => {
          await PORTAL.connect(ORACLE).updateVerificationIndex(1, []);
          expect((await PORTAL.StakingParams()).VERIFICATION_INDEX).to.be.eq(1);
        });
        it("emits VerificationIndexUpdated", async () => {
          expect(await PORTAL.connect(ORACLE).updateVerificationIndex(1, [])).to.emit(
            PORTAL,
            "VerificationIndexUpdated"
          );
        });
      });

      describe("alienate", async () => {
        it("reverts if state is NOT PROPOSED", async () => {
          await expect(
            PORTAL.connect(ORACLE).updateVerificationIndex(2, [pubkey2])
          ).to.be.revertedWith("OU: NOT all pubkeys are pending");
        });
        it("reverts if > VERIFICATION_INDEX", async () => {
          await expect(
            PORTAL.connect(ORACLE).updateVerificationIndex(1, [pubkey1])
          ).to.be.revertedWith("OU: unexpected index");
        });

        describe("success", async () => {
          let surplus;
          let secured;
          beforeEach(async () => {
            secured = await PORTAL.readUintForId(poolId, getBytes32("secured"));
            surplus = await PORTAL.readUintForId(poolId, getBytes32("surplus"));
            await PORTAL.connect(ORACLE).updateVerificationIndex(2, [pubkey1]);
          });
          it("fixes secured", async () => {
            expect(await PORTAL.readUintForId(poolId, getBytes32("secured"))).to.be.eq(
              secured.sub(String(32e18))
            );
          });
          it("fixes surplus", async () => {
            expect(await PORTAL.readUintForId(poolId, getBytes32("surplus"))).to.be.eq(
              surplus.add(String(32e18))
            );
          });
          it("changes state to ALIENATED", async () => {
            expect((await PORTAL.getValidator(pubkey1)).state).to.be.eq(69);
          });
          it("imprisons the operator", async () => {
            expect(await PORTAL.isPrisoned(operatorId)).to.be.eq(true);
          });
        });
        // TODO when changes are done on alienate bug also test the allowance
        it("emits Alienated", async () => {
          await expect(PORTAL.connect(ORACLE).updateVerificationIndex(2, [pubkey1])).to.emit(
            PORTAL,
            "Alienated"
          );
        });
      });
    });

    describe("regulateOperators", async () => {
      it("reverts if unmatched lengths", async () => {
        await expect(PORTAL.connect(ORACLE).regulateOperators([operatorId], [])).to.be.revertedWith(
          "OU: invalid proofs"
        );
      });
      it("_imprison reverts if not Operator", async () => {
        await expect(
          PORTAL.connect(ORACLE).regulateOperators([poolId], [getBytes("proof")])
        ).to.be.revertedWith("SU: TYPE NOT allowed");
      });

      describe("success", async () => {
        it("imprisons the operator", async () => {
          await PORTAL.connect(ORACLE).regulateOperators([operatorId], [getBytes("proof")]);
          expect(await PORTAL.isPrisoned(operatorId)).to.be.eq(true);
        });
        it("emits FeeTheft", async () => {
          await expect(
            PORTAL.connect(ORACLE).regulateOperators([operatorId], [getBytes("proof")])
          ).to.emit(PORTAL, "FeeTheft");
        });
      });
    });

    describe("reportOracle", async () => {
      it("reverts if sender not Oracle", async () => {
        await expect(
          PORTAL.connect(attacker).reportOracle(getBytes32("root"), 49999)
        ).to.be.revertedWith("OU: sender NOT ORACLE");
      });

      it("reverts if low allValidatorsCount", async () => {
        await expect(
          PORTAL.connect(ORACLE).reportOracle(getBytes32("root"), 49999)
        ).to.be.revertedWith("OU: low validator count");
      });

      describe("success", async () => {
        let ts;
        beforeEach(async () => {
          await PORTAL.connect(ORACLE).reportOracle(getBytes32("root"), 50001);
          ts = await getCurrentBlockTimestamp();
        });
        it("UPDATES PRICE_MERKLE_ROOT", async () => {
          expect((await PORTAL.StakingParams()).PRICE_MERKLE_ROOT).to.be.eq(getBytes32("root"));
        });
        it("UPDATES ORACLE_UPDATE_TIMESTAMP", async () => {
          expect((await PORTAL.StakingParams()).ORACLE_UPDATE_TIMESTAMP).to.be.eq(ts);
        });
        it("UPDATES MONOPOLY_THRESHOLD", async () => {
          expect((await PORTAL.StakingParams()).MONOPOLY_THRESHOLD).to.be.eq(500);
        });
        it("emits OracleReported", async () => {
          await expect(PORTAL.connect(ORACLE).reportOracle(getBytes32("root"), 50001)).to.emit(
            PORTAL,
            "OracleReported"
          );
        });
      });
    });

    describe("priceSync & priceSyncBatch", async () => {
      let tree;
      const prices = [
        String(106e16),
        String(108e16),
        String(171e16),
        String(92e16),
        String(29e16),
        String(107e16),
        String(1),
      ];
      beforeEach(async () => {
        await PORTAL.connect(poolOwner).initiatePool(
          poolFee,
          interfaceId,
          poolOwner.address,
          wrongName,
          "0x",
          [0, 0, 0],
          { value: String(32e18) }
        );
        await PORTAL.connect(poolOwner).initiatePool(
          poolFee,
          interfaceId,
          poolOwner.address,
          randomName,
          "0x",
          [0, 0, 0],
          { value: String(32e18) }
        );

        await PORTAL.connect(poolOwner).initiatePool(
          poolFee,
          interfaceId,
          poolOwner.address,
          extraName1,
          "0x",
          [0, 0, 0],
          { value: String(32e18) }
        );

        await PORTAL.connect(poolOwner).initiatePool(
          poolFee,
          interfaceId,
          poolOwner.address,
          extraName2,
          "0x",
          [0, 0, 0],
          { value: String(32e18) }
        );

        await PORTAL.connect(poolOwner).initiatePool(
          poolFee,
          interfaceId,
          poolOwner.address,
          extraName3,
          "0x",
          [0, 0, 0],
          { value: String(32e18) }
        );

        await PORTAL.connect(user).deposit(
          randomId,
          0,
          (await getCurrentBlockTimestamp()) + WEEK,
          0,
          [],
          user.address,
          {
            value: String(69e19),
          }
        );

        await PORTAL.connect(user).deposit(
          wrongId,
          0,
          (await getCurrentBlockTimestamp()) + WEEK,
          0,
          [],
          user.address,
          {
            value: String(69e19),
          }
        );

        await PORTAL.connect(user).deposit(
          extraId1,
          0,
          (await getCurrentBlockTimestamp()) + WEEK,
          0,
          [],
          user.address,
          {
            value: String(69e19),
          }
        );

        await PORTAL.connect(user).deposit(
          extraId2,
          0,
          (await getCurrentBlockTimestamp()) + WEEK,
          0,
          [],
          user.address,
          {
            value: String(69e19),
          }
        );

        await PORTAL.connect(user).deposit(
          extraId3,
          0,
          (await getCurrentBlockTimestamp()) + WEEK,
          0,
          [],
          user.address,
          {
            value: String(69e19),
          }
        );

        const values = [
          [poolId.toString(), prices[0]],
          [wrongId.toString(), prices[1]],
          [randomId.toString(), prices[2]],
          [extraId1.toString(), prices[3]],
          [extraId2.toString(), prices[4]],
          [extraId3.toString(), prices[5]],
          [operatorId.toString(), prices[6]],
        ];
        tree = StandardMerkleTree.of(values, ["uint256", "uint256"]);
      });

      it("reverts with faulty proofs", async () => {
        await PORTAL.connect(ORACLE).reportOracle(tree.root, 50001);
        await expect(
          PORTAL.priceSync(poolId.toString(), prices[0], tree.getProof(1))
        ).to.be.revertedWith("OU: NOT all proofs are valid");
      });

      it("reverts if not POOL", async () => {
        await PORTAL.connect(ORACLE).reportOracle(tree.root, 50001);
        await expect(
          PORTAL.priceSync(operatorId.toString(), prices[6], tree.getProof(6))
        ).to.be.revertedWith("OU: not a pool?");
      });

      describe("_sanityCheck", async () => {
        it("reverts if price higher than allowed for 1 days", async () => {
          await PORTAL.connect(ORACLE).reportOracle(tree.root, 50001);
          await setTimestamp((await getCurrentBlockTimestamp()) + 1 * DAY);
          await expect(
            PORTAL.priceSync(wrongId.toString(), prices[1], tree.getProof(1))
          ).to.be.revertedWith("OU: price is insane");
        });
        it("reverts if price higher than allowed for 10 days", async () => {
          await PORTAL.connect(ORACLE).reportOracle(tree.root, 50001);
          await setTimestamp((await getCurrentBlockTimestamp()) + 10 * DAY);
          await expect(
            PORTAL.priceSync(randomId.toString(), prices[2], tree.getProof(2))
          ).to.be.revertedWith("OU: price is insane");
        });
        it("reverts if price lower than allowed for 1 days", async () => {
          await PORTAL.connect(ORACLE).reportOracle(tree.root, 50001);
          await setTimestamp((await getCurrentBlockTimestamp()) + 1 * DAY);
          await expect(
            PORTAL.priceSync(extraId1.toString(), prices[3], tree.getProof(3))
          ).to.be.revertedWith("OU: price is insane");
        });
        it("reverts if price lower than allowed for 10 days", async () => {
          await PORTAL.connect(ORACLE).reportOracle(tree.root, 50001);
          await setTimestamp((await getCurrentBlockTimestamp()) + 10 * DAY);
          await expect(
            PORTAL.priceSync(extraId2.toString(), prices[4], tree.getProof(4))
          ).to.be.revertedWith("OU: price is insane");
        });

        it("priceSync: success, the correct gETH price", async () => {
          await PORTAL.connect(ORACLE).reportOracle(tree.root, 50001);
          await setTimestamp((await getCurrentBlockTimestamp()) + 1 * DAY);
          await PORTAL.priceSync(poolId.toString(), prices[0], tree.getProof(0));
          expect(await gETH.pricePerShare(poolId)).to.be.eq(prices[0]);
        });
        it("priceSyncBatch: reverts wrong length arrays", async () => {
          await expect(
            PORTAL.priceSyncBatch(
              [poolId.toString(), extraId3.toString()],
              [prices[0]],
              [tree.getProof(0), tree.getProof(5)]
            )
          ).to.be.reverted;
          await expect(
            PORTAL.priceSyncBatch(
              [poolId.toString(), extraId3.toString()],
              [prices[0], prices[5]],
              [tree.getProof(0)]
            )
          ).to.be.reverted;
        });
        it("priceSyncBatch: success the correct gETH price", async () => {
          await PORTAL.connect(ORACLE).reportOracle(tree.root, 50001);
          await setTimestamp((await getCurrentBlockTimestamp()) + 1 * DAY);
          await PORTAL.priceSyncBatch(
            [poolId.toString(), extraId3.toString()],
            [prices[0], prices[5]],
            [tree.getProof(0), tree.getProof(5)]
          );
          expect(await gETH.pricePerShare(poolId)).to.be.eq(prices[0]);
          expect(await gETH.pricePerShare(extraId3)).to.be.eq(prices[5]);
        });
      });
    });
  });

  describe("Portal Specific", async () => {
    describe("Do_we_care", async () => {
      it("We do care!", async () => {
        expect(await PORTAL.Do_we_care()).to.be.eq(true);
      });
    });
  });
});
