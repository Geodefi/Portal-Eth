# Middlewares

![middlewares](../../../docs/images/middlewares.png)

Middlewares can be described as "software glue".

In Geode, we define it as the user facing smart contracts that rely on another contract's storage and provide additional functionality.

For example, gETH allows specific contracts, that are granted, to manipulate user balances without approvals from the token holders.

## gETH Middlewares

Currently, only TYPE of middlewares are gETH Middlewares. There can be other TYPEs of middlewares that are independent from gETH's middleware functionality in the future.

gETH Middlewares provides a never seen flexibility: allowing every single ID of the ERC1155 token to be used with extra functionalities.

> **gETH Middlewares should inherit [IgETHMiddleware](../interfaces/middlewares/IgETHMiddleware.sol) interface to be compatible with Portal.**

## Middlewares vs Packages

| Middlewares                                                 | Packages                            |
| ----------------------------------------------------------- | ----------------------------------- |
| Cannot be upgraded.                                         | Limited Upgradability.              |
| No standard way to build, except the `initialize` function. | Built by utilizing the Modules.     |
| Portal supports multiple versions.                          | Portal supports the latest version. |

## Contents

- **ERC20Middleware**: Allowing an ID to behave like a plain ERC20 token.
- **ERC20PermitMiddleware**: Inherits ERC20Middleware, provides eip-2612. No functional differences between Openzeppelin's implementation of ERC20Permit.
