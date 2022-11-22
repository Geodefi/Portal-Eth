const { solidity } = require("ethereum-waffle");
const { deployments, upgrades, ethers } = require("hardhat");
const chai = require("chai");

chai.use(solidity);
const { expect } = chai;


describe("Portal", async () => {
    let testPortal;
    let gETH;
    let Swap;
    let ERC20InterfacePermitUpgradable;
    let LPToken;
    let MiniGovernance;

    // PARAMS
    const _GOVERNANCE_TAX = (1 * 10 ** 10) / 100; // 1%
    const _COMET_TAX = (3 * 10 ** 10) / 100; // 3%
    const _MAX_MAINTAINER_FEE = (10 * 10 ** 10) / 100; // 10%
    const _BOOSTRAP_PERIOD = 6 * 30 * 24 * 3600; // 6 Months

    const setupTest = deployments.createFixture(async ({ethers}) => {
        await deployments.fixture(); // ensure you start from a fresh deployments

        const { get } = deployments;
        const signers = await ethers.getSigners();
        GOVERNANCE = signers[0];
        anyUser = signers[1];
        // planetAddress = signers[2];
        // operatorAddress = signers[3];
    
        
        // https://docs.openzeppelin.com/upgrades-plugins/1.x/hardhat-upgrades
        ORACLE = GOVERNANCE.address; //just for test purposes
        gETH = (await get("gETH")).address;
        Swap = (await get("Swap")).address;
        ERC20InterfacePermitUpgradable = (
          await get("ERC20InterfacePermitUpgradable")
        ).address;
        LPToken = (await get("LPToken")).address;
        MiniGovernance = (await get("MiniGovernance")).address;
      
        const Portal = await ethers.getContractFactory("Portal", {
            libraries: {
              MaintainerUtils: (await get("MaintainerUtils")).address,
              GeodeUtils: (await get("GeodeUtils")).address,
              StakeUtils: (await get("StakeUtils")).address,
              OracleUtils: (await get("OracleUtils")).address,
            },
        });

        testPortal = await upgrades.deployProxy(
            Portal,
            [
                GOVERNANCE.address,
                gETH,
                ORACLE,
                ERC20InterfacePermitUpgradable,
                Swap,
                LPToken,
                MiniGovernance,
                _GOVERNANCE_TAX,
                _COMET_TAX,
                _MAX_MAINTAINER_FEE,
                _BOOSTRAP_PERIOD,
            ],
            {
                kind: "uups",
                unsafeAllow: ["external-library-linking"],
            }
        );

        await testPortal.deployed();
    });
    
    beforeEach(async () => {
        await setupTest();
    });

    describe("check params after deployment", async () => {
        it("getVersion checked with getIdFromName", async () => {
            versionId = await testPortal.getIdFromName("V1", 2);
            expect(await testPortal.getVersion()).to.be.eq(versionId);
        });

        it("gETH", async () => {
            expect(await testPortal.gETH()).to.be.eq(gETH);
        });

        it("allIdsByType", async () => {
            portalUprades = await testPortal.allIdsByType(2);
            expect(portalUprades.length).to.be.eq(1);
            expect(portalUprades[0]).to.be.eq(await testPortal.getIdFromName("V1", 2));

            miniGovUprades = await testPortal.allIdsByType(11);
            expect(miniGovUprades.length).to.be.eq(1);
            expect(miniGovUprades[0]).to.be.eq(await testPortal.getIdFromName("mini-v1", 11));
        });

        it("GeodeParams", async () => {
            geodeParams = await testPortal.GeodeParams();

            expect(geodeParams.SENATE).to.be.eq(GOVERNANCE.address);
            expect(geodeParams.GOVERNANCE).to.be.eq(GOVERNANCE.address);
            expect(geodeParams.GOVERNANCE_TAX).to.be.eq(_GOVERNANCE_TAX);
            expect(geodeParams.MAX_GOVERNANCE_TAX).to.be.eq(_GOVERNANCE_TAX);
            expect(geodeParams.SENATE_EXPIRY).to.be.eq(ethers.constants.MaxUint256);
        });

        it("TelescopeParams", async () => {
            telescopeParams = await testPortal.TelescopeParams();

            expect(telescopeParams.ORACLE_POSITION).to.be.eq(ORACLE);
            expect(telescopeParams.ORACLE_UPDATE_TIMESTAMP).to.be.eq(0);
            expect(telescopeParams.MONOPOLY_THRESHOLD).to.be.eq(20000);
            expect(telescopeParams.VALIDATORS_INDEX).to.be.eq(0);
            expect(telescopeParams.VERIFICATION_INDEX).to.be.eq(0);
            expect(telescopeParams.PERIOD_PRICE_INCREASE_LIMIT).to.be.eq(ethers.constants.MaxUint256);
            expect(telescopeParams.PERIOD_PRICE_DECREASE_LIMIT).to.be.eq(ethers.constants.MaxUint256);
            expect(telescopeParams.PRICE_MERKLE_ROOT).to.be.eq(ethers.utils.formatBytes32String(""));
        });

        it("StakingParams", async () => {
            stakingParams = await testPortal.StakingParams();

            expect(stakingParams.DEFAULT_gETH_INTERFACE).to.be.eq(ERC20InterfacePermitUpgradable);
            expect(stakingParams.DEFAULT_DWP).to.be.eq(Swap);
            expect(stakingParams.DEFAULT_LP_TOKEN).to.be.eq(LPToken);
            expect(stakingParams.MINI_GOVERNANCE_VERSION).to.be.eq(await testPortal.getIdFromName("mini-v1", 11));
            expect(stakingParams.MAX_MAINTAINER_FEE).to.be.eq(_MAX_MAINTAINER_FEE);
            expect(stakingParams.BOOSTRAP_PERIOD).to.be.eq(_BOOSTRAP_PERIOD);
            expect(stakingParams.COMET_TAX).to.be.eq(_COMET_TAX);

        });

        it("miniGovernanceVersion", async () => {
            miniGovernanceVersionId = await testPortal.getIdFromName("mini-v1", 11);
            expect(await testPortal.miniGovernanceVersion()).to.be.eq(miniGovernanceVersionId);
        });
    });

    describe("pause", async () => {
        it("reverts if not GOVERNANCE", async () => {
            await expect(testPortal.connect(anyUser).pause()).to.be.revertedWith("Portal: sender not GOVERNANCE");
        });
    });

    describe("unpause", async () => {
        it("reverts if not GOVERNANCE", async () => {
            await expect(testPortal.connect(anyUser).unpause()).to.be.revertedWith("Portal: sender not GOVERNANCE");
        });
    });

    describe("newProposal", async () => {
        it("reverts if not GOVERNANCE", async () => {
            await expect(testPortal.connect(anyUser).newProposal(
                anyUser.address,
                4,
                ethers.utils.formatBytes32String("beautiful-name"),
                24 * 60 * 60 * 2
            )).to.be.revertedWith("Portal: sender not GOVERNANCE");
        });
    });

    describe("updateStakingParams", async () => {
        it("reverts if not GOVERNANCE", async () => {
            await expect(testPortal.connect(anyUser).updateStakingParams(
                testPortal.address,
                testPortal.address,
                testPortal.address,
                5,
                4, // TODO: DISCUSS check, is that okay for this to be zero?
                3,
                2,
                1,
                0 // TODO: DISCUSS check, is that okay for this to be zero?
            )).to.be.revertedWith("Portal: sender not GOVERNANCE");
        });

        it("reverts if _DEFAULT_gETH_INTERFACE.code.length not bigger than 0", async () => {
            await expect(testPortal.updateStakingParams(
                anyUser.address,
                testPortal.address,
                testPortal.address,
                5,
                4, // TODO: DISCUSS check, is that okay for this to be zero?
                3,
                2,
                1,
                0 // TODO: DISCUSS check, is that okay for this to be zero?
            )).to.be.revertedWith("Portal: DEFAULT_gETH_INTERFACE NOT contract");
        });

        it("reverts if _DEFAULT_DWP.code.length not bigger than 0", async () => {
            await expect(testPortal.updateStakingParams(
                testPortal.address,
                anyUser.address,
                testPortal.address,
                5,
                4, // TODO: DISCUSS check, is that okay for this to be zero?
                3,
                2,
                1,
                0 // TODO: DISCUSS check, is that okay for this to be zero?
            )).to.be.revertedWith("Portal: DEFAULT_DWP NOT contract");
        });

        it("reverts if _DEFAULT_LP_TOKEN.code.length not bigger than 0", async () => {
            await expect(testPortal.updateStakingParams(
                testPortal.address,
                testPortal.address,
                anyUser.address,
                5,
                4, // TODO: DISCUSS check, is that okay for this to be zero?
                3,
                2,
                1,
                0 // TODO: DISCUSS check, is that okay for this to be zero?
            )).to.be.revertedWith("Portal: DEFAULT_LP_TOKEN NOT contract");
        });

        it("reverts if _MAX_MAINTAINER_FEE not bigger than 0", async () => {
            await expect(testPortal.updateStakingParams(
                testPortal.address,
                testPortal.address,
                testPortal.address,
                0,
                4, // TODO: DISCUSS check, is that okay for this to be zero?
                3,
                2,
                1,
                0 // TODO: DISCUSS check, is that okay for this to be zero?
            )).to.be.revertedWith("Portal: incorrect MAX_MAINTAINER_FEE");
        });

        it("reverts if _MAX_MAINTAINER_FEE is bigger than StakeUtils.PERCENTAGE_DENOMINATOR", async () => {
            await expect(testPortal.updateStakingParams(
                testPortal.address,
                testPortal.address,
                testPortal.address,
                10**10 + 1,
                4, // TODO: DISCUSS check, is that okay for this to be zero?
                3,
                2,
                1,
                0 // TODO: DISCUSS check, is that okay for this to be zero?
            )).to.be.revertedWith("Portal: incorrect MAX_MAINTAINER_FEE");
        });

        it("reverts if _PERIOD_PRICE_INCREASE_LIMIT is not bigger than 0", async () => {
            await expect(testPortal.updateStakingParams(
                testPortal.address,
                testPortal.address,
                testPortal.address,
                5,
                4, // TODO: DISCUSS check, is that okay for this to be zero?
                0,
                2,
                1,
                0 // TODO: DISCUSS check, is that okay for this to be zero?
            )).to.be.revertedWith("Portal: incorrect PERIOD_PRICE_INCREASE_LIMIT");
        });

        it("reverts if _PERIOD_PRICE_DECREASE_LIMIT is not bigger than 0", async () => {
            await expect(testPortal.updateStakingParams(
                testPortal.address,
                testPortal.address,
                testPortal.address,
                5,
                4, // TODO: DISCUSS check, is that okay for this to be zero?
                3,
                0,
                1,
                0 // TODO: DISCUSS check, is that okay for this to be zero?
            )).to.be.revertedWith("Portal: incorrect PERIOD_PRICE_DECREASE_LIMIT");
        });

        it("reverts if _COMET_TAX is bigger than _MAX_MAINTAINER_FEE", async () => {
            await expect(testPortal.updateStakingParams(
                testPortal.address,
                testPortal.address,
                testPortal.address,
                5,
                4, // TODO: DISCUSS check, is that okay for this to be zero?
                3,
                2,
                6,
                0 // TODO: DISCUSS check, is that okay for this to be zero?
            )).to.be.revertedWith("Portal: COMET_TAX should be less than MAX_MAINTAINER_FEE");
        });

        it("success, check changed params", async () => {
            await testPortal.updateStakingParams(
                testPortal.address,
                testPortal.address,
                testPortal.address,
                5,
                4, // TODO: DISCUSS check, is that okay for this to be zero?
                2,
                3,
                1,
                0 // TODO: DISCUSS check, is that okay for this to be zero?
            );

            stakingParams = await testPortal.StakingParams();
            telescopeParams = await testPortal.TelescopeParams();


            expect(stakingParams.DEFAULT_gETH_INTERFACE).to.be.eq(testPortal.address);
            expect(stakingParams.DEFAULT_DWP).to.be.eq(testPortal.address);
            expect(stakingParams.DEFAULT_LP_TOKEN).to.be.eq(testPortal.address);
            expect(stakingParams.MAX_MAINTAINER_FEE).to.be.eq(5);
            expect(stakingParams.BOOSTRAP_PERIOD).to.be.eq(4);
            expect(telescopeParams.PERIOD_PRICE_INCREASE_LIMIT).to.be.eq(2);
            expect(telescopeParams.PERIOD_PRICE_DECREASE_LIMIT).to.be.eq(3);
            expect(stakingParams.COMET_TAX).to.be.eq(1);
            // TODO: DISCUSS check, staking pool should return _BOOST_SWITCH_LATENCY ???


        });
    });

    describe("releasePrisoned", async () => {
        it("reverts if not GOVERNANCE", async () => {
            await expect(testPortal.connect(anyUser).releasePrisoned(1)).to.be.revertedWith("Portal: sender not GOVERNANCE");
        });
    });

    describe("Do_we_care", async () => {
        it("We do care!", async () => {
            expect(await testPortal.Do_we_care()).to.be.eq(true);
        });
    });
});