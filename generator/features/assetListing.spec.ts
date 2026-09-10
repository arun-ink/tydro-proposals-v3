// sum.test.js
import {expect, describe, it} from 'vitest';
import {assetListing} from './assetListing';
import {MOCK_OPTIONS, assetListingConfig} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, PoolConfigs} from '../types';

describe('feature: assetListing', () => {
  it('should return reasonable code', () => {
    const output = assetListing.build({
      options: MOCK_OPTIONS,
      pool: 'AaveV3Ethereum',
      cfg: assetListingConfig,
      cache: {blockNumber: 42},
      configs: {},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const poolConfigs: PoolConfigs = {
      [MOCK_OPTIONS.pools[0]]: {
        pool: MOCK_OPTIONS.pools[0],
        artifacts: [
          assetListing.build({
            options: MOCK_OPTIONS,
            pool: 'AaveV3Ethereum',
            cfg: assetListingConfig,
            cache: {blockNumber: 42},
            configs: {[FEATURE.ASSET_LISTING]: assetListingConfig},
          }),
        ],
        configs: {[FEATURE.ASSET_LISTING]: assetListingConfig},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles(MOCK_OPTIONS, poolConfigs);
    expect(files).toMatchSnapshot();
  });

  it('regression: V3.7 listings do not require or emit deprecated fields', () => {
    const output = assetListing.build({
      options: MOCK_OPTIONS,
      pool: 'AaveV3Ethereum',
      cfg: assetListingConfig,
      cache: {blockNumber: 42},
      configs: {[FEATURE.ASSET_LISTING]: assetListingConfig},
    });
    const code = output.code?.fn?.join('\n');
    const specification = output.aip?.specification?.join('\n');

    expect(code).toContain('IAaveV3ConfigEngine.Listing');
    expect(code).not.toMatch(/\b(borrowableInIsolation|withSiloedBorrowing|debtCeiling)\s*:/);
    expect(specification).toContain('| Borrowable | ENABLED |');
    expect(specification).not.toMatch(
      /\| (Isolation Mode|Debt Ceiling|Siloed Borrowing|Borrowable in Isolation)\b/,
    );
  });
});
