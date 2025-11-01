<h1 align="center"> TMBVault (Trust me bro Vault) </h1>

## Deployments

### Contract Deployments

#### Arbitrum
- StreamVault: `0x...`
- StableWrapper: `0x...`

## What is TMBVault V2?

TMBVault V2 is a yield-bearing vault system built on standard ERC20 tokens. The protocol consists of two core contracts:

- **StableWrapper** - A 1:1 wrapper contract for underlying ERC20 tokens (e.g., USDC, WBTC)
- **StreamVault** - A vault contract that accepts wrapped tokens and issues share tokens representing proportional vault ownership

Users stake wrapped tokens to earn their proportional share of yield generated from off-chain strategies. The vault uses a non-rebasing share model where share quantity remains constant while value changes based on accumulated yield.

## Implementation

The `StableWrapper` contract wraps underlying tokens 1-to-1. Upon wrapping, the deposited tokens are made available to the vault keeper for yield farming while users receive wrapped tokens. To unwrap, there is a 1-day delay to allow time for the keeper to return underlying tokens from strategies.

**NOTE:** Currently, `allowIndependence` is set to false, meaning all deposits are auto-staked. Users cannot hold wrapped tokens independently - they are automatically staked into the vault for yield.

Upon staking wrapped tokens in the `StreamVault` contract, users receive non-rebasing share tokens. The share quantity remains constant while the underlying value changes based on yield distribution.

## Yield Distribution

Yield is distributed once daily when the vault keeper calls `rollToNextRound()`. At this moment:
1. Yield (positive or negative) is distributed proportionally to all share holders
2. The vault calls `StableWrapper.permissionedMint()` or `permissionedBurn()` to adjust wrapped token supply
3. This maintains accurate accounting between wrapped tokens and underlying assets

**NOTE:** Yield can be positive or negative at any given roll.

## Timing Mechanics

### Vault Operations (Instant)
- Staking is instant, but doesn't earn yield for the entry round
- Unstaking is instant, but doesn't earn yield for the exit round
- If you stake and unstake in the same round, use `instantUnstake()` for immediate withdrawal

### Unwrapping Operations (Delayed)
Unwrapping back to underlying tokens is a two-step process:
1. Initiate the withdrawal
2. Complete after one epoch (24 hours) has passed

**Important:** If you initiate multiple withdrawals at different times, you must wait for the latest epoch to complete before withdrawing any funds. All pending withdrawals are subject to the newest epoch's timing.

## Risks

Upon wrapping, funds are held in the `StableWrapper` contract and are accessible to the vault owner for yield farming. The vault owner manages funds through a multisig wallet, which is used to farm different yield opportunities. The wallet address is public and positions are monitored through a dashboard.

## Contracts and Functions

### StableWrapper
A 1-to-1 wrapper contract with delayed withdrawals. While `allowIndependence` is false, only the `StreamVault` (set as keeper) can deposit for users, ensuring auto-staking.

**Key Functions:**

- `depositToVault()` - Keeper only. Transfers underlying tokens and mints wrapped tokens to the vault
- `initiateWithdrawalFromVault()` - Keeper only. Burns wrapped tokens and creates withdrawal receipt
- `completeWithdrawal()` - Transfers underlying tokens after 1 epoch delay
- `permissionedMint()` - Vault only. Mints wrapped tokens for positive yield
- `permissionedBurn()` - Vault only. Burns wrapped tokens for negative yield
- `transferAsset()` - Owner only. Withdraws funds for yield farming
- `processWithdrawals()` - Owner only. Settles deposits/withdrawals and advances epoch

When `allowIndependence` is true, users can also call:
- `deposit()` - Wrap tokens without auto-staking
- `initiateWithdrawal()` - Queue withdrawal of wrapped tokens

### StreamVault
Stakes wrapped tokens to earn yield. Issues non-rebasing share tokens representing proportional vault ownership. The vault operates in daily rounds where yield is distributed.

**Important:** Users don't earn yield in the round they deposit or withdraw. Very small stakes may result in 0 shares due to rounding.

**Key Functions:**

- `depositAndStake()` - Deposits underlying tokens and auto-stakes. Creates stake receipt
- `unstakeAndWithdraw()` - Burns shares, calculates wrapped token amount, queues withdrawal
- `instantUnstakeAndWithdraw()` - Instantly unstakes and queues withdrawal (same round only)
- `redeem()` - Converts contract-held shares into transferable wallet tokens
- `maxRedeem()` - Redeems maximum available shares
- `rollToNextRound()` - Keeper only. Distributes yield and mints shares for pending stakes

When `allowIndependence` is true, users can also call:
- `stake()` - Stake wrapped tokens directly
- `unstake()` - Burn shares and receive wrapped tokens (after at least 1 round)
- `instantUnstake()` - Return wrapped tokens staked in same round

**Helper Functions:**
- `accountVaultBalance()` - Returns wrapped token value of user's shares
- `shares()` - Returns total shares owned (held + unredeemed)
- `shareBalances()` - Returns shares held by user and by vault separately

## Architecture

- **Single Chain**: No cross-chain functionality
- **ERC20 Only**: No native ETH support - uses standard ERC20 tokens
- **Non-Rebasing**: Share quantity stays constant, value changes
- **Two-Step Withdrawals**: Instant vault operations, delayed unwrapping
- **Daily Yield**: Round-based yield distribution system

---

## Changes from Original Implementation

This codebase has been modified from the original Stream V2 implementation with the following key changes:

### Removed Features
- **LayerZero V2 Integration**: All OFT (Omnichain Fungible Token) functionality removed
  - No cross-chain bridging capabilities
  - Removed `bridgeWithRedeem()` function
  - Removed all LayerZero-specific imports and dependencies
  - Deleted 19+ LayerZero configuration and deployment scripts
- **Native ETH Support**: All ETH handling removed
  - No `depositETH()`, `depositETHAndStake()`, or `completeWithdrawalETH()` functions
  - No `rescueETH()` or `transferAssetETH()` functions
  - Removed WETH wrapper integration
  - No `receive()` payable fallback functions
