// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3InkWhitelabel, AaveV3InkWhitelabelAssets} from 'aave-address-book/AaveV3InkWhitelabel.sol';
import {AaveV3PayloadInkWhitelabel} from 'aave-helpers/src/v3-config-engine/AaveV3PayloadInkWhitelabel.sol';
import {EngineFlags} from 'aave-v3-origin/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {IAaveV3ConfigEngine} from 'aave-v3-origin/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {ReserveConfiguration} from 'aave-v3-origin/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {DataTypes} from 'aave-v3-origin/contracts/protocol/libraries/types/DataTypes.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IEmissionManager} from 'aave-v3-origin/contracts/rewards/interfaces/IEmissionManager.sol';

/**
 * @title list kHYPE
 * @author Arun Kirubarajan
 */
contract AaveV3InkWhitelabel_ListKHYPE_20260909 is AaveV3PayloadInkWhitelabel {
  using SafeERC20 for IERC20;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  error InvalidIsolationConfiguration(uint8 category);

  // https://explorer.inkonchain.com/address/0xAd09Cd20e513E4d8cB78036F77Ab9AfdE8555929
  address public constant kHYPE = 0xAd09Cd20e513E4d8cB78036F77Ab9AfdE8555929;
  uint256 public constant kHYPE_SEED_AMOUNT = 1e18;
  // https://explorer.inkonchain.com/address/0xB42BA1d34BbF88731aA456Ec87D039b54B818972
  address public constant kHYPE_PRICE_FEED = 0xB42BA1d34BbF88731aA456Ec87D039b54B818972;

  // Simulation candidate only: positive eMode LTV requires risk approval before production execution.
  uint256 public constant KHYPE_EMODE_LTV = 60_00;

  function _postExecute() internal override {
    _validateIsolation();
    _supplyAndConfigureLMAdmin(kHYPE, kHYPE_SEED_AMOUNT, address(0));
  }

  /// @dev Fail closed if a reused category contains pre-existing asset bits or execution state drifts.
  function _validateIsolation() internal view {
    if (
      AaveV3InkWhitelabel.POOL.getConfiguration(kHYPE).getLtv() != 0 ||
      AaveV3InkWhitelabel.POOL.getConfiguration(kHYPE).getBorrowingEnabled() ||
      AaveV3InkWhitelabel
        .POOL
        .getConfiguration(AaveV3InkWhitelabelAssets.USDG_UNDERLYING)
        .getBorrowingEnabled()
    ) revert InvalidIsolationConfiguration(0);

    uint128 collateralMask = uint128(1) << AaveV3InkWhitelabel.POOL.getReserveData(kHYPE).id;
    uint128 borrowMask = uint128(1) <<
      AaveV3InkWhitelabel.POOL.getReserveData(AaveV3InkWhitelabelAssets.USDG_UNDERLYING).id;
    uint256 usdGCategories;
    for (uint256 category = 1; category <= type(uint8).max; ++category) {
      // The loop bound guarantees that the narrowing conversion cannot truncate.
      uint8 categoryId = uint8(category);
      uint128 borrowable = AaveV3InkWhitelabel.POOL.getEModeCategoryBorrowableBitmap(categoryId);
      uint128 collateral = AaveV3InkWhitelabel.POOL.getEModeCategoryCollateralBitmap(categoryId);
      if ((borrowable & collateralMask) != 0) revert InvalidIsolationConfiguration(categoryId);
      if ((borrowable & borrowMask) != 0) {
        if (
          borrowable != borrowMask ||
          collateral != collateralMask ||
          AaveV3InkWhitelabel.POOL.getEModeCategoryLtvzeroBitmap(categoryId) != 0 ||
          !AaveV3InkWhitelabel.POOL.getIsEModeCategoryIsolated(categoryId)
        ) revert InvalidIsolationConfiguration(categoryId);
        ++usdGCategories;
      } else if ((collateral & collateralMask) != 0) {
        revert InvalidIsolationConfiguration(categoryId);
      }
    }
    if (usdGCategories != 1) revert InvalidIsolationConfiguration(0);
  }

  /// @notice Lists kHYPE without main-market collateral or borrowing permissions.
  /// @return listings The kHYPE reserve configuration.
  function newListings() public pure override returns (IAaveV3ConfigEngine.Listing[] memory) {
    IAaveV3ConfigEngine.Listing[] memory listings = new IAaveV3ConfigEngine.Listing[](1);

    listings[0] = IAaveV3ConfigEngine.Listing({
      asset: kHYPE,
      assetSymbol: 'kHYPE',
      priceFeed: kHYPE_PRICE_FEED,
      enabledToBorrow: EngineFlags.DISABLED,
      flashloanable: EngineFlags.ENABLED,
      ltv: 0,
      liqThreshold: 65_00,
      liqBonus: 10_00,
      reserveFactor: 20_00,
      supplyCap: 5_000,
      borrowCap: 0,
      liqProtocolFee: 10_00,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 45_00,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 7_00,
        variableRateSlope2: 300_00
      })
    });

    return listings;
  }

  /// @notice Keeps USDG borrowing unavailable outside an eMode.
  /// @return updates The USDG global borrowing restriction; all other parameters are preserved.
  function borrowsUpdates()
    public
    pure
    override
    returns (IAaveV3ConfigEngine.BorrowUpdate[] memory updates)
  {
    updates = new IAaveV3ConfigEngine.BorrowUpdate[](1);
    updates[0] = IAaveV3ConfigEngine.BorrowUpdate({
      asset: AaveV3InkWhitelabelAssets.USDG_UNDERLYING,
      enabledToBorrow: EngineFlags.DISABLED,
      flashloanable: EngineFlags.KEEP_CURRENT,
      reserveFactor: EngineFlags.KEEP_CURRENT
    });
  }

  /// @notice Removes USDG borrowing from every existing eMode, including categories added before execution.
  /// @dev The base payload reads and applies these updates before creating the new kHYPE eMode.
  ///      Existing debt, collateral flags, risk parameters, and other borrowable assets are not modified.
  /// @return updates Only categories whose USDG borrowable bit is currently enabled.
  function assetsEModeUpdates()
    public
    view
    override
    returns (IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates)
  {
    uint16 usdgReserveId = AaveV3InkWhitelabel
      .POOL
      .getReserveData(AaveV3InkWhitelabelAssets.USDG_UNDERLYING)
      .id;
    uint128 usdgMask = uint128(1) << usdgReserveId;
    uint8[] memory categories = new uint8[](type(uint8).max);
    uint256 count;

    // eMode identifiers are uint8; the wider loop counter safely includes category 255.
    for (uint256 category = 1; category <= type(uint8).max; ++category) {
      if (
        (AaveV3InkWhitelabel.POOL.getEModeCategoryBorrowableBitmap(uint8(category)) & usdgMask) != 0
      ) {
        categories[count++] = uint8(category);
      }
    }

    updates = new IAaveV3ConfigEngine.AssetEModeUpdate[](count);
    for (uint256 i = 0; i < count; ++i) {
      updates[i] = IAaveV3ConfigEngine.AssetEModeUpdate({
        asset: AaveV3InkWhitelabelAssets.USDG_UNDERLYING,
        eModeCategory: categories[i],
        borrowable: EngineFlags.DISABLED,
        collateral: EngineFlags.KEEP_CURRENT,
        ltvzero: EngineFlags.KEEP_CURRENT
      });
    }
  }

  /// @notice Creates the only eMode permitted to originate USDG debt after this payload executes.
  /// @return creations An isolated category with kHYPE collateral and USDG debt only.
  function eModeCategoryCreations()
    public
    pure
    override
    returns (IAaveV3ConfigEngine.EModeCategoryCreation[] memory creations)
  {
    address[] memory collaterals = new address[](1);
    collaterals[0] = kHYPE;
    address[] memory borrowables = new address[](1);
    borrowables[0] = AaveV3InkWhitelabelAssets.USDG_UNDERLYING;

    creations = new IAaveV3ConfigEngine.EModeCategoryCreation[](1);
    creations[0] = IAaveV3ConfigEngine.EModeCategoryCreation({
      ltv: KHYPE_EMODE_LTV,
      liqThreshold: 65_00,
      liqBonus: 10_00,
      label: 'kHYPE__USDG',
      collaterals: collaterals,
      borrowables: borrowables,
      isolated: true
    });
  }

  function _supplyAndConfigureLMAdmin(address asset, uint256 seedAmount, address lmAdmin) internal {
    IERC20(asset).forceApprove(address(AaveV3InkWhitelabel.POOL), seedAmount);
    AaveV3InkWhitelabel.POOL.supply(asset, seedAmount, address(AaveV3InkWhitelabel.DUST_BIN), 0);

    if (lmAdmin != address(0)) {
      address aToken = AaveV3InkWhitelabel.POOL.getReserveAToken(asset);
      address vToken = AaveV3InkWhitelabel.POOL.getReserveVariableDebtToken(asset);
      IEmissionManager(AaveV3InkWhitelabel.EMISSION_MANAGER).setEmissionAdmin(asset, lmAdmin);
      IEmissionManager(AaveV3InkWhitelabel.EMISSION_MANAGER).setEmissionAdmin(aToken, lmAdmin);
      IEmissionManager(AaveV3InkWhitelabel.EMISSION_MANAGER).setEmissionAdmin(vToken, lmAdmin);
    }
  }
}
