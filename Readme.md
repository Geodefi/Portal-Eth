# Decentralized & Liquid Staking Pools

## Documentation

Functions and Contracts are comprehensively explained with inline comments. However, to understand the logic behind it better:
> Before starting to review the contracts please take a look at [our docs](https://docs.geode.fi/).

## Contracts

This is the recommanded order to review the contracts:

- gETH
  - [ERC1155SupplyMinterPauser](contracts/Portal/helpers/ERC1155SupplyMinterPauser.sol)
  - [gETH](contracts/Portal/gETH.sol)
    - [ERC20InterfaceUpgradable](contracts/Portal/gETHInterfaces/ERC20InterfaceUpgradable.sol)
    - [ERC20InterfacePermitUpgradable](contracts/Portal/gETHInterfaces/ERC20InterfacePermitUpgradable.sol)

- Dynamic Withdrawal Pools
  - [MathUtils](contracts/Portal/withdrawalPool/utils/MathUtils.sol)
  - [AmplificationUtils](contracts/Portal/withdrawalPool/utils/AmplificationUtils.sol)
  - [SwapUtils](contracts/Portal/withdrawalPool/utils/SwapUtils.sol)
  - [Swap](contracts/Portal/withdrawalPool/Swap.sol)
  - [LPToken](contracts/Portal/withdrawalPool/LPToken.sol)

- Portal
  - [DataStoreUtilsLib](contracts/Portal/utils/DataStoreUtilsLib.sol)
  - [GeodeUtilsLib](contracts/Portal/utils/GeodeUtilsLib.sol)
  - [MaintainerUtilsLib](contracts/Portal/utils/MaintainerUtilsLib.sol)
  - [OracleUtilsLib](contracts/Portal/utils/OracleUtilsLib.sol)
  - [DepositContractUtilsLib](contracts/Portal/utils/DepositContractUtilsLib.sol)
  - [StakeUtilsLib](contracts/Portal/utils/StakeUtilsLib.sol)
  - [Portal](contracts/Portal/Portal.sol)

- MiniGovernance
  - [MiniGovernance](contracts/Portal/MiniGovernance/MiniGovernance.sol)

## Starter Pack

- Clone the repository:

```

git clone https://github.com/Geodefi/Portal-Eth.git

cd Portal-Eth

```

2. Create `.env` file, similar to:

> If mainnet is not forked, some tests related to ETH2 deposit contract may fail.

```

FORK_MAINNET= "true"
FORK_URL= "https://eth-mainnet.g.alchemy.com/v2/<YOUR_KEY>"
PRATER= "https://eth-goerli.g.alchemy.com/v2/<YOUR_KEY>"
ACCOUNT_PRIVATE_KEYS= "<array of private keys seperated with `space` character, at least 1>"

```

3. Checkout to dev repository

```

git checkout dev

```

4. Build the repository

```

npm i

```

# Extra Hardhat Tasks

## Dev Tasks

### 0. Accounts

```

npx hardhat accounts

```

- returns local addresses. Mostly, we don't use them :)

### 1. Compile

```

npx hardhat compile

```

### 2. Test

1. Test everything

```

npx hardhat test

```

2. Test a folder

```

npx hardhat test ./test/Pools/*

```

3. Test a file

```

npx hardhat test ./test/Pools/lpToken.js

```

### 3. Deploy

1. deploy locally:

```

npx hardhat deploy

```

2. deploy to prater

> You might want to remove `deployments/prater`

```

npx hardhat deploy --network prater

```

### 4. Activate Portal

Portal needs to be set as the minter address for the following scripts to work.
Please set the Portal as Minter address, by simply:

```

npx hardhat activate-portal --network prater

```

### 5. List all details from a deployment

Lists all the Planets & Operators, with curent information on fee; maintainer & CONTROLLER addresses; Withdrawal Pool, LPtoken, currentInterface addresses.

```

npx hardhat details --network prater

```

## Governance Tasks

### 6. Create a Proposal

> This proposal requires and approval
Creates a proposal with desired parameters.

- requires governance role on the deployed contract

- `t` : defines type such as senate, upgrade, operator, planet

- `c`: refers to the proposed address as the controller of resulting ID

- `n` : defines id with keccak, unique for every proposal and ID.

- gives max deadline auto: 1 weeks.

```

npx hardhat propose --t planet --c 0xbabababababababababababaabababababa --n myPlanet  --network prater

npx hardhat propose --t operator --c 0xbabababababababababababaabababababa --n myOperator  --network prater

npx hardhat propose --t senate --c 0xbabababababababababababaabababababa --n mySenate  --network prater

```

- prints the id of the proposal

## Senate Tasks

### 7. Approve Proposal

> This approval requires initiation from the controller with correct params in case of a Planet or Operator

Approves a proposal with given id.

- requires senate role on the deployed contract

- `id` : id of the given proposal to approve

```

npx hardhat approve-proposal --id 102019998765771090775971083439296966026520537939234501758803308348529554355594  --network prater

```

## User Tasks

> **following tasks might require different tasks to be run first: such as propose, approve with desired type**

### 8. Initiate an Operator

> Should be called from a Controller

- `id` : id of operator
- `f` : fee (%)
- `m` : maintainer
- `p` : validatorPeriod (s)

```

initiate-operator --id 102019998765771090775971083439296966026520537939234501758803308348529554355594 --network prater --f 10 --m 0xbabababababababababababaabababababa --p 50000

```

### 9. Initiate a Planet

> Should be called from a Controller

- `id` : id of operator
- `f` : fee (%)
- `m` : maintainer
- `n` : name of ERC20Interface
- `s` : symbol for ERC20Interface

```

npx hardhat initiate-planet --id 8438890131190638961805509956978898063010048183498455403055171776782939000754 --network prater --f 10 --m 0xbabababababababababababaabababababa --n myPlanetETH --s myETH

```

### 10. Approve a Senate Proposal as a Planet maintainer

- `sid` : id of the given proposal senate

- `pid` : id of the planet to vote

```

npx hardhat elect --sid 11419323355145529570664410446194669483221888198176733050069995917193619618789 --pid 8438890131190638961805509956978898063010048183498455403055171776782939000754  --network prater

```

### 11. set a new CONTROLLER for an ID, as CONTROLLER

- `c`: address of the new controller

```

npx hardhat set-controller --id 01102186b7e3b0dda7f022d922f87d2ae9dffe939440e17d7166b89717e96f4c --c 0xbabababa57D8418cC282e7847cd71a7eB824A30F  --network prater

```

### 12. Change the maintainer for an ID, as CONTROLLER

- `m`: address of the new maintainer

```
npx hardhat change-maintainer  --m 0xbabababababababababababaabababababa  --id 102019998765771090775971083439296966026520537939234501758803308348529554355594  --network prater

```

### 13. approve an Operator as a Planet Maintainer

- `oid` : id of the given operator

- `pid` : id of the planet

- `a` : number of validators to allow

```

npx hardhat approve-operator --pid 01102186b7e3b0dda7f022d922f87d2ae9dffe939440e17d7166b89717e96f4c --oid 91630959199093646211198814960682556727534799142799726216648273052625587106474 --a 300

```
