# EulerEarn

> [!NOTE]
> This repo is a fork of [metamorpho v1.1](https://github.com/morpho-org/metamorpho-v1.1) and [public allocator](https://github.com/morpho-org/public-allocator), inspired by [silo vaults](https://github.com/silo-finance/silo-contracts-v2/tree/develop/silo-vaults), with the following changes:
>
> - uses a set of accepted ERC4626 vaults as strategies instead of Morpho Blue markets;
> - adds [EVK](https://github.com/euler-xyz/euler-vault-kit) and EulerEarn strategy compatibility;
> - adds [EVC](https://github.com/euler-xyz/ethereum-vault-connector) compatibility;
> - adds [permit2](https://github.com/Uniswap/permit2) compatibility;
> - implements [EVK](https://github.com/euler-xyz/euler-vault-kit/blob/master/docs/whitepaper.md#accounting)-style `VIRTUAL_AMOUNT` conversions that prevents exchange rate manipulation;
> - implements internal balance tracking that prevents EulerEarn share inflation;
> - implements zero shares protection on deposits;
> - adds reentrancy protection;
> - removes the `skim` function and related functionality;
> - removes ERC-2612 permit functionality;
> - removes Multicall functionality.

## Overview

EulerEarn is a protocol for noncustodial risk management on top of accepted [ERC-4626 vaults](https://ethereum.org/en/developers/docs/standards/tokens/erc-4626/), especially the [EVK vaults](https://github.com/euler-xyz/euler-vault-kit). EulerEarn allows only accepted ERC4626 vaults to be used as strategies. This is because empty non-EVK vaults may not be safely integrated with EulerEarn if they do not have sufficient first depositor and stealth donation protection that prevents manipulation of the potential strategy exchange rate. Other EulerEarn vaults can safely be used as strategies.
EulerEarn enables anyone to create a vault depositing liquidity into multiple ERC-4626 vaults.
EulerEarn offers a seamless experience similar to [Morpho Vaults](https://docs.morpho.org/overview/concepts/vault/).

Users of EulerEarn are liquidity providers who want to earn from borrowing interest without having to actively manage the risk of their position.
The active management of the deposited assets is the responsibility of a set of different roles (owner, curator and allocators).
These roles are primarily responsible for enabling and disabling accepted ERC-4626 strategy vaults and managing the allocation of users’ funds.

[`EulerEarn`](./src/EulerEarn.sol) vaults are [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) vaults. 
One EulerEarn vault is related to one underlying.
The [`EulerEarnFactory`](./src/EulerEarnFactory.sol) is deploying immutable onchain instances of EulerEarn vaults.

Users can supply or withdraw assets at any time, depending on the available liquidity in the enabled strategies.
A maximum of 30 strategies can be enabled on a given EulerEarn vault.
Each strategy vault has a supply cap that guarantees lenders a maximum absolute exposure to the specific strategy. By default, the supply cap of a strategy vault is set to 0.

There are 4 different roles for a EulerEarn vault: owner, curator, guardian & allocator.

The vault owner can set a performance fee, cutting up to 50% of the generated interest.
The `feeRecipient` can then withdraw the accumulated fee at any time.

The vault may be entitled to some rewards emitted on the strategies. As we observe that most of the reward systems these days perform off-chain computations, those systems must either forward the rewards to the EulerEarn depositors or redirect them to an address controlled by the vault owner for the sake of further redistribution.

All actions that may be against users' interests (e.g. enabling a strategy vault with a high exposure) is subject to a timelock.
To make vault setup easier, the initial timelock can be either 0 or anywhere between 24 hours and 2 weeks.
Any further timelock change must set the value between 24 hours and 2 weeks.
The `owner`, or the `guardian` if set, can revoke the action during the timelock.
After the timelock, the action can be executed by anyone.

### Roles

#### Owner

Only one address can have this role.

It can:

- Do what the curator can do.
- Do what the guardian can do.
- Transfer or renounce the ownership.
- Set the curator.
- Set allocators.
- Increase the timelock.
- [Timelocked] Decrease the timelock.
- [Timelocked if already set] Set the guardian.
- Set the performance fee (capped at 50%).
- Set the fee recipient.
- Set the name and symbol of the vault.

#### Curator

Only one address can have this role.

It can:

- Do what allocators can do.
- Decrease the supply cap of any strategy vault.
  - To softly remove a strategy vault after the curator has set the supply cap to 0, it is expected from the allocator role to reallocate the supplied liquidity to another enabled strategy and then to update the withdraw queue.
- [Timelocked] Increase the supply cap of any strategy vault.
- [Timelocked] Submit the forced removal of a strategy vault.
  - This action is typically designed to force the removal of a strategy vault that keeps reverting thus locking the vault.
  - After the timelock has elapsed, the allocator role is free to remove the strategy vault from the withdraw queue. The funds supplied to this strategy will be lost.
  - If the strategy vault ever functions again, the allocator role can withdraw the funds that were previously lost.
- Revoke the pending cap of any strategy vault.
- Revoke the pending removal of any strategy vault.

#### Allocator

Multiple addresses can have this role.

It can:

- Set the `supplyQueue` and `withdrawQueue`, i.e. decide on the order of the strategy vaults to supply/withdraw from.
  - Upon a deposit, the vault will supply up to the cap of each ERC-4626 strategy in the `supplyQueue` in the order set.
  - Upon a withdrawal, the vault will withdraw up to the liquidity of each ERC-4626 strategy in the `withdrawQueue` in the order set.
  - The `supplyQueue` only contains strategy vaults which cap has previously been non-zero.
  - The `withdrawQueue` contains all strategy vaults that have a non-zero cap or a non-zero vault allocation.
- Instantaneously reallocate funds by supplying on strategy vaults of the `withdrawQueue` and withdrawing from strategies that have the same loan asset as the vault's asset.

> **Warning**
> If `supplyQueue` is empty, depositing to the vault is disabled.

#### Guardian

Only one address can have this role.

It can:

- Revoke the pending timelock.
- Revoke the pending guardian (which means it can revoke any attempt to change the guardian).
- Revoke the pending cap of any strategy vault.
- Revoke the pending removal of any strategy vault.

### Idle Supply

In some cases, the vault's curator or allocators may want to keep some funds "idle", to guarantee lenders that some liquidity can be withdrawn from the vault (beyond the liquidity of each of the vault's strategies).

To achieve this, they can deposit in a non-borrowable strategy vault of their choice (i.e. [Escrow Vault](https://docs.euler.finance/concepts/risk/vault-types#escrow-vaults)), ensuring that these funds can't be borrowed.
They are thus guaranteed to be liquid; though they won't generate interest.
It is advised to use these canonical configurations for non-borrowable EVK vaults:

- `asset`: The vault's asset to be able to supply/withdraw funds.
- `oracle`: `address(0)` (not necessary since no funds will be borrowed from this vault)
- `unitOfAccount`: `address(0)` (not necessary since no funds will be borrowed from this vault)
- `hookTarget`: `address(0)` (in conjunction with `hookedOps` of `0`, enables all operations)
- `hookedOps`: `0` (in conjunction with `hookTarget` of `address(0)`, enables all operations)
- `governorAdmin`: `address(0)` (should be finalized, meaning no configuration change should be allowed)

Note that to allocate funds to this non-borrowable vault, it is first required to enable its cap on EulerEarn.
Enabling an infinite cap (`type(uint184).max`) will always allow users to deposit on the vault.

## Emergency

### An enabled strategy vault is now considered unsafe

If an enabled strategy vault is considered unsafe (e.g., risk too high), the curator/owner may want to disable this strategy in the following way:

- 1. Revoke the pending cap of the strategy vault with the `revokePendingCap` function (this can also be done by the guardian).
- 2. Set the cap of the strategy vault to 0 with the `submitCap` function.
     To ensure that submit cap does not revert because of a pending cap, it is recommended to batch the two previous transactions, for example using the [`batch`](https://docs.euler.finance/developers/evc#batching) function of the EVC.
- 3. Withdraw all the supply of this strategy vault with the `reallocate` function.
     If there is not enough liquidity on the strategy, remove the maximum available liquidity with the `reallocate` function, then put the strategy at the beginning of the withdraw queue (with the `updateWithdrawQueue` function).
- 4. Once all the supply has been removed from the strategy vault, the strategy can be removed from the withdraw queue with the `updateWithdrawQueue` function.

### An enabled strategy vault reverts

If an enabled strategy vault starts reverting, many of the vault functions would revert as well. To turn the vault back to an operating state, the strategy vault must be forced removed by the owner/curator, who should follow these steps:

- 1. Revoke the pending cap of the strategy vault with the `revokePendingCap` function (this can also be done by the guardian).
- 2. Set the cap of the strategy vault to 0 with the `submitCap` function.
     To ensure that submit cap does not revert because of a pending cap, it is recommended to batch the two previous transactions, for example using the [`batch`](https://docs.euler.finance/developers/evc#batching) function of the EVC.
- 3. Submit a removal of the strategy vault with the `submitMarketRemoval` function.
- 4. Wait for the timelock to elapse
- 5. Once the timelock has elapsed, the strategy vault can be removed from the withdraw queue with the `updateWithdrawQueue` function.

Warning : Funds supplied in forced removed strategy vault will be lost, this is why only strategies expected to always revert should be disabled this way (because funds supplied in such strategies can be considered lost anyway).

### Curator takeover

If the curator starts to submit positive caps for unsafe strategy vaults that are not in line with the vault risk strategy, the owner of the vault can:

- 1. Set a new curator with the `setCurator` function.
- 2. Revoke the pending caps submitted by the curator (this can also be done by the guardian or the new curator).
- 3. If the curator had the time to accept a cap (because `timelock` has elapsed before the guardian or the owner had time to act), the owner (or the new curator) must disable the unsafe strategy vault (see [above](#an-enabled-strategy-vault-is-now-considered-unsafe)).

### Allocator takeover

If one of the allocators starts setting the withdraw queue and/or supply queue that are not in line with the vault risk strategy, or incoherently reallocating the funds, the owner of the vault should:

- 1. Deprive the faulty allocator from his privileges with the `setIsAllocator` function.
- 2. Reallocate the funds in a way consistent with the vault risk strategy with the `reallocate` function (this can also be done by the curator or the other allocators).
- 3. Set a new withdraw queue that is in line with the vault risk strategy with the `updateWithdrawQueue` function (this can also be done by the curator or the other allocators).
- 4. Set a new supply queue that is in line with the vault risk strategy with the `setSupplyQueue` function (this can also be done by the curator or the other allocators).

## Audits

All audits are stored in the [audits](./audits/) folder.

## License

EulerEarn is licensed under `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).
