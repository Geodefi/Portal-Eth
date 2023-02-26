// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "../../utils/globals.sol";

contract TestGlobals {
  function getPERCENTAGE_DENOMINATOR() public pure returns (uint256) {
    return PERCENTAGE_DENOMINATOR;
  }

  // geode types
  function getTypeNONE() public pure returns (uint256) {
    return ID_TYPE.NONE;
  }

  function getTypeSENATE() public pure returns (uint256) {
    return ID_TYPE.SENATE;
  }

  function getTypeCONTRACT_UPGRADE() public pure returns (uint256) {
    return ID_TYPE.CONTRACT_UPGRADE;
  }

  function getTypeGAP() public pure returns (uint256) {
    return ID_TYPE.__GAP__;
  }

  function getTypeOPERATOR() public pure returns (uint256) {
    return ID_TYPE.OPERATOR;
  }

  function getTypePOOL() public pure returns (uint256) {
    return ID_TYPE.POOL;
  }

  function getTypeMODULE_WITHDRAWAL_CONTRACT() public pure returns (uint256) {
    return ID_TYPE.MODULE_WITHDRAWAL_CONTRACT;
  }

  function getTypeMODULE_GETH_INTERFACE() public pure returns (uint256) {
    return ID_TYPE.MODULE_GETH_INTERFACE;
  }

  function getTypeMODULE_LIQUDITY_POOL() public pure returns (uint256) {
    return ID_TYPE.MODULE_LIQUDITY_POOL;
  }

  function getTypeMODULE_LIQUDITY_POOL_TOKEN() public pure returns (uint256) {
    return ID_TYPE.MODULE_LIQUDITY_POOL_TOKEN;
  }

  // validator states

  function getStateNONE() public pure returns (uint8) {
    return VALIDATOR_STATE.NONE;
  }

  function getStatePROPOSED() public pure returns (uint8) {
    return VALIDATOR_STATE.PROPOSED;
  }

  function getStateACTIVE() public pure returns (uint8) {
    return VALIDATOR_STATE.ACTIVE;
  }

  function getStateEXITED() public pure returns (uint8) {
    return VALIDATOR_STATE.EXITED;
  }

  function getStateALIENATED() public pure returns (uint8) {
    return VALIDATOR_STATE.ALIENATED;
  }
}
