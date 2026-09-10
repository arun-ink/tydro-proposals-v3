// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3InkWhitelabel, AaveV3InkWhitelabelAssets} from 'aave-address-book/AaveV3InkWhitelabel.sol';
import {IPool} from 'aave-v3-origin/contracts/interfaces/IPool.sol';
import {AaveV3Payload} from 'aave-v3-origin/contracts/extensions/v3-config-engine/AaveV3Payload.sol';
import {IDefaultInterestRateStrategyV2} from 'aave-v3-origin/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import {DataTypes} from 'aave-v3-origin/contracts/protocol/libraries/types/DataTypes.sol';
import {Errors} from 'aave-v3-origin/contracts/protocol/libraries/helpers/Errors.sol';
import {ReserveConfiguration} from 'aave-v3-origin/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {UserConfiguration} from 'aave-v3-origin/contracts/protocol/libraries/configuration/UserConfiguration.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';

import 'forge-std/Test.sol';
import {ProtocolV3TestBase, ReserveConfig} from 'aave-helpers/src/ProtocolV3TestBase.sol';
import {AaveV3InkWhitelabel_ListKHYPE_20260909} from './AaveV3InkWhitelabel_ListKHYPE_20260909.sol';

/**
 * @dev Test for AaveV3InkWhitelabel_ListKHYPE_20260909
 * command: FOUNDRY_PROFILE=test forge test --match-path=src/20260909_AaveV3InkWhitelabel_ListKHYPE/AaveV3InkWhitelabel_ListKHYPE_20260909.t.sol -vv
 */
