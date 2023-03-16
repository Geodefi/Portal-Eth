const { task } = require("hardhat/config");
const accounts = require("./tasks/accounts");
const details = require("./tasks/details");
const activatePortal = require("./tasks/activatePortal");

const propose = require("./tasks/propose");
const approveProposal = require("./tasks/approveProposal");

const setController = require("./tasks/setController");
const changeOperatorMaintainer = require("./tasks/changeMaintainer");

const approveOperators = require("./tasks/approveOperators");
const initiateOperator = require("./tasks/initiateOperator");
const initiatePool = require("./tasks/initiatePool");

const switchFee = require("./tasks/switchFee");

task("accounts", "Prints the list of accounts", accounts);

// portal management
task("details", "describes the Portal detail and lists users", details);
task("activate-portal", "makes Portal gETH minter", activatePortal);

// proposals
task("propose", "Creates a proposal with desired parameters")
  .addParam("t", "defines type such as pool , operator , senate , Upgrade")
  .addParam(
    "c",
    "refers to the proposed address as the controller of resulting ID"
  )
  .addParam("n", "id with keccak")
  .setAction(propose);

task("approve-proposal", "Approves a proposal with given id")
  .addOptionalParam("id", "given proposal to approve")
  .setAction(approveProposal);

// controllers
task("set-controller", "Approves a Senate proposal")
  .addParam("id", "id to change the controller")
  .addParam("c", "new controller")
  .setAction(setController);

task("change-maintainer", "Change operator of an ID")
  .addParam("id", "id for operator")
  .addParam("m", "new maintainer")
  .setAction(changeOperatorMaintainer);

// maintainers
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

task("approve-operators", "Approves a Senate proposal")
  .addParam("pid", "pool ID")
  .addParam("oids", "operator IDs array, separated by comma")
  .addParam(
    "as",
    "number of validators to allow, separated by comma, relative to oids array"
  )
  .setAction(approveOperators);

task("switch-fee", "Change fee of an ID")
  .addParam("id", "id for maintainer")
  .addParam("f", "fee")
  .setAction(switchFee);
