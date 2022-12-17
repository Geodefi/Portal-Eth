const { task } = require("hardhat/config");
const accounts = require("./tasks/accounts");
const details = require("./tasks/details");
const activatePortal = require("./tasks/activatePortal");
const upgradePortal = require("./tasks/upgrade");

const propose = require("./tasks/propose");
const approveProposal = require("./tasks/approveProposal");
const elect = require("./tasks/elect");

const setController = require("./tasks/setController");
const changeOperatorMaintainer = require("./tasks/changeMaintainer");

const approveOperator = require("./tasks/approveOperator");
const initiateOperator = require("./tasks/initiateOperator");
const initiatePlanet = require("./tasks/initiatePlanet");

const switchFee = require("./tasks/switchFee");
const rampA = require("./tasks/rampA");

task("accounts", "Prints the list of accounts", accounts);

// portal management
task("details", "", details);
task("activate-portal", "", activatePortal);
task("upgrade-portal", "", upgradePortal);

// proposals
task("propose", "Creates a proposal with desired parameters")
  .addParam("t", "defines type such as planet , operator , senate , Upgrade")
  .addParam(
    "c",
    "refers to the proposed address as the controller of resulting ID"
  )
  .addParam("n", "id with keccak")
  .setAction(propose);

task("approve-proposal", "Approves a proposal with given id")
  .addOptionalParam("id", "given proposal to approve")
  .setAction(approveProposal);

task("elect", "Approves a Senate proposal")
  .addParam("sid", "iven senate to approve")
  .addParam("pid", "id of planet")
  .setAction(elect);

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
task("initiate-planet", "initiate a planet with correct parameters")
  .addParam("f", "maintainerFee")
  .addParam("m", "maintainer address")
  .addParam("name", "planet name")
  .addParam("n", "interface name")
  .addParam("s", "interface symbol")
  .setAction(initiatePlanet);

task("initiate-operator", "initiate an operator with correct parameters")
  .addParam("id", "id for planet")
  .addParam("f", "maintainerFee")
  .addParam("m", "maintainer address")
  .addParam("p", "maintainer address")
  .setAction(initiateOperator);

task("approve-operator", "Approves a Senate proposal")
  .addParam("pid", "pool ID")
  .addParam("oid", "operator ID")
  .addParam("a", "number of validators to allow")
  .setAction(approveOperator);

task("switch-fee", "Change fee of an ID")
  .addParam("id", "id for maintainer")
  .addParam("f", "fee")
  .setAction(switchFee);

// DWP
task("ramp-a", "Change A parameter of Withdrawal Pool of given ID ")
  .addParam("id", "id of planet")
  .addParam("a", "new A")
  .setAction(rampA);
