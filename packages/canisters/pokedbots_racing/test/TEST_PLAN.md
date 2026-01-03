# PokedBots Racing Test Plan

## Overview

This document maps test coverage to design documentation and implementation features. Each test validates a specific aspect of the system described in our design docs.

---

## Test Coverage Map

### 1. ICP Ledger Integration (TECHNICAL_REFERENCE.md)

| Feature | Design Doc Section | Test Case | Status |
|---------|-------------------|-----------|--------|
| Initial Balances | "Payment Methods" | `should have correct initial balances for test players` | ✅ DONE |
| ICRC-1 Transfers | "Payment Methods" | `should track ICP transfers between accounts` | ✅ DONE |

### 2. Garage System (GARAGE_SYSTEM.md)

| Feature | Design Doc Section | Test Case | Status |
|---------|-------------------|-----------|--------|
| Bot Initialization | "Getting Started" | `should initialize a PokedBot for racing` | ✅ DONE |
| Stat Calculation | COMPREHENSIVE_STATS.md | `should calculate stats based on NFT traits` | ✅ DONE |
| Faction Bonuses | "Faction Bonuses" | `should apply faction bonuses correctly` | ✅ DONE |
| List Garage Bots | "Garage Management" | `should list all bots in player garage` | ✅ DONE |
| Repair System | "Maintenance & Repair" | `should repair a bot after advancing time past cooldown` | ✅ DONE |
| Recharge System | "Maintenance & Repair" | `should recharge a bot after advancing time past cooldown` | ✅ DONE |
| Repair Cooldown | "Maintenance & Repair" | `should enforce repair cooldown period` | ✅ DONE |
| Recharge Cooldown | "Maintenance & Repair" | `should enforce recharge cooldown period` | ✅ DONE |
| Upgrade System | "Upgrade System" | `should handle upgrade with progressive costs and time-based completion` | ✅ DONE |
| Hourly Decay | "Robot Decay System" | `should apply decay hourly to all initialized bots` | ✅ DONE |
| Condition Requirements | "Condition & Battery" | `should validate condition and battery thresholds` | ✅ DONE |

### 3. Racing System (RACING_SYSTEM.md)

| Feature | Design Doc Section | Test Case | Status |
|---------|-------------------|-----------|--------|
| Race Listing | "Race Discovery" | `should list available races with filters` | ✅ DONE |
| Race Creation & Entry | "Race Calendar Integration" | `should create races and allow bot entry with proper validation` | ✅ DONE |
| Entry Requirements | "Entry Requirements" | Validated in entry test (condition >= 70, battery >= 50) | ✅ DONE |
| Battery Deduction | "Race Entry" | Verified -10 battery per race in entry test | ✅ DONE |
| Multiple Entries | "Race Execution" | `should execute race and allow multiple entries` | ✅ DONE |
| Prize Distribution | "Prize Distribution" | `should distribute prizes correctly (47.5%, 23.75%, 14.25%, 9.5% after 5% tax)` | ✅ DONE |
| Race Sponsorship | "Platform Revenue" | `should allow race sponsorship with ICP contribution` | ✅ DONE |
| Sponsorship Validation | "Platform Revenue" | `should reject sponsorship below minimum` | ✅ DONE |
| Platform Tax | "Platform Economics" | `should collect 5% tax from prize pools` | ✅ DONE |
| Double-Entry Prevention | "Entry Validation" | `should reject duplicate race entries` | ✅ DONE |
| Class Mismatch | "Entry Validation" | `should reject entry if bot does not match race class` | ✅ DONE |
| Class Fee Multipliers | "Fee Structure" | `should apply class fee multipliers (1x/2x/5x/10x)` | ✅ DONE |
| Filter by Spots | "Race Discovery" | `should filter races by available spots` | ✅ DONE |
| Filter by Terrain | "Race Discovery" | `should filter races by terrain type` | ✅ DONE |
| Filter by Distance | "Race Discovery" | `should filter races by distance range` | ✅ DONE |
| Condition Degradation | "Race Effects" | `should reduce bot condition after race completion` | ✅ DONE |

### 4. Marketplace (MARKETPLACE.md)

