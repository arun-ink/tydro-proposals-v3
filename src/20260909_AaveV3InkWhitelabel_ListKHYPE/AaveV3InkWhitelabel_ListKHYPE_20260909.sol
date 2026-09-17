// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3InkWhitelabel, AaveV3InkWhitelabelAssets} from 'aave-address-book/AaveV3InkWhitelabel.sol';
import {AaveV3PayloadInkWhitelabel} from 'aave-helpers/src/v3-config-engine/AaveV3PayloadInkWhitelabel.sol';
import {EngineFlags} from 'aave-v3-origin/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {IAaveV3ConfigEngine} from 'aave-v3-origin/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IEmissionManager} from 'aave-v3-origin/contracts/rewards/interfaces/IEmissionManager.sol';

/**
 * @title list kHYPE
 * @author Arun Kirubarajan
 */
contract AaveV3InkWhitelabel_ListKHYPE_20260909 is AaveV3PayloadInkWhitelabel {
  using SafeERC20 for IERC20;

  // https://explorer.inkonchain.com/address/0xAd09Cd20e513E4d8cB78036F77Ab9AfdE8555929
  address public constant kHYPE = 0xAd09Cd20e513E4d8cB78036F77Ab9AfdE8555929;
  uint256 public constant kHYPE_SEED_AMOUNT = 1e18;
  // https://explorer.inkonchain.com/address/0xB42BA1d34BbF88731aA456Ec87D039b54B818972
  address public constant kHYPE_PRICE_FEED = 0xB42BA1d34BbF88731aA456Ec87D039b54B818972;

  function _postExecute() internal override {
    _supplyAndConfigureLMAdmin(kHYPE, kHYPE_SEED_AMOUNT, address(0));
  }

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
      borrowCap: 1,
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
  function borrowsUpdates()
    public
    pure
    override
    returns (IAaveV3ConfigEngine.BorrowUpdate[] memory)
  {
    IAaveV3ConfigEngine.BorrowUpdate[]
      memory borrowUpdates = new IAaveV3ConfigEngine.BorrowUpdate[](1);

    borrowUpdates[0] = IAaveV3ConfigEngine.BorrowUpdate({
      asset: AaveV3InkWhitelabelAssets.USDG_UNDERLYING,
      enabledToBorrow: EngineFlags.DISABLED,
      flashloanable: EngineFlags.KEEP_CURRENT,
      reserveFactor: EngineFlags.KEEP_CURRENT
    });

    return borrowUpdates;
  }
  function assetsEModeUpdates()
    public
    pure
    override
    returns (IAaveV3ConfigEngine.AssetEModeUpdate[] memory)
  {
    IAaveV3ConfigEngine.AssetEModeUpdate[]
      memory assetEModeUpdates = new IAaveV3ConfigEngine.AssetEModeUpdate[](3);

    assetEModeUpdates[0] = IAaveV3ConfigEngine.AssetEModeUpdate({
      asset: AaveV3InkWhitelabelAssets.USDG_UNDERLYING,
      eModeCategory: 2,
      borrowable: EngineFlags.DISABLED,
      collateral: EngineFlags.KEEP_CURRENT,
      ltvzero: EngineFlags.KEEP_CURRENT
    });
    assetEModeUpdates[1] = IAaveV3ConfigEngine.AssetEModeUpdate({
      asset: AaveV3InkWhitelabelAssets.USDG_UNDERLYING,
      eModeCategory: 3,
      borrowable: EngineFlags.DISABLED,
      collateral: EngineFlags.KEEP_CURRENT,
      ltvzero: EngineFlags.KEEP_CURRENT
    });
    assetEModeUpdates[2] = IAaveV3ConfigEngine.AssetEModeUpdate({
      asset: AaveV3InkWhitelabelAssets.USDG_UNDERLYING,
      eModeCategory: 5,
      borrowable: EngineFlags.DISABLED,
      collateral: EngineFlags.KEEP_CURRENT,
      ltvzero: EngineFlags.KEEP_CURRENT
    });

    return assetEModeUpdates;
  }
  function eModeCategoryCreations()
    public
    pure
    override
    returns (IAaveV3ConfigEngine.EModeCategoryCreation[] memory)
  {
    IAaveV3ConfigEngine.EModeCategoryCreation[]
      memory eModeCreations = new IAaveV3ConfigEngine.EModeCategoryCreation[](1);

    address[] memory collateralAssets_KHYPE__USDG = new address[](1);
    address[] memory borrowableAssets_KHYPE__USDG = new address[](1);

    collateralAssets_KHYPE__USDG[0] = kHYPE;
    borrowableAssets_KHYPE__USDG[0] = AaveV3InkWhitelabelAssets.USDG_UNDERLYING;

    eModeCreations[0] = IAaveV3ConfigEngine.EModeCategoryCreation({
      ltv: 60_00,
      liqThreshold: 65_00,
      liqBonus: 10_00,
      label: 'kHYPE__USDG',
      isolated: true,
      collaterals: collateralAssets_KHYPE__USDG,
      borrowables: borrowableAssets_KHYPE__USDG
    });

    return eModeCreations;
  }
}
