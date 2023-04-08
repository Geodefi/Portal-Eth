// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// interfaces
import {IgETH} from "../../interfaces/IgETH.sol";
// libraries
import {GeodeModuleLib as GML} from "../modules/GeodeModule/libs/GeodeModuleLib.sol";
// modules
import {GeodeModule} from "../modules/GeodeModule/GeodeModule.sol";
import {LiquidityModule} from "../modules/LiquidityModule/LiquidityModule.sol";
// external
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title Liquidity Module - LM
 *
 * @author Icebear & Crash Bandicoot
 *
 */
contract LiquidityPool is LiquidityModule, GeodeModule {
  // todo: probably a parameter fetched from globals showing the package type here.
  using GML for GML.DualGovernance;

  ///@custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() public virtual initializer returns (bool success) {
    success = true;
  }

  /**
   * @dev                                     ** MODIFIERS **
   */

  modifier onlyOwner() {
    require(msg.sender == GEODE.getSenate(), "LP: sender NOT SENATE");
    _;
  }

  /**
   * @dev                                     ** Owner FUNCTIONS **
   */
  /**
   * @dev -> external: all
   */

  /**
   * @dev Pausability Functions
   */

  /**
   * @notice pausing the contract activates the isolationMode
   */
  function pause() external virtual onlyOwner {
    _pause();
  }

  /**
   * @notice unpausing the contract deactivates the isolationMode
   */
  function unpause() external virtual onlyOwner {
    _unpause();
  }

  /**
   * @dev GeodeModule Functions overrides
   */

  // function getProposedVersion() public view virtual override returns (uint256) {}
  // function pullUpgrade() external virtual override onlyOwner {}
  // function isolationMode() external view virtual override returns (bool isolated) {}

  /**
   * @dev LiquidityModule Function overrides
   */

  function withdrawAdminFees(address receiver) public virtual override onlyOwner {
    super.withdrawAdminFees(receiver);
  }

  function setAdminFee(uint256 newAdminFee) public virtual override onlyOwner {
    super.setAdminFee(newAdminFee);
  }

  function setSwapFee(uint256 newSwapFee) public virtual override onlyOwner {
    super.setSwapFee(newSwapFee);
  }

  function rampA(uint256 futureA, uint256 futureTime) public virtual override onlyOwner {
    super.rampA(futureA, futureTime);
  }

  function stopRampA() public virtual override onlyOwner {
    super.stopRampA();
  }
}