contract AaveV3InkWhitelabel_ListKHYPE_20260909_Test is ProtocolV3TestBase {
  using SafeERC20 for IERC20;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;

  // Address-book constants keep the fork behavior checks tied to the existing Tydro market.
  IPool internal constant POOL = AaveV3InkWhitelabel.POOL;
  address internal constant USDG = AaveV3InkWhitelabelAssets.USDG_UNDERLYING;
  address internal constant USDC = AaveV3InkWhitelabelAssets.USDC_UNDERLYING;
  address internal constant KBTC = AaveV3InkWhitelabelAssets.kBTC_UNDERLYING;
  address internal constant SUSDE = AaveV3InkWhitelabelAssets.sUSDe_UNDERLYING;
  address internal constant USDT0 = AaveV3InkWhitelabelAssets.USDT_UNDERLYING;
  AaveV3InkWhitelabel_ListKHYPE_20260909 internal proposal;

  /// @notice Uses a reproducible Ink snapshot and funds the listing's seed deposit.
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('ink'), 55500415);
    proposal = new AaveV3InkWhitelabel_ListKHYPE_20260909();

    // Fund the listing's seed deposit on the fork; production funding is required separately.
    deal(proposal.kHYPE(), AaveV3InkWhitelabel.ACL_ADMIN, proposal.kHYPE_SEED_AMOUNT());
  }

  /**
   * @dev Retains configuration snapshots, plausibility, execution-gas and seatbelt checks.
   *      The generic route selector chooses the legacy LTV-zero sUSDe/USDT0 eMode 2.
   *      Explicit route-aware e2e tests below avoid expecting new debt in that reduce-only category.
   * forge-config: default.isolate = true
   */
  function test_defaultProposalExecution() public {
    defaultTest(
      'AaveV3InkWhitelabel_ListKHYPE_20260909',
      AaveV3InkWhitelabel.POOL,
      address(proposal),
      false,
      true
    );
  }

  /// @notice Runs the helper's supply, withdrawal, caps, repayment, liquidation and flashloan suite on kHYPE/USDG.
  function test_kHYPEUSDGEndToEnd() public {
    _executeListing();
    ReserveConfig[] memory configs = _getReservesConfigs(POOL);
    e2eTestAsset(
      POOL,
      _findReserveConfig(configs, proposal.kHYPE()),
      _findReserveConfig(configs, USDG)
    );
  }

  /// @notice Runs the same end-to-end operations on the existing kBTC/USDC base-market route.
  function test_kBTCUSDCEndToEnd() public {
    _executeListing();
    ReserveConfig[] memory configs = _getReservesConfigs(POOL);
    e2eTestAsset(POOL, _findReserveConfig(configs, KBTC), _findReserveConfig(configs, USDC));
  }

  function test_dustBinHaskHYPEFunds() public {
    _executeListing();
    address aTokenAddress = AaveV3InkWhitelabel.POOL.getReserveAToken(proposal.kHYPE());
    assertGe(IERC20(aTokenAddress).balanceOf(address(AaveV3InkWhitelabel.DUST_BIN)), 10 ** 18);
  }

  /// @notice kHYPE has no base-market borrowing power and belongs to exactly one isolated category.
  function test_kHYPEUSDGConfiguration() public {
    assertEq(address(proposal.CONFIG_ENGINE()), 0xF1Cd4193bbc1aD4a23E833170f49d60f3D35a621);
    assertEq(
      address(proposal.CONFIG_ENGINE()),
      address(AaveV3Payload(0x4355C01CB049B2a298595B1BB1B3f25C5063982f).CONFIG_ENGINE())
    );
    assertEq(address(proposal.CONFIG_ENGINE().POOL()), address(POOL));
    assertEq(
      address(proposal.CONFIG_ENGINE().POOL_CONFIGURATOR()),
      address(AaveV3InkWhitelabel.POOL_CONFIGURATOR)
    );
    _executeListing();
    uint8 category = _kHypeEMode();
    DataTypes.ReserveConfigurationMap memory reserve = POOL.getConfiguration(proposal.kHYPE());
    DataTypes.CollateralConfig memory collateral = POOL.getEModeCategoryCollateralConfig(category);

    assertEq(reserve.getLtv(), 0);
    assertFalse(reserve.getBorrowingEnabled());
    assertFalse(POOL.getConfiguration(USDG).getBorrowingEnabled());
    assertEq(collateral.ltv, 6000);
    assertEq(collateral.liquidationThreshold, 6500);
    assertEq(collateral.liquidationBonus, 11000);
    assertTrue(POOL.getIsEModeCategoryIsolated(category));
    assertEq(POOL.getEModeCategoryCollateralBitmap(category), _reserveMask(proposal.kHYPE()));
    assertEq(POOL.getEModeCategoryBorrowableBitmap(category), _reserveMask(USDG));
    assertEq(POOL.getEModeCategoryLtvzeroBitmap(category), 0);

    for (uint256 i = 1; i <= type(uint8).max; ++i) {
      if (i != category) {
        assertEq(POOL.getEModeCategoryBorrowableBitmap(uint8(i)) & _reserveMask(USDG), 0);
        assertEq(
          POOL.getEModeCategoryCollateralBitmap(uint8(i)) & _reserveMask(proposal.kHYPE()),
          0
        );
      }
      assertEq(POOL.getEModeCategoryBorrowableBitmap(uint8(i)) & _reserveMask(proposal.kHYPE()), 0);
    }
  }

  /// @notice The new route creates USDG debt against kHYPE and remains repayable.
  function test_kHYPECanBorrowUSDGAndRepay() public {
    _executeListing();
    address user = makeAddr('khype-usdg');
    _selectEMode(user, _kHypeEMode());
    _supplyFor(user, proposal.kHYPE(), 100 ether);
    _borrowFor(user, USDG, 1e6);
    assertGe(_debtBalance(user, USDG), 1e6);
    assertEq(IERC20(USDG).balanceOf(user), 1e6);

    _repayAll(user, USDG);
    assertEq(_debtBalance(user, USDG), 0);
  }

  /// @notice Fuzzes valid borrow sizes within the configured kHYPE account limit.
  /// @param amountSeed The bounded USDG borrow-size seed.
  function testFuzz_kHYPEUSDGBorrowAndRepay(uint256 amountSeed) public {
    _executeListing();
    address user = makeAddr('khype-usdg-fuzz');
    _selectEMode(user, _kHypeEMode());
    _supplyFor(user, proposal.kHYPE(), 100 ether);
    (, , uint256 availableBorrows, , , ) = POOL.getUserAccountData(user);
    uint256 usdgPrice = AaveV3InkWhitelabel.ORACLE.getAssetPrice(USDG);
    // Leave a margin from the account LTV boundary and cap the fork-only liquidity demand.
    uint256 maximumAmount = (availableBorrows * 1e6) / usdgPrice / 2;
    if (maximumAmount > 100e6) maximumAmount = 100e6;
    uint256 amount = bound(amountSeed, 1e6, maximumAmount);
    _borrowFor(user, USDG, amount);
    assertGe(_debtBalance(user, USDG), amount);
    _repayAll(user, USDG);
    assertEq(_debtBalance(user, USDG), 0);
  }

  /// @notice The isolated kHYPE category rejects every listed debt asset other than USDG.
  function test_kHYPEEModeCannotBorrowOtherAssets() public {
    _executeListing();
    address user = makeAddr('khype-debt-allowlist');
    _selectEMode(user, _kHypeEMode());
    _supplyFor(user, proposal.kHYPE(), 100 ether);
    address[] memory assets = POOL.getReservesList();
    for (uint256 i = 0; i < assets.length; ++i) {
      if (assets[i] != USDG) {
        DataTypes.ReserveConfigurationMap memory config = POOL.getConfiguration(assets[i]);
        assertEq(POOL.getEModeCategoryBorrowableBitmap(_kHypeEMode()) & _reserveMask(assets[i]), 0);
        // Reserve safety checks precede the eMode check; assert their exact error where applicable.
        bytes4 expectedError = !config.getActive()
          ? Errors.ReserveInactive.selector
          : config.getPaused()
            ? Errors.ReservePaused.selector
            : config.getFrozen()
              ? Errors.ReserveFrozen.selector
              : Errors.NotBorrowableInEMode.selector;
        uint256 amount = 10 ** config.getDecimals();
        vm.expectRevert(expectedError);
        vm.prank(user);
        POOL.borrow(assets[i], amount, 2, 0, user);
      }
    }
  }

  /// @notice No existing category can originate USDG debt, regardless of available collateral.
  function test_USDGDisabledInEveryOtherConfiguredEMode() public {
    _executeListing();
    uint8 category = _kHypeEMode();
    for (uint256 i = 1; i <= type(uint8).max; ++i) {
      if (
        i != category && POOL.getEModeCategoryCollateralConfig(uint8(i)).liquidationThreshold != 0
      ) {
        address user = makeAddr(string.concat('old-emode-', vm.toString(i)));
        _selectEMode(user, uint8(i));
        vm.expectRevert(Errors.NotBorrowableInEMode.selector);
        vm.prank(user);
        POOL.borrow(USDG, 1e6, 2, 0, user);
      }
    }
  }

  /// @notice kHYPE cannot activate collateral or originate USDC/USDG debt in the base market.
  function test_kHYPECannotBorrowInMainMarket() public {
    _executeListing();
    address user = makeAddr('khype-main-market');
    address khype = proposal.kHYPE();
    _supplyFor(user, khype, 100 ether);
    assertFalse(
      POOL.getUserConfiguration(user).isUsingAsCollateral(POOL.getReserveData(proposal.kHYPE()).id)
    );
    vm.expectRevert(Errors.UserHasAssetWithZeroLtv.selector);
    vm.prank(user);
    POOL.setUserUseReserveAsCollateral(khype, true);
    vm.expectRevert(Errors.LtvValidationFailed.selector);
    vm.prank(user);
    POOL.borrow(USDC, 1e6, 2, 0, user);
    vm.expectRevert(Errors.BorrowingNotEnabled.selector);
    vm.prank(user);
    POOL.borrow(USDG, 1e6, 2, 0, user);
  }

  /// @notice The existing kBTC/USDC base-market route stays open, while USDG stays unavailable.
  function test_kBTCCanStillBorrowUSDCButNotUSDG() public {
    _executeListing();
    address user = makeAddr('kbtc-main-market');
    _supplyFor(user, KBTC, 1e6);
    _borrowFor(user, USDC, 1e6);
    assertGe(_debtBalance(user, USDC), 1e6);
    vm.expectRevert(Errors.BorrowingNotEnabled.selector);
    vm.prank(user);
    POOL.borrow(USDG, 1e6, 2, 0, user);
  }

  /// @notice Depositing assets from other routes cannot augment collateral in the kHYPE category.
  function test_OutsideCollateralCannotBackUSDGInKHYPEEMode() public {
    _executeListing();
    address user = makeAddr('mixed-collateral');
    _selectEMode(user, _kHypeEMode());
    _supplyFor(user, proposal.kHYPE(), 100 ether);
    (uint256 collateralBefore, , uint256 availableBefore, , , ) = POOL.getUserAccountData(user);
    _supplyFor(user, KBTC, 1e6);
    _supplyFor(user, USDC, 100e6);
    _supplyFor(user, SUSDE, 100 ether);
    (uint256 collateralAfter, , uint256 availableAfter, , , ) = POOL.getUserAccountData(user);
    assertEq(collateralAfter, collateralBefore);
    assertEq(availableAfter, availableBefore);
    address[3] memory outsiders = [KBTC, USDC, SUSDE];
    for (uint256 i = 0; i < outsiders.length; ++i) {
      assertFalse(
        POOL.getUserConfiguration(user).isUsingAsCollateral(POOL.getReserveData(outsiders[i]).id)
      );
      vm.expectRevert(Errors.UserHasAssetWithZeroLtv.selector);
      vm.prank(user);
      POOL.setUserUseReserveAsCollateral(outsiders[i], true);
    }
  }

  /// @notice Selecting the new category with only kBTC supply does not create USDG borrowing power.
  function test_OutsideCollateralAloneCannotBorrowUSDGInKHYPEEMode() public {
    _executeListing();
    address user = makeAddr('outside-collateral-only');
    _selectEMode(user, _kHypeEMode());
    _supplyFor(user, KBTC, 1e6);
    (uint256 collateral, , uint256 availableBorrows, , uint256 ltv, ) = POOL.getUserAccountData(
      user
    );
    assertEq(collateral, 0);
    assertEq(availableBorrows, 0);
    assertEq(ltv, 0);
    vm.expectRevert(Errors.LtvValidationFailed.selector);
    vm.prank(user);
    POOL.borrow(USDG, 1e6, 2, 0, user);
  }

  /// @notice Existing main-market collateral cannot be carried into the isolated kHYPE category.
  function test_MainMarketCollateralPreventsEnteringKHYPEEMode() public {
    _executeListing();
    address user = makeAddr('main-to-khype');
    _supplyFor(user, KBTC, 1e6);
    _borrowFor(user, USDC, 1e6);
    uint8 category = _kHypeEMode();
    vm.expectRevert(
      abi.encodeWithSelector(Errors.InvalidCollateralInEmode.selector, KBTC, category)
    );
    vm.prank(user);
    POOL.setUserEMode(category);
    assertEq(POOL.getUserEMode(user), 0);
  }

  /// @notice USDG debt cannot be exported to either the main market or its former stablecoin category.
  function test_USDGDebtPreventsLeavingKHYPEEMode() public {
    _executeListing();
    address user = makeAddr('khype-mode-exit');
    uint8 category = _kHypeEMode();
    _selectEMode(user, category);
    _supplyFor(user, proposal.kHYPE(), 100 ether);
    _borrowFor(user, USDG, 1e6);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidDebtInEmode.selector, USDG, 0));
    vm.prank(user);
    POOL.setUserEMode(0);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidDebtInEmode.selector, USDG, 5));
    vm.prank(user);
    POOL.setUserEMode(5);
    assertEq(POOL.getUserEMode(user), category);

    _repayAll(user, USDG);
    address khype = proposal.kHYPE();
    vm.prank(user);
    POOL.setUserUseReserveAsCollateral(khype, false);
    _selectEMode(user, 0);
    assertEq(POOL.getUserEMode(user), 0);
  }

  /// @notice Existing USDG debt survives unchanged and can be repaid; other category-5 debt remains usable.
  function test_LegacyUSDGBorrowerCanRepayButCannotIncreaseUSDGDebt() public {
    address user = makeAddr('legacy-susde-usdg');
    _selectEMode(user, 5);
    _supplyFor(user, SUSDE, 100 ether);
    _borrowFor(user, USDG, 1e6);
    uint256 debtBefore = _debtBalance(user, USDG);
    (, , , , , uint256 healthBefore) = POOL.getUserAccountData(user);

    _executeListing();
    assertEq(_debtBalance(user, USDG), debtBefore);
    (, , , , , uint256 healthAfter) = POOL.getUserAccountData(user);
    assertEq(healthAfter, healthBefore);
    assertEq(POOL.getUserEMode(user), 5);
    vm.expectRevert(Errors.NotBorrowableInEMode.selector);
    vm.prank(user);
    POOL.borrow(USDG, 1e6, 2, 0, user);
    uint256 collateralBefore = IERC20(POOL.getReserveAToken(SUSDE)).balanceOf(user);
    _supplyFor(user, SUSDE, 10 ether);
    vm.prank(user);
    POOL.withdraw(SUSDE, 10 ether, user);
    assertApproxEqAbs(IERC20(POOL.getReserveAToken(SUSDE)).balanceOf(user), collateralBefore, 1);
    assertEq(_debtBalance(user, USDG), debtBefore);
    _borrowFor(user, USDT0, 1e6);
    assertGe(_debtBalance(user, USDT0), 1e6);
    _repayAll(user, USDG);
    assertEq(_debtBalance(user, USDG), 0);
    assertGe(_debtBalance(user, USDT0), 1e6);
  }

  /// @notice Removing USDG borrowing permission does not prevent liquidation of existing USDG debt.
  function test_LegacyUSDGDebtRemainsLiquidatable() public {
    address user = makeAddr('legacy-usdg-liquidation');
    _selectEMode(user, 5);
    _supplyFor(user, SUSDE, 100 ether);
    _borrowFor(user, USDG, 1e6);
    _executeListing();
    uint256 debtBefore = _debtBalance(user, USDG);
    uint256 collateralBefore = IERC20(POOL.getReserveAToken(SUSDE)).balanceOf(user);

    // Fork-only oracle response: force the synthetic borrower below its liquidation threshold.
    vm.mockCall(
      address(AaveV3InkWhitelabel.ORACLE),
      abi.encodeWithSignature('getAssetPrice(address)', SUSDE),
      abi.encode(uint256(1e6))
    );
    (, , , , , uint256 healthFactor) = POOL.getUserAccountData(user);
    assertLt(healthFactor, 1 ether);
    address liquidator = makeAddr('legacy-usdg-liquidator');
    deal(USDG, liquidator, 2e6);
    vm.startPrank(liquidator);
    IERC20(USDG).forceApprove(address(POOL), 2e6);
    POOL.liquidationCall(SUSDE, USDG, user, type(uint256).max, false);
    vm.stopPrank();
    assertLt(_debtBalance(user, USDG), debtBefore);
    assertLt(IERC20(POOL.getReserveAToken(SUSDE)).balanceOf(user), collateralBefore);
    assertGt(IERC20(SUSDE).balanceOf(liquidator), 0);
    assertEq(POOL.getEModeCategoryBorrowableBitmap(5) & _reserveMask(USDG), 0);
  }

  /// @notice The payload does not change the existing kBTC/USDC configuration or interest-rate models.
  function test_kBTCUSDCConfigurationAndInterestRateModelsUnchanged() public {
    bytes32 kbtcBefore = _reserveAndRateSettings(KBTC);
    bytes32 usdcBefore = _reserveAndRateSettings(USDC);
    _executeListing();
    assertEq(_reserveAndRateSettings(KBTC), kbtcBefore);
    assertEq(_reserveAndRateSettings(USDC), usdcBefore);
  }

  function _executeListing() internal {
    executePayload(vm, address(proposal), POOL);
  }

  function _kHypeEMode() internal view returns (uint8) {
    for (uint256 i = 1; i <= type(uint8).max; ++i) {
      if (keccak256(bytes(POOL.getEModeCategoryLabel(uint8(i)))) == keccak256('kHYPE__USDG')) {
        return uint8(i);
      }
    }
    revert('kHYPE eMode missing');
  }

  function _reserveMask(address asset) internal view returns (uint128) {
    return uint128(1) << POOL.getReserveData(asset).id;
  }

  function _selectEMode(address user, uint8 category) internal {
    vm.prank(user);
    POOL.setUserEMode(category);
  }

  function _supplyFor(address user, address asset, uint256 amount) internal {
    deal(asset, user, amount);
    vm.startPrank(user);
    IERC20(asset).forceApprove(address(POOL), amount);
    POOL.supply(asset, amount, user, 0);
    vm.stopPrank();
  }

  function _borrowFor(address user, address asset, uint256 amount) internal {
    vm.prank(user);
    POOL.borrow(asset, amount, 2, 0, user);
  }

  function _repayAll(address user, address asset) internal {
    deal(asset, user, _debtBalance(user, asset) + 1);
    vm.startPrank(user);
    IERC20(asset).forceApprove(address(POOL), type(uint256).max);
    POOL.repay(asset, type(uint256).max, 2, user);
    vm.stopPrank();
  }

  function _debtBalance(address user, address asset) internal view returns (uint256) {
    return IERC20(POOL.getReserveVariableDebtToken(asset)).balanceOf(user);
  }

  function _reserveAndRateSettings(address asset) internal view returns (bytes32) {
    address strategy = POOL.RESERVE_INTEREST_RATE_STRATEGY();
    return
      keccak256(
        abi.encode(
          POOL.getReserveData(asset),
          strategy,
          IDefaultInterestRateStrategyV2(strategy).getInterestRateData(asset)
        )
      );
  }
}
