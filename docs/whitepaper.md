---
title: Euler Yield Aggregator
description: An open source protocol for permissionless risk curation on top of ERC4626 vaults
---

# Yield Aggregator Whitepaper

Haythem Sellami & Mick de Graaf.

## Introduction

The YieldAggregatorVault is an open source protocol for permissionless risk curation on top of [ERC4626 vaults](https://eips.ethereum.org/EIPS/eip-4626)(strategies). Although it is initially designed to be integrated with [Euler V2 vaults](https://github.com/euler-xyz/euler-vault-kit), technically it supports any other vault as long as it is ERC4626 compliant.
The yield aggregator in itself is an ERC4626 vault, and any risk curator can deploy one through the factory. Each vault has one loan asset and can allocate deposits to multiple strategies. The aggregator vaults are noncustodial and immutable instances, and offer users an easy way to provide liquidity and passively earn yield. 

## Motivation

Euler V2 is a lending and borrowing protocol built on top of the EVC primitive, prioritising modularity, efficiency and flexibility. On Euler V2, lenders must consider multiple factors, including the loan-to-value ratio, the used oracles, caps, the type of vault(borrowable, escrow)...etc. For that reason, interacting with the lending vaults directly is more suited to sophisticated and knowledgeable lenders than passive ones, that’s why we introduce Euler Yield Aggregator vault, to provide a passive yield for users, and to manage the risk on their behalf.

## Permissionless yield aggregation and risk management

Anyone can use the factory to create a YieldAggregator vault, including DAOs, protocols, risk experts, funds…etc can all leverage the permissionless infrastructure to provide passive users with a simple yield earning experience.

## Core concepts

### Strategy

An ERC4626 compatible contract in which the aggregation layer vault will deposit assets. A single aggregator vault can have many strategies.

A strategy can be any ERC4626 compliant vault:
- Euler V2 lending protocol vaults.
- Yearn V3 vaults.
- MetaMorpho vaults.
- etc...

The strategy with address zero is used as a cash reserve. 

### Cash reserve

An amount of the total deposited assets not allocated to any strategy, and used as the first source of liquidity during withdrawal. The amount to set as cash reserve is decided based on the allocation points set for the cash reserve strategy.

### Allocation Points

Each strategy gets assigned allocation points, including the cash reserve strategy.
During strategy rebalance, the amount of asset to allocate is calculated based on its allocation points.

### Rebalance

The user's deposited assets are allocated across the yield aggregator vault’s strategies through rebalance. When executing a rebalance, the aggregator vault will deposit more assets to the strategy or withdraw from it based on its current and target allocation amounts. 

### Harvest

Harvesting strategies are required to count for accrued yield, and this can be executed in a permissionless way by any user.
During harvesting, the aggregator vault goes through all the strategies to calculate the net yield amount, and that happens according to the order of the strategies in the withdrawal queue.
In the case of positive net yield, a performance fee is accrued, if applicable. In the case of negative net yield, a loss deduction mechanism is applied.

### Performance Fee

A performance fee can be accrued for the aggregated net yield amount, by converting the fee assets to the aggregator vault shares and minting it to the fee recipient.

### Loss Deduction

A loss deduction mechanism is implemented in the case of harvesting a negative net yield amount. The net negative yield amount will be first deducted from the interest left to accrue, if not enough to cover that, the rest will be socialised across depositors.

### Yield Gulping & Smearing 

Harvested positive yield is not instantly added to the aggregator total deposits, instead, it gets gulped as an interest to be distributed(smeared) along the smearing period(2 weeks), and that prevents sudden jumps in the yield aggregator vault’s exchange rate.

### Withdrawal Queue

A queue of strategies addresses, mainly used during yield harvesting and executing withdrawal requests from the yield aggregator.
Strategies are pushed into the withdrawal queue and removed from it when the add or removing strategy operation is called. Only an address that holds the withdrawal queue manager role can re-order it.

### Roles

Governance over the aggregation layer vault can be granularly managed. Both fully ungoverned or completely governed are both easily achieved through access control management.
An Euler aggregation layer can have different managers each serving a specific role. Setting up the vaults can be set in a manner which makes sure no entity is able to take user funds from the vault.
Each role has their own specific `Admin role`, the holder of the Admin role can assign the role. The `Default Admin` role has ownership of all other admin roles.

- Default Admin:
    - Manages admin roles, including itself.
- Strategy Operator:
    - Add strategy.
    - Remove strategy.
- Aggregation Vault Manager:
    - Set performance fee and recipient.
    - Opt in & out from the underlying strategy rewards stream, including enable/disable and claiming rewards.
    - Set hooks config.
- Withdrawal Queue Manager:
    - Re-order withdrawal queue array.
- Guardian:
    - Set strategy cap.
    - Adjust strategy allocation points.
    - Set strategy as `Emergency` or revert it back.

### Strategy Emergency Status

In case of a faulty strategy that has already an allocated amount, the Guardian can set that strategy status as `Emergency`, therefore the aggregator vault will be functioning as expected, without taking into account that specific strategy.

The Guardian can toggle back the strategy status back to active anytime.

### Native ERC20 Votes

The Yield Aggregator vault natively integrates with ERC20Votes contract to support Compound-like voting and delegation, therefore the users and shareholders of a certain Yield Aggregator vault, can use their shares as voting power in the vault governance.

## Immutability, Management and Fees

The YieldAggregator is a robust and yet flexible protocol, by providing an immutable set of contracts and a set of parameters to configure. 

The core contracts are fully immutable, where the set of parameters to configure are governed by the different roles owner, as explained above. Additionally, risk curators can easily provide a fully immutable experience by revoking access to the roles mentioned above.

Euler DAO can’t take fees on the Yield Aggregator Vaults but Vaults owners can set a performance fee, as explained above. The maximum performance fee is 50%.