# Globals

## Contents

This folder contains the global parameters that are used accross different modules and packages.

> **Why not use an enum, it does the same thing?**
>
> We prefer explicitly defined uints over linearly increasing ones, in general.
>
> This allows regrouping some of the global parameters according to the behaviour of the uint it represents, if needed.

---

### Macros

Global constant UINT256 values.

- **PERCENTAGE_DENOMINATOR**: There are no floats in solidity. This denominator always represents **1** (100%):
  - Scaling a parameter and getting a percentage of it when needed.
  - Setting a parameter as a sole percentage.

---

### Reserved Key Space

[DataStore](../modules/DataStoreModule/DataStoreModule.sol) allows storage to be organized and isolated with defined ID and keys. It is not desired to predefine the IDs. However, to prevent developer mistakes like typos, use a list of reserved keys to access the DataStore rather than literal strings.

---

### ID Type

As mentioned above, IDs are not predefined. However, grouping some\* IDs according to the expected behaviour of it can help us develop predefined functionalities according to the group it is involved.

For example we can define an ID as a:

- **Operation**, allowing contracts to communicate with other contracts and addresses.
- **Pool**, allowing it to be used for minting gETH.
- **Limit**, allowing a range of IDs to be represented as a group.
- **Package**, allowing it to have limited upgradability.

---

### Validator State

Allowing the state of the validator on the Consensus Layer to be available on the Execution Layer. Which is important for some operations such as withdrawals.

Only used for the `state` parameter of the `Validator` struct defined in the [StakeModuleLib](../modules/StakeModule/libs/StakeModuleLib.sol).
