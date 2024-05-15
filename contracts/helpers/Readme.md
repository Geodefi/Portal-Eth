# Helper Contracts

## Contents

This folder includes the smart contracts and libraries that are utilized by the other contracts, but not crucial to the development of Portal or its modules, middlewares and packages.

### How helper contracts differ?

There can be important contracts that are inherited by the main contracts, such as [ERC1155PausableBurnableSupply](ERC1155PausableBurnableSupply.sol). However, these contracts are subject to minimal functional and/or semantic changes, and can be seen as a dependency no different from the Openzeppelin contracts.

There can be libraries that are utilized by the main contracts, such as
[BytesLib](BytesLib.sol). However, these libraries can be seen as a dependency no different from openzeppelin contracts.

Additionally, while some contracts are not directly used within the Portal's code, they can be used on an official deployment, such as [LPToken](LPToken.sol); or can be deployed and used by the users, such as [Whitelist](Whitelist.sol).

Finally, [test folder](./test/) contains the contracts solely used within the testing process and are not deployed or utilized outside of the test suite whatsoever.

---

## Audit

This folder requires no audits and assumed to be safe until further notice.

However, if you want to make sure and audit this folder, you can exclude the [test folder](./test/) and [BytesLib library](BytesLib.sol) .
