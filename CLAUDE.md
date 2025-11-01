# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Stream V2 is a yield-bearing vault system that enables users to wrap underlying ERC20 tokens and stake them to earn proportional yield. The protocol consists of two main contracts:

1. **StableWrapper** - Wraps underlying ERC20 tokens (e.g., USDC, WBTC) 1:1 into Stream tokens
2. **StreamVault** - Accepts wrapped tokens and issues share tokens representing vault positions

Both contracts are standard ERC20 tokens built with OpenZeppelin libraries. The system operates entirely on a single chain with no cross-chain or native ETH support.

## Core Architecture

### Two-Contract System

The system is designed around a separation of concerns:

- **StableWrapper**: Manages the underlying asset deposits/withdrawals with delayed withdrawal periods (1 epoch = 24 hours). When `allowIndependence` is false, all deposits are auto-staked into StreamVault. Inherits from `ERC20`, `Ownable`, and `ReentrancyGuard`.
- **StreamVault**: Issues non-rebasing share tokens representing proportional ownership of the vault. Yield is distributed during discrete "round rolls" performed by the keeper. Inherits from `ERC20`, `Ownable`, and `ReentrancyGuard`.

### Key Timing Mechanics

- **Vault operations (instant)**: Staking/unstaking is instant, but no yield is earned in entry/exit rounds
- **Unwrapping (delayed)**: Two-step process requiring 1 epoch (24 hours) between initiation and completion
- **Round rolls**: Yield distribution events managed by the keeper via `rollToNextRound()`

### Yield Distribution Flow

1. Keeper calls `StreamVault.rollToNextRound(yieldAmount, isPositive)` with yield amount (positive or negative)
2. Shares are minted for pending stakes from the previous round
3. StreamVault calls `StableWrapper.permissionedMint()` or `permissionedBurn()` to adjust wrapped token supply based on yield
4. This maintains accounting where share value changes but share quantity remains constant (non-rebasing)

### Important State Variables

- **allowIndependence** (StableWrapper): When false, enables auto-staking mode where users cannot hold wrapped tokens independently
- **currentEpoch** (StableWrapper): Tracks withdrawal delay periods
- **round** (StreamVault): Tracks yield distribution cycles
- **totalPending** (StreamVault): Tracks wrapped tokens waiting to be converted to shares on next round roll
- **stakeReceipts** (StreamVault): Maps users to their pending stakes that haven't been converted to shares yet

## Development Commands

### Build and Test

```bash
# Build the project
forge build

# Run all tests
forge test

# Run tests with verbosity (useful for debugging)
forge test -vvv

# Run specific test file
forge test --match-path test/StreamVault/Stake.t.sol

# Run specific test function
forge test --match-test testStakeSuccess

# Run tests with gas reporting
forge test --gas-report

# Run tests with summary
forge test --summary
```

### Deployment and Scripts

```bash
# Run a script (dry run)
forge script scripts/Deploy.s.sol

# Deploy to a network (requires env vars)
forge script scripts/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast

# Verify contract on Etherscan
forge verify-contract <address> <contract> --chain-id <chain-id> --etherscan-api-key $ETHERSCAN_API_KEY
```

### Other Useful Commands

```bash
# Format code
forge fmt

# Check formatting without modifying
forge fmt --check

# Generate gas snapshot
forge snapshot

# Clean build artifacts
forge clean
```

## Contract Interaction Patterns

### User Flow: Deposit and Stake

When `allowIndependence` is false (auto-stake mode):
1. User calls `StreamVault.depositAndStake(amount, creditor)` with ERC20 tokens approved
2. Underlying asset transferred from user to StableWrapper
3. Wrapped tokens minted directly to StreamVault (keeper)
4. Stake receipt created for user
5. On next `rollToNextRound()`, shares are minted based on `pricePerShare`
6. User must call `redeem()` to receive transferable share tokens

### User Flow: Unstake and Withdraw

1. User calls `StreamVault.unstakeAndWithdraw(shares, minAmountOut)`
2. Shares burned, wrapped tokens calculated based on current share price
3. Wrapped tokens burned and withdrawal queued in StableWrapper
4. After 1 epoch passes, user calls `StableWrapper.completeWithdrawal(to)`
5. Underlying asset transferred back to user

### Keeper Operations

**Daily Round Roll:**
1. Calculate yield generated from off-chain strategies
2. Call `StreamVault.rollToNextRound(yieldAmount, isPositive)`
3. Call `StableWrapper.processWithdrawals()` to settle epoch

**Managing Withdrawals:**
- `StableWrapper.processWithdrawals()` must be called each epoch
- If net withdrawals > deposits, keeper must provide tokens from strategies
- If net deposits > withdrawals, excess tokens sent to keeper for strategy deployment

## Testing Structure

Tests are organized by contract:
- `test/StableWrapper/` - Tests for StableWrapper contract functions
- `test/StreamVault/` - Tests for StreamVault contract functions
- `test/ShareMath.t.sol` - Tests for share calculation library
- `test/StreamVault/ERC4626Wrapper.t.sol` - Tests for ERC4626 compatibility wrapper

Each test folder typically contains:
- `Base.t.sol` - Base test contract with common setup and helper functions
- Individual test files for each major function (Constructor, Deposit, Withdraw, Stake, Unstake, etc.)

## Important Constraints

- **Minimum stake amounts**: Share calculations round down, so very small stakes may result in 0 shares
- **Round participation**: Users don't earn yield in the round they deposit or the round they withdraw
- **Withdrawal resets**: Initiating a new withdrawal while having pending withdrawals resets the epoch timer for ALL pending withdrawals
- **Cap limits**: Vault has a configurable cap on total deposits
- **Early round limitations**: Cannot preview redemptions or calculate share prices until vault has completed at least one round (round >= 2)

## Architecture Decisions

### No Cross-Chain Support
The codebase has been cleaned of all LayerZero OFT (Omnichain Fungible Token) functionality. The system operates entirely on a single chain using standard ERC20 tokens.

### No Native ETH Support
The system only supports ERC20 tokens. All native ETH functionality has been removed. Users must use wrapped tokens (e.g., WETH, USDC, WBTC) directly.

### Non-Rebasing Shares
The StreamVault uses a non-rebasing share model where the number of shares remains constant, but their value changes based on yield. This is different from rebasing tokens where the balance changes.

## Solidity Version and Dependencies

- Solidity: `0.8.22`
- OpenZeppelin Contracts: Used for standard ERC20, Ownable, SafeERC20, ReentrancyGuard
- Foundry: Build and test framework
- Uses `via-ir = true` compilation for optimizer

## Configuration

Key configuration in `foundry.toml`:
- `via-ir = true` - Required for compilation
- `solc-version = "0.8.22"`
- RPC endpoints configured via environment variables

Remappings in `remappings.txt`:
- `@openzeppelin/contracts/` maps to `lib/openzeppelin-contracts/contracts/`

## Known Issues & Quirks

### ShareMath Requirements
The `ShareMath` library requires `assetPerShare > 1` (the PLACEHOLDER_UINT). This means:
- Round 1 has no valid price per share yet
- Functions like `sharesToAsset()` and `assetToShares()` will revert if called before round 2
- The ERC4626Wrapper handles this by returning 0 for early rounds

### Public State Variables
Both `vaultParams` and `vaultState` are public state variables, which means Solidity auto-generates getter functions that return tuples, not structs. When accessing these through interfaces, you need to destructure the return values:

```solidity
(uint8 decimals, uint56 minimumSupply, uint104 cap) = vault.vaultParams();
(uint16 round, uint128 totalPending) = vault.vaultState();
```
