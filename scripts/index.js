const { task } = require("hardhat/config");
const accounts = require("./tasks/accounts");
const activatePortal = require("./tasks/activatePortal");
task("accounts", "Prints the list of accounts", accounts);
task("activate-portal", "Prints the list of accounts", activatePortal);
