#### Redeem without harvesting, one strategy
Harvest explicitly called before redeem, therefore no harvest while redeeming because of cool down period

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 239648          | 239648 | 239648 | 239648 | 1       |

#### Redeem without harvesting, five strategies
Harvest explicitly called before redeem, therefore no harvest while redeeming because of cool down period

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 734642          | 734642  | 734642  | 734642  | 1    |

#### Redeem with harvesting, one strategy, no yield no loss

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawSingleStrategyNoYieldNoLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 236562          | 236562 | 236562 | 236562 | 2       |

#### Redeem with harvesting, two strategies, no yield no loss

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawTwoStrategiesNoYieldNoLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 360311          | 360311 | 360311 | 360311 | 1       |

#### Redeem with harvesting, three strategies, no yield no loss

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawThreeStrategiesNoYieldNoLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 484059          | 484059 | 484059 | 484059 | 1       |

#### Redeem with harvesting, five strategies, no yield no loss

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFiveStrategiesNoYieldNoLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 731556          | 731556  | 731556  | 731556  | 1       |

#### Redeem with harvesting, one strategy with yield

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawSingleStrategyWithYield`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 229565          | 229565 | 229565 | 229565 | 1       |

#### Redeem with harvesting, two strategies with yield

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawTwoStrategiesWithYield`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 341487          | 341487 | 341487 | 341487 | 1       |

#### Redeem with harvesting, five strategies with yield

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFiveStrategiesWithYield`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 677251          | 677251  | 677251  | 677251  | 1       |

#### Redeem with harvesting, one strategies with loss

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawSingleStrategyWithLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 220211          | 220211 | 220211 | 220211 | 1       |

#### Redeem with harvesting, five strategies with loss

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFiveStrategiesWithLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 631129          | 631129  | 631129  | 631129  | 1       |