const web3 = require("web3");
const BN = require("bignumber.js");
/// TODO: fix
const func = async (taskArgs, hre) => {
  const { deployments } = hre;
  const { read } = deployments;
  try {
    const gETH = await read("Portal", "gETH");
    const GeodeParams = await read("Portal", "GeodeParams");
    const TelescopeParams = await read("Portal", "TelescopeParams");
    const StakingParams = await read("Portal", "StakingParams");

    console.log({
      gETH,
      GEODE: {
        SENATE: GeodeParams.SENATE,
        GOVERNANCE: GeodeParams.GOVERNANCE,
        GOVERNANCE_FEE: `${GeodeParams.GOVERNANCE_FEE.div(
          10 ** 8
        ).toString()}%`,
        MAX_GOVERNANCE_FEE: `${GeodeParams.MAX_GOVERNANCE_FEE.div(
          10 ** 8
        ).toString()}%`,
        SENATE_EXPIRY: new Date(GeodeParams.SENATE_EXPIRY),
      },
      TELESCOPE: {
        ORACLE_POSITION: TelescopeParams.ORACLE_POSITION,
        MONOPOLY_THRESHOLD: TelescopeParams.MONOPOLY_THRESHOLD.toString(),
        PERIOD_PRICE_INCREASE_LIMIT: `${TelescopeParams.PERIOD_PRICE_INCREASE_LIMIT.div(
          10 ** 8
        ).toString()}%`,
        PERIOD_PRICE_DECREASE_LIMIT: `${TelescopeParams.PERIOD_PRICE_DECREASE_LIMIT.div(
          10 ** 8
        ).toString()}%`,
      },
      STAKING: {
        DEFAULT_gETH_INTERFACE: StakingParams.DEFAULT_gETH_INTERFACE,
        DEFAULT_DWP: StakingParams.DEFAULT_DWP,
        DEFAULT_LP_TOKEN: StakingParams.DEFAULT_LP_TOKEN,
        MINI_GOVERNANCE_VERSION:
          StakingParams.MINI_GOVERNANCE_VERSION.toString(),
        MAX_MAINTAINER_FEE: `${StakingParams.MAX_MAINTAINER_FEE.div(
          10 ** 8
        ).toString()}%`,
        BOOSTRAP_PERIOD: `${StakingParams.BOOSTRAP_PERIOD.div(
          24 * 3600
        ).toString()} days`,
      },
    });

    const allOperatorIds = await read("Portal", "allIdsByType", 4);
    pd = await Promise.all(
      allOperatorIds.map(async (k) => {
        const p = await read("Portal", "getOperator", k);
        return {
          name: `${web3.utils.toAscii(p.name)}`,
          CONTROLLER: `${p.CONTROLLER}`,
          maintainer: `${p.maintainer}`,
          initiated: `${p.initiated.toString()}`,
          fee: `${`${p.fee.div(10 ** 8).toString()}%`}`,
          totalActiveValidators: `${p.totalActiveValidators.toString()}`,
          validatorPeriod: `${`${p.validatorPeriod
            .div(24 * 3600)
            .toString()} days`}`,
        };
      })
    );
    console.table(pd);
    console.log(allOperatorIds.map((k) => k.toString()));

    const allPlanetIds = await read("Portal", "allIdsByType", 5);
    pd = await Promise.all(
      allPlanetIds.map(async (k) => {
        const p = await read("Portal", "getPlanet", k);
        return {
          name: `${web3.utils.toAscii(p.name)}`,
          CONTROLLER: `${p.CONTROLLER}`,
          maintainer: `${p.maintainer}`,
          initiated: `${p.initiated}`,
          fee: `${p.fee}`,
          feeSwitch: `${p.feeSwitch}`,
          withdrawalBoost: `${p.withdrawalBoost}`,
          withdrawalPool: `${p.withdrawalPool}`,
          LPToken: `${p.LPToken}`,
          WithdrawalContract: `${p.WithdrawalContract}`,
        };
      })
    );
    console.table(pd);
    console.log(allPlanetIds.map((k) => k.toString()));
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful catching...");
    console.log("try --network");
  }
};

module.exports = func;