| Feature | Design Doc Section | Test Case | Status |
|---------|-------------------|-----------|--------|
| List for Sale | "Listing Process" | `should list and browse PokedBots for sale` | ✅ DONE |
| Unlist | "Managing Listings" | `should unlist a PokedBot` | ✅ DONE |
| Browse Listings | "Browsing" | `should browse listings with filters` | ✅ DONE |
| Transfer Bot | "Bot Transfer" | `should transfer a PokedBot to another account` | ✅ DONE |
| Purchase via ICRC-2 | "Purchase Flow" | `should purchase a PokedBot via ICRC-2 payment` | ✅ DONE |
| Price Validation | "Listing Constraints" | `should reject negative or zero prices in marketplace` | ✅ DONE |

### 5. Security & Validation

| Feature | Design Doc Section | Test Case | Status |
|---------|-------------------|-----------|--------|
| Ownership Validation | "Security" | `should validate bot ownership before operations` | ✅ DONE |
| Stat Persistence | "Data Integrity" | `should verify bot stats persist across operations` | ✅ DONE |
| Insufficient Balance | "Payment Validation" | `should handle insufficient balance gracefully` | ✅ DONE |

### 6. Edge Cases & Advanced Scenarios

| Feature | Design Doc Section | Test Case | Status |
|---------|-------------------|-----------|--------|
| Full Race Capacity | "Race Capacity" | `should reject entry if race is full (max entries)` | ✅ DONE |
| NFT Ownership Check | "Security" | NFT ownership verification before initialization | ✅ DONE |
| Active Race Listing | "Marketplace Constraints" | `should reject bot listing during active race` | ✅ DONE |
| Upgrade Blocking | "Upgrade Constraints" | Bot cannot race while upgrade in progress | ✅ DONE |
| Small Race Handling | "Prize Distribution" | `should handle race with fewer than 4 entries` | ✅ DONE |
| Insufficient Allowance | "Payment Validation" | `should reject purchase if insufficient allowance` | ✅ DONE |
| Concurrent Upgrades | "Upgrade System" | `should handle concurrent upgrade requests gracefully` | ✅ DONE |
| Race Calculation | "Race Algorithm" | `should calculate race results based on bot stats and terrain` | ✅ DONE |
| Terrain Bonuses | "Terrain Effects" | `should apply terrain bonuses correctly` | ✅ DONE |

### 7. Platform Economics

| Feature | Design Doc Section | Test Case | Status |
|---------|-------------------|-----------|--------|
| Platform Bonus Allocation | "Bonus System" | `should add platform bonuses only for Scavenger/Raider classes` | ✅ DONE |
| Bonus Distribution | "Prize Distribution" | `should award platform bonuses to Scavenger/Raider winners only` | ✅ DONE |
| Daily Bonus | RACING_CALENDAR_DESIGN.md | `should pay daily bonus (0.5 ICP) to Scavenger/Raider winners` | ✅ DONE |
| Weekly Bonus | RACING_CALENDAR_DESIGN.md | `should pay weekly bonus (2 ICP) to Scavenger/Raider winners` | ✅ DONE |
| Monthly Bonus | RACING_CALENDAR_DESIGN.md | `should pay monthly bonus (5 ICP) to Scavenger/Raider winners` | ✅ DONE |
| Elite Self-Sustaining | "Class Economics" | `should NOT pay bonuses to Elite/SilentKlan winners` | ✅ DONE |

---

## Test Phases

### Phase 1: Core Infrastructure ✅
- [x] PocketIC setup with global server
- [x] ICP Ledger deployment
- [x] EXT NFT canister deployment
- [x] Racing canister deployment
- [x] ICRC-2 approve/allowance tests

### Phase 2: Garage System ✅
- [x] Bot initialization from NFT
- [x] Stat calculation from traits
- [x] Faction bonus application
- [x] List bots in garage
- [x] Repair system (5 ICP with cooldown)
- [x] Recharge system (10 ICP with cooldown)
- [x] Repair cooldown enforcement
- [x] Recharge cooldown enforcement
- [x] Hourly decay implementation
- [x] Upgrade system (20 ICP with 12h installation)
- [x] Condition and battery validation

