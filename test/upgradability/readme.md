
# Check

UUPSUpgradeable              = x
Initializable                = x
ReentrancyGuardUpgradeable   = +
PausableUpgradeable          = +
ERC1155HolderUpgradeable     = x
Clones                       = x

# Inheritance order

gETH, PORTAL, Modules, packages.

# Scripts

upgrade portal
upgrade a package: when only the package's code is updated (adding a new module etc.), update the effected packages and release.
upgrade a module: when a module's code or storage is mutated, update the effected packages and release.
upgrade a library: when a library' code is updated, update the effected packages and release.

# Notes

- new module to rightmost.
- Inheritance must be ordered from “most base-like” to “most derived”.

1. bütün package ve modullerin inheritence orderlarının beklenildiği gibi olduğunu web3 ile test et: inheritance.test.je

2. renaming a storage variable (or storage struct) is done with      * @custom:oz-renamed-from _PERMIT_TYPEHASH
   1. [example](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/5bc59992591b84bba18dc1ac46942f1886b30ccd/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol#L37)
