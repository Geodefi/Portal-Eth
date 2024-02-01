# Interfaces

## What is an interface?

- Interface cannot have any function with implementation.
- Functions of an interface can be only of type external.
- Interface cannot have a constructor, state variables and modifiers.
- Interface can have events, enums and structs. **However, we do not advise putting them in an interface.**

> Please refer to the [official solidity docs](https://docs.soliditylang.org/en/v0.8.20/contracts.html#interfaces) for more.

## As a Standard

![interfaces as a standard](../../../docs/images/interfaces1.png)

Interfaces are _mainly_ used to provide a way for two contracts to communicate easily. Interfaces provide only the function selectors and no detail on the functionality. The information on the interface and inherited contracts' ABI should be compatible.

Interfaces are crucial as they allow contracts to make use of specific functions within the external contracts without concerning the functionality. Thus, Interfaces help creating a standard for all external contracts to integrate easily.

## As Building Blocks

![interfaces as building blocks](../../../docs/images/interfaces2.png)

One can suggest that, Interfaces are the building blocks of the smart contract development. As contracts inheriting specific Interface can be grouped within the shared definition of the intended functionality.

With predefined interfaces that are inherited by packages, modules and middlewares, Portal makes use of this statement and removes the difference between contracts without needing any changes on the caller side. This is especially important with the Limited Upgradability, which allows changing dependencies without changing the code.

Thus, Modular Architecture of the Portal relies on interfaces as its building blocks.

## Contents

The directory structure within the `/interfaces` directory corresponds to the `/contracts` directory.

- **Helpers**
  - [**IDepositContract**](./helpers/IDepositContract.sol): Referance for the [Beacon Deposit Contract](https://etherscan.io/address/0x00000000219ab540356cbb839cbe05303d7705fa). Used within [DepositContractLib](../modules/StakeModule/libs/DepositContractLib.sol) when creating a validator or a validator proposal.
  - [**IERC1155PausableBurnableSupply**](./helpers/IERC1155PausableBurnableSupply.sol): Inherited by the base contract of gETH, [ERC1155PausableBurnableSupply](../helpers/ERC1155PausableBurnableSupply.sol).
  - [**ILPToken**](./helpers/ILPToken.sol): Inherited by the [LPToken](../helpers/LPToken.sol) which is prepeared for [Liquidity Module](../modules/LiquidityModule/LiquidityModule.sol). Used within [LiquidityModuleLib](../modules/LiquidityModule/libs/LiquidityModuleLib.sol).
  - [**IWhitelist**](./helpers/IWhitelist.sol): Should be inherited by any whitelisting contracts that a pool owner wants to use. Used within [StakeModuleLib](../modules/StakeModule/libs/StakeModuleLib.sol).
- **Middlewares**:
  - [**IgETHMiddleware**](./middlewares/IgETHMiddleware.sol): All gETHMiddlewares should inherit this interface. Provides a way to call `initialize` with a `data` parameter which can be used to specify some additional data such as token name, symbol, etc.
- **Modules**:
  - [**IDataStoreModule**](./modules/IDataStoreModule.sol): Inherited by [DataStoreModule](../modules/DataStoreModule/DataStoreModule.sol).
  - [**IGeodeModule**](./modules/IGeodeModule.sol): Inherits IDataStoreModule. Inherited by [GeodeModule](../modules/GeodeModule/GeodeModule.sol).
  - [**ILiquidityModule**](./modules/ILiquidityModule.sol): Inherited by [LiquidityModule](../modules/LiquidityModule/LiquidityModule.sol).
  - [**IStakeModule**](./modules/IStakeModule.sol): Inherits IDataStoreModule. Inherited by [StakeModule](../modules/StakeModule/StakeModule.sol).
  - [**IWithdrawalModule**](./modules/IWithdrawalModule.sol): **_To be implemented._**
- **Packages**:
  - [**IGeodePackage**](./packages/IGeodePackage.sol): As packages follow the Limited Upgradability Pattern, all packages except Portal are _GeodePackages_ and should inherit IGeodePackage instead of IGeodeModule. Inherits IGeodeModule with additional functions.
  - [**ILiquidityPool**](./packages/ILiquidityPool.sol): Inherits IGeodePackage and ILiquidityModule.
  - [**IWithdrawalContract**](./packages/IWithdrawalContract.sol): **_To be implemented._**
- [**IgETH**](./IgETH.sol): Inherits IERC1155PausableBurnableSupply. Inherited by [gETH](../gETH.sol) contract.
- [**IPortal**](./IPortal.sol):Inherits IGeodeModule and IStakeModule. Inherited by [Portal](../Portal.sol) contract.
