module.exports = {
  skipFiles: [
    "globals",
    "interfaces",
    "helpers/test",
    "helpers/BytesLib.sol",
    "contracts/modules/LiquidityModule",
  ],
  configureYulOptimizer: true,
};
