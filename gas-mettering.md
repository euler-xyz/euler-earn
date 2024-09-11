#### Redeem without harvesting, one strategy, withdrawing from startegies
Harvest explicitly called before redeem, therefore no harvest while redeeming because of cool down period

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 216139          | 216139 | 216139 | 216139 | 1       |

#### Redeem without harvesting, five strategies, withdrawing from startegies
Harvest explicitly called before redeem, therefore no harvest while redeeming because of cool down period

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 655003          | 655003  | 655003  | 655003  | 1    |

#### Redeem without harvesting, five strategies, withdrawing from cash reserve (no second loop to withdraw from strategies)

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| withdraw                                                          | 79629           | 79629   | 79629   | 79629   | 1    |

#### Redeem without harvesting, five strategies, withdrawing from cash reserve + 2 other strategy

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| withdraw                                                          | 309379          | 309379  | 309379  | 309379  | 1    |

#### Redeem with harvesting, one strategy, no yield no loss, withdrawing from startegies

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFromStrategies_SingleStrategyNoYieldNoLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 236562          | 236562 | 236562 | 236562 | 2       |

#### Redeem with harvesting, two strategies, no yield no loss, withdrawing from startegies

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFromStrategies_TwoStrategiesNoYieldNoLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 360311          | 360311 | 360311 | 360311 | 1       |

#### Redeem with harvesting, three strategies, no yield no loss, withdrawing from startegies

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFromStrategies_ThreeStrategiesNoYieldNoLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 484059          | 484059 | 484059 | 484059 | 1       |

#### Redeem with harvesting, five strategies, no yield no loss, withdrawing from startegies

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFromStrategies_FiveStrategiesNoYieldNoLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 731556          | 731556  | 731556  | 731556  | 1    |

#### Redeem with harvesting, one strategy with yield, withdrawing from startegies

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFromStrategies_SingleStrategyWithYield`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 229565          | 229565 | 229565 | 229565 | 1       |

#### Redeem with harvesting, two strategies with yield, withdrawing from startegies

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFromStrategies_TwoStrategiesWithYield`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 341487          | 341487 | 341487 | 341487 | 1       |

#### Redeem with harvesting, five strategies with yield, withdrawing from startegies

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFromStrategies_FiveStrategiesWithYield`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 689078          | 689078  | 689078  | 689078  | 1    |

#### Redeem with harvesting, one strategies with loss, withdrawing from startegies

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFromStrategies_SingleStrategyWithLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 220211          | 220211 | 220211 | 220211 | 1       |

#### Redeem with harvesting, five strategies with loss, withdrawing from startegies

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFromStrategies_FiveStrategiesWithLoss`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| redeem                                                            | 631129          | 631129  | 631129  | 631129  | 1    |

#### Redeem with harvesting, five strategies with yield, withdrawing from cash reserve (no second loop to withdraw from strategies)

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFromCashReserve_FiveStrategiesWithYield`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| withdraw                                                          | 261112          | 261112  | 261112  | 261112  | 1    |


#### Redeem with harvesting, five strategies, withdrawing from cash reserve + 2 other strategy

`FOUNDRY_PROFILE=test forge test --gas-report --match-test testWithdrawFromCashReservePlusTwoStrategies_FiveStrategiesWithYield`

| src/module/YieldAggregatorVault.sol:YieldAggregatorVault contract |                 |        |        |        |         |
|-------------------------------------------------------------------|-----------------|--------|--------|--------|---------|
| Function Name                                                     | min             | avg    | median | max    | # calls |
| withdraw                                                          | 435963          | 435963  | 435963  | 435963  | 1    |