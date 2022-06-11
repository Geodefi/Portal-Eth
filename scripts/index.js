const { task } = require("hardhat/config");
const accounts = require("./tasks/accounts");
task("accounts", "Prints the list of accounts", accounts);
