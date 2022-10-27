const { task } = require("hardhat/config");
const accounts = require("./tasks/accounts");
const activatePortal = require("./tasks/activatePortal");

const propose = require("./tasks/propose");
const approveProposal = require("./tasks/approveProposal");
const elect = require("./tasks/elect");

const setController = require("./tasks/setController");
const changePoolMaintainer = require("./tasks/changePoolMaintainer");
const changeOperatorMaintainer = require("./tasks/changeOperatorMaintainer");

const approveOperator = require("./tasks/approveOperator");
const initiateOperator = require("./tasks/initiateOperator");
const initiatePlanet = require("./tasks/initiatePlanet");

const switchFee = require("./tasks/switchFee");
const rampA = require("./tasks/rampA");

task("accounts", "Prints the list of accounts", accounts);

// portal management
task("activate-portal", "", activatePortal);

// proposals
task("propose", "Creates a proposal with desired parameters")
  .addParam("t", "defines type such as planet , operator , senate , Upgrade")
  .addParam(
    "c",
    "refers to the proposed address as the controller of resulting ID"
  )
  .addParam("n", "id with keccak")
  .setAction(propose);

task("approveProposal", "Approves a proposal with given id")
  .addOptionalParam("id", "given proposal to approve")
  .setAction(approveProposal);

task("elect", "Approves a Senate proposal")
  .addParam("sid", "iven senate to approve")
  .addParam("pid", "id of planet")
  .setAction(elect);

// controllers
task("setController", "Approves a Senate proposal")
  .addParam("id", "id to change the controller")
  .addParam("c", "new controller")
  .setAction(setController);

task("changePoolMaintainer", "Approves a Senate proposal")
  .addParam("id", "id to change the controller")
  .addParam("m", "new maintainer")
  .setAction(changePoolMaintainer);

task("changeOperatorMaintainer", "Change fee of an ID")
  .addParam("id", "id for operator")
  .addParam("m", "new maintainer")
  .setAction(changeOperatorMaintainer);

// maintainers
task("initiatePlanet", "Change fee of an ID")
  .addParam("id", "id for planet")
  .addParam("f", "maintainerFee")
  .addParam("m", "maintainer address")
  .addParam("n", "interface name")
  .addParam("s", "interface symbol")
  .setAction(initiatePlanet);

task("initiateOperator", "Change fee of an ID")
  .addParam("id", "id for planet")
  .addParam("f", "maintainerFee")
  .addParam("m", "maintainer address")
  .addParam("p", "maintainer address")
  .setAction(initiateOperator);

task("approveOperator", "Approves a Senate proposal")
  .addParam("pid", "pool ID")
  .addParam("oid", "operator ID")
  .addParam("a", "# validators to approve for")
  .setAction(approveOperator);

task("switchFee", "Change fee of an ID")
  .addParam("id", "id for maintainer")
  .addParam("f", "fee")
  .setAction(switchFee);

// DWP
task("rampA", "Change A parameter of Withdrawal Pool of given ID ")
  .addParam("id", "id of planet")
  .addParam("a", "new A")
  .setAction(rampA);
