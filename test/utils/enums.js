function Enum(...options) {
  return Object.fromEntries(options.map((key, i) => [key, web3.utils.toBN(i)]));
}

function EnumBigInt(...options) {
  return Object.fromEntries(options.map((key, i) => [key, BigInt(i)]));
}

function createExport(Enum) {
  return {
    Enum,
    ProposalState: Enum(
      "Pending",
      "Active",
      "Canceled",
      "Defeated",
      "Succeeded",
      "Queued",
      "Expired",
      "Executed"
    ),
    VoteType: Enum("Against", "For", "Abstain"),
    Rounding: Enum("Floor", "Ceil", "Trunc", "Expand"),
    OperationState: Enum("Unset", "Waiting", "Ready", "Done"),
  };
}

module.exports = createExport(Enum);
module.exports.bigint = createExport(EnumBigInt);