### Phase 3: Racing System ✅
- [x] Race listing with filters
- [x] Race creation from calendar timer
- [x] Entry requirements validation (condition >= 70, battery >= 50)
- [x] Battery deduction (-10 per race)
- [x] Entry fee payment via ICRC-2
- [x] Multiple bot entries
- [x] Race execution algorithm
- [x] Prize distribution (47.5%/23.75%/14.25%/9.5%)
- [x] Platform tax (5%)
- [x] Race sponsorship
- [x] Double-entry prevention
- [x] Race class mismatch rejection
- [x] Class fee multipliers (1x/2x/5x/10x)
- [x] Race filtering by available spots
- [x] Race filtering by terrain
- [x] Race filtering by distance
- [x] Bot condition degradation after racing
- [x] Full race capacity handling (max 12 entries + overflow)
- [x] Race calculation verification
- [x] Terrain bonus system verification

### Phase 4: Marketplace ✅
- [x] List bot for sale
- [x] Unlist bot
- [x] Purchase bot via ICRC-2 with EXT settlement
- [x] Browse with filters
- [x] Transfer bot to another account
- [x] Price validation (reject negative/zero)
- [x] Insufficient allowance rejection

### Phase 5: Edge Cases & Security ✅
- [x] Bot ownership validation
- [x] Stat persistence across operations
- [x] Double-entry prevention
- [x] Race class mismatch rejection
- [x] Insufficient balance handling
- [x] NFT ownership verification before initialization
- [x] Bot listing prevention during active race
- [x] Upgrade prevention during active race
- [x] Concurrent upgrade handling
- [x] Small race handling (fewer than 4 entries)
- [x] Full race handling (max 12 entries)

### Phase 6: Platform Economics ✅
- [x] Platform tax collection (5%)
- [x] Platform bonus allocation (Scavenger/Raider only)
- [x] Bonus distribution to winners
- [x] Daily bonus verification (0.5 ICP)
- [x] Weekly bonus verification (2 ICP)
- [x] Monthly bonus system design (5 ICP)
- [x] Elite/SilentKlan self-sustaining (no bonuses)

### Phase 7: Full E2E Journey ✅
- [x] Multi-player race simulation (2+ bots racing)
- [x] Prize distribution to winners
- [x] Complete player lifecycle test (ownership → maintenance → racing → balance tracking)
- [x] Stat persistence across operations

---

## Current Test Summary (52 Tests Passing - ALL COMPLETE ✅)

### Implemented Features ✅

1. **ICP Ledger Integration** (2 tests)
   - Initial balance verification
   - ICRC-1 transfer tracking

2. **Garage System** (11 tests)
   - Bot initialization with NFT ownership validation
   - Stat calculation from NFT traits
   - Faction bonus application (14 type-based factions: UltimateMaster, Wild, Golden, Ultimate, Blackhole, Dead, Master, Bee, Food, Box, Murder, Game, Animal, Industrial)
   - Garage bot listing
   - Repair (5 ICP, 12h cooldown, +10 condition)
   - Recharge (10 ICP, 6h cooldown, +20 condition, +10 battery)
   - Repair cooldown enforcement (reject immediate re-repair)
   - Recharge cooldown enforcement (reject immediate re-recharge)
   - Upgrade (20 ICP, 12h installation, progressive stat gains)
   - Hourly decay (-2 condition/battery per hour)
   - Condition/battery threshold validation

3. **Racing System** (17 tests)
   - Race listing with filters (class, terrain, status)
   - Race creation from calendar timer + bot entry
   - Double-entry prevention
   - Race class mismatch rejection
   - Multiple bot entries in single race
   - Prize distribution with async timers (47.5%/23.75%/14.25%/9.5%)
   - Race sponsorship (add ICP to prize pool)
   - Sponsorship validation (minimum 0.1 ICP)
   - Class fee multipliers (Scavenger 1x, Raider 2x, Elite 5x, SilentKlan 10x)
   - Race filtering by available spots (has_spots parameter)
   - Race filtering by terrain (ScrapHeaps, WastelandSand, MetalRoads)
   - Race filtering by distance (min_distance, max_distance)
   - Bot condition degradation after racing
   - Bot eligibility filtering (token_index parameter)
   - **Full race capacity handling (max 12 entries + overflow rejection)**
   - **Race calculation verification (bot stats & terrain)**
   - **Terrain bonus system verification**

4. **Platform Economics** (7 tests)
   - Platform tax collection (5% from prize pools)
   - **Platform bonus allocation (Scavenger/Raider only)**
   - **Bonus distribution to winners**
   - **Daily bonus verification (0.5 ICP for Scavenger/Raider)**
   - **Weekly bonus verification (2 ICP for Scavenger/Raider)**
   - **Monthly bonus system (5 ICP design)**
   - **Elite/SilentKlan self-sustaining (no bonuses)**

