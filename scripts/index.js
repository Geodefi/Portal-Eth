const { task } = require("hardhat/config");

const propose = require("./tasks/propose");
const approveProposal = require("./tasks/approveProposal");

const initiateOperator = require("./tasks/initiateOperator");
const initiatePool = require("./tasks/initiatePool");

// proposals
task("propose", "Creates a proposal with desired parameters")
  .addParam("t", "defines type such as pool , operator , senate , Upgrade")
  .addParam("c", "refers to the proposed address as the controller of resulting ID")
  .addParam("n", "id with keccak")
  .setAction(propose);

task("approve-proposal", "Approves a proposal with given id")
  .addOptionalParam("id", "given proposal to approve")
  .setAction(approveProposal);

// initiators
task("initiate-pool", "initiate a pool with correct parameters")
  .addParam("f", "maintenance fee")
  .addOptionalParam("i", "interface name, default: none")
  .addParam("m", "maintainer address")
  .addParam("n", "name of the pool")
  .addOptionalParam("tn", "token name")
  .addOptionalParam("ts", "token symbol")
  .addOptionalParam("v", "visibility: public/private, default:public")
  .addOptionalParam("lp", "liquidity pool, default: false")
  .setAction(initiatePool);

task("initiate-operator", "initiate an operator with correct parameters")
  .addParam("id", "id for operator")
  .addParam("f", "MaintenanceFee")
  .addParam("m", "maintainer address")
  .addParam("p", "maintainer address")
  .setAction(initiateOperator);
