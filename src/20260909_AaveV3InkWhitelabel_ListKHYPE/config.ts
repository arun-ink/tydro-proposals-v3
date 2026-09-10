import {ConfigFile} from '../../generator/types';

// Simulation candidate: 60% eMode LTV requires risk approval before production execution.
// The Solidity payload additionally scans every eMode at execution time to remove USDG
// borrowing, covering categories created after this snapshot. Preserve that custom hook
// when regenerating; the legacy listing generator also needs its obsolete V3 fields removed.
export const config: ConfigFile = {
  rootOptions: {
    configFile: 'src/20260909_AaveV3InkWhitelabel_ListKHYPE/config.ts',
    force: false,
    pools: ['AaveV3InkWhitelabel'],
    title: 'list kHYPE',
    shortName: 'ListKHYPE',
    date: '20260909',
    author: 'Arun Kirubarajan',
  },
  poolOptions: {
    AaveV3InkWhitelabel: {
      configs: {
        ASSET_LISTING: [
          {
            assetSymbol: 'kHYPE',
            decimals: 18,
            priceFeed: '0xB42BA1d34BbF88731aA456Ec87D039b54B818972',
            ltv: '0',
            liqThreshold: '65',
            liqBonus: '10',
            liqProtocolFee: '10',
            enabledToBorrow: 'DISABLED',
            flashloanable: 'ENABLED',
            reserveFactor: '20',
            supplyCap: '5000',
            borrowCap: '0',
            rateStrategyParams: {
              optimalUtilizationRate: '45',
              baseVariableBorrowRate: '0',
              variableRateSlope1: '7',
              variableRateSlope2: '300',
            },
            eModeCategory: 'AaveV3InkWhitelabelEModes.NONE',
            asset: '0xAd09Cd20e513E4d8cB78036F77Ab9AfdE8555929',
            admin: '',
          },
        ],
        BORROWS_UPDATE: [
          {
            asset: 'USDG',
            enabledToBorrow: 'DISABLED',
            flashloanable: 'KEEP_CURRENT',
            reserveFactor: '',
          },
        ],
        EMODES_ASSETS: [
          {
            asset: 'USDG',
            eModeCategory: '2',
            collateral: 'KEEP_CURRENT',
            borrowable: 'DISABLED',
            ltvzero: 'KEEP_CURRENT',
          },
          {
            asset: 'USDG',
            eModeCategory: '3',
            collateral: 'KEEP_CURRENT',
            borrowable: 'DISABLED',
            ltvzero: 'KEEP_CURRENT',
          },
          {
            asset: 'USDG',
            eModeCategory: '5',
            collateral: 'KEEP_CURRENT',
            borrowable: 'DISABLED',
            ltvzero: 'KEEP_CURRENT',
          },
        ],
        EMODES_CREATION: [
          {
            ltv: '60',
            liqThreshold: '65',
            liqBonus: '10',
            label: 'kHYPE__USDG',
            isolated: 'ENABLED',
            collateralAssets: ['kHYPE'],
            borrowableAssets: ['USDG'],
          },
        ],
      },
      cache: {blockNumber: 55500415},
    },
  },
};