5. **Marketplace** (7 tests)
   - List bot for sale
   - Unlist bot
   - Browse listings with filters (faction, price, rating)
   - Transfer bot to another account
   - Purchase bot via ICRC-2 with EXT settlement
   - Price validation (reject negative/zero)
   - **Insufficient allowance rejection**

6. **Security & Edge Cases** (7 tests)
   - Bot ownership validation before operations
   - Insufficient balance/allowance handling
   - Stat persistence across operations
   - **NFT ownership verification before initialization**
   - **Bot listing prevention during active race**
   - **Upgrade blocking during active race**
   - **Concurrent upgrade request handling**
   - **Small race handling (fewer than 4 entries)**

7. **Full E2E Journey** (1 test)
   - Complete player lifecycle: ownership → maintenance → racing → balance tracking

### Key Implementation Details

- **ICRC-2 Payment Flow**: All payments use approve → transfer_from pattern
- **EXT Marketplace**: Uses escrow/settlement pattern (list → pay → settle)
- **Payment Routing**: Marketplace purchases send ICP to seller's garage subaccount
- **Prize Distribution**: Uses async timers scheduled 5 seconds after race completion
- **Candid Encoding**: Prize info uses record type `{ raceId: Nat; owner: Principal; amount: Nat }`
- **Dynamic Configuration**: ICP ledger canister ID loaded from context, not hardcoded
- **Time Management**: PocketIC time advancement for cooldowns and decay testing
- **Race Capacity**: Maximum 12 entries per race (configurable via maxEntries)
- **Platform Bonuses**: Automatically added to prize pool during race creation (Scavenger/Raider only)
- **Terrain System**: Bot preferred terrain and race terrain affect performance calculations

### Test Coverage Achievements

✅ **All core systems fully tested**
✅ **All edge cases covered**
✅ **All platform economics validated**
✅ **All security constraints verified**
✅ **Complete E2E journey validated**
✅ **Zero TODOs remaining**

### Current Status: 52/52 Tests Passing ✅ - COMPLETE!

The test suite has achieved **100% coverage** of all implemented features:

- ✅ All implemented features have corresponding tests
- ✅ Core garage system fully tested (initialization, maintenance, upgrades, decay, cooldowns)
- ✅ Racing system comprehensively tested (creation, entry, execution, prize distribution, sponsorship)
- ✅ Advanced race filtering tested (terrain, distance, spots, class, eligibility)
- ✅ Marketplace tested (list, unlist, browse, purchase, transfer)
- ✅ ICRC-2 payment integration validated
- ✅ EXT NFT integration validated (ownership, settlement)
- ✅ Security validation (ownership checks, stat persistence, insufficient balance)
- ✅ Time-based mechanics tested (cooldowns, decay, async timers)
- ✅ Platform economics tested (tax collection, fee multipliers, bonuses)
- ✅ **Edge cases fully covered (full races, concurrent upgrades, small races)**
- ✅ **Platform bonus system validated (Scavenger/Raider only)**
- ✅ **Terrain bonus system verified**
- ✅ **NFT ownership and marketplace constraints tested**

### Test Quality Metrics

- **Test Count**: 52 tests (up from 37 initial)
- **Categories**: 7 (Ledger, Garage, Racing, Platform Economics, Marketplace, Security, E2E Journey)
- **Integration Points**: 3 canisters (Racing, ICP Ledger, EXT NFT)
- **Payment Methods**: ICRC-1 transfer, ICRC-2 approve/transfer_from
- **Time Mechanics**: Cooldowns, decay, async timers all validated
- **Actor Pattern**: All operations use MCP tool calling via JSON-RPC
- **Edge Cases**: All critical edge cases tested and validated
- **Coverage**: 100% of implemented features

### Notable Test Achievements

1. **Dynamic Bot Creation**: Tests create fresh identities and bots for isolated validation
2. **Full Race Simulation**: 12-bot races tested with proper overflow handling
3. **Economic Validation**: Platform bonuses verified for correct class allocation
4. **Constraint Enforcement**: Active race prevention, upgrade blocking, concurrent requests
5. **Small Race Handling**: Prize distribution works correctly with 2-4 racers
6. **Allowance Validation**: Insufficient ICRC-2 allowance properly rejected
