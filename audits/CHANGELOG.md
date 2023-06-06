# Change Log

All notable changes related with smart contracts will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

### Added

- `USER limits` are added to id_type.sol
- `fallbackThreshold` parameter is added to reserved_key_space.sol
- `yieldReceiver` parameter is added to reserved_key_space.sol
- yield separation logic is added

### Changed

- Making all "PORTAL" words all uppercase in require messages on Portal
- Curly brackets are added to lacking if statements
- `\_decreaseWalletBalance` function call bring to top to save gas on `proposeStake` function
- Improve `fallbackOperator` logic by making fallback treshold settable
- Package update logic (Limited UUPS) changed to use package type as proposal type instead of `CONTRACT_UPGRADE (TYPE 2)`

### Fixed

- Typos and small mistakes on tasks
- Typos and small mistakes on comments
- `onlyGovernance` was checking Senate instead of Governence
- Anyone were able to transfer roles to themselves, `onlyRole` modifiers added to transfer functions
- Operator id check is added for each pubkey to prevent staking other operator's pubkeys
- Prevent any type to change controller, restricted with USER types only with range (3,9999)

### Removed

- Unnecessary `sinceLastIdChange` greater zero check is removed
- `FALLBACK_THRESHOLD` constant is removed
- `CONTRACT_UPGRADE` and `__GAP__` removed from ID_TYPE

## [0.6.0] - 2023-03-23

- [Diligence Audit Response](audits/external/Diligence/2023-03-Diligence-Audit-Response) can be counted as the change log until this document.
