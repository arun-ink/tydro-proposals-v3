// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3InkWhitelabel} from 'aave-address-book/AaveV3InkWhitelabel.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

import 'forge-std/Test.sol';
import {ProtocolV3TestBase, ReserveConfig} from 'aave-helpers/src/ProtocolV3TestBase.sol';
import {AaveV3InkWhitelabel_ListKHYPE_20260909} from './AaveV3InkWhitelabel_ListKHYPE_20260909.sol';

/**
 * @dev Test for AaveV3InkWhitelabel_ListKHYPE_20260909
 * command: FOUNDRY_PROFILE=test forge test --match-path=src/20260909_AaveV3InkWhitelabel_ListKHYPE/AaveV3InkWhitelabel_ListKHYPE_20260909.t.sol -vv
 */
contract AaveV3InkWhitelabel_ListKHYPE_20260909_Test is ProtocolV3TestBase {
  AaveV3InkWhitelabel_ListKHYPE_20260909 internal proposal;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('ink'), 55488495);
    proposal = new AaveV3InkWhitelabel_ListKHYPE_20260909();

    // the payload seeds the dust bin with 1 kHYPE, so the executor must hold it at execution time
    deal(proposal.kHYPE(), AaveV3InkWhitelabel.ACL_ADMIN, proposal.kHYPE_SEED_AMOUNT());
  }

  /**
   * @dev executes the generic test suite including e2e and config snapshots
   */
  function test_defaultProposalExecution() public {
    defaultTest(
      'AaveV3InkWhitelabel_ListKHYPE_20260909',
      AaveV3InkWhitelabel.POOL,
      address(proposal),
      true,
      true
    );
  }

  function test_dustBinHaskHYPEFunds() public {
    executePayload(vm, address(proposal), AaveV3InkWhitelabel.POOL);
    address aTokenAddress = AaveV3InkWhitelabel.POOL.getReserveAToken(proposal.kHYPE());
    assertGe(IERC20(aTokenAddress).balanceOf(address(AaveV3InkWhitelabel.DUST_BIN)), 10 ** 18);
  }
}
