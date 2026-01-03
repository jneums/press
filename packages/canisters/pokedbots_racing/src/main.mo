import Result "mo:base/Result";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Float "mo:base/Float";
import Error "mo:base/Error";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Order "mo:base/Order";

import HttpTypes "mo:http-types";
import Map "mo:map/Map";
import IC "mo:ic";
import ClassPlus "mo:class-plus";

import AuthCleanup "mo:mcp-motoko-sdk/auth/Cleanup";
import AuthState "mo:mcp-motoko-sdk/auth/State";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";

import Mcp "mo:mcp-motoko-sdk/mcp/Mcp";
import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import HttpHandler "mo:mcp-motoko-sdk/mcp/HttpHandler";
import Cleanup "mo:mcp-motoko-sdk/mcp/Cleanup";
import State "mo:mcp-motoko-sdk/mcp/State";
import Payments "mo:mcp-motoko-sdk/mcp/Payments";
import HttpAssets "mo:mcp-motoko-sdk/mcp/HttpAssets";
import Beacon "mo:mcp-motoko-sdk/mcp/Beacon";
import ApiKey "mo:mcp-motoko-sdk/auth/ApiKey";

import SrvTypes "mo:mcp-motoko-sdk/server/Types";

// Import tool modules
import ToolContext "tools/ToolContext";
import GarageListMyPokedBots "tools/garage_list_my_pokedbots";
import MarketplaceBrowsePokedBots "tools/marketplace_browse_pokedbots";
import MarketplacePurchasePokedBot "tools/marketplace_purchase_pokedbot";
import GarageInitializePokedBot "tools/garage_initialize_pokedbot";
import GarageGetRobotDetails "tools/garage_get_robot_details";
import GarageRechargeRobot "tools/garage_recharge_robot";
import GarageRepairRobot "tools/garage_repair_robot";
import GarageUpgradeRobot "tools/garage_upgrade_robot";
import GarageCancelUpgrade "tools/garage_cancel_upgrade";
import GarageTransferParts "tools/garage_transfer_parts";
import GarageStartScavenging "tools/garage_start_scavenging";
import GarageCompleteScavenging "tools/garage_complete_scavenging";
import GarageConvertParts "tools/garage_convert_parts";
import RacingListRaces "tools/racing_list_races";
import RacingEnterRace "tools/racing_enter_race";
import RacingSponsorRace "tools/racing_sponsor_race";
import RacingGetRaceDetails "tools/racing_get_race_details";
import RacingGetBotRaces "tools/racing_get_bot_races";
import HelpGetCompendium "tools/help_get_compendium";
import BettingPlaceBet "tools/betting_place_bet";
import BettingListPools "tools/betting_list_pools";
import BettingGetPoolInfo "tools/betting_get_pool_info";
import BettingGetMyBets "tools/betting_get_my_bets";

// Import Stats module for NFT metadata
import Stats "Stats";

// Import Racing modules (new architecture)
import RacingSimulator "RacingSimulator";
import PokedBotsGarage "PokedBotsGarage";
// import Racing "Racing"; // REMOVED: No longer needed after migration to new architecture
import RaceCalendar "RaceCalendar";
import Leaderboard "Leaderboard";
import ExtIntegration "ExtIntegration";
import IcpLedger "IcpLedger";
import UsernameValidator "UsernameValidator";
import BettingManager "BettingManager";
import BettingTypes "BettingTypes";
import TT "mo:timer-tool";
import Star "mo:star/star";

// (
//   with migration = func(
//     old_state : {
//       var stable_races : Map.Map<Nat, { /* Race type WITHOUT events field */
//       raceId : Nat; name : Text; distance : Nat; terrain : RacingSimulator.Terrain; trackId : Nat; trackSeed : Nat; raceClass : RacingSimulator.RaceClass; entryFee : Nat; maxEntries : Nat; minEntries : Nat; startTime : Int; duration : Nat; entryDeadline : Int; createdAt : Int; entries : [RacingSimulator.RaceEntry]; status : RacingSimulator.RaceStatus; results : ?[RacingSimulator.RaceResult]; prizePool : Nat; platformTax : Nat; platformBonus : Nat; sponsors : [RacingSimulator.Sponsor] }>;
//     }
//   ) : {
//     var stable_races : Map.Map<Nat, RacingSimulator.Race>;
//   } {
//     // Migrate races - add events field with empty array
//     let new_races = Map.new<Nat, RacingSimulator.Race>();

//     for ((raceId, oldRace) in Map.entries(old_state.stable_races)) {
//       let newRace : RacingSimulator.Race = {
//         raceId = oldRace.raceId;
//         name = oldRace.name;
//         distance = oldRace.distance;
//         terrain = oldRace.terrain;
//         trackId = oldRace.trackId;
//         trackSeed = oldRace.trackSeed;
//         raceClass = oldRace.raceClass;
//         entryFee = oldRace.entryFee;
//         maxEntries = oldRace.maxEntries;
//         minEntries = oldRace.minEntries;
//         startTime = oldRace.startTime;
//         duration = oldRace.duration;
//         entryDeadline = oldRace.entryDeadline;
//         createdAt = oldRace.createdAt;
//         entries = oldRace.entries;
//         status = oldRace.status;
//         results = oldRace.results;
//         events = []; // Add empty events array
//         prizePool = oldRace.prizePool;
//         platformTax = oldRace.platformTax;
//         platformBonus = oldRace.platformBonus;
//         sponsors = oldRace.sponsors;
//       };
//       ignore Map.put(new_races, Map.nhash, raceId, newRace);
//     };

//     {
//       var stable_races = new_races;
//     };
//   }
// )
shared ({ caller = deployer }) persistent actor class McpServer(
  args : ?{
    owner : ?Principal;
    extCanisterId : ?Principal;
  }
) = self {

  // The canister owner, who can manage treasury funds.
  // Defaults to the deployer if not specified.
  var owner : Principal = Option.get(do ? { args!.owner! }, deployer);
  let thisPrincipal = Principal.fromActor(self);

  // State for certified HTTP assets (like /.well-known/...)
  var stable_http_assets : HttpAssets.StableEntries = [];
  transient let http_assets = HttpAssets.init(stable_http_assets);

  // Stable state for NFT metadata
  let stable_nft_stats = Map.new<Nat, Stats.NFTStats>();
  var stable_trait_schema : Stats.TraitSchema = [];

  // Stable state for pre-computed base stats (speed, power, accel, stability, faction)
  let stable_base_stats = Map.new<Nat, { speed : Nat; powerCore : Nat; acceleration : Nat; stability : Nat; faction : PokedBotsGarage.FactionType }>();

  // Stable state for racing stats (PokedBots-specific)
  let stable_racing_stats = Map.new<Nat, PokedBotsGarage.PokedBotRacingStats>();
  let stable_active_upgrades = Map.new<Nat, PokedBotsGarage.UpgradeSession>();
  let stable_user_inventories = Map.new<Principal, PokedBotsGarage.UserInventory>();
  let stable_pity_counters = Map.new<Nat, Nat>(); // Upgrade failure pity system

  // Stable state for races (generic racing)
  let stable_races = Map.new<Nat, RacingSimulator.Race>();

  // Stable state for calendar events
  let stable_events = Map.new<Nat, RaceCalendar.ScheduledEvent>();

  // Stable state for leaderboards
  let stable_monthly_boards = Map.new<Nat, Map.Map<Nat, Leaderboard.LeaderboardEntry>>();
  let stable_season_boards = Map.new<Nat, Map.Map<Nat, Leaderboard.LeaderboardEntry>>();
  let stable_alltime_board = Map.new<Nat, Leaderboard.LeaderboardEntry>();
  let stable_faction_boards = Map.new<Text, Map.Map<Nat, Leaderboard.LeaderboardEntry>>();

  // Stable state for battery recharge tracking
  var stable_last_recharge_time : Int = 0;

  // Stable state for prize payment tracking (prevents duplicate payments)
  // Key: "raceId:owner:amount" - ensures each prize is only paid once
  let stable_paid_prizes = Map.new<Text, Int>(); // Maps prize key to timestamp when paid

  // Stable state for betting system
  let stable_betting_pools = Map.new<Nat, BettingTypes.BettingPool>(); // raceId -> BettingPool
  let stable_betting_bets = Map.new<Nat, BettingTypes.Bet>(); // betId -> Bet
  let stable_betting_user_bets = Map.new<Principal, [Nat]>(); // userId -> [betIds]
  let stable_betting_user_stats = Map.new<Principal, BettingTypes.UserBettingStats>(); // userId -> stats
  var stable_betting_next_bet_id : Nat = 1;
  var stable_platform_treasury : Principal = Principal.fromText("aaaaa-aa"); // Will be set on initialization

  // Constants
  let TRANSFER_FEE : Nat = 10_000; // 0.0001 ICP
  let PRIZE_DISTRIBUTION_TIMEOUT : Nat = 60_000_000_000; // 60 seconds timeout for prize transfers
  let RACE_BREAK_TIME : Nat = 30_000_000_000; // 30 seconds between chained races (commercial break)

  // NFT metadata storage
  transient let statsManager = Stats.StatsManager(stable_nft_stats, stable_trait_schema);

  transient let initManager = ClassPlus.ClassPlusInitializationManager(owner, thisPrincipal, true);

  // --- TT Setup ---
  private func reportTTExecution(execInfo : TT.ExecutionReport) : Bool {
    Debug.print("CANISTER: TimerTool Execution: " # debug_show (execInfo));
    false;
  };

  private func reportTTError(errInfo : TT.ErrorReport) : ?Nat {
    Debug.print("CANISTER: TimerTool Error: " # debug_show (errInfo));
    null;
  };

  var tt_migration_state : TT.State = TT.Migration.migration.initialState;
  transient let tt = TT.Init<system>({
    manager = initManager;
    initialState = tt_migration_state;
    args = null;
    pullEnvironment = ?(
      func() : TT.Environment {
        {
          advanced = null;
          reportExecution = ?reportTTExecution;
          reportError = ?reportTTError;
          syncUnsafe = null;
          reportBatch = null;
        };
      }
    );
    onInitialize = ?(
      func(newClass : TT.TimerTool) : async* () {
        Debug.print("Initializing TimerTool");
        newClass.initialize<system>();
      }
    );
    onStorageChange = func(state : TT.State) { tt_migration_state := state };
  });

  // Resource contents stored in memory for simplicity.
  // In a real application these would probably be uploaded or user generated.
  var resourceContents = [
    ("file:///main.py", "print('Hello from main.py!')"),
    ("file:///README.md", "# MCP Motoko Server"),
  ];

  // The application context that holds our state.
  var appContext : McpTypes.AppContext = State.init(resourceContents);

  // =================================================================================
  // --- AUTHENTICATION & EXT INTEGRATION ---
  // Authentication is enabled to get the user's principal for EXT ownership verification
  // =================================================================================

  // PokedBots EXT Canister ID
  // Can be overridden via init args for testing, defaults to production
  var extCanisterId = Option.get(
    do ? { args!.extCanisterId! },
    Principal.fromText("bzsui-sqaaa-aaaah-qce2a-cai"),
  );
  transient let extCanister = ExtIntegration.getExtCanister(extCanisterId);

  // ICP Ledger Canister ID (optional, can be set dynamically)
  var icpLedgerCanisterId : ?Principal = null;

  // PokedBots Garage Manager (collection-specific logic)
  transient let garageManager = PokedBotsGarage.PokedBotsGarageManager(
    stable_racing_stats,
    stable_active_upgrades,
    stable_user_inventories,
    stable_pity_counters,
    {
      getNFTMetadata = func(tokenId : Nat) : ?[(Text, Text)] {
        statsManager.getNFTMetadata(tokenId);
      };
      getPrecomputedStats = func(tokenId : Nat) : ?{
        speed : Nat;
        powerCore : Nat;
        acceleration : Nat;
        stability : Nat;
        faction : PokedBotsGarage.FactionType;
      } {
        Map.get(stable_base_stats, Map.nhash, tokenId);
      };
    },
  );

  // Racing Simulator (generic racing engine)
  transient let raceSimulator = RacingSimulator.RaceSimulator();

  // Race Manager (uses generic racing logic)
  transient let raceManager = RacingSimulator.RaceManager(stable_races);

  // Event calendar manager
  transient let eventCalendar = RaceCalendar.EventCalendar(stable_events);

  /// Get race class based on overall rating (average of max stats)
  func getRaceClassFromRating(overallRating : Nat) : RacingSimulator.RaceClass {
    // Based on overall rating (average of max stats: 0-100)
    if (overallRating >= 50) {
      #SilentKlan; // Top tier: 50+ (highly upgraded)
    } else if (overallRating >= 40) {
      #Elite; // High tier: 40-49
    } else if (overallRating >= 30) {
      #Raider; // Mid tier: 30-39
    } else if (overallRating >= 20) {
      #Junker; // Low tier: 20-29
    } else {
      #Scrap; // Bottom tier: 0-19
    };
  };

  /// Calculate overall rating from max stats (for race class determination)
  /// This should be used for determining race eligibility, not current degraded stats
  func calculateMaxRating(botStats : PokedBotsGarage.PokedBotRacingStats) : Nat {
    let baseStats = garageManager.getBaseStats(botStats.tokenIndex);
    let maxSpeed = baseStats.speed + botStats.speedBonus;
    let maxPowerCore = baseStats.powerCore + botStats.powerCoreBonus;
    let maxAcceleration = baseStats.acceleration + botStats.accelerationBonus;
    let maxStability = baseStats.stability + botStats.stabilityBonus;
    (maxSpeed + maxPowerCore + maxAcceleration + maxStability) / 4;
  };

  // Leaderboard manager
  transient let leaderboardManager = Leaderboard.LeaderboardManager(
    stable_monthly_boards,
    stable_season_boards,
    stable_alltime_board,
    stable_faction_boards,
    func(tokenIndex : Nat) : RacingSimulator.RaceClass {
      // Calculate race class from current stats (inlined to avoid forward reference issues)
      switch (garageManager.getStats(tokenIndex)) {
        case (?botStats) {
          let baseStats = garageManager.getBaseStats(botStats.tokenIndex);
          let maxSpeed = baseStats.speed + botStats.speedBonus;
          let maxPowerCore = baseStats.powerCore + botStats.powerCoreBonus;
          let maxAcceleration = baseStats.acceleration + botStats.accelerationBonus;
          let maxStability = baseStats.stability + botStats.stabilityBonus;
          let overallRating = (maxSpeed + maxPowerCore + maxAcceleration + maxStability) / 4;

          // Determine race class based on rating
          if (overallRating >= 50) {
            #SilentKlan;
          } else if (overallRating >= 40) {
            #Elite;
          } else if (overallRating >= 30) {
            #Raider;
          } else if (overallRating >= 20) {
            #Junker;
          } else {
            #Scrap;
          };
        };
        case (null) { #Scrap }; // Default if no stats
      };
    },
  );

  // Betting manager (integrated into racing canister)
  transient let bettingManager = BettingManager.BettingManager(
    stable_betting_pools,
    stable_betting_bets,
    stable_betting_user_bets,
    stable_betting_user_stats,
    stable_betting_next_bet_id,
    stable_platform_treasury,
    Option.get(icpLedgerCanisterId, Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")) // Default to local ledger, will be set properly
  );

  // Marketplace listings cache removed to save memory
  // Fetch listings on-demand instead of caching
  let CACHE_TTL_SECONDS : Int = 300; // 5 minutes (unused, kept for compatibility)

  let issuerUrl = "https://bfggx-7yaaa-aaaai-q32gq-cai.icp0.io";
  let allowanceUrl = "https://prometheusprotocol.org/connections";
  let requiredScopes = ["openid"];

  // Function to transform the response for jwks client
  public query func transformJwksResponse({
    context : Blob;
    response : IC.HttpRequestResult;
  }) : async IC.HttpRequestResult {
    {
      response with headers = []; // not interested in the headers
    };
  };

  // Initialize the auth context with the issuer URL and required scopes.
  let authContext : ?AuthTypes.AuthContext = ?AuthState.init(
    Principal.fromActor(self),
    owner,
    issuerUrl,
    requiredScopes,
    transformJwksResponse,
  );

  // =================================================================================
  // --- OPT-IN: USAGE ANALYTICS (BEACON) ---
  // To enable anonymous usage analytics, uncomment the `beaconContext` initialization.
  // This helps the Prometheus Protocol DAO understand ecosystem growth.
  // =================================================================================

  // transient let beaconContext : ?Beacon.BeaconContext = null;

  // --- UNCOMMENT THIS BLOCK TO ENABLE THE BEACON ---
  let beaconCanisterId = Principal.fromText("m63pw-fqaaa-aaaai-q33pa-cai");
  transient let beaconContext : ?Beacon.BeaconContext = ?Beacon.init(
    beaconCanisterId, // Public beacon canister ID
    ?(15 * 60), // Send a beacon every 15 minutes
  );
  // --- END OF BEACON BLOCK ---

  // --- Timers ---
  Cleanup.startCleanupTimer<system>(appContext);

  // The AuthCleanup timer only needs to run if authentication is enabled.
  switch (authContext) {
    case (?ctx) { AuthCleanup.startCleanupTimer<system>(ctx) };
    case (null) { Debug.print("Authentication is disabled.") };
  };

  // The Beacon timer only needs to run if the beacon is enabled.
  switch (beaconContext) {
    case (?ctx) { Beacon.startTimer<system>(ctx) };
    case (null) { Debug.print("Beacon is disabled.") };
  };

  // --- 1. DEFINE YOUR RESOURCES & TOOLS ---
  transient let resources : [McpTypes.Resource] = [
    {
      uri = "file:///main.py";
      name = "main.py";
      title = ?"Main Python Script";
      description = ?"Contains the main logic of the application.";
      mimeType = ?"text/x-python";
    },
    {
      uri = "file:///README.md";
      name = "README.md";
      title = ?"Project Documentation";
      description = null;
      mimeType = ?"text/markdown";
    },
  ];

  // Function to get marketplace listings with caching
  func getMarketplaceListings() : async [(Nat32, ExtIntegration.Listing, ExtIntegration.Metadata)] {
    // Fetch fresh data every time - no caching to save memory
    // The EXT canister call is fast enough for our use case
    await extCanister.listings();
  };

  // Handle completed upgrades with V2 RNG mechanics
  func handleScavengingAccumulation<system>(actionId : TT.ActionId, action : TT.Action) : TT.ActionId {
    Debug.print("Scavenging accumulation handler triggered");

    // Decode the token index from params
    let tokenIndexOpt : ?Nat = from_candid (action.params);

    switch (tokenIndexOpt) {
      case (?tokenIndex) {
        Debug.print("Processing accumulation for token " # debug_show (tokenIndex));

        let now = Time.now();
        switch (garageManager.accumulateScavengingRewards(tokenIndex, now)) {
          case (#ok(msg)) {
            Debug.print("Accumulation successful: " # msg);

            // Schedule next accumulation in 15 minutes
            let next15Min = now + (15 * 60 * 1_000_000_000);
            ignore tt().setActionSync<system>(
              Int.abs(next15Min),
              {
                actionType = "scavenge_accumulate";
                params = to_candid (tokenIndex);
              },
            );
          };
          case (#err(msg)) {
            Debug.print("Accumulation failed: " # msg);
            // Mission likely ended (bot died or was pulled), don't reschedule
          };
        };
      };
      case (null) {
        Debug.print("Could not decode token index for scavenging accumulation");
      };
    };

    actionId;
  };

  func handleUpgradeCompletion<system>(actionId : TT.ActionId, action : TT.Action) : TT.ActionId {
    Debug.print("Upgrade completion handler triggered (V2)");

    // Decode the token index from params
    let tokenIndexOpt : ?Nat = from_candid (action.params);

    switch (tokenIndexOpt) {
      case (?tokenIndex) {
        Debug.print("Processing upgrade completion for token " # debug_show (tokenIndex));

        // Get the active upgrade session
        switch (garageManager.getActiveUpgrade(tokenIndex)) {
          case (?session) {
            Debug.print("Found active upgrade session: " # debug_show (session.upgradeType));

            // Get current stats
            switch (garageManager.getStats(tokenIndex)) {
              case (?stats) {
                // Get current stats for calculation
                let currentStats = garageManager.getCurrentStats(stats);

                let (currentStatValue, upgradeCount) = switch (session.upgradeType) {
                  case (#Velocity) { (currentStats.speed, stats.speedUpgrades) };
                  case (#PowerCore) {
                    (currentStats.powerCore, stats.powerCoreUpgrades);
                  };
                  case (#Thruster) {
                    (currentStats.acceleration, stats.accelerationUpgrades);
                  };
                  case (#Gyro) {
                    (currentStats.stability, stats.stabilityUpgrades);
                  };
                };

                // Get base stat for attempt calculation
                let baseStat = switch (session.upgradeType) {
                  case (#Velocity) { currentStats.speed - stats.speedBonus };
                  case (#PowerCore) {
                    currentStats.powerCore - stats.powerCoreBonus;
                  };
                  case (#Thruster) {
                    currentStats.acceleration - stats.accelerationBonus;
                  };
                  case (#Gyro) { currentStats.stability - stats.stabilityBonus };
                };

                let attemptNumber = currentStatValue - baseStat;

                // Calculate success rate with pity
                let successRate = garageManager.calculateSuccessRate(attemptNumber, session.consecutiveFails);

                // Generate RNG seed with proper hashing to avoid modulo bias
                let timeNanos = Int.abs(Time.now());
                let seedInput = tokenIndex + timeNanos;
                let hashedSeed = garageManager.hashForRNG(seedInput);
                let seed = Nat32.fromNat(hashedSeed % 4_294_967_296);

                // Roll for success
                let roll = Nat32.toNat(seed % 100);
                let success = Float.fromInt(roll) < successRate;

                Debug.print("Upgrade roll: " # debug_show (roll) # " vs success rate: " # debug_show (successRate) # " = " # debug_show (success));

                if (success) {
                  // Success! Check for double points
                  let doubleChance = 15.0 - (Float.fromInt(attemptNumber) * 0.87);
                  let doubleRoll = Nat32.toNat((seed / 100) % 100);
                  let isDouble = Float.fromInt(doubleRoll) < Float.max(2.0, doubleChance);
                  let pointsAwarded = if (isDouble) { 2 } else { 1 };

                  Debug.print("SUCCESS! Points awarded: " # debug_show (pointsAwarded) # (if (isDouble) { " 🎰 DOUBLE!" } else { "" }));

                  // Apply the stat boost
                  let updatedStats = switch (session.upgradeType) {
                    case (#Velocity) {
                      {
                        stats with
                        speedBonus = stats.speedBonus + pointsAwarded;
                        speedUpgrades = stats.speedUpgrades + 1;
                        experience = stats.experience + 5;
                        factionReputation = stats.factionReputation + 2;
                        upgradeEndsAt = null;
                        listedForSale = false;
                      };
                    };
                    case (#PowerCore) {
                      {
                        stats with
                        powerCoreBonus = stats.powerCoreBonus + pointsAwarded;
                        powerCoreUpgrades = stats.powerCoreUpgrades + 1;
                        experience = stats.experience + 5;
                        factionReputation = stats.factionReputation + 2;
                        upgradeEndsAt = null;
                        listedForSale = false;
                      };
                    };
                    case (#Thruster) {
                      {
                        stats with
                        accelerationBonus = stats.accelerationBonus + pointsAwarded;
                        accelerationUpgrades = stats.accelerationUpgrades + 1;
                        experience = stats.experience + 5;
                        factionReputation = stats.factionReputation + 2;
                        upgradeEndsAt = null;
                        listedForSale = false;
                      };
                    };
                    case (#Gyro) {
                      {
                        stats with
                        stabilityBonus = stats.stabilityBonus + pointsAwarded;
                        stabilityUpgrades = stats.stabilityUpgrades + 1;
                        experience = stats.experience + 10;
                        factionReputation = stats.factionReputation + 3;
                        upgradeEndsAt = null;
                        listedForSale = false;
                      };
                    };
                  };

                  garageManager.updateStats(tokenIndex, updatedStats);
                  garageManager.clearUpgrade(tokenIndex);
                  // Reset pity counter on success
                  garageManager.setPityCounter(tokenIndex, 0);
                } else {
                  // Failure! Refund 50% (ICP or parts) and increment pity counter
                  let newPityCounter = session.consecutiveFails + 1;

                  // Update stats without stat increase but reset upgrade session
                  let updatedStats = {
                    stats with
                    upgradeEndsAt = null;
                    listedForSale = false;
                  };
                  garageManager.updateStats(tokenIndex, updatedStats);

                  // Store pity counter for next attempt
                  garageManager.setPityCounter(tokenIndex, newPityCounter);
                  garageManager.clearUpgrade(tokenIndex);

                  // Refund based on payment method
                  if (session.paymentMethod == "icp") {
                    // Refund 50% of ICP cost
                    let refundAmount = session.costPaid / 2;
                    Debug.print("FAILED! Refunding " # debug_show (refundAmount) # " e8s (50% ICP), pity: " # debug_show (newPityCounter));

                    if (refundAmount > 0) {
                      let refundActionId = tt().setActionASync<system>(
                        Int.abs(Time.now() + 1_000_000_000), // 1 second delay
                        {
                          actionType = "prize_distribution";
                          params = to_candid ({
                            raceId = 0; // Not a race prize, use 0
                            owner = stats.ownerPrincipal;
                            amount = refundAmount;
                          });
                        },
                        PRIZE_DISTRIBUTION_TIMEOUT,
                      );
                      Debug.print("Scheduled ICP refund " # debug_show (refundActionId) # " of " # debug_show (refundAmount) # " e8s to " # Principal.toText(stats.ownerPrincipal));
                    };
                  } else {
                    // Refund 50% of parts cost
                    let partsToRefund = session.partsUsed / 2;
                    Debug.print("FAILED! Refunding " # debug_show (partsToRefund) # " parts (50%), pity: " # debug_show (newPityCounter));

                    if (partsToRefund > 0) {
                      // Determine part type from upgrade type
                      let partType : PokedBotsGarage.PartType = switch (session.upgradeType) {
                        case (#Velocity) { #SpeedChip };
                        case (#PowerCore) { #PowerCoreFragment };
                        case (#Thruster) { #ThrusterKit };
                        case (#Gyro) { #GyroModule };
                      };
                      garageManager.refundParts(stats.ownerPrincipal, partType, partsToRefund);
                      Debug.print("Refunded " # debug_show (partsToRefund) # " " # debug_show (partType) # " to " # Principal.toText(stats.ownerPrincipal));
                    };
                  };
                };

                Debug.print("Upgrade completion processed");
              };
              case null {
                Debug.print("Warning: No stats found for token " # debug_show (tokenIndex));
              };
            };
          };
          case null {
            Debug.print("Warning: No active upgrade found for token " # debug_show (tokenIndex));
          };
        };
      };
      case null {
        Debug.print("Error: Could not decode token index from action params");
      };
    };

    actionId;
  };

  // Handle hourly battery recharge (self-rescheduling timer)
  func handleHourlyRecharge<system>(_actionId : TT.ActionId, _action : TT.Action) : TT.ActionId {
    Debug.print("Hourly battery recharge handler triggered");

    let now = Time.now();
    let botsRecharged = garageManager.applyRechargeToAll(now);
    stable_last_recharge_time := now;

    Debug.print("Applied battery recharge to " # debug_show (botsRecharged) # " bots");

    // Schedule next recharge in 1 hour
    let nextRechargeTime = now + (60 * 60 * 1_000_000_000); // 1 hour in nanoseconds
    let nextActionId = tt().setActionSync<system>(
      Int.abs(nextRechargeTime),
      {
        actionType = "hourly_recharge";
        params = to_candid (());
      },
    );
    Debug.print("Scheduled next recharge for " # debug_show (nextRechargeTime));

    nextActionId;
  };

  // Handle automatic race creation (recurring timer)
  func handleRaceCreation<system>(actionId : TT.ActionId, _action : TT.Action) : TT.ActionId {
    Debug.print("Race creation handler triggered");

    let now = Time.now();

    // First, ensure we have upcoming calendar events scheduled
    ensureCalendarScheduled<system>(now);

    // Get events that need races created (within next 7 days, no races yet)
    let upcomingEvents = eventCalendar.getUpcomingEvents(now, 7);

    for (event in upcomingEvents.vals()) {
      // Create races for events that don't have them yet
      if (event.raceIds.size() == 0) {
        var createdRaceIds : [Nat] = [];
        var raceIndex : Nat = 0;

        // Create races based on event divisions
        for (division in event.metadata.divisions.vals()) {
          // Use event ID and race count for better seed variation
          let seed = Nat32.fromNat(Int.abs((event.scheduledTime + event.eventId * 7919 + createdRaceIds.size() * 1000000) % 1000000));

          // Distance and terrain based on event type
          let (distance, terrain) = switch (event.eventType) {
            case (#WeeklyLeague) {
              // League races: longer distances (15-30km) with varied terrain
              let leagueDistances = [15, 20, 25, 30];
              let dist = leagueDistances[Nat32.toNat(seed % 4)];

              let terr = switch (Nat32.toNat((seed / 4) % 3)) {
                case (0) { #WastelandSand }; // Favor endurance
                case (1) { #MetalRoads }; // High speed
                case (_) { #ScrapHeaps }; // Technical
              };
              (dist, terr);
            };
            case (#MonthlyCup) {
              // Cup races: epic distances (25-40km) with challenging terrain
              let cupDistances = [25, 30, 35, 40];
              let dist = cupDistances[Nat32.toNat(seed % 4)];

              let terr = switch (Nat32.toNat((seed / 4) % 3)) {
                case (0) { #WastelandSand };
                case (1) { #MetalRoads };
                case (_) { #ScrapHeaps };
              };
              (dist, terr);
            };
            case (#DailySprint) {
              // Sprint races: short distances (5-10km) with varied terrain
              let sprintDistances = [5, 7, 10];
              let dist = sprintDistances[Nat32.toNat(seed % 3)];

              // Better terrain distribution using different modulo
              let terr = switch (Nat32.toNat(seed % 3)) {
                case (0) { #ScrapHeaps };
                case (1) { #WastelandSand };
                case (_) { #MetalRoads };
              };
              (dist, terr);
            };
            case (#SpecialEvent(_)) {
              // Special events: full variety
              let distances = [10, 15, 20, 25, 30];
              let dist = distances[Nat32.toNat(seed % 5)];

              let terr = switch (Nat32.toNat((seed / 5) % 3)) {
                case (0) { #ScrapHeaps };
                case (1) { #WastelandSand };
                case (_) { #MetalRoads };
              };
              (dist, terr);
            };
          };

          // Apply class-based entry fee multiplier - More linear progression
          let classFeeMultiplier : Float = switch (division) {
            case (#Scrap) { 0.5 }; // 0.5x base
            case (#Junker) { 1.0 }; // 1x base (reference)
            case (#Raider) { 1.5 }; // 1.5x base (+50%)
            case (#Elite) { 2.0 }; // 2x base (+100%)
            case (#SilentKlan) { 2.5 }; // 2.5x base (+150%)
          };

          let adjustedEntryFee = Int.abs(Float.toInt(Float.fromInt(event.metadata.entryFee) * classFeeMultiplier));

          // Platform bonus to guarantee top 3 profitability, 4th breaks even
          // Calculated for 8-player races with new distribution (45%, 28%, 18%, 9%)
          // Increased by 25% to maximize player rewards
          let platformBonus : Nat = switch (event.eventType, division) {
            // Daily Sprint bonuses - Entry fees: Scrap 0.1, Junker 0.2, Raider 0.3, Elite 0.4, SilentKlan 0.5
            case (#DailySprint, #Scrap) { 20_000_000 }; // 0.20 ICP (2x)
            case (#DailySprint, #Junker) { 40_000_000 }; // 0.40 ICP (2x)
            case (#DailySprint, #Raider) { 60_000_000 }; // 0.60 ICP (2x)
            case (#DailySprint, #Elite) { 80_000_000 }; // 0.80 ICP (2x)
            case (#DailySprint, #SilentKlan) { 100_000_000 }; // 1.00 ICP (2x)
            // Weekly League bonuses - Entry fees: Scrap 0.4, Junker 0.8, Raider 1.2, Elite 1.6, SilentKlan 2.4
            case (#WeeklyLeague, #Scrap) { 80_000_000 }; // 0.80 ICP (2x)
            case (#WeeklyLeague, #Junker) { 160_000_000 }; // 1.60 ICP (2x)
            case (#WeeklyLeague, #Raider) { 240_000_000 }; // 2.40 ICP (2x)
            case (#WeeklyLeague, #Elite) { 320_000_000 }; // 3.20 ICP (2x)
            case (#WeeklyLeague, #SilentKlan) { 480_000_000 }; // 4.80 ICP (2x)
            // Monthly Cup bonuses - Entry fees: Elite 4.0, SilentKlan 6.0
            case (#MonthlyCup, #Elite) { 800_000_000 }; // 8.0 ICP (2x)
            case (#MonthlyCup, #SilentKlan) { 1_200_000_000 }; // 12.0 ICP (2x)
            // Fallback
            case _ { event.metadata.prizePoolBonus };
          };

          // All races in an event share the same base scheduled time
          // Only the first race will be scheduled - the rest chain dynamically
          let race = raceManager.createRace(
            distance,
            terrain,
            division,
            adjustedEntryFee,
            event.metadata.maxEntries,
            event.metadata.minEntries,
            event.scheduledTime, // All races use event scheduled time
            platformBonus,
            event.registrationCloses,
          );

          createdRaceIds := Array.append(createdRaceIds, [race.raceId]);

          Debug.print("Created race " # Nat.toText(race.raceId) # " for " # event.metadata.name # ": " # race.name # " (duration ~" # Nat.toText(race.duration) # "s)");

          // Schedule betting pool creation when registration closes (using ASync for timer context)
          let poolActionId = tt().setActionASync<system>(
            Int.abs(event.registrationCloses),
            {
              actionType = "betting_pool_create";
              params = to_candid (race.raceId);
            },
            3_600_000_000_000, // 1 hour timeout
          );
          Debug.print("Scheduled betting pool creation for race " # Nat.toText(race.raceId) # " at registration close (action " # debug_show (poolActionId) # ")");

          // Only schedule the first race - subsequent races will be chained from handleRaceFinish
          if (raceIndex == 0) {
            let startActionId = tt().setActionASync<system>(
              Int.abs(event.scheduledTime),
              {
                actionType = "race_start";
                params = to_candid (race.raceId);
              },
              3_600_000_000_000, // 1 hour timeout
            );
            Debug.print("Scheduled FIRST race start for race " # Nat.toText(race.raceId) # " at event time (action " # debug_show (startActionId) # ") - subsequent races will chain");
          } else {
            Debug.print("Race " # Nat.toText(race.raceId) # " will be chained from previous race completion");
          };

          raceIndex += 1;
        };

        // Atomically add races to event - only succeeds if event still has no races
        // This prevents race conditions where multiple timers try to create races for the same event
        switch (eventCalendar.addRacesToEventIfEmpty(event.eventId, createdRaceIds)) {
          case (?_updatedEvent) {
            // Success! We won the race to add races to this event
            Debug.print("Successfully associated " # Nat.toText(createdRaceIds.size()) # " races with event " # Nat.toText(event.eventId));
          };
          case (null) {
            // Either event disappeared OR another timer already added races
            // Clean up our duplicate races
            Debug.print("WARNING: Failed to add races to event " # Nat.toText(event.eventId) # " (another timer beat us or event disappeared). Cleaning up " # Nat.toText(createdRaceIds.size()) # " duplicate races");

            for (raceId in createdRaceIds.vals()) {
              switch (raceManager.getRace(raceId)) {
                case (?race) {
                  ignore raceManager.updateRaceStatus(raceId, #Cancelled);

                  // Cancel the race_start timer
                  let raceStartTimers = tt().getActionsByFilter(#ByType("race_start"));
                  for ((timerId, timerAction) in raceStartTimers.vals()) {
                    let timerRaceIdOpt : ?Nat = from_candid (timerAction.params);
                    switch (timerRaceIdOpt) {
                      case (?timerRaceId) {
                        if (timerRaceId == raceId) {
                          ignore tt().cancelActionsByIds<system>([timerId.id]);
                        };
                      };
                      case (null) {};
                    };
                  };

                  ignore raceManager.deleteRace(raceId);
                };
                case (null) {};
              };
            };
          };
        };
      };
    };

    // Schedule next race creation check in 1 hour
    // First check if we already have a race_create scheduled for around this time to avoid duplicates
    let nextCreationTime = now + (60 * 60 * 1_000_000_000);
    let existingRaceCreateActions = tt().getActionsByFilter(#ByType("race_create"));

    // Check if any existing race_create action is scheduled within 30 seconds of our target time
    var alreadyScheduled = false;
    for ((actionId, _action) in existingRaceCreateActions.vals()) {
      let timeDiff = if (actionId.time > Int.abs(nextCreationTime)) {
        actionId.time - Int.abs(nextCreationTime);
      } else {
        Int.abs(nextCreationTime) - actionId.time;
      };

      if (timeDiff < 30_000_000_000) {
        // Within 30 seconds
        alreadyScheduled := true;
      };
    };

    var nextActionId : TT.ActionId = { id = 0; time = 0 };
    if (not alreadyScheduled) {
      nextActionId := tt().setActionSync<system>(
        Int.abs(nextCreationTime),
        {
          actionType = "race_create";
          params = to_candid (());
        },
      );
    };

    nextActionId;
  };

  // Ensure calendar has events scheduled (Weekly League + Daily Sprints)
  func ensureCalendarScheduled<system>(now : Int) {
    let upcomingEvents = eventCalendar.getUpcomingEvents(now, 14); // Next 2 weeks

    // Check for Weekly League races in next 2 weeks
    let weeklyLeagues = Array.filter<RaceCalendar.ScheduledEvent>(
      upcomingEvents,
      func(e) {
        switch (e.eventType) {
          case (#WeeklyLeague) { true };
          case (_) { false };
        };
      },
    );

    // Schedule next 2 Weekly Leagues if less than 2 scheduled
    if (weeklyLeagues.size() < 2) {
      // Start from the last existing weekly league, or now if none exist
      var scheduleTime = if (weeklyLeagues.size() > 0) {
        // Sort by scheduledTime to find the latest
        let sorted = Array.sort<RaceCalendar.ScheduledEvent>(
          weeklyLeagues,
          func(a, b) { Int.compare(a.scheduledTime, b.scheduledTime) },
        );
        sorted[sorted.size() - 1].scheduledTime + 1_000_000_000; // Start after the last one
      } else {
        now;
      };

      for (i in Iter.range(0, 1 - weeklyLeagues.size())) {
        let nextSunday = RaceCalendar.getNextWeeklyOccurrence(0, 20, 0, scheduleTime);

        // Check if event already exists at this time (within 30-minute window)
        let existingAtTime = Array.filter<RaceCalendar.ScheduledEvent>(
          upcomingEvents,
          func(e) {
            switch (e.eventType) {
              case (#WeeklyLeague) {
                let timeDiff = Int.abs(e.scheduledTime - nextSunday);
                timeDiff < (30 * 60 * 1_000_000_000); // Within 30 minutes
              };
              case (_) { false };
            };
          },
        );

        if (existingAtTime.size() == 0) {
          ignore eventCalendar.createWeeklyLeagueEvent(nextSunday, now);
          Debug.print("Auto-scheduled Weekly League for timestamp: " # debug_show (nextSunday));
        } else {
          Debug.print("SKIP: Weekly League already exists at timestamp: " # debug_show (nextSunday));
        };

        scheduleTime := nextSunday + 1_000_000_000; // Move past this event
      };
    };

    // Check for Daily Sprints in next 48 hours
    let sprintsIn48h = Array.filter<RaceCalendar.ScheduledEvent>(
      eventCalendar.getUpcomingEvents(now, 2), // Next 2 days
      func(e) {
        switch (e.eventType) {
          case (#DailySprint) { true };
          case (_) { false };
        };
      },
    );

    // Schedule Daily Sprints to ensure at least 8 in next 48 hours (one every 6 hours)
    if (sprintsIn48h.size() < 8) {
      // Start from the last existing sprint time, or now if none exist
      var scheduleTime = if (sprintsIn48h.size() > 0) {
        // Sort by scheduledTime to find the latest
        let sorted = Array.sort<RaceCalendar.ScheduledEvent>(
          sprintsIn48h,
          func(a, b) { Int.compare(a.scheduledTime, b.scheduledTime) },
        );
        sorted[sorted.size() - 1].scheduledTime + 1_000_000_000; // Start after the last one
      } else {
        now;
      };

      for (i in Iter.range(0, 7 - sprintsIn48h.size())) {
        let nextSprint = RaceCalendar.getNextDailySprintTime(scheduleTime);

        // Check if event already exists at this time (within 5-minute window)
        let existingAtTime = Array.filter<RaceCalendar.ScheduledEvent>(
          upcomingEvents,
          func(e) {
            switch (e.eventType) {
              case (#DailySprint) {
                let timeDiff = Int.abs(e.scheduledTime - nextSprint);
                timeDiff < (5 * 60 * 1_000_000_000); // Within 5 minutes
              };
              case (_) { false };
            };
          },
        );

        if (existingAtTime.size() == 0) {
          ignore eventCalendar.createDailySprintEvent(nextSprint, now);
          Debug.print("Auto-scheduled Daily Sprint for timestamp: " # debug_show (nextSprint));
        } else {
          Debug.print("SKIP: Daily Sprint already exists at timestamp: " # debug_show (nextSprint));
        };

        scheduleTime := nextSprint + 1_000_000_000;
      };
    };
  };

  // Handle prize distribution asynchronously
  func handlePrizeDistribution<system>(actionId : TT.ActionId, action : TT.Action) : async* Star.Star<TT.ActionId, TT.Error> {
    Debug.print("Prize distribution handler triggered");

    // Decode prize info using a record type instead of tuple
    type PrizeInfo = {
      raceId : Nat;
      owner : Principal;
      amount : Nat;
    };
    let prizeInfoOpt : ?PrizeInfo = from_candid (action.params);

    switch (prizeInfoOpt) {
      case (?prizeInfo) {
        // Create unique key for this prize payment
        let prizeKey = Nat.toText(prizeInfo.raceId) # ":" # Principal.toText(prizeInfo.owner) # ":" # Nat.toText(prizeInfo.amount);

        // Check if this prize was already paid
        switch (Map.get(stable_paid_prizes, Map.thash, prizeKey)) {
          case (?paidAt) {
            Debug.print("DUPLICATE PREVENTED: Prize already paid at " # debug_show (paidAt) # " for key: " # prizeKey);
            return #awaited(actionId); // Already paid, mark as complete to prevent retries
          };
          case (null) {
            // Not paid yet, mark as in-progress IMMEDIATELY to prevent race conditions
            ignore Map.put(stable_paid_prizes, Map.thash, prizeKey, Time.now());
          };
        };

        Debug.print("Distributing " # debug_show (prizeInfo.amount) # " to " # Principal.toText(prizeInfo.owner) # " for race " # debug_show (prizeInfo.raceId));

        let ledgerCanisterId = switch (icpLedgerCanisterId) {
          case (?id) { id };
          case (null) {
            Debug.print("ICP Ledger not configured, skipping prize distribution");
            return #trappable(actionId); // Return actionId, not error - will be cleaned up
          };
        };
        let ledger = actor (Principal.toText(ledgerCanisterId)) : actor {
          icrc1_transfer : shared IcpLedger.TransferArg -> async IcpLedger.Result;
        };

        try {
          let transferResult = await ledger.icrc1_transfer({
            from_subaccount = null;
            to = { owner = prizeInfo.owner; subaccount = null };
            amount = prizeInfo.amount;
            fee = ?TRANSFER_FEE;
            memo = null;
            created_at_time = null;
          });

          switch (transferResult) {
            case (#Ok(blockIndex)) {
              Debug.print("Prize sent successfully, block: " # debug_show (blockIndex));
              return #awaited(actionId); // Success - action completed
            };
            case (#Err(err)) {
              Debug.print("Prize transfer failed: " # debug_show (err));
              return #trappable(actionId); // Failed - will be cleaned up
            };
          };
        } catch (e) {
          Debug.print("Prize transfer caught error: " # Error.message(e));
          return #trappable(actionId); // Exception - will be cleaned up
        };
      };
      case (null) {
        Debug.print("Could not decode prize info");
        return #trappable(actionId); // Invalid data - will be cleaned up
      };
    };
  };

  // Handle bet settlement asynchronously
  func handleBetSettlement<system>(actionId : TT.ActionId, action : TT.Action) : async* Star.Star<TT.ActionId, TT.Error> {
    Debug.print("Bet settlement handler triggered");

    type BetSettlementInfo = {
      raceId : Nat;
      rankings : [Nat];
    };
    let settlementInfoOpt : ?BetSettlementInfo = from_candid (action.params);

    switch (settlementInfoOpt) {
      case (?info) {
        Debug.print("Settling bets for race " # debug_show (info.raceId));

        try {
          ignore await bettingManager.settleBets(info.raceId, info.rankings);
          Debug.print("Successfully settled bets for race " # debug_show (info.raceId));
          return #awaited(actionId);
        } catch (e) {
          Debug.print("Bet settlement failed: " # Error.message(e));
          return #trappable(actionId);
        };
      };
      case (null) {
        Debug.print("Could not decode bet settlement info");
        return #trappable(actionId);
      };
    };
  };

  // Handle betting pool creation (when registration closes)
  func handleBettingPoolCreate<system>(actionId : TT.ActionId, action : TT.Action) : TT.ActionId {
    Debug.print("Betting pool creation handler triggered");

    let raceIdOpt : ?Nat = from_candid (action.params);

    switch (raceIdOpt) {
      case (?raceId) {
        Debug.print("Creating betting pool for race " # debug_show (raceId));

        switch (raceManager.getRace(raceId)) {
          case (?race) {
            // Only create pool if race is still upcoming and has entries
            if (race.status == #Upcoming and race.entries.size() > 0) {
              // Check if pool already exists (from manual creation)
              switch (bettingManager.getPool(raceId)) {
                case (?existingPool) {
                  // Pool exists, open it if it's pending
                  if (existingPool.status == #Pending) {
                    ignore bettingManager.openPool(raceId);
                    Debug.print("Opened existing betting pool for race " # debug_show (raceId));
                  };
                };
                case (null) {
                  // Create new pool (will be #Open since we're at registration close time)
                  ignore bettingManager.createPool(race);
                  Debug.print("Created betting pool for race " # debug_show (raceId) # " with " # debug_show (race.entries.size()) # " entrants");
                };
              };
            } else {
              Debug.print("Skipped pool creation - race status: " # debug_show (race.status) # ", entries: " # debug_show (race.entries.size()));
            };
          };
          case (null) {
            Debug.print("Race not found: " # debug_show (raceId));
          };
        };
      };
      case (null) {
        Debug.print("Could not decode race ID for betting pool creation");
      };
    };

    actionId;
  };

  // Handle race start - marks race as in progress
  func handleRaceStart<system>(actionId : TT.ActionId, action : TT.Action) : TT.ActionId {
    Debug.print("Race start handler triggered");

    let raceIdOpt : ?Nat = from_candid (action.params);

    switch (raceIdOpt) {
      case (?raceId) {
        Debug.print("Starting race " # debug_show (raceId));

        switch (raceManager.getRace(raceId)) {
          case (?race) {
            // Backwards compatibility: Skip if race is already in progress or completed
            switch (race.status) {
              case (#InProgress) {
                Debug.print("Race " # debug_show (raceId) # " already in progress, skipping duplicate start");
                return actionId;
              };
              case (#Completed) {
                Debug.print("Race " # debug_show (raceId) # " already completed, skipping duplicate start");
                return actionId;
              };
              case (_) {};
            };

            // Allow all registered entries to race regardless of rating changes during upgrade
            // Registrations are only a few days out, so letting bots race in their registered class is fine

            // Check if race has enough entries
            if (race.entries.size() < race.minEntries) {
              Debug.print("Race cancelled - not enough entries (" # debug_show (race.entries.size()) # " < " # debug_show (race.minEntries) # "), issuing refunds");
              ignore raceManager.updateRaceStatus(raceId, #Cancelled);

              // Refund all entries
              for (entry in race.entries.vals()) {
                let refundActionId = tt().setActionASync<system>(
                  Int.abs(Time.now() + 1_000_000_000), // 1 second delay
                  {
                    actionType = "prize_distribution";
                    params = to_candid ({
                      raceId = raceId;
                      owner = entry.owner;
                      amount = entry.entryFee;
                    });
                  },
                  PRIZE_DISTRIBUTION_TIMEOUT,
                );
                Debug.print("Scheduled refund " # debug_show (refundActionId) # " of " # debug_show (entry.entryFee) # " to " # Principal.toText(entry.owner));
              };

              // Refund all sponsors
              for (sponsor in race.sponsors.vals()) {
                let sponsorRefundActionId = tt().setActionASync<system>(
                  Int.abs(Time.now() + 1_000_000_000), // 1 second delay
                  {
                    actionType = "prize_distribution";
                    params = to_candid ({
                      raceId = raceId;
                      owner = sponsor.sponsor;
                      amount = sponsor.amount;
                    });
                  },
                  PRIZE_DISTRIBUTION_TIMEOUT,
                );
                Debug.print("Scheduled sponsor refund " # debug_show (sponsorRefundActionId) # " of " # debug_show (sponsor.amount) # " to " # Principal.toText(sponsor.sponsor));
              };

              return actionId;
            };

            // Generate unpredictable trackSeed using race start execution time
            // This prevents pre-simulation while allowing frontend to simulate in real-time
            // Use full timestamp for maximum entropy and uniqueness
            let executionTime = Time.now();
            let trackSeed = Int.abs(raceId * 7919 + executionTime);

            Debug.print("Generated trackSeed at race start: " # debug_show (trackSeed) # " (executionTime: " # debug_show (executionTime) # ")");

            // Update race with trackSeed so frontend can fetch it for real-time simulation
            switch (raceManager.setTrackSeed(raceId, trackSeed)) {
              case (?_updated) {
                Debug.print("Updated race " # debug_show (raceId) # " with trackSeed " # debug_show (trackSeed));
              };
              case (null) {
                Debug.print("Failed to update race with trackSeed");
              };
            };

            // Close betting pool (betting window ends)
            ignore bettingManager.closePool(raceId);
            Debug.print("Closed betting pool for race " # debug_show (raceId));

            // Mark as in progress
            ignore raceManager.updateRaceStatus(raceId, #InProgress);
            Debug.print("Race in progress: " # race.name # " with " # debug_show (race.entries.size()) # " entries");

            // Snapshot stats for all entries at race start (includes buffs/penalties)
            var entriesWithStats : [RacingSimulator.RaceEntry] = [];
            for (entry in race.entries.vals()) {
              // Parse token index
              let tokenIndexOpt = Nat.fromText(entry.nftId);

              switch (tokenIndexOpt) {
                case (?tokenIndex) {
                  // First, check if bot is on a scavenging mission and pull them out
                  switch (garageManager.getStats(tokenIndex)) {
                    case (?botStats) {
                      switch (botStats.activeMission) {
                        case (?mission) {
                          // Pull bot from scavenging mission with penalties
                          let rng = Int.abs(executionTime % 1000000);
                          switch (garageManager.pullFromScavenging(tokenIndex, executionTime, rng)) {
                            case (#ok(result)) {
                              Debug.print("Pulled bot " # entry.nftId # " from scavenging at race start: " # result.penalties);
                            };
                            case (#err(errMsg)) {
                              Debug.print("Error pulling bot " # entry.nftId # " from scavenging: " # errMsg);
                            };
                          };
                        };
                        case (null) {
                          // Not on mission, proceed normally
                        };
                      };
                    };
                    case (null) {};
                  };

                  // Get bot stats WITH terrain bonuses for this race
                  switch (garageManager.getRacingStatsWithTerrain(entry.nftId, race.terrain)) {
                    case (?stats) {
                      let entryWithStats : RacingSimulator.RaceEntry = {
                        nftId = entry.nftId;
                        owner = entry.owner;
                        entryFee = entry.entryFee;
                        enteredAt = entry.enteredAt;
                        stats = ?stats;
                      };
                      entriesWithStats := Array.append(entriesWithStats, [entryWithStats]);
                    };
                    case (null) {
                      Debug.print("Warning: No stats found for NFT " # entry.nftId # ", keeping entry without stats");
                      entriesWithStats := Array.append(entriesWithStats, [entry]);
                    };
                  };
                };
                case (null) {
                  Debug.print("Warning: Invalid nftId format: " # entry.nftId);
                  entriesWithStats := Array.append(entriesWithStats, [entry]);
                };
              };
            };

            // Update race entries with stats snapshot
            ignore raceManager.updateRaceEntries(raceId, entriesWithStats);
            Debug.print("Snapshotted stats for " # debug_show (entriesWithStats.size()) # " entries at race start");

            // Simulate the race immediately to get actual finish time
            var participants : [RacingSimulator.RacingParticipant] = [];
            for (entry in entriesWithStats.vals()) {
              switch (entry.stats) {
                case (?stats) {
                  let participant : RacingSimulator.RacingParticipant = {
                    nftId = entry.nftId;
                    owner = entry.owner;
                    stats = stats;
                  };
                  participants := Array.append(participants, [participant]);
                };
                case (null) {};
              };
            };

            // Get updated race with trackSeed
            let updatedRace = switch (raceManager.getRace(raceId)) {
              case (?r) { r };
              case (null) {
                Debug.print("Error: Race not found after trackSeed update");
                return actionId;
              };
            };

            // Simulate race and store results
            switch (raceSimulator.simulateRaceSegmented(updatedRace, participants)) {
              case (?(results, events)) {
                Debug.print("Race simulated at start, " # debug_show (results.size()) # " racers, " # debug_show (events.size()) # " events");

                // Store results and events immediately
                let updatedWithResults = raceManager.setRaceResults(raceId, results, events);
                Debug.print("Stored results and events in race, updated race: " # debug_show (updatedWithResults));

                // Find slowest finisher to determine actual race duration
                var slowestTime : Float = 0.0;
                for (result in results.vals()) {
                  if (result.finalTime > slowestTime) {
                    slowestTime := result.finalTime;
                  };
                };

                // Update race duration to actual slowest time (rounded up)
                let actualDuration = Nat.max(1, Int.abs(Float.toInt(Float.ceil(slowestTime))));
                ignore raceManager.updateRaceDuration(raceId, actualDuration);
                Debug.print("Updated race duration from " # Nat.toText(race.duration) # "s to actual " # Nat.toText(actualDuration) # "s");

                // Convert slowest time to nanoseconds and schedule finish
                // Note: slowestTime is already divided by 10 for display, so use it as-is for real-time scheduling
                let raceDurationNanos = Int.abs(Float.toInt(slowestTime * 1_000_000_000.0));
                let finishTime = race.startTime + raceDurationNanos;

                let finishActionId = tt().setActionASync<system>(
                  Int.abs(finishTime),
                  {
                    actionType = "race_finish";
                    params = to_candid (raceId);
                  },
                  60_000_000_000,
                );
                Debug.print("Scheduled race_finish action (async) " # debug_show (finishActionId) # " for race " # debug_show (raceId) # " at " # debug_show (finishTime) # " (slowest time: " # Float.toText(slowestTime) # "s)");
              };
              case (null) {
                Debug.print("Error: Failed to simulate race at start");
                // Fallback to estimated duration
                let finishTime = race.startTime + (race.duration * 1_000_000_000);
                let finishActionId = tt().setActionASync<system>(
                  Int.abs(finishTime),
                  {
                    actionType = "race_finish";
                    params = to_candid (raceId);
                  },
                  60_000_000_000,
                );
                Debug.print("Scheduled race_finish action (fallback, async) " # debug_show (finishActionId) # " for race " # debug_show (raceId) # " at " # debug_show (finishTime));
              };
            };
          };
          case (null) {
            Debug.print("Race not found: " # debug_show (raceId));
          };
        };
      };
      case (null) {
        Debug.print("Could not decode race ID");
      };
    };

    actionId;
  };

  // Handle race finish - apply results and distribute prizes
  func handleRaceFinish<system>(actionId : TT.ActionId, action : TT.Action) : async* Star.Star<TT.ActionId, TT.Error> {
    Debug.print("Race finish handler triggered");

    // Decode race ID
    let raceIdOpt : ?Nat = from_candid (action.params);

    switch (raceIdOpt) {
      case (?raceId) {
        Debug.print("Finishing race " # debug_show (raceId));

        switch (raceManager.getRace(raceId)) {
          case (?race) {
            // Guard: Skip if race is already completed to prevent duplicate processing
            switch (race.status) {
              case (#Completed) {
                Debug.print("Race " # debug_show (raceId) # " already completed, skipping duplicate finish");
                return #awaited(actionId);
              };
              case _ {};
            };

            // Mark as completed IMMEDIATELY to prevent duplicate processing
            ignore raceManager.updateRaceStatus(raceId, #Completed);
            Debug.print("Marked race as Completed to prevent duplicate processing");

            // Results were already simulated and stored at race start
            // Just retrieve them and apply consequences (ELO, stats, prizes)
            Debug.print("Applying race results simulated at race start");

            switch (race.results) {
              case (null) {
                Debug.print("Error: No results found for race " # debug_show (raceId) # " - race may not have been properly started");
                return #trappable(actionId);
              };
              case (?results) {
                if (results.size() == 0) {
                  Debug.print("Error: Empty results array for race " # debug_show (raceId));
                  return #trappable(actionId);
                };

                Debug.print("Applying race results, " # debug_show (results.size()) # " racers");

                // Settle betting pool with race results
                let rankings = Array.map<RacingSimulator.RaceResult, Nat>(
                  results,
                  func(r : RacingSimulator.RaceResult) : Nat {
                    // Extract token index from nftId
                    switch (Nat.fromText(r.nftId)) {
                      case (?idx) { idx };
                      case null { 0 }; // Should never happen
                    };
                  },
                );
                // Schedule bet settlement
                type BetSettlementInfo = {
                  raceId : Nat;
                  rankings : [Nat];
                };
                let settlementActionId = tt().setActionSync<system>(
                  Int.abs(Time.now() + 1_000_000_000), // 1 second from now
                  {
                    actionType = "bet_settlement";
                    params = to_candid (
                      {
                        raceId = raceId;
                        rankings = rankings;
                      } : BetSettlementInfo
                    );
                  },
                );
                Debug.print("Scheduled bet_settlement action " # debug_show (settlementActionId) # " for race " # debug_show (raceId));

                // Apply ELO rating changes first
                let eloResults = Array.map<RacingSimulator.RaceResult, (Text, Nat)>(
                  results,
                  func(r : RacingSimulator.RaceResult) : (Text, Nat) {
                    (r.nftId, r.position);
                  },
                );
                let eloChanges = garageManager.applyRaceEloChanges(eloResults);

                // Now update race stats (should preserve ELO from previous update)
                for (result in results.vals()) {
                  // Apply Golden faction synergy bonus to race prizes (8-25% boost)
                  let synergies = garageManager.calculateFactionSynergies(result.owner);
                  let adjustedPrize = Float.toInt(Float.fromInt(result.prizeAmount) * synergies.yieldMultipliers.racePrizes);

                  garageManager.recordRaceResult(
                    result.nftId,
                    result.position,
                    results.size(),
                    Int.abs(adjustedPrize),
                  );

                  // Award parts based on race terrain and position
                  // Terrain determines which part drops:
                  // - MetalRoads: SpeedChips (speed is key on roads)
                  // - ScrapHeaps: PowerCells (power to push through debris)
                  // - WastelandSand: ThrusterKits/GyroModules alternating (accel/stability in sand)

                  let partType : PokedBotsGarage.PartType = switch (race.terrain) {
                    case (#MetalRoads) { #SpeedChip };
                    case (#ScrapHeaps) { #PowerCoreFragment };
                    case (#WastelandSand) {
                      // Alternate between Thruster and Gyro based on race ID
                      if (raceId % 2 == 0) { #ThrusterKit } else { #GyroModule };
                    };
                  };

                  // Base parts awarded by race class (matches original scrap system: 1 scrap = 1 part)
                  // First upgrade costs 100 parts, achievable in ~7-15 Junker races
                  let baseParts : Nat = switch (race.raceClass) {
                    case (#Scrap) { 2 }; // Rookie: 1-6 parts per race (winner: 6, participation: 1)
                    case (#Junker) { 5 }; // Entry: 2.5-15 parts per race (winner: 15, participation: 2.5)
                    case (#Raider) { 12 }; // Mid: 6-36 parts per race (winner: 36)
                    case (#Elite) { 25 }; // High: 12.5-75 parts per race (winner: 75)
                    case (#SilentKlan) { 50 }; // Top: 25-150 parts per race (winner: 150)
                  };

                  // Position multiplier (winner gets most, last place gets least)
                  let positionMultiplier : Float = if (result.position == 1) {
                    3.0; // Winner: 3x
                  } else if (result.position == 2) {
                    2.0; // Second: 2x
                  } else if (result.position == 3) {
                    1.5; // Third: 1.5x
                  } else if (result.position <= 5) {
                    1.0; // Top 5: 1x
                  } else {
                    0.5; // Everyone else: 0.5x (participation)
                  };

                  let partsEarned = Int.abs(Float.toInt(Float.fromInt(baseParts) * positionMultiplier));
                  garageManager.addParts(result.owner, partType, partsEarned);

                  let partName = switch (partType) {
                    case (#SpeedChip) { "SpeedChips" };
                    case (#PowerCoreFragment) { "PowerCells" };
                    case (#ThrusterKit) { "ThrusterKits" };
                    case (#GyroModule) { "GyroModules" };
                    case (#UniversalPart) { "UniversalParts" };
                  };
                  Debug.print("Awarded " # debug_show (partsEarned) # " " # partName # " to " # Principal.toText(result.owner));

                  // Apply race costs (battery drain and condition wear based on race)
                  garageManager.applyRaceCosts(result.nftId, race.distance, race.trackId, result.position);

                  // Update leaderboard (convert nftId back to tokenIndex)
                  switch (Nat.fromText(result.nftId)) {
                    case (?tokenIndex) {
                      switch (garageManager.getStats(tokenIndex)) {
                        case (?botStats) {
                          let now = Time.now();
                          leaderboardManager.updateCurrentPeriods(now);

                          // Convert faction type for leaderboard
                          let leaderboardFaction : PokedBotsGarage.FactionType = botStats.faction;

                          // Calculate bot's race class from its max stats
                          let maxRating = calculateMaxRating(botStats);
                          let botRaceClass = getRaceClassFromRating(maxRating);

                          // Apply Golden faction synergy bonus to leaderboard prize tracking
                          let synergies = garageManager.calculateFactionSynergies(result.owner);
                          let adjustedPrize = Float.toInt(Float.fromInt(result.prizeAmount) * synergies.yieldMultipliers.racePrizes);

                          leaderboardManager.recordRaceResult(
                            tokenIndex,
                            result.owner,
                            result.position,
                            results.size(),
                            Int.abs(adjustedPrize),
                            1.0,
                            leaderboardFaction,
                            now,
                          );
                        };
                        case (null) {};
                      };
                    };
                    case (null) {};
                  };

                  // Schedule async prize distribution if there's a prize
                  if (result.prizeAmount > 0) {
                    let prizeActionId = tt().setActionASync<system>(
                      Int.abs(Time.now() + 5_000_000_000), // 5 seconds delay
                      {
                        actionType = "prize_distribution";
                        params = to_candid ({
                          raceId = raceId;
                          owner = result.owner;
                          amount = result.prizeAmount;
                        });
                      },
                      PRIZE_DISTRIBUTION_TIMEOUT,
                    );
                    Debug.print("Scheduled prize distribution " # debug_show (prizeActionId) # " for " # Principal.toText(result.owner));
                  };
                };

                Debug.print("Race completed successfully - " # debug_show (results.size()) # " participants updated");

                // Chain to next race in event if there is one
                switch (eventCalendar.getEventByRaceId(raceId)) {
                  case (?event) {
                    // Find current race index in event
                    let raceIndexOpt = Array.indexOf<Nat>(raceId, event.raceIds, Nat.equal);
                    switch (raceIndexOpt) {
                      case (?currentIndex) {
                        // Check if there's a next race
                        if (currentIndex + 1 < event.raceIds.size()) {
                          let nextRaceId = event.raceIds[currentIndex + 1];

                          // Backwards compatibility: Check if next race already has a start timer scheduled
                          // (from old staggered timing system)
                          let existingTimers = tt().getActionsByFilter(#ByType("race_start"));
                          var alreadyScheduled = false;
                          for ((timerId, timerAction) in existingTimers.vals()) {
                            let timerRaceIdOpt : ?Nat = from_candid (timerAction.params);
                            switch (timerRaceIdOpt) {
                              case (?timerRaceId) {
                                if (timerRaceId == nextRaceId) {
                                  alreadyScheduled := true;
                                  Debug.print("Next race " # debug_show (nextRaceId) # " already has scheduled start timer (backwards compat), skipping chain");
                                };
                              };
                              case (null) {};
                            };
                          };

                          // Also check if next race already started or completed
                          switch (raceManager.getRace(nextRaceId)) {
                            case (?nextRace) {
                              switch (nextRace.status) {
                                case (#InProgress) {
                                  alreadyScheduled := true;
                                  Debug.print("Next race " # debug_show (nextRaceId) # " already in progress, skipping chain");
                                };
                                case (#Completed) {
                                  alreadyScheduled := true;
                                  Debug.print("Next race " # debug_show (nextRaceId) # " already completed, skipping chain");
                                };
                                case (_) {};
                              };
                            };
                            case (null) {};
                          };

                          if (not alreadyScheduled) {
                            Debug.print("Chaining to next race " # debug_show (nextRaceId) # " in event " # debug_show (event.eventId));

                            // Schedule next race start after commercial break
                            let nextRaceStartTime = Time.now() + RACE_BREAK_TIME;
                            let nextRaceActionId = tt().setActionSync<system>(
                              Int.abs(nextRaceStartTime),
                              {
                                actionType = "race_start";
                                params = to_candid (nextRaceId);
                              },
                            );
                            Debug.print("Scheduled next race start " # debug_show (nextRaceActionId) # " at " # debug_show (nextRaceStartTime) # " (+" # debug_show (RACE_BREAK_TIME / 1_000_000_000) # "s)");
                          };
                        } else {
                          Debug.print("Last race in event completed");
                        };
                      };
                      case (null) {
                        Debug.print("Race not found in event race list");
                      };
                    };
                  };
                  case (null) {
                    Debug.print("Event not found for race " # debug_show (raceId));
                  };
                };
              };
            };
          };
          case (null) {
            Debug.print("Race not found: " # debug_show (raceId));
          };
        };
      };
      case (null) {
        Debug.print("Could not decode race ID");
      };
    };

    return #awaited(actionId);
  };

  /// Handle auto-complete of scavenging mission when duration expires
  func handleScavengingAutoComplete<system>(actionId : TT.ActionId, action : TT.Action) : TT.ActionId {
    Debug.print("Handling scavenging auto-complete for action " # debug_show (actionId));

    let tokenIndexOpt : ?Nat = from_candid (action.params);
    switch (tokenIndexOpt) {
      case (?tokenIndex) {
        let now = Time.now();

        // Complete mission
        switch (garageManager.completeScavengingMissionV2(tokenIndex, now)) {
          case (#ok(result)) {
            // Cancel remaining accumulation timers for this bot
            let scavengeTimers = tt().getActionsByFilter(#ByType("scavenge_accumulate"));
            for ((timerId, timerAction) in scavengeTimers.vals()) {
              let timerTokenOpt : ?Nat = from_candid (timerAction.params);
              switch (timerTokenOpt) {
                case (?timerToken) {
                  if (timerToken == tokenIndex) {
                    ignore tt().cancelActionsByIds<system>([timerId.id]);
                  };
                };
                case (null) {};
              };
            };

            Debug.print("Auto-completed scavenging for bot " # Nat.toText(tokenIndex) # ": " # Nat.toText(result.totalParts) # " parts collected");
          };
          case (#err(msg)) {
            Debug.print("Error auto-completing scavenging for bot " # Nat.toText(tokenIndex) # ": " # msg);
          };
        };
      };
      case (null) {
        Debug.print("Could not decode token index");
      };
    };

    actionId;
  };

  tt().registerExecutionListenerSync(?"scavenge_accumulate", handleScavengingAccumulation);
  tt().registerExecutionListenerSync(?"scavenge_auto_complete", handleScavengingAutoComplete);
  tt().registerExecutionListenerSync(?"upgrade_complete", handleUpgradeCompletion);
  tt().registerExecutionListenerSync(?"hourly_recharge", handleHourlyRecharge);
  tt().registerExecutionListenerSync(?"race_create", handleRaceCreation);
  tt().registerExecutionListenerSync(?"betting_pool_create", handleBettingPoolCreate);
  tt().registerExecutionListenerSync(?"race_start", handleRaceStart);
  tt().registerExecutionListenerAsync(?"race_finish", handleRaceFinish);
  tt().registerExecutionListenerAsync(?"prize_distribution", handlePrizeDistribution);
  tt().registerExecutionListenerAsync(?"bet_settlement", handleBetSettlement);

  // Create the tool context that will be passed to all tools
  transient let toolContext : ToolContext.ToolContext = {
    canisterPrincipal = Principal.fromActor(self);
    owner = owner;
    appContext = appContext;
    garageManager = garageManager;
    raceManager = raceManager;
    bettingManager = bettingManager;
    extCanister = extCanister;
    extCanisterId = extCanisterId;
    icpLedgerCanisterId = func() : ?Principal { icpLedgerCanisterId };
    getMarketplaceListings = getMarketplaceListings;
    timerTool = tt();
    getNFTMetadata = statsManager.getNFTMetadata;
    getStats = garageManager.getStats;
    getCurrentStats = garageManager.getCurrentStats;
    isInActiveRace = func(tokenIndex : Nat) : Bool {
      // Check if bot is in any active race
      let allRaces = raceManager.getAllRaces();
      let nftId = Nat.toText(tokenIndex);
      let activeRace = Array.find<RacingSimulator.Race>(
        allRaces,
        func(r) {
          let isActive = switch (r.status) {
            case (#Upcoming) { true };
            case (#InProgress) { true };
            case (_) { false };
          };
          if (not isActive) { return false };
          let hasEntry = Array.find<RacingSimulator.RaceEntry>(
            r.entries,
            func(e) { e.nftId == nftId },
          );
          Option.isSome(hasEntry);
        },
      );
      Option.isSome(activeRace);
    };
    addSponsor = raceManager.addSponsor;
    checkRegistrationWindow = func(raceId : Nat, now : Int) : Result.Result<(), Text> {
      // Check if registration is open for this race's event
      switch (eventCalendar.getEventByRaceId(raceId)) {
        case (?event) {
          if (now < event.registrationOpens) {
            let hoursUntilOpen = (event.registrationOpens - now) / (60 * 60 * 1_000_000_000);
            return #err("Registration has not opened yet. Opens in " # Nat.toText(Int.abs(hoursUntilOpen)) # " hours.");
          };
          if (now > event.registrationCloses) {
            return #err("Registration has closed for this event.");
          };
          #ok();
        };
        case (null) {
          // Race not part of an event - allow entry
          #ok();
        };
      };
    };
    checkBotInEvent = func(raceId : Nat, nftId : Text) : Result.Result<(), Text> {
      switch (eventCalendar.getEventByRaceId(raceId)) {
        case (?event) {
          // Check if bot is in any race within this event
          for (eventRaceId in event.raceIds.vals()) {
            switch (Map.get(stable_races, Map.nhash, eventRaceId)) {
              case (?eventRace) {
                for (entry in eventRace.entries.vals()) {
                  if (entry.nftId == nftId) {
                    return #err("This bot is already entered in another race in this event (Race #" # Nat.toText(eventRaceId) # ")");
                  };
                };
              };
              case (null) {};
            };
          };
          #ok();
        };
        case (null) { #ok() }; // No event, allow entry
      };
    };
  };

  // Import tool configurations from separate modules
  transient let tools : [McpTypes.Tool] = [
    HelpGetCompendium.config(),
    GarageListMyPokedBots.config(),
    MarketplaceBrowsePokedBots.config(),
    MarketplacePurchasePokedBot.config(),
    GarageInitializePokedBot.config(),
    GarageGetRobotDetails.config(),
    GarageRechargeRobot.config(),
    GarageRepairRobot.config(),
    GarageUpgradeRobot.config(),
    GarageCancelUpgrade.config(),
    GarageTransferParts.config(),
    GarageStartScavenging.config(),
    GarageCompleteScavenging.config(),
    GarageConvertParts.config(),
    RacingListRaces.config(),
    RacingEnterRace.config(),
    RacingSponsorRace.config(),
    RacingGetRaceDetails.config(),
    RacingGetBotRaces.config(),
    BettingPlaceBet.config(),
    BettingListPools.config(),
    BettingGetPoolInfo.config(),
    BettingGetMyBets.config(),
  ];

  // --- 2. CONFIGURE THE SDK ---
  transient let mcpConfig : McpTypes.McpConfig = {
    self = Principal.fromActor(self);
    allowanceUrl = ?allowanceUrl;
    serverInfo = {
      name = "pokedbots-wasteland-racing";
      title = "PokedBots Wasteland Racing";
      version = "0.4.0";
    };
    resources = resources;
    resourceReader = func(uri) {
      Map.get(appContext.resourceContents, Map.thash, uri);
    };
    tools = tools;
    toolImplementations = [
      ("help_get_compendium", HelpGetCompendium.handle(toolContext)),
      ("garage_list_my_pokedbots", GarageListMyPokedBots.handler(toolContext)),
      ("browse_pokedbots", MarketplaceBrowsePokedBots.handle(toolContext)),
      ("purchase_pokedbot", MarketplacePurchasePokedBot.handle(toolContext)),
      ("garage_initialize_pokedbot", GarageInitializePokedBot.handle(toolContext)),
      ("garage_get_robot_details", GarageGetRobotDetails.handle(toolContext)),
      ("garage_recharge_robot", GarageRechargeRobot.handle(toolContext)),
      ("garage_repair_robot", GarageRepairRobot.handle(toolContext)),
      ("garage_upgrade_robot", GarageUpgradeRobot.handle(toolContext)),
      ("garage_cancel_upgrade", GarageCancelUpgrade.handle(toolContext)),
      ("garage_transfer_parts", GarageTransferParts.handle(toolContext)),
      ("garage_start_scavenging", GarageStartScavenging.handle(toolContext)),
      ("garage_complete_scavenging", GarageCompleteScavenging.handle(toolContext)),
      ("garage_convert_parts", GarageConvertParts.handle(toolContext)),
      ("racing_list_races", RacingListRaces.handle(toolContext)),
      ("racing_enter_race", RacingEnterRace.handle(toolContext)),
      ("racing_sponsor_race", RacingSponsorRace.handle(toolContext)),
      ("racing_get_race_details", RacingGetRaceDetails.handle(toolContext)),
      ("racing_get_bot_races", RacingGetBotRaces.handle(toolContext)),
      ("betting_place_bet", BettingPlaceBet.handle(toolContext)),
      ("betting_list_pools", BettingListPools.handle(toolContext)),
      ("betting_get_pool_info", BettingGetPoolInfo.handle(toolContext)),
      ("betting_get_my_bets", BettingGetMyBets.handle(toolContext)),
    ];
    beacon = beaconContext;
  };

  // --- 3. CREATE THE SERVER LOGIC ---
  transient let mcpServer = Mcp.createServer(mcpConfig);

  // --- PUBLIC ENTRY POINTS ---

  // Do not remove these public methods below. They are required for the MCP Registry and MCP Orchestrator
  // to manage the canister upgrades and installs, handle payments, and allow owner only methods.

  /// Get the current owner of the canister.
  public query func get_owner() : async Principal { return owner };

  /// Set a new owner for the canister. Only the current owner can call this.
  public shared ({ caller }) func set_owner(new_owner : Principal) : async Result.Result<(), Payments.TreasuryError> {
    if (caller != owner) { return #err(#NotOwner) };
    owner := new_owner;
    return #ok(());
  };

  /// Set the ICP ledger canister ID. Only the current owner can call this.
  public shared ({ caller }) func set_icp_ledger(ledger_id : Principal) : async Result.Result<(), Text> {
    if (caller != owner) {
      return #err("Only the owner can set the ICP ledger canister ID");
    };
    icpLedgerCanisterId := ?ledger_id;
    return #ok(());
  };

  /// Get the currently configured ICP ledger canister ID.
  public query func get_icp_ledger() : async ?Principal {
    return icpLedgerCanisterId;
  };

  /// Set the EXT NFT canister ID. Only the current owner can call this.
  public shared ({ caller }) func set_ext_canister(canister_id : Principal) : async Result.Result<(), Text> {
    if (caller != owner) {
      return #err("Only the owner can set the EXT canister ID");
    };
    extCanisterId := canister_id;
    // Note: extCanister is transient and initialized at deployment
    // It will use the new extCanisterId on next upgrade
    // For immediate effect, canister should be upgraded after calling this
    return #ok(());
  };

  /// Get the currently configured EXT NFT canister ID.
  public query func get_ext_canister() : async Principal {
    return extCanisterId;
  };

  /// Get the canister's balance of a specific ICRC-1 token.
  public shared func get_treasury_balance(ledger_id : Principal) : async Nat {
    return await Payments.get_treasury_balance(Principal.fromActor(self), ledger_id);
  };

  /// Withdraw tokens from the canister's treasury to a specified destination.
  public shared ({ caller }) func withdraw(
    ledger_id : Principal,
    amount : Nat,
    destination : Payments.Destination,
  ) : async Result.Result<Nat, Payments.TreasuryError> {
    return await Payments.withdraw(
      caller,
      owner,
      ledger_id,
      amount,
      destination,
    );
  };

  // Helper to create the HTTP context for each request.
  private func _create_http_context() : HttpHandler.Context {
    return {
      self = Principal.fromActor(self);
      active_streams = appContext.activeStreams;
      mcp_server = mcpServer;
      streaming_callback = http_request_streaming_callback;
      // This passes the optional auth context to the handler.
      // If it's `null`, the handler will skip all auth checks.
      auth = authContext;
      http_asset_cache = ?http_assets.cache;
      mcp_path = ?"/mcp";
    };
  };

  /// Handle incoming HTTP requests.
  public query func http_request(req : SrvTypes.HttpRequest) : async SrvTypes.HttpResponse {
    let ctx : HttpHandler.Context = _create_http_context();
    // Ask the SDK to handle the request
    switch (HttpHandler.http_request(ctx, req)) {
      case (?mcpResponse) {
        // The SDK handled it, so we return its response.
        return mcpResponse;
      };
      case (null) {
        // The SDK ignored it. Now we can handle our own custom routes.
        if (req.url == "/") {
          // e.g., Serve a frontend asset
          return {
            status_code = 200;
            headers = [("Content-Type", "text/html")];
            body = Text.encodeUtf8("<h1>My Canister Frontend</h1>");
            upgrade = null;
            streaming_strategy = null;
          };
        } else {
          // Return a 404 for any other unhandled routes.
          return {
            status_code = 404;
            headers = [];
            body = Blob.fromArray([]);
            upgrade = null;
            streaming_strategy = null;
          };
        };
      };
    };
  };

  /// Handle incoming HTTP requests that modify state (e.g., POST).
  public shared func http_request_update(req : SrvTypes.HttpRequest) : async SrvTypes.HttpResponse {
    let ctx : HttpHandler.Context = _create_http_context();

    // Ask the SDK to handle the request
    let mcpResponse = await HttpHandler.http_request_update(ctx, req);

    switch (mcpResponse) {
      case (?res) {
        // The SDK handled it.
        return res;
      };
      case (null) {
        // The SDK ignored it. Handle custom update calls here.
        return {
          status_code = 404;
          headers = [];
          body = Blob.fromArray([]);
          upgrade = null;
          streaming_strategy = null;
        };
      };
    };
  };

  /// Handle streaming callbacks for large HTTP responses.
  public query func http_request_streaming_callback(token : HttpTypes.StreamingToken) : async ?HttpTypes.StreamingCallbackResponse {
    let ctx : HttpHandler.Context = _create_http_context();
    return HttpHandler.http_request_streaming_callback(ctx, token);
  };

  // --- NFT METADATA PUBLIC METHODS ---

  /// Upload trait schema (owner only, done once)
  public shared ({ caller }) func upload_trait_schema(
    schemaData : Stats.TraitSchema
  ) : async Result.Result<(), Text> {
    if (caller != owner) {
      return #err("Only the owner can upload schema");
    };
    statsManager.setSchema(schemaData);
    #ok(());
  };

  /// Upload NFT stats in batch (owner only for security)
  /// Stats are stored as raw integer arrays [type_id, body_id, driver_id, ...]
  public shared ({ caller }) func upload_nft_stats_batch(
    batch : [(Nat, Stats.NFTStats)]
  ) : async Result.Result<(), Text> {
    if (caller != owner) {
      return #err("Only the owner can upload stats");
    };
    statsManager.addBatchStats(batch);
    #ok(());
  };

  /// Get raw stats for a specific NFT (returns integer array)
  public query func get_nft_stats(tokenId : Nat) : async ?Stats.NFTStats {
    statsManager.getNFTStats(tokenId);
  };

  /// Get decoded metadata for a specific NFT (public query)
  public query func get_nft_metadata(tokenId : Nat) : async ?Stats.NFTMetadata {
    statsManager.getNFTMetadata(tokenId);
  };

  /// Get metadata by EXT token identifier (public query)
  public query func get_nft_metadata_by_identifier(tokenIdentifier : Text) : async ?Stats.NFTMetadata {
    statsManager.getNFTMetadataByIdentifier(tokenIdentifier);
  };

  /// Get raw stats by EXT token identifier (public query)
  public query func get_nft_stats_by_identifier(tokenIdentifier : Text) : async ?Stats.NFTStats {
    statsManager.getNFTStatsByIdentifier(tokenIdentifier);
  };

  /// Decode EXT token identifier to get token index (public query)
  public query func decode_token_identifier(tokenIdentifier : Text) : async Nat {
    Nat32.toNat(Stats.getTokenIndex(tokenIdentifier));
  };

  /// Encode token index to EXT token identifier (public query)
  public query func encode_token_identifier(tokenIndex : Nat32) : async Text {
    ExtIntegration.encodeTokenIdentifier(tokenIndex, extCanisterId);
  };

  /// Get decoded metadata for multiple NFTs in one call (public query)
  public query func get_nft_metadata_batch(tokenIds : [Nat]) : async [(Nat, ?Stats.NFTMetadata)] {
    statsManager.getBatchMetadata(tokenIds);
  };

  /// Get paginated NFT metadata (decoded, public query)
  public query func get_nft_metadata_page(offset : Nat, limit : Nat) : async [(Nat, Stats.NFTMetadata)] {
    statsManager.getStatsPage(offset, limit);
  };

  /// Get the trait schema (public query)
  public query func get_trait_schema() : async Stats.TraitSchema {
    statsManager.getSchema();
  };

  /// Get total count of NFTs with metadata stored
  public query func get_total_nft_count() : async Nat {
    statsManager.getTotalCount();
  };

  /// Get all token IDs that have metadata
  public query func get_all_token_ids() : async [Nat] {
    statsManager.getAllTokenIds();
  };

  /// Get enriched marketplace listings with racing stats (public query)
  /// Takes a list of token indices to enrich (no inter-canister calls in queries)
  public query func get_marketplace_bots_enriched(tokenIndices : [Nat32]) : async [{
    tokenIndex : Nat32;
    isInitialized : Bool;
    racingStats : ?{
      faction : Text;
      currentSpeed : Nat;
      currentPowerCore : Nat;
      currentAcceleration : Nat;
      currentStability : Nat;
      baseSpeed : Nat;
      basePowerCore : Nat;
      baseAcceleration : Nat;
      baseStability : Nat;
      baseRating : Nat;
      currentRating : Nat;
      overallRating : Nat;
      racesEntered : Nat;
      wins : Nat;
      places : Nat;
      shows : Nat;
      winRate : Float;
      battery : Nat;
      condition : Nat;
    };
    baseStats : {
      speed : Nat;
      powerCore : Nat;
      acceleration : Nat;
      stability : Nat;
    };
  }] {
    Array.map<Nat32, { tokenIndex : Nat32; isInitialized : Bool; racingStats : ?{ faction : Text; currentSpeed : Nat; currentPowerCore : Nat; currentAcceleration : Nat; currentStability : Nat; baseSpeed : Nat; basePowerCore : Nat; baseAcceleration : Nat; baseStability : Nat; baseRating : Nat; currentRating : Nat; overallRating : Nat; racesEntered : Nat; wins : Nat; places : Nat; shows : Nat; winRate : Float; battery : Nat; condition : Nat }; baseStats : { speed : Nat; powerCore : Nat; acceleration : Nat; stability : Nat } }>(
      tokenIndices,
      func(tokenIndex : Nat32) {
        let tokenIndexNat = Nat32.toNat(tokenIndex);

        // Get base stats
        let baseStats = garageManager.getBaseStats(tokenIndexNat);

        // Try to get racing stats
        let maybeRacingStats = garageManager.getStats(tokenIndexNat);

        let racingStatsInfo = switch (maybeRacingStats) {
          case (?stats) {
            // Calculate max stats (base + upgrades only, no penalties, no garage auras)
            let maxStats = {
              speed = baseStats.speed + stats.speedBonus;
              powerCore = baseStats.powerCore + stats.powerCoreBonus;
              acceleration = baseStats.acceleration + stats.accelerationBonus;
              stability = baseStats.stability + stats.stabilityBonus;
            };

            // Calculate base rating (from base stats only)
            let baseRating = (baseStats.speed + baseStats.powerCore + baseStats.acceleration + baseStats.stability) / 4;

            // Calculate current rating (from max stats: base + upgrades)
            let currentRating = (maxStats.speed + maxStats.powerCore + maxStats.acceleration + maxStats.stability) / 4;

            let winRate = if (stats.racesEntered > 0) {
              Float.fromInt(stats.wins) / Float.fromInt(stats.racesEntered) * 100.0;
            } else { 0.0 };

            let factionText = switch (stats.faction) {
              case (#UltimateMaster) { "UltimateMaster" };
              case (#Wild) { "Wild" };
              case (#Golden) { "Golden" };
              case (#Ultimate) { "Ultimate" };
              case (#Blackhole) { "Blackhole" };
              case (#Dead) { "Dead" };
              case (#Master) { "Master" };
              case (#Bee) { "Bee" };
              case (#Food) { "Food" };
              case (#Box) { "Box" };
              case (#Murder) { "Murder" };
              case (#Game) { "Game" };
              case (#Animal) { "Animal" };
              case (#Industrial) { "Industrial" };
            };

            ?{
              faction = factionText;
              currentSpeed = maxStats.speed;
              currentPowerCore = maxStats.powerCore;
              currentAcceleration = maxStats.acceleration;
              currentStability = maxStats.stability;
              baseSpeed = baseStats.speed;
              basePowerCore = baseStats.powerCore;
              baseAcceleration = baseStats.acceleration;
              baseStability = baseStats.stability;
              baseRating = baseRating;
              currentRating = currentRating;
              overallRating = currentRating;
              racesEntered = stats.racesEntered;
              wins = stats.wins;
              places = stats.places;
              shows = stats.shows;
              winRate = winRate;
              battery = stats.battery;
              condition = stats.condition;
            };
          };
          case (null) { null };
        };

        {
          tokenIndex = tokenIndex;
          isInitialized = switch (maybeRacingStats) {
            case (?_) { true };
            case (null) { false };
          };
          racingStats = racingStatsInfo;
          baseStats = baseStats;
        };
      },
    );
  };

  /// Debug: Test simulate a race with specific bots and track
  /// Returns backend-calculated times for validation
  public query func debug_test_simulation(
    tokenIndexes : [Nat],
    trackId : Nat,
    trackSeed : Nat,
  ) : async ?{
    results : [{
      tokenIndex : Nat;
      finalTime : Float;
    }];
  } {
    // Get track to determine terrain
    let trackOpt = RacingSimulator.getTrack(trackId);
    let terrain = switch (trackOpt) {
      case (?track) { track.primaryTerrain };
      case (null) { #ScrapHeaps }; // Fallback
    };

    // Get stats for all bots at 100% battery/condition with terrain bonuses applied
    // This matches what the frontend simulator uses (stats from get_bot_profile + bonuses)
    let participants = Array.mapFilter<Nat, RacingSimulator.RacingParticipant>(
      tokenIndexes,
      func(tokenIndex : Nat) : ?RacingSimulator.RacingParticipant {
        let nftId = Nat.toText(tokenIndex);
        switch (garageManager.getStatsAt100WithTerrain(nftId, terrain)) {
          case (?stats) {
            ?{
              nftId = nftId;
              owner = Principal.fromText("aaaaa-aa"); // Dummy owner for test
              stats = stats;
            };
          };
          case null { null };
        };
      },
    );

    if (participants.size() == 0) {
      return null;
    };

    // Create a test race
    let distance = 15000; // 15km in meters
    let duration = raceSimulator.calculateRaceDuration(distance, terrain);

    let testRace : RacingSimulator.Race = {
      raceId = 0;
      name = "Test Simulation";
      trackId = trackId;
      trackSeed = trackSeed;
      distance = distance;
      duration = duration;
      terrain = terrain;
      entryFee = 0;
      prizePool = 0;
      platformBonus = 0;
      platformTax = 0;
      maxEntries = 20;
      minEntries = 2;
      startTime = 0;
      entryDeadline = 0;
      status = #InProgress;
      entries = [];
      results = null;
      events = [];
      createdAt = 0;
      raceClass = #Junker;
      sponsors = [];
    };

    // Simulate the race
    switch (raceSimulator.simulateRaceSegmented(testRace, participants)) {
      case (?(results, _events)) {
        let formattedResults = Array.map<RacingSimulator.RaceResult, { tokenIndex : Nat; finalTime : Float }>(
          results,
          func(result : RacingSimulator.RaceResult) : {
            tokenIndex : Nat;
            finalTime : Float;
          } {
            let tokenIndex = switch (Nat.fromText(result.nftId)) {
              case (?idx) { idx };
              case null { 0 };
            };
            {
              tokenIndex = tokenIndex;
              finalTime = result.finalTime;
            };
          },
        );
        ?{ results = formattedResults };
      };
      case null { null };
    };
  };

  // --- RACE HISTORY ---

  /// Get all completed races with their results for analysis
  public query func get_completed_races(limit : Nat) : async [{
    raceId : Nat;
    name : Text;
    terrain : RacingSimulator.Terrain;
    distance : Nat;
    raceClass : RacingSimulator.RaceClass;
    trackId : Nat;
    trackSeed : Nat;
    entryCount : Nat;
    results : ?[{
      position : Nat;
      nftId : Text;
      finalTime : Float;
    }];
  }] {
    let allRaces = raceManager.getAllRaces();

    // Filter only completed races with results
    let completedRaces = Array.filter<RacingSimulator.Race>(
      allRaces,
      func(race) {
        switch (race.status) {
          case (#Completed) { Option.isSome(race.results) };
          case (_) { false };
        };
      },
    );

    // Take only the requested number
    let limited = if (completedRaces.size() > limit) {
      Array.tabulate<RacingSimulator.Race>(limit, func(i) { completedRaces[i] });
    } else {
      completedRaces;
    };

    // Map to output format
    Array.map<RacingSimulator.Race, { raceId : Nat; name : Text; terrain : RacingSimulator.Terrain; distance : Nat; raceClass : RacingSimulator.RaceClass; trackId : Nat; trackSeed : Nat; entryCount : Nat; results : ?[{ position : Nat; nftId : Text; finalTime : Float }] }>(
      limited,
      func(race) {
        let mappedResults = switch (race.results) {
          case (?results) {
            ?Array.map<RacingSimulator.RaceResult, { position : Nat; nftId : Text; finalTime : Float }>(
              results,
              func(r) {
                {
                  position = r.position;
                  nftId = r.nftId;
                  finalTime = r.finalTime;
                };
              },
            );
          };
          case (null) { null };
        };

        {
          raceId = race.raceId;
          name = race.name;
          terrain = race.terrain;
          distance = race.distance;
          raceClass = race.raceClass;
          trackId = race.trackId;
          trackSeed = race.trackSeed;
          entryCount = race.entries.size();
          results = mappedResults;
        };
      },
    );
  };

  // --- SIMULATION TESTING ---

  /// Test/debug: Simulate a race with specific bots on a specific track
  /// Returns detailed results for balance testing
  public query func debug_simulate_race(
    trackId : Nat,
    tokenIndices : [Nat],
    seed : Nat,
  ) : async ?{
    track : {
      trackId : Nat;
      name : Text;
      description : Text;
      totalDistance : Nat;
      laps : Nat;
      segmentCount : Nat;
    };
    participants : [{
      tokenIndex : Nat;
      stats : {
        speed : Nat;
        powerCore : Nat;
        acceleration : Nat;
        stability : Nat;
      };
    }];
    results : [{
      tokenIndex : Nat;
      position : Nat;
      finalTime : Float;
      avgSegmentTime : Float;
    }];
    analysis : {
      winner : Nat;
      winnerTime : Float;
      lastPlaceTime : Float;
      timeSpread : Float;
      avgTime : Float;
    };
  } {
    // Get track
    let trackOpt = RacingSimulator.getTrack(trackId);
    let track = switch (trackOpt) {
      case (?t) { t };
      case (null) { return null };
    };

    // Build participants from token indices
    var participants : [RacingSimulator.RacingParticipant] = [];
    var participantData : [{
      tokenIndex : Nat;
      stats : {
        speed : Nat;
        powerCore : Nat;
        acceleration : Nat;
        stability : Nat;
      };
    }] = [];

    for (tokenIndex in tokenIndices.vals()) {
      let nftId = Nat.toText(tokenIndex);
      // Get stats at 100% with terrain bonuses (matches actual race simulation)
      switch (garageManager.getStatsAt100WithTerrain(nftId, track.primaryTerrain)) {
        case (?statsAt100) {
          let participant : RacingSimulator.RacingParticipant = {
            nftId = nftId;
            owner = Principal.fromText("aaaaa-aa"); // Dummy principal for simulation
            stats = statsAt100;
          };

          participants := Array.append(participants, [participant]);
          participantData := Array.append(
            participantData,
            [{
              tokenIndex = tokenIndex;
              stats = statsAt100;
            }],
          );
        };
        case (null) {
          // Skip uninitialized bots
        };
      };
    };

    if (participants.size() < 2) {
      return null;
    };

    // Create mock race
    let mockRace : RacingSimulator.Race = {
      raceId = 999999;
      name = "Debug Test Race";
      distance = track.totalDistance / 1000; // Convert meters to km
      terrain = track.primaryTerrain;
      trackId = trackId;
      trackSeed = seed; // Use provided seed for reproducibility testing
      raceClass = #Elite;
      entryFee = 0;
      maxEntries = 20;
      minEntries = 2;
      startTime = Time.now();
      duration = 300;
      entryDeadline = Time.now();
      createdAt = Time.now();
      entries = [];
      status = #InProgress;
      results = null;
      events = [];
      prizePool = 0;
      platformTax = 0;
      platformBonus = 0;
      sponsors = [];
    };

    // Simulate the race
    let simulator = RacingSimulator.RaceSimulator();
    switch (simulator.simulateRaceSegmented(mockRace, participants)) {
      case (?(results, _events)) {
        // Calculate analysis
        var totalTime : Float = 0.0;
        var fastestTime : Float = 999999.0;
        var slowestTime : Float = 0.0;
        var winnerIndex : Nat = 0;

        var resultData : [{
          tokenIndex : Nat;
          position : Nat;
          finalTime : Float;
          avgSegmentTime : Float;
        }] = [];

        let totalSegments = track.segments.size() * track.laps;

        for (result in results.vals()) {
          let tokenIndex = switch (Nat.fromText(result.nftId)) {
            case (?idx) { idx };
            case (null) { 0 };
          };

          if (result.finalTime < 999999.0) {
            // Not DNF
            totalTime += result.finalTime;
            if (result.finalTime < fastestTime) {
              fastestTime := result.finalTime;
              winnerIndex := tokenIndex;
            };
            if (result.finalTime > slowestTime) {
              slowestTime := result.finalTime;
            };
          };

          resultData := Array.append(
            resultData,
            [{
              tokenIndex = tokenIndex;
              position = result.position;
              finalTime = result.finalTime;
              avgSegmentTime = if (totalSegments > 0) {
                result.finalTime / Float.fromInt(totalSegments);
              } else { 0.0 };
            }],
          );
        };

        let avgTime = if (results.size() > 0) {
          totalTime / Float.fromInt(results.size());
        } else { 0.0 };

        ?{
          track = {
            trackId = track.trackId;
            name = track.name;
            description = track.description;
            totalDistance = track.totalDistance;
            laps = track.laps;
            segmentCount = track.segments.size();
          };
          participants = participantData;
          results = resultData;
          analysis = {
            winner = winnerIndex;
            winnerTime = fastestTime;
            lastPlaceTime = slowestTime;
            timeSpread = slowestTime - fastestTime;
            avgTime = avgTime;
          };
        };
      };
      case (null) { null };
    };
  };

  /// Test/debug: Get all available tracks
  public query func debug_get_all_tracks() : async [{
    trackId : Nat;
    name : Text;
    description : Text;
    totalDistance : Nat;
    primaryTerrain : RacingSimulator.Terrain;
    laps : Nat;
    segmentCount : Nat;
  }] {
    let trackIds = [1, 2, 3, 4, 5];
    var tracks : [{
      trackId : Nat;
      name : Text;
      description : Text;
      totalDistance : Nat;
      primaryTerrain : RacingSimulator.Terrain;
      laps : Nat;
      segmentCount : Nat;
    }] = [];

    for (id in trackIds.vals()) {
      switch (RacingSimulator.getTrack(id)) {
        case (?track) {
          tracks := Array.append(
            tracks,
            [{
              trackId = track.trackId;
              name = track.name;
              description = track.description;
              totalDistance = track.totalDistance;
              primaryTerrain = track.primaryTerrain;
              laps = track.laps;
              segmentCount = track.segments.size();
            }],
          );
        };
        case (null) {};
      };
    };

    tracks;
  };

  /// Get a specific trait value ID by trait index (for calculations)
  public query func get_nft_trait_value(tokenId : Nat, traitIndex : Nat) : async ?Nat {
    statsManager.getTraitValue(tokenId, traitIndex);
  };

  /// Get a decoded trait value by trait name (for display)
  public query func get_nft_trait(tokenId : Nat, traitName : Text) : async ?Text {
    statsManager.getTraitValueByName(tokenId, traitName);
  };

  /// Get public bot profile (stats + career, no sensitive info like battery/condition)
  public query func get_bot_profile(tokenIndex : Nat) : async ?{
    tokenIndex : Nat;
    name : ?Text;
    owner : ?Principal;
    faction : ?PokedBotsGarage.FactionType;
    raceClass : ?RacingSimulator.RaceClass;
    preferredTerrain : ?RacingSimulator.Terrain;
    stats : {
      speed : Nat;
      powerCore : Nat;
      acceleration : Nat;
      stability : Nat;
      overallRating : Nat;
    };
    career : {
      racesEntered : Nat;
      wins : Nat;
      podiums : Nat;
      totalEarnings : Nat;
    };
    eloRating : ?Nat;
    isInitialized : Bool;
  } {
    switch (garageManager.getStats(tokenIndex)) {
      case (?botStats) {
        // Show stats at 100% (no battery/condition penalties visible to others)
        let baseStats = garageManager.getBaseStats(tokenIndex);
        let statsAt100 = {
          speed = baseStats.speed + botStats.speedBonus;
          powerCore = baseStats.powerCore + botStats.powerCoreBonus;
          acceleration = baseStats.acceleration + botStats.accelerationBonus;
          stability = baseStats.stability + botStats.stabilityBonus;
        };
        // Calculate rating based on stats at 100%
        let totalStats = statsAt100.speed + statsAt100.powerCore + statsAt100.acceleration + statsAt100.stability;
        let rating = totalStats / 4;
        let raceClass = getRaceClassFromRating(rating);

        ?{
          tokenIndex = tokenIndex;
          name = botStats.name;
          owner = ?botStats.ownerPrincipal;
          faction = ?botStats.faction;
          raceClass = ?raceClass;
          preferredTerrain = ?botStats.preferredTerrain;
          stats = {
            speed = statsAt100.speed;
            powerCore = statsAt100.powerCore;
            acceleration = statsAt100.acceleration;
            stability = statsAt100.stability;
            overallRating = rating;
          };
          career = {
            racesEntered = botStats.racesEntered;
            wins = botStats.wins;
            podiums = Nat.add(botStats.wins, Nat.add(botStats.places, botStats.shows));
            totalEarnings = botStats.totalScrapEarned;
          };
          eloRating = ?botStats.eloRating;
          isInitialized = true;
        };
      };
      case (null) {
        // Bot not initialized - return base stats only with faction info
        let baseStats = garageManager.getBaseStats(tokenIndex);
        let totalBaseStats = baseStats.speed + baseStats.powerCore + baseStats.acceleration + baseStats.stability;
        let baseRating = totalBaseStats / 4;

        // Get faction from precomputed stats
        let precomputedStats = Map.get(stable_base_stats, Map.nhash, tokenIndex);
        let faction = switch (precomputedStats) {
          case (?stats) { ?stats.faction };
          case (null) { null };
        };

        ?{
          tokenIndex = tokenIndex;
          name = null;
          owner = null;
          faction = faction;
          raceClass = null;
          preferredTerrain = null;
          stats = {
            speed = baseStats.speed;
            powerCore = baseStats.powerCore;
            acceleration = baseStats.acceleration;
            stability = baseStats.stability;
            overallRating = baseRating;
          };
          career = {
            racesEntered = 0;
            wins = 0;
            podiums = 0;
            totalEarnings = 0;
          };
          eloRating = null;
          isInitialized = false;
        };
      };
    };
  };

  // ===== PRE-COMPUTED BASE STATS UPLOAD =====

  /// Upload a batch of pre-computed base stats
  public shared (msg) func upload_base_stats_batch(
    batch : [(Nat, { speed : Nat; powerCore : Nat; acceleration : Nat; stability : Nat; faction : Text })]
  ) : async () {
    if (msg.caller != owner) {
      Debug.trap("Only the owner can upload base stats");
    };

    for ((tokenId, stats) in batch.vals()) {
      // Convert faction text to FactionType
      let factionType : PokedBotsGarage.FactionType = switch (stats.faction) {
        case ("UltimateMaster") { #UltimateMaster };
        case ("Ultimate-master") { #UltimateMaster }; // Handle hyphenated variant
        case ("Wild") { #Wild };
        case ("Golden") { #Golden };
        case ("Ultimate") { #Ultimate };
        case ("Blackhole") { #Blackhole };
        case ("Dead") { #Dead };
        case ("Master") { #Master };
        case ("Bee") { #Bee };
        case ("Food") { #Food };
        case ("Box") { #Box };
        case ("Murder") { #Murder };
        case ("Game") { #Game };
        case ("Animal") { #Animal };
        case ("Industrial") { #Industrial };
        case (_) { #Industrial }; // Default to Industrial
      };

      ignore Map.put(
        stable_base_stats,
        Map.nhash,
        tokenId,
        {
          speed = stats.speed;
          powerCore = stats.powerCore;
          acceleration = stats.acceleration;
          stability = stats.stability;
          faction = factionType;
        },
      );
    };
  };

  /// Get total count of pre-computed base stats
  public query func get_base_stats_count() : async Nat {
    Map.size(stable_base_stats);
  };

  // Tracing functions
  public query func get_reconstitution_traces() : async [TT.ReconstitutionTrace] {
    tt().getReconstitutionTraces();
  };

  public query func get_latest_reconstitution_trace() : async ?TT.ReconstitutionTrace {
    tt().getLatestReconstitutionTrace();
  };

  public shared func clear_reconstitution_traces() : async () {
    tt().clearReconstitutionTraces();
  };

  public query func validate_timer_state() : async [Text] {
    tt().validateTimerState();
  };

  public query func get_timer_diagnostics() : async TT.TimerDiagnostics {
    tt().getTimerDiagnostics();
  };

  // Cancellation functions
  public shared func cancel_actions_by_filter(filter : TT.ActionFilter) : async TT.CancellationResult {
    tt().cancelActionsByFilter<system>(filter);
  };

  public shared func cancel_actions_by_ids(ids : [Nat]) : async TT.CancellationResult {
    tt().cancelActionsByIds<system>(ids);
  };

  public query func get_actions_by_filter(filter : TT.ActionFilter) : async [TT.ActionDetail] {
    tt().getActionsByFilter(filter);
  };

  public shared func emergency_clear_all_timers() : async Nat {
    tt().emergencyClearAllTimers<system>();
  };

  public shared func force_system_timer_cancel() : async Bool {
    tt().forceSystemTimerCancel();
  };

  public shared func force_release_lock() : async ?Time.Time {
    tt().forceReleaseLock();
  };

  // ===== LEADERBOARD QUERY FUNCTIONS =====

  // Get leaderboard by type
  public query func get_leaderboard(
    lbType : Leaderboard.LeaderboardType,
    limit : Nat,
    bracket : ?RacingSimulator.RaceClass,
  ) : async [Leaderboard.LeaderboardEntry] {
    leaderboardManager.getLeaderboard(lbType, ?limit, bracket);
  };

  // Get leaderboard entry for a specific bot
  public query func get_my_ranking(
    lbType : Leaderboard.LeaderboardType,
    tokenIndex : Nat,
  ) : async ?Leaderboard.LeaderboardEntry {
    leaderboardManager.getEntryForBot(lbType, tokenIndex);
  };

  // Get current season and month IDs
  public query func get_current_periods() : async {
    seasonId : Nat;
    monthId : Nat;
  } {
    {
      seasonId = leaderboardManager.getCurrentSeasonId();
      monthId = leaderboardManager.getCurrentMonthId();
    };
  };

  // Get upcoming scheduled events
  public query func get_upcoming_events(daysAhead : Nat) : async [RaceCalendar.ScheduledEvent] {
    let now = Time.now();
    eventCalendar.getUpcomingEvents(now, daysAhead);
  };

  // Get upcoming events with race summaries
  public query func get_upcoming_events_with_races(daysAhead : Nat) : async [{
    event : RaceCalendar.ScheduledEvent;
    raceSummary : {
      totalRaces : Nat;
      terrains : [RacingSimulator.Terrain];
      distances : [Nat];
      totalParticipants : Nat;
    };
  }] {
    let now = Time.now();
    let events = eventCalendar.getUpcomingEvents(now, daysAhead);

    Array.map<RaceCalendar.ScheduledEvent, { event : RaceCalendar.ScheduledEvent; raceSummary : { totalRaces : Nat; terrains : [RacingSimulator.Terrain]; distances : [Nat]; totalParticipants : Nat } }>(
      events,
      func(event) {
        var terrains : [RacingSimulator.Terrain] = [];
        var distances : [Nat] = [];
        var totalParticipants : Nat = 0;

        for (raceId in event.raceIds.vals()) {
          switch (raceManager.getRace(raceId)) {
            case (?race) {
              terrains := Array.append(terrains, [race.terrain]);
              distances := Array.append(distances, [race.distance]);
              totalParticipants += race.entries.size();
            };
            case (null) {};
          };
        };

        {
          event = event;
          raceSummary = {
            totalRaces = event.raceIds.size();
            terrains = terrains;
            distances = distances;
            totalParticipants = totalParticipants;
          };
        };
      },
    );
  };

  // Get past events (paginated)
  public query func get_past_events(offset : Nat, limit : Nat) : async [RaceCalendar.ScheduledEvent] {
    let now = Time.now();
    eventCalendar.getPastEvents(now, offset, limit);
  };

  // Get all events
  public query func get_all_scheduled_events() : async [RaceCalendar.ScheduledEvent] {
    eventCalendar.getAllEvents();
  };

  // Get event details by ID
  public query func get_event_details(eventId : Nat) : async ?RaceCalendar.ScheduledEvent {
    eventCalendar.getEvent(eventId);
  };

  // Get event with aggregated race details
  public query func get_event_with_races(eventId : Nat) : async ?{
    event : RaceCalendar.ScheduledEvent;
    races : [{
      raceId : Nat;
      name : Text;
      distance : Nat;
      terrain : RacingSimulator.Terrain;
      raceClass : RacingSimulator.RaceClass;
      entryFee : Nat;
      currentEntries : Nat;
      maxEntries : Nat;
      participantTokens : [Nat];
    }];
  } {
    switch (eventCalendar.getEvent(eventId)) {
      case (null) { null };
      case (?event) {
        var raceDetails : [{
          raceId : Nat;
          name : Text;
          distance : Nat;
          terrain : RacingSimulator.Terrain;
          raceClass : RacingSimulator.RaceClass;
          entryFee : Nat;
          currentEntries : Nat;
          maxEntries : Nat;
          participantTokens : [Nat];
        }] = [];

        for (raceId in event.raceIds.vals()) {
          switch (raceManager.getRace(raceId)) {
            case (?race) {
              // Extract token indices from entries
              let tokens = Array.map<RacingSimulator.RaceEntry, Nat>(
                race.entries,
                func(entry) {
                  // Parse token index from nftId (format: "token_123")
                  let parts = Text.split(entry.nftId, #char '_');
                  var tokenIndex : Nat = 0;
                  for (part in parts) {
                    switch (Nat.fromText(part)) {
                      case (?n) { tokenIndex := n };
                      case (null) {};
                    };
                  };
                  tokenIndex;
                },
              );

              raceDetails := Array.append(
                raceDetails,
                [{
                  raceId = race.raceId;
                  name = race.name;
                  distance = race.distance;
                  terrain = race.terrain;
                  raceClass = race.raceClass;
                  entryFee = race.entryFee;
                  currentEntries = race.entries.size();
                  maxEntries = race.maxEntries;
                  participantTokens = tokens;
                }],
              );
            };
            case (null) {};
          };
        };

        ?{
          event = event;
          races = raceDetails;
        };
      };
    };
  };

  // Get race details by race ID
  public query func get_race_by_id(raceId : Nat) : async ?RacingSimulator.Race {
    raceManager.getRace(raceId);
  };

  // Debug: Regenerate commentary for a completed race
  public shared ({ caller }) func debug_regenerate_race_commentary(raceId : Nat) : async Result.Result<Text, Text> {
    if (caller != owner) {
      return #err("Unauthorized: Only owner can regenerate commentary");
    };

    let ?race = Map.get(stable_races, Map.nhash, raceId) else {
      return #err("Race not found");
    };

    // Only regenerate for completed races
    switch (race.status) {
      case (#Completed) {};
      case (_) {
        return #err("Can only regenerate commentary for completed races");
      };
    };

    // Verify race has results
    let ?results = race.results else {
      return #err("Race has no results to generate commentary from");
    };

    // Use original entries to maintain deterministic simulation order
    // The simulation is seeded and depends on participant order
    let participants = Array.map<RacingSimulator.RaceEntry, RacingSimulator.RacingParticipant>(
      race.entries,
      func(entry) : RacingSimulator.RacingParticipant {
        {
          nftId = entry.nftId;
          owner = entry.owner;
          stats = Option.get(entry.stats, { speed = 100; stability = 100; powerCore = 100; acceleration = 100 });
        };
      },
    );

    // Call simulator with existing race data to regenerate events
    let ?(_, newEvents) = raceSimulator.simulateRaceSegmented(race, participants) else {
      return #err("Failed to regenerate commentary");
    };

    // Update race with new events
    let updatedRace : RacingSimulator.Race = {
      raceId = race.raceId;
      name = race.name;
      distance = race.distance;
      terrain = race.terrain;
      trackId = race.trackId;
      trackSeed = race.trackSeed;
      raceClass = race.raceClass;
      entryFee = race.entryFee;
      maxEntries = race.maxEntries;
      minEntries = race.minEntries;
      startTime = race.startTime;
      duration = race.duration;
      entryDeadline = race.entryDeadline;
      createdAt = race.createdAt;
      entries = race.entries;
      status = race.status;
      results = race.results;
      events = newEvents; // Updated commentary
      prizePool = race.prizePool;
      platformTax = race.platformTax;
      platformBonus = race.platformBonus;
      sponsors = race.sponsors;
    };

    ignore Map.put(stable_races, Map.nhash, raceId, updatedRace);

    #ok("Successfully regenerated commentary for race " # Nat.toText(raceId) # " with " # Nat.toText(newEvents.size()) # " events (was " # Nat.toText(race.events.size()) # ")");
  };

  // Get race history for a specific bot
  public query func get_bot_race_history(tokenIndex : Nat, limit : Nat, afterRaceId : ?Nat) : async {
    races : [{
      eventId : Nat;
      eventName : Text;
      scheduledTime : Int;
      raceId : Nat;
      raceName : Text;
      position : Nat;
      totalRacers : Nat;
      finalTime : ?Float;
      prizeAmount : Nat;
    }];
    hasMore : Bool;
    nextRaceId : ?Nat;
  } {
    let allRaces = raceManager.getAllRaces();
    var history : [{
      eventId : Nat;
      eventName : Text;
      scheduledTime : Int;
      raceId : Nat;
      raceName : Text;
      position : Nat;
      totalRacers : Nat;
      finalTime : ?Float;
      prizeAmount : Nat;
    }] = [];

    let nftId = Nat.toText(tokenIndex);

    // Iterate through races in reverse (newest first)
    let racesArray = Array.reverse(allRaces);

    // Skip races until we find the cursor (afterRaceId)
    var skipMode = switch (afterRaceId) {
      case (?_) { true };
      case null { false };
    };

    var lastRaceId : ?Nat = null;

    label raceLoop for (race in racesArray.vals()) {
      // If we're in skip mode, skip until we pass the cursor
      if (skipMode) {
        switch (afterRaceId) {
          case (?targetId) {
            if (race.raceId == targetId) {
              skipMode := false;
            };
          };
          case null {};
        };
        continue raceLoop;
      };

      if (history.size() >= limit) {
        break raceLoop;
      };

      // Only include completed races with results
      switch (race.status) {
        case (#Completed) {
          switch (race.results) {
            case (?results) {
              // Find this bot in the results
              var position : ?Nat = null;
              var finalTime : ?Float = null;
              var prizeAmount : Nat = 0;

              label resultLoop for (i in Iter.range(0, results.size() - 1)) {
                if (results[i].nftId == nftId) {
                  position := ?(i + 1);
                  finalTime := ?results[i].finalTime;
                  prizeAmount := results[i].prizeAmount;
                  break resultLoop;
                };
              };

              // If bot participated, add to history
              switch (position) {
                case (?pos) {
                  // Get event details for this race
                  let eventOpt = eventCalendar.getEventByRaceId(race.raceId);
                  switch (eventOpt) {
                    case (?event) {
                      let newEntry = {
                        eventId = event.eventId;
                        eventName = event.metadata.name;
                        scheduledTime = event.scheduledTime;
                        raceId = race.raceId;
                        raceName = race.name;
                        position = pos;
                        totalRacers = results.size();
                        finalTime = finalTime;
                        prizeAmount = prizeAmount;
                      };
                      history := Array.append(history, [newEntry]);
                      lastRaceId := ?race.raceId;
                    };
                    case null {};
                  };
                };
                case null {};
              };
            };
            case null {};
          };
        };
        case _ {};
      };
    };

    // Check if there are more races by looking ahead one more
    var hasMore = false;
    if (history.size() == limit) {
      var foundMore = false;
      label checkMoreLoop for (race in racesArray.vals()) {
        if (foundMore) { break checkMoreLoop };

        // Skip until we pass the last race we included
        switch (lastRaceId) {
          case (?lid) {
            if (race.raceId != lid) { continue checkMoreLoop };
            foundMore := true;
            continue checkMoreLoop;
          };
          case null { continue checkMoreLoop };
        };

        // Check if there's another race with this bot
        switch (race.status) {
          case (#Completed) {
            switch (race.results) {
              case (?results) {
                for (result in results.vals()) {
                  if (result.nftId == nftId) {
                    hasMore := true;
                    break checkMoreLoop;
                  };
                };
              };
              case null {};
            };
          };
          case _ {};
        };
      };
    };

    {
      races = history;
      hasMore = hasMore;
      nextRaceId = if (hasMore) { lastRaceId } else { null };
    };
  };

  // Query races with advanced filtering and pagination
  public query func query_races(
    filters : {
      // Status filters
      status : ?RacingSimulator.RaceStatus; // #Upcoming, #InProgress, #Completed, #Cancelled

      // Class and terrain filters
      raceClass : ?RacingSimulator.RaceClass;
      terrain : ?RacingSimulator.Terrain;

      // Entry filters
      minEntries : ?Nat; // Minimum current entries
      maxEntries : ?Nat; // Maximum current entries
      hasMinimumEntries : ?Bool; // Has minimum entries to run (won't be cancelled)

      // Prize pool filters
      minPrizePool : ?Nat; // Minimum total prize pool (including bonuses and sponsors)
      maxPrizePool : ?Nat; // Maximum total prize pool

      // Participant filters
      participantPrincipal : ?Principal; // Races where this principal has bots entered
      participantNftId : ?Text; // Races where this specific NFT is entered

      // Eligibility filters (requires caller principal)
      eligibleForCaller : ?{
        caller : Principal;
        eligibleOnly : Bool; // true = only races caller can enter, false = only races caller cannot enter
      };

      // Time filters
      startTimeFrom : ?Int; // Races starting after this timestamp
      startTimeTo : ?Int; // Races starting before this timestamp

      // Pagination
      limit : Nat; // Max results (1-100)
      afterRaceId : ?Nat; // Continue after this race ID
    }
  ) : async {
    races : [RacingSimulator.Race];
    hasMore : Bool;
    nextRaceId : ?Nat;
    totalMatching : Nat;
  } {
    let allRaces = raceManager.getAllRaces();
    let racesArray = Iter.toArray(allRaces.vals());

    // Determine sort order based on status filter:
    // - Upcoming/InProgress: ascending (soonest first)
    // - Completed/Cancelled: descending (newest first)
    // - No filter: descending (default to showing recent activity)
    let shouldSortAscending = switch (filters.status) {
      case (?#Upcoming) { true };
      case (?#InProgress) { true };
      case (_) { false }; // Completed, Cancelled, or no filter
    };

    let sortedRaces = Array.sort<RacingSimulator.Race>(
      racesArray,
      func(a, b) {
        if (shouldSortAscending) {
          // Ascending: soonest first
          if (a.startTime < b.startTime) { #less } else if (a.startTime > b.startTime) {
            #greater;
          } else { #equal };
        } else {
          // Descending: newest first
          if (a.startTime > b.startTime) { #less } else if (a.startTime < b.startTime) {
            #greater;
          } else { #equal };
        };
      },
    );

    // Validate limit
    let actualLimit = if (filters.limit < 1 or filters.limit > 100) { 20 } else {
      filters.limit;
    };

    var filtered : [RacingSimulator.Race] = [];
    var totalMatching : Nat = 0;
    var skipUntilRaceId : ?Nat = filters.afterRaceId;
    var foundAfterRace = switch (filters.afterRaceId) {
      case (null) { true }; // No pagination, start from beginning
      case (_) { false }; // Need to find the pagination point
    };

    label raceLoop for (race in sortedRaces.vals()) {
      // Handle pagination
      if (not foundAfterRace) {
        if (?race.raceId == filters.afterRaceId) {
          foundAfterRace := true;
        };
        continue raceLoop;
      };

      // Apply filters
      var matches = true;

      // Status filter
      switch (filters.status) {
        case (?status) {
          if (race.status != status) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      // Race class filter
      switch (filters.raceClass) {
        case (?raceClass) {
          if (race.raceClass != raceClass) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      // Terrain filter
      switch (filters.terrain) {
        case (?terrain) {
          if (race.terrain != terrain) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      // Entry count filters
      let currentEntries = race.entries.size();

      switch (filters.minEntries) {
        case (?min) {
          if (currentEntries < min) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      switch (filters.maxEntries) {
        case (?max) {
          if (currentEntries > max) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      // Has minimum entries filter (won't be cancelled)
      switch (filters.hasMinimumEntries) {
        case (?shouldHaveMin) {
          let hasMin = currentEntries >= race.minEntries;
          if (hasMin != shouldHaveMin) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      // Prize pool filters
      let totalPrizePool = race.prizePool + race.platformBonus;

      switch (filters.minPrizePool) {
        case (?min) {
          if (totalPrizePool < min) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      switch (filters.maxPrizePool) {
        case (?max) {
          if (totalPrizePool > max) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      // Participant filters
      switch (filters.participantPrincipal) {
        case (?principal) {
          var found = false;
          for (entry in race.entries.vals()) {
            if (entry.owner == principal) {
              found := true;
            };
          };
          if (not found) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      switch (filters.participantNftId) {
        case (?nftId) {
          var found = false;
          for (entry in race.entries.vals()) {
            if (entry.nftId == nftId) {
              found := true;
            };
          };
          if (not found) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      // Eligibility filter (check if caller can participate)
      switch (filters.eligibleForCaller) {
        case (?eligibilityCheck) {
          let caller = eligibilityCheck.caller;
          let eligibleOnly = eligibilityCheck.eligibleOnly;

          // Check if race is open for entries
          let isOpen = race.status == #Upcoming and currentEntries < race.maxEntries and Time.now() < race.entryDeadline;

          if (not isOpen and eligibleOnly) {
            matches := false;
          } else if (isOpen) {
            // Check if caller already has bots in this race
            var alreadyEntered = false;
            for (entry in race.entries.vals()) {
              if (entry.owner == caller) {
                alreadyEntered := true;
              };
            };

            // Get caller's bots to check if they have eligible bots
            let callerBots = garageManager.getBotsForOwner(caller);
            var hasEligibleBot = false;

            for (bot in callerBots.vals()) {
              // Check if bot's rating (max stats) matches race class
              let rating = calculateMaxRating(bot); // Use max stats, not current degraded stats
              let isEligible = switch (race.raceClass) {
                case (#Scrap) { rating < 20 };
                case (#Junker) { rating >= 20 and rating < 30 };
                case (#Raider) { rating >= 30 and rating < 40 };
                case (#Elite) { rating >= 40 and rating < 50 };
                case (#SilentKlan) { rating >= 50 };
              };

              // Check if this bot is not already entered
              var botAlreadyEntered = false;
              let nftId = Nat.toText(bot.tokenIndex);
              for (entry in race.entries.vals()) {
                if (entry.nftId == nftId) {
                  botAlreadyEntered := true;
                };
              };

              if (isEligible and not botAlreadyEntered) {
                hasEligibleBot := true;
              };
            };

            let canParticipate = hasEligibleBot;

            // Apply the eligibility filter
            if (eligibleOnly and not canParticipate) {
              matches := false;
            } else if (not eligibleOnly and canParticipate) {
              matches := false;
            };
          };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      // Time filters
      switch (filters.startTimeFrom) {
        case (?fromTime) {
          if (race.startTime < fromTime) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      switch (filters.startTimeTo) {
        case (?toTime) {
          if (race.startTime > toTime) { matches := false };
        };
        case null {};
      };

      if (not matches) { continue raceLoop };

      // If we reach here, race matches all filters
      totalMatching += 1;

      // Add to results if we haven't reached limit
      if (filtered.size() < actualLimit) {
        filtered := Array.append(filtered, [race]);
      };
    };

    // Check if there are more results
    let hasMore = totalMatching > filtered.size();
    let nextRaceId = if (hasMore and filtered.size() > 0) {
      ?filtered[filtered.size() - 1].raceId;
    } else {
      null;
    };

    {
      races = filtered;
      hasMore = hasMore;
      nextRaceId = nextRaceId;
      totalMatching = totalMatching;
    };
  };

  // ===== DEBUG/ADMIN FUNCTIONS =====

  // Update minimum racer requirement for a specific race
  public shared ({ caller }) func admin_update_race_min_entries(raceId : Nat, minEntries : Nat) : async Text {
    if (caller != owner) {
      Debug.trap("Only owner can update race requirements");
    };

    switch (raceManager.getRace(raceId)) {
      case (?race) {
        switch (race.status) {
          case (#Upcoming) {
            // Update the race directly in the map
            let updatedRace = {
              race with
              minEntries = minEntries;
            };
            Map.set(raceManager.getRacesMap(), Map.nhash, raceId, updatedRace);
            "Successfully updated race " # Nat.toText(raceId) # " minEntries to " # Nat.toText(minEntries);
          };
          case (_) {
            "Error: Can only update minEntries for Upcoming races";
          };
        };
      };
      case (null) {
        "Error: Race not found";
      };
    };
  };

  /// Admin function to manually create betting pool for an existing race
  /// Useful for testing and recovery when races are created in advance
  public shared ({ caller }) func admin_create_betting_pool(raceId : Nat) : async Result.Result<Text, Text> {
    if (caller != owner) {
      return #err("Only owner can manually create betting pools");
    };

    switch (raceManager.getRace(raceId)) {
      case (?race) {
        // Check if registration is closed (entry deadline has passed)
        let now = Time.now();
        if (race.entryDeadline > now) {
          return #err("Cannot create betting pool - registration is still open (closes at " # Int.toText(race.entryDeadline / 1_000_000) # ")");
        };

        // Check if race has entries
        if (race.entries.size() == 0) {
          return #err("Race has no entries yet");
        };

        // Check if pool already exists
        switch (bettingManager.getPool(raceId)) {
          case (?_) {
            return #err("Betting pool already exists for this race");
          };
          case (null) {
            // Create the pool
            let result = bettingManager.createPool(race);
            switch (result) {
              case (#ok(_)) {
                #ok("Successfully created betting pool for race " # Nat.toText(raceId) # " with " # Nat.toText(race.entries.size()) # " entrants");
              };
              case (#err(msg)) {
                #err("Failed to create pool: " # msg);
              };
            };
          };
        };
      };
      case (null) {
        #err("Race not found");
      };
    };
  };

  // Manually cancel specific races by ID (with refunds)
  public shared ({ caller }) func cancel_races_by_ids(raceIds : [Nat]) : async [(Nat, Text)] {
    if (caller != owner) {
      Debug.trap("Only owner can cancel races");
    };

    var cancelledRaces : [(Nat, Text)] = [];

    for (raceId in raceIds.vals()) {
      switch (raceManager.getRace(raceId)) {
        case (?race) {
          if (race.status == #Upcoming) {
            ignore raceManager.updateRaceStatus(raceId, #Cancelled);

            // Refund all entries
            for (entry in race.entries.vals()) {
              let refundActionId = tt().setActionASync<system>(
                Int.abs(Time.now() + 1_000_000_000), // 1 second delay
                {
                  actionType = "prize_distribution";
                  params = to_candid ({
                    raceId = raceId;
                    owner = entry.owner;
                    amount = entry.entryFee;
                  });
                },
                PRIZE_DISTRIBUTION_TIMEOUT,
              );
              Debug.print("Scheduled refund " # debug_show (refundActionId) # " of " # debug_show (entry.entryFee) # " to " # Principal.toText(entry.owner));
            };

            // Refund all sponsors
            for (sponsor in race.sponsors.vals()) {
              let sponsorRefundActionId = tt().setActionASync<system>(
                Int.abs(Time.now() + 1_000_000_000), // 1 second delay
                {
                  actionType = "prize_distribution";
                  params = to_candid ({
                    raceId = raceId;
                    owner = sponsor.sponsor;
                    amount = sponsor.amount;
                  });
                },
                PRIZE_DISTRIBUTION_TIMEOUT,
              );
              Debug.print("Scheduled sponsor refund " # debug_show (sponsorRefundActionId) # " of " # debug_show (sponsor.amount) # " to " # Principal.toText(sponsor.sponsor));
            };

            cancelledRaces := Array.append(cancelledRaces, [(raceId, race.name)]);
          };
        };
        case (null) { /* Race doesn't exist */ };
      };
    };

    cancelledRaces;
  };

  // Manually force-finish a stuck race
  public shared ({ caller }) func force_finish_race(raceId : Nat) : async Text {
    if (caller != owner) {
      return "Unauthorized: only owner can force-finish races";
    };

    // Trigger the race finish handler directly and await completion
    let dummyActionId : TT.ActionId = { id = 0; time = Int.abs(Time.now()) };
    let result = await* handleRaceFinish<system>(
      dummyActionId,
      {
        actionType = "race_finish";
        params = to_candid (raceId);
        retries = 0;
        aSync = null;
      },
    );

    // Check if the handler succeeded
    switch (result) {
      case (#awaited(_)) {
        "Force-finished race " # Nat.toText(raceId) # " successfully";
      };
      case (#trappable(_)) {
        "Force-finish triggered for race " # Nat.toText(raceId) # " but encountered an error";
      };
      case (_) {
        "Force-finish triggered for race " # Nat.toText(raceId) # " with unknown result";
      };
    };
  };

  /// Admin method to remove a bot from a race (for fixing bugs/errors)
  public shared ({ caller }) func admin_remove_race_entry(raceId : Nat, tokenIndex : Nat) : async Result.Result<Text, Text> {
    if (caller != owner) {
      return #err("Unauthorized: only owner can remove race entries");
    };

    let race = switch (Map.get(stable_races, Map.nhash, raceId)) {
      case (?r) { r };
      case (null) { return #err("Race not found") };
    };

    let nftId = Nat.toText(tokenIndex);

    // Filter out the entry to remove
    let newEntries = Array.filter<RacingSimulator.RaceEntry>(
      race.entries,
      func(e : RacingSimulator.RaceEntry) : Bool { e.nftId != nftId },
    );

    if (newEntries.size() == race.entries.size()) {
      return #err("Bot #" # Nat.toText(tokenIndex) # " not found in race #" # Nat.toText(raceId));
    };

    // Refund entry fee to bot owner
    let removedEntry = Array.find<RacingSimulator.RaceEntry>(
      race.entries,
      func(e : RacingSimulator.RaceEntry) : Bool { e.nftId == nftId },
    );

    switch (removedEntry) {
      case (?entry) {
        // Calculate new prize pool (subtract entry fee)
        let newPrizePool = if (race.prizePool >= race.entryFee) {
          race.prizePool - race.entryFee;
        } else {
          0;
        };
        let newTax = (newPrizePool * 5) / 100;

        // Update race with removed entry
        let updatedRace = {
          race with
          entries = newEntries;
          prizePool = newPrizePool;
          platformTax = newTax;
        };

        ignore Map.put(stable_races, Map.nhash, raceId, updatedRace);

        // Issue refund
        let ledgerId = switch (icpLedgerCanisterId) {
          case (?id) { id };
          case (null) {
            return #ok("Bot removed but refund failed: ICP Ledger not configured. Manual refund required for " # Principal.toText(entry.owner));
          };
        };

        let ledger = actor (Principal.toText(ledgerId)) : actor {
          icrc1_transfer : shared IcpLedger.TransferArg -> async IcpLedger.Result;
        };

        try {
          let transferResult = await ledger.icrc1_transfer({
            from_subaccount = null;
            to = { owner = entry.owner; subaccount = null };
            amount = entry.entryFee;
            fee = ?TRANSFER_FEE;
            memo = null;
            created_at_time = null;
          });

          switch (transferResult) {
            case (#Ok(_blockIndex)) {
              #ok("Bot #" # Nat.toText(tokenIndex) # " removed from race #" # Nat.toText(raceId) # " and refunded " # Nat.toText(entry.entryFee) # " e8s");
            };
            case (#Err(err)) {
              #ok("Bot removed but refund failed: " # debug_show (err) # ". Manual refund required for " # Principal.toText(entry.owner));
            };
          };
        } catch (e) {
          #ok("Bot removed but refund failed: " # Error.message(e) # ". Manual refund required for " # Principal.toText(entry.owner));
        };
      };
      case (null) {
        #err("Entry not found");
      };
    };
  };

  // Delete events and their associated races (cleanup duplicates)
  // Internal function to delete events and races
  private func delete_events_and_races_internal(eventIds : [Nat]) : async Text {
    var deletedEvents : Nat = 0;
    var deletedRaces : Nat = 0;
    var cancelledTimers : Nat = 0;

    for (eventId in eventIds.vals()) {
      // Get event to find associated races
      switch (eventCalendar.getEvent(eventId)) {
        case (?event) {
          // Cancel all races associated with this event
          for (raceId in event.raceIds.vals()) {
            switch (raceManager.getRace(raceId)) {
              case (?race) {
                // Cancel the race if it's not completed
                if (race.status == #Upcoming or race.status == #InProgress) {
                  ignore raceManager.updateRaceStatus(raceId, #Cancelled);
                  deletedRaces += 1;

                  // Cancel any pending timers for this race
                  let raceStartActions = tt().getActionsByFilter(#ByType("race_start"));
                  for ((actionId, action) in raceStartActions.vals()) {
                    // Check if this action is for this race
                    let raceIdOpt : ?Nat = from_candid (action.params);
                    switch (raceIdOpt) {
                      case (?rid) {
                        if (rid == raceId) {
                          ignore tt().cancelAction<system>(actionId.id);
                          cancelledTimers += 1;
                        };
                      };
                      case (null) {};
                    };
                  };

                  let raceFinishActions = tt().getActionsByFilter(#ByType("race_finish"));
                  for ((actionId, action) in raceFinishActions.vals()) {
                    let raceIdOpt : ?Nat = from_candid (action.params);
                    switch (raceIdOpt) {
                      case (?rid) {
                        if (rid == raceId) {
                          ignore tt().cancelAction<system>(actionId.id);
                          cancelledTimers += 1;
                        };
                      };
                      case (null) {};
                    };
                  };
                };

                // Delete the race from storage to prevent orphans
                ignore raceManager.deleteRace(raceId);
              };
              case (null) {};
            };
          };

          // Delete the event
          if (eventCalendar.deleteEvent(eventId)) {
            deletedEvents += 1;
          };
        };
        case (null) {};
      };
    };

    "Deleted " # Nat.toText(deletedEvents) # " events, deleted " # Nat.toText(deletedRaces) # " races, and cancelled " # Nat.toText(cancelledTimers) # " timers";
  };

  // Public wrapper for delete_events_and_races
  public shared ({ caller }) func delete_events_and_races(eventIds : [Nat]) : async Text {
    if (caller != owner) {
      return "Unauthorized: only owner can delete events";
    };
    return await delete_events_and_races_internal(eventIds);
  };

  // Admin function to clear a bot's stuck active mission (useful after upgrades that change ScavengingZone type)
  public shared ({ caller }) func admin_clear_active_mission(tokenIndex : Nat) : async Text {
    if (caller != owner) {
      return "Unauthorized: only owner can clear missions";
    };

    switch (garageManager.getStats(tokenIndex)) {
      case (null) { "Bot not found" };
      case (?botStats) {
        let updatedStats = {
          botStats with
          activeMission = null;
        };
        garageManager.updateStats(tokenIndex, updatedStats);
        "Cleared active mission for bot #" # Nat.toText(tokenIndex);
      };
    };
  };

  // Admin function to debug/inspect a bot's active mission
  public shared query ({ caller }) func admin_get_active_mission(tokenIndex : Nat) : async Text {
    if (caller != owner) {
      return "Unauthorized: only owner can inspect missions";
    };

    switch (garageManager.getStats(tokenIndex)) {
      case (null) { "Bot not found" };
      case (?botStats) {
        switch (botStats.activeMission) {
          case (null) {
            "Bot #" # Nat.toText(tokenIndex) # " has NO active mission";
          };
          case (?mission) {
            let zoneName = switch (mission.zone) {
              case (#ScrapHeaps) { "ScrapHeaps" };
              case (#AbandonedSettlements) { "AbandonedSettlements" };
              case (#DeadMachineFields) { "DeadMachineFields" };
              case (#RepairBay) { "RepairBay" };
              case (#ChargingStation) { "ChargingStation" };
            };
            "Bot #" # Nat.toText(tokenIndex) # " HAS active mission:\n" #
            "  Mission ID: " # Nat.toText(mission.missionId) # "\n" #
            "  Zone: " # zoneName # "\n" #
            "  Start Time: " # Int.toText(mission.startTime) # "\n" #
            "  Last Accumulation: " # Int.toText(mission.lastAccumulation) # "\n" #
            "  Duration: " # (switch (mission.durationMinutes) { case (null) { "Continuous" }; case (?d) { Nat.toText(d) # " minutes" } }) # "\n" #
            "  Pending Parts: " # Nat.toText(mission.pendingParts.speedChips + mission.pendingParts.powerCoreFragments + mission.pendingParts.thrusterKits + mission.pendingParts.gyroModules + mission.pendingParts.universalParts) # "\n" #
            "  Pending Condition Restored: " # Nat.toText(mission.pendingConditionRestored);
          };
        };
      };
    };
  };

  // Admin function to manually trigger race start for races with missing timers
  public shared ({ caller }) func trigger_race_start(raceId : Nat) : async Text {
    if (caller != owner) {
      return "Unauthorized: only owner can trigger race start";
    };

    switch (raceManager.getRace(raceId)) {
      case (?race) {
        if (race.status != #Upcoming) {
          return "Race " # Nat.toText(raceId) # " is not in Upcoming status";
        };

        // Manually call the race start handler
        let actionId : TT.ActionId = { id = 0; time = 0 };
        let action : TT.Action = {
          actionType = "race_start";
          params = to_candid (raceId);
          aSync = null;
          retries = 0;
        };

        ignore handleRaceStart<system>(actionId, action);
        "Triggered race start for race " # Nat.toText(raceId);
      };
      case (null) {
        "Race " # Nat.toText(raceId) # " not found";
      };
    };
  };

  // Admin function to clean up duplicate hourly_recharge timers
  public shared ({ caller }) func cleanup_duplicate_recharge_timers() : async Text {
    if (caller != owner) {
      return "Unauthorized: only owner can cleanup timers";
    };

    let rechargeActions = tt().getActionsByFilter(#ByType("hourly_recharge"));
    let count = rechargeActions.size();

    if (count <= 1) {
      return "No cleanup needed. Found " # Nat.toText(count) # " recharge timer(s).";
    };

    // Find the earliest scheduled action (the one we want to keep)
    var earliestActionId : ?TT.ActionId = null;
    var earliestTime : Nat = 9999999999999999999;

    for ((actionId, _action) in rechargeActions.vals()) {
      if (actionId.time < earliestTime) {
        earliestTime := actionId.time;
        earliestActionId := ?actionId;
      };
    };

    // Cancel all actions except the earliest one
    var cancelledCount : Nat = 0;
    for ((actionId, _action) in rechargeActions.vals()) {
      switch (earliestActionId) {
        case (?earliest) {
          if (actionId.id != earliest.id) {
            ignore tt().cancelActionsByIds<system>([actionId.id]);
            cancelledCount += 1;
          };
        };
        case (null) {};
      };
    };

    "Cleaned up " # Nat.toText(cancelledCount) # " duplicate recharge timers. Kept the earliest one scheduled at " # Nat.toText(earliestTime) # ".";
  };

  // Admin function to clean up duplicate race_create timers
  public shared ({ caller }) func cleanup_duplicate_race_create_timers() : async Text {
    if (caller != owner) {
      return "Unauthorized: only owner can cleanup timers";
    };

    let raceCreateActions = tt().getActionsByFilter(#ByType("race_create"));
    let count = raceCreateActions.size();

    if (count == 0) {
      return "No race_create timers found.";
    };

    // Group actions by timestamp - we want to keep only the first action for each unique timestamp
    // Build a map of timestamp -> list of action IDs
    var timestampMap = HashMap.HashMap<Nat, [TT.ActionId]>(0, Nat.equal, Hash.hash);

    for ((actionId, _action) in raceCreateActions.vals()) {
      let timestamp = actionId.time;
      let existing = switch (timestampMap.get(timestamp)) {
        case (?ids) { ids };
        case (null) { [] };
      };
      timestampMap.put(timestamp, Array.append(existing, [actionId]));
    };

    // For each timestamp, keep the action with the lowest ID (first created), cancel the rest
    var cancelledCount : Nat = 0;
    var uniqueTimestamps : Nat = 0;

    for ((timestamp, actionIds) in timestampMap.entries()) {
      uniqueTimestamps += 1;
      if (actionIds.size() > 1) {
        // Sort by ID and keep the first one
        let sorted = Array.sort(
          actionIds,
          func(a : TT.ActionId, b : TT.ActionId) : Order.Order {
            Nat.compare(a.id, b.id);
          },
        );

        // Cancel all except the first
        for (i in Iter.range(1, sorted.size() - 1)) {
          ignore tt().cancelActionsByIds<system>([sorted[i].id]);
          cancelledCount += 1;
        };
      };
    };

    "Cleaned up " # Nat.toText(cancelledCount) # " duplicate race_create timers across " # Nat.toText(uniqueTimestamps) # " unique timestamps. Kept " # Nat.toText(uniqueTimestamps) # " timers.";
  };

  // Admin function to manually trigger race finish for stuck races
  public shared ({ caller }) func trigger_race_finish(raceId : Nat) : async Text {
    if (caller != owner) {
      return "Unauthorized: only owner can trigger race finish";
    };

    switch (raceManager.getRace(raceId)) {
      case (?race) {
        if (race.status != #InProgress) {
          return "Race " # Nat.toText(raceId) # " is not in InProgress status (current: " # debug_show (race.status) # ")";
        };

        // Manually call the race finish handler
        let actionId : TT.ActionId = { id = 0; time = 0 };
        let action : TT.Action = {
          actionType = "race_finish";
          params = to_candid (raceId);
          aSync = null;
          retries = 0;
        };

        ignore handleRaceFinish<system>(actionId, action);
        "Triggered race finish for race " # Nat.toText(raceId);
      };
      case (null) {
        "Race " # Nat.toText(raceId) # " not found";
      };
    };
  };

  // Recalculate bot stats from actual race results (fixes stats after orphan cleanup)
  public shared ({ caller }) func recalculate_bot_stats() : async Text {
    if (caller != owner) {
      return "Unauthorized: only owner can recalculate stats";
    };

    let allRaces = raceManager.getAllRaces();
    let allEvents = eventCalendar.getAllEvents();
    let now = Time.now();

    // Build a set of valid race IDs (races that belong to events)
    var validRaceIds : [Nat] = [];
    for (event in allEvents.vals()) {
      validRaceIds := Array.append(validRaceIds, event.raceIds);
    };

    // Clear all leaderboards
    leaderboardManager.clearAllLeaderboards();

    // Track stats per bot
    var botStats = Map.new<Nat, { racesEntered : Nat; wins : Nat; places : Nat; shows : Nat; totalEarnings : Nat }>();

    // Go through all completed valid races
    for (race in allRaces.vals()) {
      // Only count races that belong to events
      let isValid = Array.find<Nat>(validRaceIds, func(id) { id == race.raceId });
      if (Option.isSome(isValid) and race.status == #Completed) {
        switch (race.results) {
          case (?results) {
            for (result in results.vals()) {
              switch (Nat.fromText(result.nftId)) {
                case (?tokenIndex) {
                  // Get or create stats for this bot
                  let currentStats = switch (Map.get(botStats, Map.nhash, tokenIndex)) {
                    case (?stats) { stats };
                    case null {
                      {
                        racesEntered = 0;
                        wins = 0;
                        places = 0;
                        shows = 0;
                        totalEarnings = 0;
                      };
                    };
                  };

                  // Update stats
                  let newStats = {
                    racesEntered = currentStats.racesEntered + 1;
                    wins = if (result.position == 1) { currentStats.wins + 1 } else {
                      currentStats.wins;
                    };
                    places = if (result.position == 2) {
                      currentStats.places + 1;
                    } else { currentStats.places };
                    shows = if (result.position == 3) { currentStats.shows + 1 } else {
                      currentStats.shows;
                    };
                    totalEarnings = currentStats.totalEarnings + result.prizeAmount;
                  };

                  ignore Map.put(botStats, Map.nhash, tokenIndex, newStats);
                };
                case null {};
              };
            };
          };
          case null {};
        };
      };
    };

    // Update bot stats in stable storage and rebuild leaderboards
    var updatedCount = 0;

    // If there are no races, zero out all bot stats
    if (Map.size(botStats) == 0) {
      for ((tokenIndex, currentBotStats) in Map.entries(stable_racing_stats)) {
        let updatedBotStats : PokedBotsGarage.PokedBotRacingStats = {
          currentBotStats with
          racesEntered = 0;
          wins = 0;
          places = 0;
          shows = 0;
          totalScrapEarned = 0;
        };
        garageManager.updateStats(tokenIndex, updatedBotStats);
        updatedCount += 1;
      };
    } else {
      // Update bots that have race data
      for ((tokenIndex, calculatedStats) in Map.entries(botStats)) {
        switch (garageManager.getStats(tokenIndex)) {
          case (?currentBotStats) {
            let updatedBotStats : PokedBotsGarage.PokedBotRacingStats = {
              currentBotStats with
              racesEntered = calculatedStats.racesEntered;
              wins = calculatedStats.wins;
              places = calculatedStats.places;
              shows = calculatedStats.shows;
              totalScrapEarned = calculatedStats.totalEarnings;
              // Keep existing ELO and other fields
            };

            garageManager.updateStats(tokenIndex, updatedBotStats);
            updatedCount += 1;
          };
          case null {};
        };
      };
    };

    // Rebuild leaderboards from valid races only
    leaderboardManager.updateCurrentPeriods(now);
    var leaderboardUpdates = 0;

    for (race in allRaces.vals()) {
      let isValid = Array.find<Nat>(validRaceIds, func(id) { id == race.raceId });
      if (Option.isSome(isValid) and race.status == #Completed) {
        switch (race.results) {
          case (?results) {
            for (i in Iter.range(0, results.size() - 1)) {
              let result = results[i];
              switch (Nat.fromText(result.nftId)) {
                case (?tokenIndex) {
                  switch (garageManager.getStats(tokenIndex)) {
                    case (?botStats) {
                      let position = i + 1;

                      // Apply Golden faction synergy bonus to leaderboard prize tracking
                      let synergies = garageManager.calculateFactionSynergies(result.owner);
                      let adjustedPrize = Float.toInt(Float.fromInt(result.prizeAmount) * synergies.yieldMultipliers.racePrizes);

                      leaderboardManager.recordRaceResult(
                        tokenIndex,
                        result.owner,
                        position,
                        results.size(),
                        Int.abs(adjustedPrize),
                        1.0, // pointsMultiplier
                        botStats.faction,
                        race.startTime,
                      );
                      leaderboardUpdates += 1;
                    };
                    case null {};
                  };
                };
                case null {};
              };
            };
          };
          case null {};
        };
      };
    };

    "Recalculated stats for " # Nat.toText(updatedCount) # " bots and recorded " # Nat.toText(leaderboardUpdates) # " leaderboard entries from " # Nat.toText(allRaces.size()) # " races.";
  };

  system func preupgrade() {
    stable_http_assets := HttpAssets.preupgrade(http_assets);

    // Save the trait schema from statsManager to stable storage before upgrade
    stable_trait_schema := statsManager.getSchemaValue();

    // Save betting next bet ID
    stable_betting_next_bet_id := bettingManager.getNextBetId();
  };

  system func postupgrade() {
    HttpAssets.postupgrade(http_assets);

    // Note: Overcharge migration completed - all bots now have overcharge field
    // No longer need to reset overcharge on every upgrade

    // Update leaderboard periods based on current time
    let now = Time.now();
    leaderboardManager.updateCurrentPeriods(now);
  };

  // Initialize the hourly battery recharge timer (called on postupgrade or first install)
  func initializeRechargeTimer<system>() {
    // Check if we already have a recharge timer scheduled
    let existingActions = tt().getActionsByFilter(#ByType("hourly_recharge"));
    if (existingActions.size() == 0) {
      // No recharge timer exists, schedule the first one
      let now = Time.now();
      let firstRechargeTime = if (stable_last_recharge_time == 0) {
        // First install, schedule recharge in 1 hour
        Int.abs(now + (60 * 60 * 1_000_000_000));
      } else {
        // After upgrade, schedule based on last recharge
        let timeSinceLastRecharge = now - stable_last_recharge_time;
        let hourInNs = 60 * 60 * 1_000_000_000;
        if (timeSinceLastRecharge >= hourInNs) {
          // Overdue, schedule immediately
          Int.abs(now + 60_000_000_000); // 1 minute from now
        } else {
          // Schedule at next 1-hour mark
          Int.abs(stable_last_recharge_time + hourInNs);
        };
      };

      ignore tt().setActionSync<system>(
        firstRechargeTime,
        {
          actionType = "hourly_recharge";
          params = to_candid (());
        },
      );

      Debug.print("Created initial recharge timer scheduled for " # Nat.toText(firstRechargeTime));
    } else {
      Debug.print("Recharge timer already exists (" # Nat.toText(existingActions.size()) # " found), skipping initialization");
    };
  };

  // Initialize race creation timer (called on postupgrade or first install)
  func initializeRaceCreationTimer<system>() {
    // Check if race creation timer already exists
    let existingTimers = tt().getActionsByFilter(#ByType("race_create"));

    if (existingTimers.size() == 0) {
      // No race creation timer, create the first one
      let now = Time.now();
      let firstRaceTime = now + (5 * 60 * 1_000_000_000); // First race in 5 minutes

      ignore tt().setActionSync<system>(
        Int.abs(firstRaceTime),
        {
          actionType = "race_create";
          params = to_candid (());
        },
      );
      Debug.print("Initialized race creation timer for " # debug_show (firstRaceTime));
    } else {
      Debug.print("Race creation timer already exists, skipping initialization");
    };
  };

  initializeRechargeTimer<system>();
  initializeRaceCreationTimer<system>();

  /**
   * Creates a new API key. This API key is linked to the caller's principal.
   * @param name A human-readable name for the key.
   * @returns The raw, unhashed API key. THIS IS THE ONLY TIME IT WILL BE VISIBLE.
   */
  public shared (msg) func create_my_api_key(name : Text, scopes : [Text]) : async Text {
    switch (authContext) {
      case (null) {
        Debug.trap("Authentication is not enabled on this canister.");
      };
      case (?ctx) {
        return await ApiKey.create_my_api_key(
          ctx,
          msg.caller,
          name,
          scopes,
        );
      };
    };
  };

  /** Revoke (delete) an API key owned by the caller.
   * @param key_id The ID of the key to revoke.
   * @returns True if the key was found and revoked, false otherwise.
   */
  public shared (msg) func revoke_my_api_key(key_id : Text) : async () {
    switch (authContext) {
      case (null) {
        Debug.trap("Authentication is not enabled on this canister.");
      };
      case (?ctx) {
        return ApiKey.revoke_my_api_key(ctx, msg.caller, key_id);
      };
    };
  };

  /** List all API keys owned by the caller.
   * @returns A list of API key metadata (but not the raw keys).
   */
  public query (msg) func list_my_api_keys() : async [AuthTypes.ApiKeyMetadata] {
    switch (authContext) {
      case (null) {
        Debug.trap("Authentication is not enabled on this canister.");
      };
      case (?ctx) {
        return ApiKey.list_my_api_keys(ctx, msg.caller);
      };
    };
  };

  public type UpgradeFinishedResult = {
    #InProgress : Nat;
    #Failed : (Nat, Text);
    #Success : Nat;
  };
  private func natNow() : Nat {
    return Int.abs(Time.now());
  };
  /* Return success after post-install/upgrade operations complete.
   * The Nat value is a timestamp (in nanoseconds) of when the upgrade finished.
   * If the upgrade is still in progress, return #InProgress with a timestamp of when it started.
   * If the upgrade failed, return #Failed with a timestamp and an error message.
   */
  public func icrc120_upgrade_finished() : async UpgradeFinishedResult {
    #Success(natNow());
  };

  // ============================================================================
  // WEB API FUNCTIONS - For website gameplay
  // ============================================================================

  /// Get bot details for multiple token indices (query call for performance)
  public query func web_get_bot_details_batch(tokenIndices : [Nat]) : async [{
    tokenIndex : Nat;
    faction : ?Text;
    baseSpeed : Nat;
    basePowerCore : Nat;
    baseAcceleration : Nat;
    baseStability : Nat;
    overallRating : Nat;
    wins : Nat;
    racesEntered : Nat;
    winRate : Float;
    imageUrl : Text;
    isInitialized : Bool;
  }] {
    let extCanisterIdBytes = Principal.toBlob(extCanisterId);

    Array.map<Nat, { tokenIndex : Nat; faction : ?Text; baseSpeed : Nat; basePowerCore : Nat; baseAcceleration : Nat; baseStability : Nat; overallRating : Nat; wins : Nat; racesEntered : Nat; winRate : Float; imageUrl : Text; isInitialized : Bool }>(
      tokenIndices,
      func(tokenIndex) {
        let baseStats = garageManager.getBaseStats(tokenIndex);
        let racingStats = garageManager.getStats(tokenIndex);

        let tokenIndex32 = Nat32.fromNat(tokenIndex);
        let tokenId = ExtIntegration.encodeTokenIdentifier(tokenIndex32, extCanisterId);
        let imageUrl = "https://bzsui-sqaaa-aaaah-qce2a-cai.raw.icp0.io/?tokenid=" # tokenId # "&type=thumbnail";

        switch (racingStats) {
          case (?stats) {
            let rating = garageManager.calculateOverallRating(stats);
            let winRate = if (stats.racesEntered > 0) {
              Float.fromInt(stats.wins) / Float.fromInt(stats.racesEntered) * 100.0;
            } else { 0.0 };

            let factionText = switch (stats.faction) {
              case (#UltimateMaster) { ?"UltimateMaster" };
              case (#Wild) { ?"Wild" };
              case (#Golden) { ?"Golden" };
              case (#Ultimate) { ?"Ultimate" };
              case (#Blackhole) { ?"Blackhole" };
              case (#Dead) { ?"Dead" };
              case (#Master) { ?"Master" };
              case (#Bee) { ?"Bee" };
              case (#Food) { ?"Food" };
              case (#Box) { ?"Box" };
              case (#Murder) { ?"Murder" };
              case (#Game) { ?"Game" };
              case (#Animal) { ?"Animal" };
              case (#Industrial) { ?"Industrial" };
            };

            {
              tokenIndex;
              faction = factionText;
              baseSpeed = baseStats.speed;
              basePowerCore = baseStats.powerCore;
              baseAcceleration = baseStats.acceleration;
              baseStability = baseStats.stability;
              overallRating = rating;
              wins = stats.wins;
              racesEntered = stats.racesEntered;
              winRate;
              imageUrl;
              isInitialized = true;
            };
          };
          case (null) {
            // Uninitialized bots don't have faction visible yet
            let avgStat = (baseStats.speed + baseStats.powerCore + baseStats.acceleration + baseStats.stability) / 4;
            {
              tokenIndex;
              faction = null; // Faction revealed upon initialization
              baseSpeed = baseStats.speed;
              basePowerCore = baseStats.powerCore;
              baseAcceleration = baseStats.acceleration;
              baseStability = baseStats.stability;
              overallRating = avgStat;
              wins = 0;
              racesEntered = 0;
              winRate = 0.0;
              imageUrl;
              isInitialized = false;
            };
          };
        };
      },
    );
  };

  /// List all PokedBots owned by the caller in their wallet
  public shared ({ caller }) func web_list_my_bots() : async [{
    tokenIndex : Nat;
    name : ?Text;
    stats : ?PokedBotsGarage.PokedBotRacingStats;
    currentStats : ?{
      speed : Nat;
      powerCore : Nat;
      acceleration : Nat;
      stability : Nat;
    };
    maxStats : ?{
      speed : Nat;
      powerCore : Nat;
      acceleration : Nat;
      stability : Nat;
    };
    upgradeCostsV2 : ?{
      speed : { costE8s : Nat; successRate : Float };
      powerCore : { costE8s : Nat; successRate : Float };
      acceleration : { costE8s : Nat; successRate : Float };
      stability : { costE8s : Nat; successRate : Float };
      pityCounter : Nat;
    };
    isInitialized : Bool;
    currentOwner : Text;
    activeUpgrade : ?PokedBotsGarage.UpgradeSession;
    upcomingRaces : [{
      raceId : Nat;
      name : Text;
      startTime : Int;
      entryDeadline : Int;
      entryFee : Nat;
      terrain : RacingSimulator.Terrain;
    }];
    eligibleRaces : [{
      raceId : Nat;
      name : Text;
      startTime : Int;
      entryDeadline : Int;
      entryFee : Nat;
      terrain : RacingSimulator.Terrain;
    }];
  }] {
    let walletAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);
    let tokensResult = await ExtIntegration.getOwnedTokens(extCanister, walletAccountId);

    switch (tokensResult) {
      case (#err(_)) { [] };
      case (#ok(tokens)) {
        // Get all upcoming races once
        let allRaces = raceManager.getAllRaces();
        let upcomingRaces = Array.filter<RacingSimulator.Race>(
          allRaces,
          func(race) {
            race.status == #Upcoming;
          },
        );

        let results = Array.mapFilter<Nat32, { tokenIndex : Nat; name : ?Text; stats : ?PokedBotsGarage.PokedBotRacingStats; currentStats : ?{ speed : Nat; powerCore : Nat; acceleration : Nat; stability : Nat }; maxStats : ?{ speed : Nat; powerCore : Nat; acceleration : Nat; stability : Nat }; upgradeCostsV2 : ?{ speed : { costE8s : Nat; successRate : Float }; powerCore : { costE8s : Nat; successRate : Float }; acceleration : { costE8s : Nat; successRate : Float }; stability : { costE8s : Nat; successRate : Float }; pityCounter : Nat }; isInitialized : Bool; currentOwner : Text; activeUpgrade : ?PokedBotsGarage.UpgradeSession; upcomingRaces : [{ raceId : Nat; name : Text; startTime : Int; entryDeadline : Int; entryFee : Nat; terrain : RacingSimulator.Terrain }]; eligibleRaces : [{ raceId : Nat; name : Text; startTime : Int; entryDeadline : Int; entryFee : Nat; terrain : RacingSimulator.Terrain }] }>(
          tokens,
          func(tokenIndex32) {
            let tokenIndex = Nat32.toNat(tokenIndex32);
            let stats = garageManager.getStats(tokenIndex);
            let isInit = Option.isSome(stats);
            let activeUpgrade = Map.get(stable_active_upgrades, Map.nhash, tokenIndex);

            // Calculate current and max stats
            let (currentStats, maxStats) = switch (stats) {
              case (?botStats) {
                // Get current stats (with battery/condition penalties)
                let current = garageManager.getCurrentStats(botStats);
                // Get max stats (at 100% battery/condition)
                let base = garageManager.getBaseStats(tokenIndex);
                let max = {
                  speed = base.speed + botStats.speedBonus;
                  powerCore = base.powerCore + botStats.powerCoreBonus;
                  acceleration = base.acceleration + botStats.accelerationBonus;
                  stability = base.stability + botStats.stabilityBonus;
                };
                (?current, ?max);
              };
              case (null) { (null, null) };
            };

            // Calculate V2 upgrade costs if bot is initialized
            let upgradeCostsV2 = switch (stats, currentStats, maxStats) {
              case (?botStats, ?current, ?max) {
                let baseStats = garageManager.getBaseStats(tokenIndex);
                let overallRating = (max.speed + max.powerCore + max.acceleration + max.stability) / 4;
                let pityCounter = garageManager.getPityCounter(tokenIndex);
                let synergies = garageManager.calculateFactionSynergies(caller);

                // Calculate costs for each stat (use max stats for consistent pricing)
                let speedCost = garageManager.calculateUpgradeCostV2(baseStats.speed, max.speed, overallRating, synergies.costMultipliers.upgradeCost);
                let powerCoreCost = garageManager.calculateUpgradeCostV2(baseStats.powerCore, max.powerCore, overallRating, synergies.costMultipliers.upgradeCost);
                let accelerationCost = garageManager.calculateUpgradeCostV2(baseStats.acceleration, max.acceleration, overallRating, synergies.costMultipliers.upgradeCost);
                let stabilityCost = garageManager.calculateUpgradeCostV2(baseStats.stability, max.stability, overallRating, synergies.costMultipliers.upgradeCost);

                // Calculate success rates (use upgrade counts, not current stats which have penalties)
                let speedRate = garageManager.calculateSuccessRate(botStats.speedUpgrades, pityCounter);
                let powerCoreRate = garageManager.calculateSuccessRate(botStats.powerCoreUpgrades, pityCounter);
                let accelerationRate = garageManager.calculateSuccessRate(botStats.accelerationUpgrades, pityCounter);
                let stabilityRate = garageManager.calculateSuccessRate(botStats.stabilityUpgrades, pityCounter);

                ?{
                  speed = { costE8s = speedCost; successRate = speedRate };
                  powerCore = {
                    costE8s = powerCoreCost;
                    successRate = powerCoreRate;
                  };
                  acceleration = {
                    costE8s = accelerationCost;
                    successRate = accelerationRate;
                  };
                  stability = {
                    costE8s = stabilityCost;
                    successRate = stabilityRate;
                  };
                  pityCounter = pityCounter;
                };
              };
              case (_, _, _) { null };
            };

            // Find races this bot is entered in and races eligible to enter
            let nftId = Nat.toText(tokenIndex);
            let botEloClass = switch (stats) {
              case (?s) {
                let rating = calculateMaxRating(s); // Use max stats, not current degraded stats
                getRaceClassFromRating(rating);
              };
              case (null) { #Scrap };
            };

            var enteredRaces : [{
              raceId : Nat;
              name : Text;
              startTime : Int;
              entryDeadline : Int;
              entryFee : Nat;
              terrain : RacingSimulator.Terrain;
            }] = [];
            var eligibleRaces : [{
              raceId : Nat;
              name : Text;
              startTime : Int;
              entryDeadline : Int;
              entryFee : Nat;
              terrain : RacingSimulator.Terrain;
            }] = [];

            for (race in upcomingRaces.vals()) {
              let isEntered = Array.find<RacingSimulator.RaceEntry>(
                race.entries,
                func(entry) { entry.nftId == nftId },
              );

              let raceInfo = {
                raceId = race.raceId;
                name = race.name;
                startTime = race.startTime;
                entryDeadline = race.entryDeadline;
                entryFee = race.entryFee;
                terrain = race.terrain;
              };

              switch (isEntered) {
                case (?_) {
                  // Already entered
                  enteredRaces := Array.append(enteredRaces, [raceInfo]);
                };
                case (null) {
                  // Not entered - check if eligible (rating-based class matches and not full)
                  if (race.raceClass == botEloClass and race.entries.size() < race.maxEntries) {
                    eligibleRaces := Array.append(eligibleRaces, [raceInfo]);
                  };
                };
              };
            };

            ?{
              tokenIndex = tokenIndex;
              name = switch (stats) { case (?s) { s.name }; case null { null } };
              stats = stats;
              currentStats = currentStats;
              maxStats = maxStats;
              upgradeCostsV2 = upgradeCostsV2;
              isInitialized = isInit;
              currentOwner = walletAccountId;
              activeUpgrade = activeUpgrade;
              upcomingRaces = enteredRaces;
              eligibleRaces = eligibleRaces;
            };
          },
        );
        results;
      };
    };
  };

  /// List all PokedBots registered in the garage by the caller (QUERY - no EXT canister call)
  /// Returns only bots that have been initialized for racing
  /// Frontend should query EXT canister separately to show unregistered bots
  public shared query ({ caller }) func web_list_my_registered_bots() : async [{
    tokenIndex : Nat;
    name : ?Text;
    stats : PokedBotsGarage.PokedBotRacingStats;
    currentStats : {
      speed : Nat;
      powerCore : Nat;
      acceleration : Nat;
      stability : Nat;
    };
    maxStats : {
      speed : Nat;
      powerCore : Nat;
      acceleration : Nat;
      stability : Nat;
    };
    upgradeCostsV2 : {
      speed : { costE8s : Nat; successRate : Float };
      powerCore : { costE8s : Nat; successRate : Float };
      acceleration : { costE8s : Nat; successRate : Float };
      stability : { costE8s : Nat; successRate : Float };
      pityCounter : Nat;
    };
    activeUpgrade : ?PokedBotsGarage.UpgradeSession;
    upcomingRaces : [{
      raceId : Nat;
      name : Text;
      startTime : Int;
      entryDeadline : Int;
      entryFee : Nat;
      terrain : RacingSimulator.Terrain;
    }];
    eligibleRaces : [{
      raceId : Nat;
      name : Text;
      startTime : Int;
      entryDeadline : Int;
      entryFee : Nat;
      terrain : RacingSimulator.Terrain;
    }];
  }] {
    let callerAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);

    // Get all upcoming races once
    let allRaces = raceManager.getAllRaces();
    let upcomingRaces = Array.filter<RacingSimulator.Race>(
      allRaces,
      func(race) {
        race.status == #Upcoming;
      },
    );

    // Iterate through all registered bots and filter by owner
    let registeredBots = Buffer.Buffer<{ tokenIndex : Nat; name : ?Text; stats : PokedBotsGarage.PokedBotRacingStats; currentStats : { speed : Nat; powerCore : Nat; acceleration : Nat; stability : Nat }; maxStats : { speed : Nat; powerCore : Nat; acceleration : Nat; stability : Nat }; upgradeCostsV2 : { speed : { costE8s : Nat; successRate : Float }; powerCore : { costE8s : Nat; successRate : Float }; acceleration : { costE8s : Nat; successRate : Float }; stability : { costE8s : Nat; successRate : Float }; pityCounter : Nat }; activeUpgrade : ?PokedBotsGarage.UpgradeSession; upcomingRaces : [{ raceId : Nat; name : Text; startTime : Int; entryDeadline : Int; entryFee : Nat; terrain : RacingSimulator.Terrain }]; eligibleRaces : [{ raceId : Nat; name : Text; startTime : Int; entryDeadline : Int; entryFee : Nat; terrain : RacingSimulator.Terrain }] }>(10);

    for ((tokenIndex, botStats) in Map.entries(stable_racing_stats)) {
      // Only include bots owned by the caller (compare principals)
      if (botStats.ownerPrincipal == caller) {
        let baseStats = garageManager.getBaseStats(tokenIndex);
        let currentStats = garageManager.getCurrentStats(botStats);
        let maxStats = {
          speed = baseStats.speed + botStats.speedBonus;
          powerCore = baseStats.powerCore + botStats.powerCoreBonus;
          acceleration = baseStats.acceleration + botStats.accelerationBonus;
          stability = baseStats.stability + botStats.stabilityBonus;
        };

        let overallRating = (maxStats.speed + maxStats.powerCore + maxStats.acceleration + maxStats.stability) / 4;
        let pityCounter = garageManager.getPityCounter(tokenIndex);

        // Calculate V2 upgrade costs
        let synergies = garageManager.calculateFactionSynergies(caller);
        let speedCost = garageManager.calculateUpgradeCostV2(baseStats.speed, maxStats.speed, overallRating, synergies.costMultipliers.upgradeCost);
        let powerCoreCost = garageManager.calculateUpgradeCostV2(baseStats.powerCore, maxStats.powerCore, overallRating, synergies.costMultipliers.upgradeCost);
        let accelerationCost = garageManager.calculateUpgradeCostV2(baseStats.acceleration, maxStats.acceleration, overallRating, synergies.costMultipliers.upgradeCost);
        let stabilityCost = garageManager.calculateUpgradeCostV2(baseStats.stability, maxStats.stability, overallRating, synergies.costMultipliers.upgradeCost);

        // Calculate success rates
        let speedRate = garageManager.calculateSuccessRate(botStats.speedUpgrades, pityCounter);
        let powerCoreRate = garageManager.calculateSuccessRate(botStats.powerCoreUpgrades, pityCounter);
        let accelerationRate = garageManager.calculateSuccessRate(botStats.accelerationUpgrades, pityCounter);
        let stabilityRate = garageManager.calculateSuccessRate(botStats.stabilityUpgrades, pityCounter);

        let activeUpgrade = Map.get(stable_active_upgrades, Map.nhash, tokenIndex);

        // Find races this bot is entered in and races eligible to enter
        let nftId = Nat.toText(tokenIndex);
        let rating = calculateMaxRating(botStats); // Use max stats, not current degraded stats
        let botEloClass = getRaceClassFromRating(rating);

        var enteredRaces : [{
          raceId : Nat;
          name : Text;
          startTime : Int;
          entryDeadline : Int;
          entryFee : Nat;
          terrain : RacingSimulator.Terrain;
        }] = [];
        var eligibleRaces : [{
          raceId : Nat;
          name : Text;
          startTime : Int;
          entryDeadline : Int;
          entryFee : Nat;
          terrain : RacingSimulator.Terrain;
        }] = [];

        for (race in upcomingRaces.vals()) {
          let isEntered = Array.find<RacingSimulator.RaceEntry>(
            race.entries,
            func(entry) { entry.nftId == nftId },
          );

          let raceInfo = {
            raceId = race.raceId;
            name = race.name;
            startTime = race.startTime;
            entryDeadline = race.entryDeadline;
            entryFee = race.entryFee;
            terrain = race.terrain;
          };

          switch (isEntered) {
            case (?_) {
              // Already entered
              enteredRaces := Array.append(enteredRaces, [raceInfo]);
            };
            case (null) {
              // Not entered - check if eligible (rating-based class matches and not full)
              if (race.raceClass == botEloClass and race.entries.size() < race.maxEntries) {
                eligibleRaces := Array.append(eligibleRaces, [raceInfo]);
              };
            };
          };
        };

        registeredBots.add({
          tokenIndex = tokenIndex;
          name = botStats.name;
          stats = botStats;
          currentStats = currentStats;
          maxStats = maxStats;
          upgradeCostsV2 = {
            speed = { costE8s = speedCost; successRate = speedRate };
            powerCore = { costE8s = powerCoreCost; successRate = powerCoreRate };
            acceleration = {
              costE8s = accelerationCost;
              successRate = accelerationRate;
            };
            stability = { costE8s = stabilityCost; successRate = stabilityRate };
            pityCounter = pityCounter;
          };
          activeUpgrade = activeUpgrade;
          upcomingRaces = enteredRaces;
          eligibleRaces = eligibleRaces;
        });
      };
    };

    Buffer.toArray(registeredBots);
  };

  /// Get user's parts inventory
  public shared query ({ caller }) func web_get_user_inventory() : async PokedBotsGarage.UserInventory {
    garageManager.getUserInventory(caller);
  };

  /// Get faction synergy bonuses for the caller's collection
  public shared query ({ caller }) func web_get_collection_bonuses() : async {
    statBonuses : {
      speed : Int;
      powerCore : Int;
      acceleration : Int;
      stability : Int;
    };
    costMultipliers : {
      repair : Float;
      upgrade : Float;
      rechargeCooldown : Float;
    };
    yieldMultipliers : { parts : Float; prizes : Float };
    drainMultipliers : { scavenging : Float };
  } {
    let synergies = garageManager.calculateFactionSynergies(caller);

    // Sum up all stat bonuses from all factions
    var totalSpeed : Int = 0;
    var totalPower : Int = 0;
    var totalAccel : Int = 0;
    var totalStab : Int = 0;

    for ((faction, stats) in synergies.statBonuses.vals()) {
      totalSpeed += stats.speed;
      totalPower += stats.powerCore;
      totalAccel += stats.acceleration;
      totalStab += stats.stability;
    };

    {
      statBonuses = {
        speed = totalSpeed;
        powerCore = totalPower;
        acceleration = totalAccel;
        stability = totalStab;
      };
      costMultipliers = {
        repair = synergies.costMultipliers.repairCost;
        upgrade = synergies.costMultipliers.upgradeCost;
        rechargeCooldown = synergies.costMultipliers.rechargeCooldown;
      };
      yieldMultipliers = {
        parts = synergies.yieldMultipliers.scavengingParts;
        prizes = synergies.yieldMultipliers.racePrizes;
      };
      drainMultipliers = {
        scavenging = synergies.drainMultipliers.scavengingDrain;
      };
    };
  };

  /// Initialize a bot for racing (web equivalent of garage_initialize_pokedbot)
  public shared ({ caller }) func web_initialize_bot(
    tokenIndex : Nat,
    name : ?Text,
  ) : async Result.Result<Text, Text> {
    // Validate name if provided
    switch (name) {
      case (?n) {
        switch (UsernameValidator.validateUsername(n)) {
          case (?error) { return #err(error) };
          case (null) {};
        };
      };
      case (null) {};
    };

    // Verify caller owns the NFT in their wallet
    let walletAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);
    let ownerResult = try {
      await extCanister.bearer(
        ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), extCanisterId)
      );
    } catch (_) {
      return #err("Failed to verify ownership");
    };

    switch (ownerResult) {
      case (#err(_)) { #err("Bot does not exist") };
      case (#ok(owner)) {
        if (owner != walletAccountId) {
          #err("You do not own this bot - it must be in your wallet");
        } else {
          // Check if already initialized by someone else
          switch (garageManager.getStats(tokenIndex)) {
            case (?existingStats) {
              // Check if owned by caller
              if (existingStats.ownerPrincipal != caller) {
                // Transfer case - still charge 0.1 ICP registration fee
                let REGISTRATION_COST = 10000000 : Nat; // 0.1 ICP in e8s
                let TRANSFER_FEE = 10000 : Nat; // 0.0001 ICP in e8s
                let totalCost = REGISTRATION_COST + TRANSFER_FEE;

                let ledgerId = switch (icpLedgerCanisterId) {
                  case (?id) { id };
                  case (null) {
                    return #err("ICP Ledger not configured");
                  };
                };

                let icpLedger = actor (Principal.toText(ledgerId)) : actor {
                  icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
                };

                let transferResult = try {
                  await icpLedger.icrc2_transfer_from({
                    from = { owner = caller; subaccount = null };
                    to = { owner = thisPrincipal; subaccount = null };
                    amount = totalCost;
                    fee = ?TRANSFER_FEE;
                    memo = null;
                    created_at_time = null;
                    spender_subaccount = null;
                  });
                } catch (e) {
                  return #err("Payment failed: " # Error.message(e) # ". Please approve the canister to spend 0.1001 ICP using icrc2_approve.");
                };

                switch (transferResult) {
                  case (#Err(e)) {
                    let errorMsg = switch (e) {
                      case (#InsufficientFunds({ balance })) {
                        "Insufficient funds. Balance: " # Nat.toText(balance / 100000000) # " ICP";
                      };
                      case (#InsufficientAllowance({ allowance })) {
                        "Insufficient spending allowance. Current: " # Nat.toText(allowance / 100000000) # " ICP. Please go to the Garage page and set a spending allowance first.";
                      };
                      case (#BadFee({ expected_fee })) {
                        "Bad fee. Expected: " # Nat.toText(expected_fee) # " e8s";
                      };
                      case _ { "Transfer failed" };
                    };
                    #err(errorMsg);
                  };
                  case (#Ok(_)) {
                    // Payment successful, update owner
                    ignore garageManager.updateBotOwner(tokenIndex, caller);
                    // Also update name if provided
                    if (Option.isSome(name)) {
                      ignore garageManager.updateBotName(tokenIndex, name);
                    };
                    let nameMsg = switch (name) {
                      case (?n) { " with name: " # n };
                      case (null) { "" };
                    };
                    #ok("Bot re-registered to your account" # nameMsg # ". 0.1 ICP registration fee paid.");
                  };
                };
              } else {
                // Already owned by caller - allow name update if provided
                switch (name) {
                  case (?newName) {
                    ignore garageManager.updateBotName(tokenIndex, name);
                    #ok("Bot name updated to: " # newName);
                  };
                  case (null) {
                    #ok("Bot already initialized for your account");
                  };
                };
              };
            };
            case (null) {
              // First time initialization - charge 0.1 ICP registration fee
              let REGISTRATION_COST = 10000000 : Nat; // 0.1 ICP in e8s
              let TRANSFER_FEE = 10000 : Nat; // 0.0001 ICP in e8s
              let totalCost = REGISTRATION_COST + TRANSFER_FEE;

              let ledgerId = switch (icpLedgerCanisterId) {
                case (?id) { id };
                case (null) {
                  return #err("ICP Ledger not configured");
                };
              };

              let icpLedger = actor (Principal.toText(ledgerId)) : actor {
                icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
              };

              let transferResult = try {
                await icpLedger.icrc2_transfer_from({
                  from = { owner = caller; subaccount = null };
                  to = { owner = thisPrincipal; subaccount = null };
                  amount = totalCost;
                  fee = ?TRANSFER_FEE;
                  memo = null;
                  created_at_time = null;
                  spender_subaccount = null;
                });
              } catch (e) {
                return #err("Payment failed: " # Error.message(e) # ". Please approve the canister to spend 0.1001 ICP using icrc2_approve.");
              };

              switch (transferResult) {
                case (#Err(e)) {
                  let errorMsg = switch (e) {
                    case (#InsufficientFunds({ balance })) {
                      "Insufficient funds. Balance: " # Nat.toText(balance / 100000000) # " ICP";
                    };
                    case (#InsufficientAllowance({ allowance })) {
                      "Insufficient spending allowance. Current: " # Nat.toText(allowance / 100000000) # " ICP. Please go to the Garage page and set a spending allowance first.";
                    };
                    case (#BadFee({ expected_fee })) {
                      "Bad fee. Expected: " # Nat.toText(expected_fee) # " e8s";
                    };
                    case _ { "Transfer failed" };
                  };
                  #err(errorMsg);
                };
                case (#Ok(_)) {
                  // Payment successful, initialize bot
                  ignore garageManager.initializeBot(tokenIndex, caller, null, name);
                  #ok("Bot initialized successfully. 0.1 ICP registration fee paid.");
                };
              };
            };
          };
        };
      };
    };
  };

  /// Get detailed stats for a specific bot
  public shared ({ caller }) func web_get_bot_details(
    tokenIndex : Nat
  ) : async Result.Result<{ stats : ?PokedBotsGarage.PokedBotRacingStats; baseStats : { speed : Nat; powerCore : Nat; acceleration : Nat; stability : Nat }; isOwner : Bool; isInitialized : Bool; currentCondition : ?Nat; currentBattery : ?Nat; activeUpgrade : ?PokedBotsGarage.UpgradeSession; upgradeCosts : ?{ Velocity : { parts : Nat; icp : Nat }; PowerCore : { parts : Nat; icp : Nat }; Thruster : { parts : Nat; icp : Nat }; Gyro : { parts : Nat; icp : Nat } } }, Text> {
    // Check ownership first
    let walletAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);
    let ownerResult = await extCanister.bearer(
      ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), extCanisterId)
    );

    let isOwner = switch (ownerResult) {
      case (#ok(owner)) { owner == walletAccountId };
      case (#err(_)) { return #err("Bot does not exist") };
    };

    let baseStats = garageManager.getBaseStats(tokenIndex);

    // Check if bot is initialized
    let statsOpt = garageManager.getStats(tokenIndex);

    switch (statsOpt) {
      case (null) {
        // Bot not initialized - return base stats only
        let totalBaseStats = baseStats.speed + baseStats.powerCore + baseStats.acceleration + baseStats.stability;

        #ok({
          stats = null;
          baseStats = baseStats;
          isOwner = isOwner;
          isInitialized = false;
          currentCondition = null;
          currentBattery = null;
          activeUpgrade = null;
          upgradeCosts = null;
        });
      };
      case (?stats) {
        // Bot is initialized - return full details
        let activeUpgrade = Map.get(stable_active_upgrades, Map.nhash, tokenIndex);

        // Calculate current stats (base + bonuses)
        let currentSpeed = baseStats.speed + stats.speedBonus;
        let currentPowerCore = baseStats.powerCore + stats.powerCoreBonus;
        let currentAcceleration = baseStats.acceleration + stats.accelerationBonus;
        let currentStability = baseStats.stability + stats.stabilityBonus;

        // Calculate overall rating from current stats (max 100)
        let overallRating = (currentSpeed + currentPowerCore + currentAcceleration + currentStability) / 4;

        // Calculate upgrade costs using V2 dynamic formula with Game faction synergy
        let synergies = garageManager.calculateFactionSynergies(caller);
        let velocityCostE8s = garageManager.calculateUpgradeCostV2(
          baseStats.speed,
          currentSpeed,
          overallRating,
          synergies.costMultipliers.upgradeCost,
        );
        let powerCoreCostE8s = garageManager.calculateUpgradeCostV2(
          baseStats.powerCore,
          currentPowerCore,
          overallRating,
          synergies.costMultipliers.upgradeCost,
        );
        let thrusterCostE8s = garageManager.calculateUpgradeCostV2(
          baseStats.acceleration,
          currentAcceleration,
          overallRating,
          synergies.costMultipliers.upgradeCost,
        );
        let gyroCostE8s = garageManager.calculateUpgradeCostV2(
          baseStats.stability,
          currentStability,
          overallRating,
          synergies.costMultipliers.upgradeCost,
        );

        // Convert e8s to parts (divide by 10_000)
        let velocityCost = velocityCostE8s / 10_000;
        let powerCoreCost = powerCoreCostE8s / 10_000;
        let thrusterCost = thrusterCostE8s / 10_000;
        let gyroCost = gyroCostE8s / 10_000;

        #ok({
          stats = ?stats;
          baseStats = baseStats;
          isOwner = isOwner;
          isInitialized = true;
          currentCondition = ?stats.condition;
          currentBattery = ?stats.battery;
          activeUpgrade = activeUpgrade;
          upgradeCosts = ?{
            Velocity = { parts = velocityCost; icp = velocityCostE8s };
            PowerCore = { parts = powerCoreCost; icp = powerCoreCostE8s };
            Thruster = { parts = thrusterCost; icp = thrusterCostE8s };
            Gyro = { parts = gyroCost; icp = gyroCostE8s };
          };
        });
      };
    };
  };

  /// Recharge a bot's battery (0.1 ICP + fee via ICRC-2)
  public shared ({ caller }) func web_recharge_bot(
    tokenIndex : Nat
  ) : async Result.Result<Text, Text> {
    // Verify ownership
    let walletAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);
    let ownerResult = await extCanister.bearer(
      ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), extCanisterId)
    );

    switch (ownerResult) {
      case (#err(_)) { return #err("Bot does not exist") };
      case (#ok(owner)) {
        if (owner != walletAccountId) {
          return #err("You do not own this bot");
        };
      };
    };

    // Check if bot is on scavenging mission
    let stats = switch (garageManager.getStats(tokenIndex)) {
      case (null) { return #err("Bot not found in garage") };
      case (?s) { s };
    };

    switch (stats.activeMission) {
      case (?_mission) {
        return #err("Cannot recharge while bot is on a scavenging mission. Retrieve the bot first.");
      };
      case (null) { /* OK to proceed */ };
    };

    // Check cooldown (6 hours, reduced by Food faction synergy 15-45%)
    let BASE_RECHARGE_COOLDOWN : Int = 21600000000000; // 6 hours in nanoseconds
    let synergies = garageManager.calculateFactionSynergies(caller);
    let RECHARGE_COOLDOWN = Float.toInt(Float.fromInt(BASE_RECHARGE_COOLDOWN) * synergies.costMultipliers.rechargeCooldown);

    let now = Time.now();
    switch (stats.lastRecharged) {
      case (?lastTime) {
        let timeSince = now - lastTime;
        if (timeSince < RECHARGE_COOLDOWN) {
          let hoursLeft = (RECHARGE_COOLDOWN - timeSince) / (60 * 60 * 1_000_000_000);
          let minutesLeft = ((RECHARGE_COOLDOWN - timeSince) % (60 * 60 * 1_000_000_000)) / (60 * 1_000_000_000);
          return #err("Recharge cooldown active. Time remaining: " # Int.toText(hoursLeft) # "h " # Int.toText(minutesLeft) # "m");
        };
      };
      case (null) { /* First recharge, no cooldown */ };
    };

    // Process ICRC-2 payment and recharge
    let RECHARGE_COST : Nat = 10_000_000; // 0.1 ICP

    let ledgerId = switch (icpLedgerCanisterId) {
      case (?id) { id };
      case (null) { return #err("ICP Ledger not configured") };
    };

    let icpLedger = actor (Principal.toText(ledgerId)) : actor {
      icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
    };

    let transferResult = try {
      await icpLedger.icrc2_transfer_from({
        from = { owner = caller; subaccount = null };
        to = { owner = thisPrincipal; subaccount = null };
        amount = RECHARGE_COST + TRANSFER_FEE;
        fee = ?TRANSFER_FEE;
        memo = null;
        created_at_time = null;
        spender_subaccount = null;
      });
    } catch (e) {
      return #err("Payment transfer failed: " # Error.message(e));
    };

    switch (transferResult) {
      case (#Err(e)) {
        let errorMsg = switch (e) {
          case (#InsufficientAllowance({ allowance })) {
            "Insufficient spending allowance. Current: " # Nat.toText(allowance / 100000000) # " ICP. Please go to the Garage page and set a spending allowance first.";
          };
          case _ { "Payment failed: " # debug_show (e) };
        };
        #err(errorMsg);
      };
      case (#Ok(_blockIndex)) {
        // Get fresh stats (already checked for mission above)
        let freshStats = switch (garageManager.getStats(tokenIndex)) {
          case (null) { return #err("Bot not found in garage") };
          case (?s) { s };
        };

        let now = Time.now();
        let totalRecharge = 75;
        let currentBattery = freshStats.battery;
        let currentCondition = freshStats.condition;
        let maxBattery = 100;

        // Battery increases by 75 (capped at 100)
        let newBattery = Nat.min(maxBattery, currentBattery + totalRecharge);

        // Overcharge based on how LOW battery was before recharge
        // Lower battery = bigger overcharge potential (risk/reward mechanic)
        // Base formula: (100 - currentBattery) * 0.4, max 40%
        let batteryDeficit = if (currentBattery >= 100) { 0 } else {
          100 - currentBattery;
        };
        let baseOvercharge = Float.fromInt(batteryDeficit) * 0.4;

        // Condition affects efficiency with randomness
        // efficiency = 0.5 + (condition / 200) + random(-0.2, +0.2)
        // At 100% condition: 0.5 + 0.5 + random = 0.8-1.2 (avg 1.0)
        // At 50% condition: 0.5 + 0.25 + random = 0.55-0.95 (avg 0.75)
        // At 0% condition: 0.5 + 0 + random = 0.3-0.7 (avg 0.5)
        let conditionBonus = Float.fromInt(currentCondition) / 200.0;

        // Generate pseudo-random variance based on timestamp and token index
        let seed = Int.abs(now) + tokenIndex;
        let randomHash = seed % 1000; // 0-999
        let randomVariance = (Float.fromInt(randomHash) / 1000.0) * 0.4 - 0.2; // -0.2 to +0.2

        let efficiency = 0.5 + conditionBonus + randomVariance;
        let finalOvercharge = baseOvercharge * efficiency;
        let newOvercharge = Nat.min(40, Int.abs(Float.toInt(finalOvercharge)));

        let overchargeAdded = if (newOvercharge >= freshStats.overcharge) {
          newOvercharge - freshStats.overcharge;
        } else { 0 };

        let updatedStats = {
          freshStats with
          battery = newBattery;
          overcharge = newOvercharge;
          lastRecharged = ?now;
        };

        garageManager.updateStats(tokenIndex, updatedStats);

        let overchargeMsg = if (overchargeAdded > 0) {
          let speedBoost = Int.abs(Float.toInt(Float.fromInt(overchargeAdded) * 0.15));
          let stabilityPenalty = Int.abs(Float.toInt(Float.fromInt(overchargeAdded) * 0.1));
          " ⚡ OVERCHARGE: +" # Nat.toText(overchargeAdded) # "% (+" # Nat.toText(speedBoost) # "% Speed/Accel, -" # Nat.toText(stabilityPenalty) # "% Stability/PowerCore for next race)";
        } else {
          "";
        };

        #ok("⚡ Battery recharged to " # Nat.toText(newBattery) # "%!" # overchargeMsg);
      };
    };
  };

  /// Repair a bot to restore condition (0.05 ICP + fee via ICRC-2)
  public shared ({ caller }) func web_repair_bot(
    tokenIndex : Nat
  ) : async Result.Result<Text, Text> {
    // Verify ownership
    let walletAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);
    let ownerResult = await extCanister.bearer(
      ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), extCanisterId)
    );

    switch (ownerResult) {
      case (#err(_)) { return #err("Bot does not exist") };
      case (#ok(owner)) {
        if (owner != walletAccountId) {
          return #err("You do not own this bot");
        };
      };
    };

    // Check if bot is on scavenging mission
    let stats = switch (garageManager.getStats(tokenIndex)) {
      case (null) { return #err("Bot not found in garage") };
      case (?s) { s };
    };

    switch (stats.activeMission) {
      case (?_mission) {
        return #err("Cannot repair while bot is on a scavenging mission. Retrieve the bot first.");
      };
      case (null) { /* OK to proceed */ };
    };

    // Check cooldown (3 hours)
    let REPAIR_COOLDOWN : Int = 10800000000000; // 3 hours in nanoseconds
    let now = Time.now();
    switch (stats.lastRepaired) {
      case (?lastTime) {
        let timeSince = now - lastTime;
        if (timeSince < REPAIR_COOLDOWN) {
          let hoursLeft = (REPAIR_COOLDOWN - timeSince) / (60 * 60 * 1_000_000_000);
          let minutesLeft = ((REPAIR_COOLDOWN - timeSince) % (60 * 60 * 1_000_000_000)) / (60 * 1_000_000_000);
          return #err("Repair cooldown active. Time remaining: " # Int.toText(hoursLeft) # "h " # Int.toText(minutesLeft) # "m");
        };
      };
      case (null) { /* First repair, no cooldown */ };
    };

    // Process ICRC-2 payment and repair
    let BASE_REPAIR_COST : Nat = 5_000_000; // 0.05 ICP

    // Apply Industrial faction synergy discount to repair cost
    let synergies = garageManager.calculateFactionSynergies(caller);
    let REPAIR_COST = Nat.max(1_000_000, Int.abs(Float.toInt(Float.fromInt(BASE_REPAIR_COST) * synergies.costMultipliers.repairCost)));

    let ledgerId = switch (icpLedgerCanisterId) {
      case (?id) { id };
      case (null) { return #err("ICP Ledger not configured") };
    };

    let icpLedger = actor (Principal.toText(ledgerId)) : actor {
      icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
    };

    let transferResult = try {
      await icpLedger.icrc2_transfer_from({
        from = { owner = caller; subaccount = null };
        to = { owner = thisPrincipal; subaccount = null };
        amount = REPAIR_COST + TRANSFER_FEE;
        fee = ?TRANSFER_FEE;
        memo = null;
        created_at_time = null;
        spender_subaccount = null;
      });
    } catch (e) {
      return #err("Payment transfer failed: " # Error.message(e));
    };

    switch (transferResult) {
      case (#Err(e)) {
        let errorMsg = switch (e) {
          case (#InsufficientAllowance({ allowance })) {
            "Insufficient spending allowance. Current: " # Nat.toText(allowance / 100000000) # " ICP. Please go to the Garage page and set a spending allowance first.";
          };
          case _ { "Payment failed: " # debug_show (e) };
        };
        #err(errorMsg);
      };
      case (#Ok(_blockIndex)) {
        // Get fresh stats (already checked for mission above)
        let freshStats = switch (garageManager.getStats(tokenIndex)) {
          case (null) { return #err("Bot not found in garage") };
          case (?s) { s };
        };

        let newCondition = Nat.min(100, freshStats.condition + 30);
        let updatedStats = {
          freshStats with
          condition = newCondition;
          lastRepaired = ?Time.now();
        };

        garageManager.updateStats(tokenIndex, updatedStats);
        #ok("Bot repaired successfully!");
      };
    };
  };

  /// Upgrade a bot stat (via ICRC-2 payment or parts)
  public shared ({ caller }) func web_upgrade_bot(
    tokenIndex : Nat,
    upgradeType : PokedBotsGarage.UpgradeType,
    paymentMethod : { #icp; #parts },
  ) : async Result.Result<Text, Text> {
    // Verify ownership
    let walletAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);
    let ownerResult = await extCanister.bearer(
      ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), extCanisterId)
    );

    switch (ownerResult) {
      case (#err(_)) { return #err("Bot does not exist") };
      case (#ok(owner)) {
        if (owner != walletAccountId) {
          return #err("You do not own this bot");
        };
      };
    };

    // Get current stats to calculate V2 upgrade cost
    let stats = switch (garageManager.getStats(tokenIndex)) {
      case (null) { return #err("Bot not found in garage") };
      case (?s) { s };
    };

    let baseStats = garageManager.getBaseStats(tokenIndex);

    // Calculate current stats (base + bonuses)
    let currentSpeed = baseStats.speed + stats.speedBonus;
    let currentPowerCore = baseStats.powerCore + stats.powerCoreBonus;
    let currentAcceleration = baseStats.acceleration + stats.accelerationBonus;
    let currentStability = baseStats.stability + stats.stabilityBonus;
    let overallRating = (currentSpeed + currentPowerCore + currentAcceleration + currentStability) / 4;

    // Calculate current stat and base stat for the upgrade type
    let (baseStat, currentStat) = switch (upgradeType) {
      case (#Velocity) { (baseStats.speed, currentSpeed) };
      case (#PowerCore) { (baseStats.powerCore, currentPowerCore) };
      case (#Thruster) { (baseStats.acceleration, currentAcceleration) };
      case (#Gyro) { (baseStats.stability, currentStability) };
    };

    // Use V2 dynamic cost calculation
    let synergies = garageManager.calculateFactionSynergies(caller);
    let icpCost = garageManager.calculateUpgradeCostV2(baseStat, currentStat, overallRating, synergies.costMultipliers.upgradeCost);
    let partsCost = icpCost / 1_000_000; // Convert e8s to parts (100 parts = 1 ICP, so 1 part = 0.01 ICP = 1_000_000 e8s)

    switch (paymentMethod) {
      case (#icp) {
        // Process ICP payment via ICRC-2
        let ledgerId = switch (icpLedgerCanisterId) {
          case (?id) { id };
          case (null) { return #err("ICP Ledger not configured") };
        };

        let icpLedger = actor (Principal.toText(ledgerId)) : actor {
          icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
        };

        let transferResult = try {
          await icpLedger.icrc2_transfer_from({
            from = { owner = caller; subaccount = null };
            to = { owner = thisPrincipal; subaccount = null };
            amount = icpCost;
            fee = null;
            memo = null;
            created_at_time = null;
            spender_subaccount = null;
          });
        } catch (e) {
          return #err("Payment transfer failed: " # Error.message(e));
        };

        switch (transferResult) {
          case (#Err(e)) {
            let errorMsg = switch (e) {
              case (#InsufficientAllowance({ allowance })) {
                "Insufficient spending allowance. Current: " # Nat.toText(allowance / 100000000) # " ICP. Please go to the Garage page and set a spending allowance first.";
              };
              case _ { "Payment failed: " # debug_show (e) };
            };
            #err(errorMsg);
          };
          case (#Ok(_blockIndex)) {
            // Start upgrade session with V2 parameters
            let now = Time.now();
            let UPGRADE_DURATION : Int = 12 * 60 * 60 * 1_000_000_000; // 12 hours in nanoseconds
            let endsAt = now + UPGRADE_DURATION;

            let pityCounter = garageManager.getPityCounter(tokenIndex);
            garageManager.startUpgrade(tokenIndex, upgradeType, now, endsAt, pityCounter, icpCost, "icp", 0);

            // Schedule timer to complete the upgrade
            ignore tt().setActionSync<system>(
              Int.abs(endsAt),
              {
                actionType = "upgrade_complete";
                params = to_candid (tokenIndex);
              },
            );

            // Update bot stats with upgradeEndsAt
            let updatedStats = {
              stats with
              upgradeEndsAt = ?endsAt;
            };
            garageManager.updateStats(tokenIndex, updatedStats);

            #ok("Upgrade started! Will complete in 12 hours.");
          };
        };
      };
      case (#parts) {
        // Deduct parts from inventory
        let partType : PokedBotsGarage.PartType = switch (upgradeType) {
          case (#Velocity) { #SpeedChip };
          case (#PowerCore) { #PowerCoreFragment };
          case (#Thruster) { #ThrusterKit };
          case (#Gyro) { #GyroModule };
        };

        if (not garageManager.removeParts(caller, partType, partsCost)) {
          return #err("Insufficient parts. Needed: " # Nat.toText(partsCost) # " " # debug_show (partType));
        };

        // Start upgrade with V2 parameters
        let now = Time.now();
        let UPGRADE_DURATION : Int = 12 * 60 * 60 * 1_000_000_000;
        let endsAt = now + UPGRADE_DURATION;

        let pityCounter = garageManager.getPityCounter(tokenIndex);
        garageManager.startUpgrade(tokenIndex, upgradeType, now, endsAt, pityCounter, icpCost, "parts", partsCost);

        // Schedule timer to complete the upgrade
        ignore tt().setActionSync<system>(
          Int.abs(endsAt),
          {
            actionType = "upgrade_complete";
            params = to_candid (tokenIndex);
          },
        );

        // Update bot stats with upgradeEndsAt
        let updatedStats = {
          stats with
          upgradeEndsAt = ?endsAt;
        };
        garageManager.updateStats(tokenIndex, updatedStats);

        #ok("Upgrade started with parts! Will complete in 12 hours.");
      };
    };
  };

  /// Cancel an in-progress upgrade and receive a full refund
  public shared ({ caller }) func web_cancel_upgrade(
    tokenIndex : Nat
  ) : async Result.Result<Text, Text> {
    // Verify ownership
    let walletAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);
    let ownerResult = await extCanister.bearer(
      ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), extCanisterId)
    );

    switch (ownerResult) {
      case (#err(_)) { return #err("Bot does not exist") };
      case (#ok(owner)) {
        if (owner != walletAccountId) {
          return #err("You do not own this bot");
        };
      };
    };

    // Get racing stats
    let stats = switch (garageManager.getStats(tokenIndex)) {
      case (null) { return #err("Bot not found in garage") };
      case (?s) { s };
    };

    // Check for active upgrade
    let upgradeSession = switch (garageManager.getActiveUpgrade(tokenIndex)) {
      case (null) { return #err("No active upgrade to cancel") };
      case (?session) { session };
    };

    // Process refund based on payment method
    if (upgradeSession.paymentMethod == "icp") {
      // Refund ICP (full amount minus transfer fee)
      let TRANSFER_FEE = 10000 : Nat;
      if (upgradeSession.costPaid > TRANSFER_FEE) {
        // Get ICP Ledger canister
        let ledgerId = switch (icpLedgerCanisterId) {
          case (?id) { id };
          case (null) { return #err("ICP Ledger not configured") };
        };

        let icpLedger = actor (Principal.toText(ledgerId)) : actor {
          icrc1_transfer : shared IcpLedger.TransferArg -> async IcpLedger.Result;
        };

        let refundAmount = upgradeSession.costPaid - TRANSFER_FEE;
        let transferResult = await icpLedger.icrc1_transfer({
          from_subaccount = null;
          to = { owner = caller; subaccount = null };
          amount = refundAmount;
          fee = ?TRANSFER_FEE;
          memo = null;
          created_at_time = null;
        });

        switch (transferResult) {
          case (#Err(e)) {
            return #err("ICP refund failed: " # debug_show (e));
          };
          case (#Ok(_)) { /* Refund successful, continue */ };
        };
      };
    } else {
      // Refund parts of the correct type
      let partType : PokedBotsGarage.PartType = switch (upgradeSession.upgradeType) {
        case (#Velocity) { #SpeedChip };
        case (#PowerCore) { #PowerCoreFragment };
        case (#Thruster) { #ThrusterKit };
        case (#Gyro) { #GyroModule };
      };
      garageManager.addParts(caller, partType, upgradeSession.partsUsed);
    };

    // Clear the upgrade session and update bot stats
    garageManager.clearUpgrade(tokenIndex);
    garageManager.setUpgradeEndsAt(tokenIndex, null);

    let upgradeTypeName = switch (upgradeSession.upgradeType) {
      case (#Velocity) { "Velocity" };
      case (#PowerCore) { "Power Core" };
      case (#Thruster) { "Thruster" };
      case (#Gyro) { "Gyro" };
    };

    let refundText = if (upgradeSession.paymentMethod == "icp") {
      let icpAmount = Float.fromInt(upgradeSession.costPaid - 10000) / 100_000_000.0;
      "Refunded " # Float.toText(icpAmount) # " ICP";
    } else {
      "Refunded " # Nat.toText(upgradeSession.partsUsed) # " parts";
    };

    #ok("Upgrade cancelled. " # refundText # " returned to your account.");
  };

  /// Respec a bot - reset all upgrades and refund parts (with penalty)
  /// Cost: 1 ICP (flat rate)
  public shared ({ caller }) func web_respec_bot(
    tokenIndex : Nat
  ) : async Result.Result<{ speedPartsRefunded : Nat; powerCorePartsRefunded : Nat; accelerationPartsRefunded : Nat; stabilityPartsRefunded : Nat; totalRefunded : Nat; respecCost : Nat }, Text> {
    // Verify ownership
    let walletAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);
    let ownerResult = await extCanister.bearer(
      ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), extCanisterId)
    );

    switch (ownerResult) {
      case (#err(_)) { return #err("Bot does not exist") };
      case (#ok(owner)) {
        if (owner != walletAccountId) {
          return #err("You do not own this bot");
        };
      };
    };

    // Get current stats
    let stats = switch (garageManager.getStats(tokenIndex)) {
      case (null) { return #err("Bot not initialized") };
      case (?s) { s };
    };

    // Calculate respec cost
    let respecCost = garageManager.calculateRespecCost(stats.respecCount);

    // Process ICRC-2 payment
    let ledgerId = switch (icpLedgerCanisterId) {
      case (?id) { id };
      case (null) { return #err("ICP Ledger not configured") };
    };

    let icpLedger = actor (Principal.toText(ledgerId)) : actor {
      icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
    };

    let transferResult = try {
      await icpLedger.icrc2_transfer_from({
        from = { owner = caller; subaccount = null };
        to = { owner = thisPrincipal; subaccount = null };
        amount = respecCost + TRANSFER_FEE;
        fee = ?TRANSFER_FEE;
        memo = null;
        created_at_time = null;
        spender_subaccount = null;
      });
    } catch (e) {
      return #err("Payment transfer failed: " # Error.message(e));
    };

    switch (transferResult) {
      case (#Err(e)) {
        let errorMsg = switch (e) {
          case (#InsufficientAllowance({ allowance })) {
            let requiredICP = (respecCost + TRANSFER_FEE) / 100_000_000;
            "Insufficient spending allowance. Required: " # Nat.toText(requiredICP) # " ICP. Current: " # Nat.toText(allowance / 100_000_000) # " ICP. Please set a higher allowance first.";
          };
          case _ { "Payment failed: " # debug_show (e) };
        };
        #err(errorMsg);
      };
      case (#Ok(_blockIndex)) {
        // Process respec
        switch (garageManager.respecBot(tokenIndex, caller)) {
          case (#err(msg)) { #err(msg) };
          case (#ok(result)) {
            #ok({
              speedPartsRefunded = result.speedPartsRefunded;
              powerCorePartsRefunded = result.powerCorePartsRefunded;
              accelerationPartsRefunded = result.accelerationPartsRefunded;
              stabilityPartsRefunded = result.stabilityPartsRefunded;
              totalRefunded = result.totalRefunded;
              respecCost = respecCost;
            });
          };
        };
      };
    };
  };

  /// Enter a race (with ICRC-2 payment for entry fee)
  public shared ({ caller }) func web_enter_race(
    raceId : Nat,
    tokenIndex : Nat,
  ) : async Result.Result<Text, Text> {
    // Verify ownership
    let walletAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);
    let ownerResult = await extCanister.bearer(
      ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), extCanisterId)
    );

    switch (ownerResult) {
      case (#err(_)) { return #err("Bot does not exist") };
      case (#ok(owner)) {
        if (owner != walletAccountId) {
          return #err("You do not own this bot");
        };
      };
    };

    // Verify bot is initialized and registered to current owner
    let botStats = switch (garageManager.getStats(tokenIndex)) {
      case (null) {
        return #err("This PokedBot is not initialized for racing. Use garage_initialize_pokedbot first to register it.");
      };
      case (?stats) {
        // Verify caller is the registered owner
        if (not Principal.equal(stats.ownerPrincipal, caller)) {
          return #err("This PokedBot is registered to a different owner. Please use garage_initialize_pokedbot to register it to your account.");
        };
        stats;
      };
    };

    // Get race and verify it exists
    let race = switch (Map.get(stable_races, Map.nhash, raceId)) {
      case (?r) { r };
      case (null) { return #err("Race not found") };
    };

    // Check if bot meets rating requirements for race class
    let rating = garageManager.calculateRatingAt100(botStats);
    let meetsClass = switch (race.raceClass) {
      case (#Scrap) { rating < 20 };
      case (#Junker) {
        rating >= 20 and rating < 30
      };
      case (#Raider) {
        rating >= 30 and rating < 40
      };
      case (#Elite) {
        rating >= 40 and rating < 50
      };
      case (#SilentKlan) {
        rating >= 50;
      };
    };

    if (not meetsClass) {
      return #err("Bot does not meet race class requirements (Rating: " # Nat.toText(rating) # ")");
    };

    // Check if registration is open for this race's event
    let now = Time.now();
    switch (eventCalendar.getEventByRaceId(raceId)) {
      case (?event) {
        // Check if registration window is open
        if (now < event.registrationOpens) {
          let hoursUntilOpen = (event.registrationOpens - now) / (60 * 60 * 1_000_000_000);
          return #err("Registration has not opened yet. Opens in " # Nat.toText(Int.abs(hoursUntilOpen)) # " hours.");
        };
        if (now > event.registrationCloses) {
          return #err("Registration has closed for this event.");
        };
      };
      case (null) {
        // Race not part of an event - allow entry (shouldn't happen normally)
      };
    };

    // Check if bot is already entered in any race within this event BEFORE taking payment
    let nftId = Nat.toText(tokenIndex);
    switch (eventCalendar.getEventByRaceId(raceId)) {
      case (?event) {
        // Check if bot is in any race within this event
        for (eventRaceId in event.raceIds.vals()) {
          switch (Map.get(stable_races, Map.nhash, eventRaceId)) {
            case (?eventRace) {
              for (entry in eventRace.entries.vals()) {
                if (entry.nftId == nftId) {
                  return #err("This bot is already entered in another race in this event (Race #" # Nat.toText(eventRaceId) # ")");
                };
              };
            };
            case (null) {};
          };
        };
      };
      case (null) {}; // No event, allow entry
    };

    // Process entry fee via ICRC-2
    let ledgerId = switch (icpLedgerCanisterId) {
      case (?id) { id };
      case (null) { return #err("ICP Ledger not configured") };
    };

    let icpLedger = actor (Principal.toText(ledgerId)) : actor {
      icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
    };

    let transferResult = try {
      await icpLedger.icrc2_transfer_from({
        from = { owner = caller; subaccount = null };
        to = { owner = thisPrincipal; subaccount = null };
        amount = race.entryFee;
        fee = null;
        memo = null;
        created_at_time = null;
        spender_subaccount = null;
      });
    } catch (e) {
      return #err("Payment transfer failed: " # Error.message(e));
    };

    switch (transferResult) {
      case (#Err(err)) {
        #err("Entry fee payment failed: " # debug_show (err));
      };
      case (#Ok(_blockIndex)) {
        // Enter the race
        let now = Time.now();
        let nftId = Nat.toText(tokenIndex); // Store token index as text, not EXT identifier
        switch (raceManager.enterRace(raceId, nftId, caller, now)) {
          case (?_updatedRace) {
            #ok("Successfully entered race!");
          };
          case (null) {
            #err("Failed to enter race - bot may already be entered, race may be full, or race is closed");
          };
        };
      };
    };
  };

  /// Start a scavenging mission (web method)
  public shared ({ caller }) func web_start_scavenging(
    tokenIndex : Nat,
    zone : Text,
    durationMinutes : ?Nat,
  ) : async Result.Result<Text, Text> {
    // Verify ownership
    let walletAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);
    let ownerResult = await extCanister.bearer(
      ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), extCanisterId)
    );

    switch (ownerResult) {
      case (#err(_)) { return #err("Bot does not exist") };
      case (#ok(owner)) {
        if (owner != walletAccountId) {
          return #err("You do not own this bot");
        };
      };
    };

    // Parse zone
    let parsedZone : PokedBotsGarage.ScavengingZone = switch (zone) {
      case ("ScrapHeaps") { #ScrapHeaps };
      case ("AbandonedSettlements") { #AbandonedSettlements };
      case ("DeadMachineFields") { #DeadMachineFields };
      case ("RepairBay") { #RepairBay };
      case ("ChargingStation") { #ChargingStation };
      case (_) {
        return #err("Invalid zone. Must be ScrapHeaps, AbandonedSettlements, DeadMachineFields, RepairBay, or ChargingStation");
      };
    };

    // Start continuous mission
    let now = Time.now();
    switch (garageManager.startScavengingMission(tokenIndex, parsedZone, now, durationMinutes)) {
      case (#ok(_)) {
        // Schedule first accumulation in 15 minutes
        let next15Min = now + (15 * 60 * 1_000_000_000);
        ignore tt().setActionSync<system>(
          Int.abs(next15Min),
          {
            actionType = "scavenge_accumulate";
            params = to_candid (tokenIndex);
          },
        );

        // If duration provided, schedule auto-complete
        let message = switch (durationMinutes) {
          case (?minutes) {
            let endTime = now + (minutes * 60 * 1_000_000_000);
            ignore tt().setActionSync<system>(
              Int.abs(endTime),
              {
                actionType = "scavenge_auto_complete";
                params = to_candid (tokenIndex);
              },
            );
            "Scavenging started for " # Nat.toText(minutes) # " minutes! Bot will accumulate rewards every 15 minutes and auto-collect when done.";
          };
          case (null) {
            "Continuous scavenging started! Bot will accumulate rewards every 15 minutes. Collect anytime.";
          };
        };

        #ok(message);
      };
      case (#err(msg)) {
        #err(msg);
      };
    };
  };

  /// Complete a scavenging mission and collect rewards (web method)
  public shared ({ caller }) func web_complete_scavenging(
    tokenIndex : Nat
  ) : async Result.Result<Text, Text> {
    // Verify ownership
    let walletAccountId = ExtIntegration.principalToAccountIdentifier(caller, null);
    let ownerResult = await extCanister.bearer(
      ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), extCanisterId)
    );

    switch (ownerResult) {
      case (#err(_)) { return #err("Bot does not exist") };
      case (#ok(owner)) {
        if (owner != walletAccountId) {
          return #err("You do not own this bot");
        };
      };
    };

    // Complete mission (forces final accumulation)
    let now = Time.now();
    Debug.print("web_complete_scavenging called for bot " # debug_show (tokenIndex));

    switch (garageManager.completeScavengingMissionV2(tokenIndex, now)) {
      case (#ok(result)) {
        Debug.print("web_complete_scavenging SUCCESS for bot " # debug_show (tokenIndex) # ": " # debug_show (result.totalParts) # " parts");

        // Verify lastMissionRewards was stored
        switch (garageManager.getStats(tokenIndex)) {
          case (?stats) {
            Debug.print("Verified stats for bot " # debug_show (tokenIndex) # ", lastMissionRewards: " # debug_show (stats.lastMissionRewards));
          };
          case (null) {
            Debug.print("WARNING: Could not retrieve stats after completing mission for bot " # debug_show (tokenIndex));
          };
        };

        // Cancel all pending scavenge_accumulate AND auto_complete timers for this bot
        let scavengeTimers = tt().getActionsByFilter(#ByType("scavenge_accumulate"));
        for ((timerId, timerAction) in scavengeTimers.vals()) {
          let timerTokenOpt : ?Nat = from_candid (timerAction.params);
          switch (timerTokenOpt) {
            case (?timerToken) {
              if (timerToken == tokenIndex) {
                ignore tt().cancelActionsByIds<system>([timerId.id]);
              };
            };
            case (null) {};
          };
        };

        let autoCompleteTimers = tt().getActionsByFilter(#ByType("scavenge_auto_complete"));
        for ((timerId, timerAction) in autoCompleteTimers.vals()) {
          let timerTokenOpt : ?Nat = from_candid (timerAction.params);
          switch (timerTokenOpt) {
            case (?timerToken) {
              if (timerToken == tokenIndex) {
                ignore tt().cancelActionsByIds<system>([timerId.id]);
              };
            };
            case (null) {};
          };
        };

        var message = "Mission complete! Time elapsed: " # Nat.toText(result.hoursOut) # " hours\n";
        message #= "Total parts collected: " # Nat.toText(result.totalParts) # "\n\n";
        message #= "• Speed Chips: " # Nat.toText(result.speedChips) # "\n";
        message #= "• Power Core Fragments: " # Nat.toText(result.powerCoreFragments) # "\n";
        message #= "• Thruster Kits: " # Nat.toText(result.thrusterKits) # "\n";
        message #= "• Gyro Modules: " # Nat.toText(result.gyroModules) # "\n";
        message #= "• Universal Parts: " # Nat.toText(result.universalParts);

        #ok(message);
      };
      case (#err(msg)) {
        #err(msg);
      };
    };
  };

  /// Convert parts from one type to another (25% conversion cost)
  public shared ({ caller }) func web_convert_parts(
    fromType : Text,
    toType : Text,
    amount : Nat,
  ) : async Result.Result<Text, Text> {
    // Parse part types
    let fromPartType = switch (fromType) {
      case ("SpeedChip") { #SpeedChip };
      case ("PowerCoreFragment") { #PowerCoreFragment };
      case ("ThrusterKit") { #ThrusterKit };
      case ("GyroModule") { #GyroModule };
      case ("UniversalPart") { #UniversalPart };
      case (_) { return #err("Invalid fromType: " # fromType) };
    };

    let toPartType = switch (toType) {
      case ("SpeedChip") { #SpeedChip };
      case ("PowerCoreFragment") { #PowerCoreFragment };
      case ("ThrusterKit") { #ThrusterKit };
      case ("GyroModule") { #GyroModule };
      case ("UniversalPart") { #UniversalPart };
      case (_) { return #err("Invalid toType: " # toType) };
    };

    // Call garage manager to do conversion
    switch (garageManager.convertParts(caller, fromPartType, toPartType, amount)) {
      case (#err(e)) { #err(e) };
      case (#ok()) {
        let converted = (amount * 3) / 4;
        #ok("✅ Converted " # Nat.toText(amount) # " " # fromType # " → " # Nat.toText(converted) # " " # toType # " (25% cost)");
      };
    };
  };

  // ===========================
  // WEB BETTING FUNCTIONS
  // ===========================

  /// Get betting pool info for UI
  public query func web_betting_get_pool_info(raceId : Nat) : async ?BettingTypes.BettingPool {
    bettingManager.getPool(raceId);
  };

  /// Get user's betting history for UI
  public shared query ({ caller }) func web_betting_get_my_bets(limit : Nat) : async {
    bets : [{
      bet_id : Nat;
      race_id : Nat;
      token_index : Nat;
      bet_type : Text;
      amount_icp : Text;
      amount_e8s : Nat;
      status : Text;
      timestamp : Int;
      payout : ?{
        payout_icp : Text;
        payout_e8s : Nat;
        roi_percent : Text;
      };
    }];
    count : Nat;
    summary : {
      total_bets : Nat;
      wins : Nat;
      losses : Nat;
      pending : Nat;
      total_wagered_icp : Text;
      total_won_icp : Text;
      net_profit_icp : Text;
      roi_percent : Text;
      win_rate_percent : Text;
    };
  } {
    let userBets = bettingManager.getUserBets(caller, limit);

    // Calculate summary (excluding pending bets from ROI/profit calculations)
    var totalWagered : Nat = 0;
    var totalWon : Nat = 0;
    var wins : Nat = 0;
    var losses : Nat = 0;
    var pending : Nat = 0;

    for (bet in userBets.vals()) {
      switch (bet.status) {
        case (#Won) {
          wins += 1;
          totalWagered += bet.amount; // Only count wagered if bet is settled
          switch (bet.potentialPayout) {
            case (?payout) { totalWon += payout };
            case (null) {};
          };
        };
        case (#Lost) {
          losses += 1;
          totalWagered += bet.amount; // Only count wagered if bet is settled
        };
        case (#Pending or #Active) { pending += 1 }; // Don't count pending in totals
        case (#Refunded) {
          totalWagered += bet.amount;
          totalWon += bet.amount;
        };
      };
    };

    let netProfit : Int = totalWon - totalWagered;
    let settledBets = wins + losses; // Only count settled bets for win rate
    let winRate : Float = if (settledBets > 0) {
      Float.fromInt(wins) / Float.fromInt(settledBets) * 100.0;
    } else {
      0.0;
    };
    let roi : Float = if (totalWagered > 0) {
      (Float.fromInt(totalWon) / Float.fromInt(totalWagered) - 1.0) * 100.0;
    } else {
      0.0;
    };

    // Convert bets to web-friendly format
    let webBets = Array.map<BettingTypes.Bet, { bet_id : Nat; race_id : Nat; token_index : Nat; bet_type : Text; amount_icp : Text; amount_e8s : Nat; status : Text; timestamp : Int; payout : ?{ payout_icp : Text; payout_e8s : Nat; roi_percent : Text } }>(
      userBets,
      func(bet) {
        let statusText = switch (bet.status) {
          case (#Pending) "Pending";
          case (#Active) "Active";
          case (#Won) "Won";
          case (#Lost) "Lost";
          case (#Refunded) "Refunded";
        };

        let betTypeText = switch (bet.betType) {
          case (#Win) "Win";
          case (#Place) "Place";
          case (#Show) "Show";
        };

        let amountIcp = Float.fromInt(bet.amount) / 100_000_000.0;

        let payoutInfo = switch (bet.potentialPayout) {
          case (?payout) {
            let payoutIcp = Float.fromInt(payout) / 100_000_000.0;
            let betRoi = if (bet.amount > 0) {
              (Float.fromInt(payout) / Float.fromInt(bet.amount) - 1.0) * 100.0;
            } else {
              0.0;
            };
            ?{
              payout_icp = Float.format(#fix 2, payoutIcp);
              payout_e8s = payout;
              roi_percent = Float.format(#fix 1, betRoi) # "%";
            };
          };
          case (null) { null };
        };

        {
          bet_id = bet.betId;
          race_id = bet.raceId;
          token_index = bet.tokenIndex;
          bet_type = betTypeText;
          amount_icp = Float.format(#fix 2, amountIcp);
          amount_e8s = bet.amount;
          status = statusText;
          timestamp = bet.timestamp;
          payout = payoutInfo;
        };
      },
    );

    {
      bets = webBets;
      count = userBets.size();
      summary = {
        total_bets = userBets.size();
        wins = wins;
        losses = losses;
        pending = pending;
        total_wagered_icp = Float.format(#fix 2, Float.fromInt(totalWagered) / 100_000_000.0);
        total_won_icp = Float.format(#fix 2, Float.fromInt(totalWon) / 100_000_000.0);
        net_profit_icp = Float.format(#fix 2, Float.fromInt(netProfit) / 100_000_000.0);
        roi_percent = Float.format(#fix 1, roi) # "%";
        win_rate_percent = Float.format(#fix 1, winRate) # "%";
      };
    };
  };

  public shared query ({ caller }) func web_betting_get_my_bets_paginated(limit : Nat, offset : Nat) : async {
    bets : [{
      bet_id : Nat;
      race_id : Nat;
      token_index : Nat;
      bet_type : Text;
      amount_icp : Text;
      amount_e8s : Nat;
      status : Text;
      timestamp : Int;
      payout : ?{
        payout_icp : Text;
        payout_e8s : Nat;
        roi_percent : Text;
      };
    }];
    hasMore : Bool;
    total : Nat;
    summary : {
      total_bets : Nat;
      wins : Nat;
      losses : Nat;
      pending : Nat;
      total_wagered_icp : Text;
      total_won_icp : Text;
      net_profit_icp : Text;
      roi_percent : Text;
      win_rate_percent : Text;
    };
  } {
    let paginatedResult = bettingManager.getUserBetsPaginated(caller, limit, offset);
    let userBets = paginatedResult.bets;

    // Calculate summary from ALL user bets for accurate stats
    let allBetIds = Option.get(Map.get(bettingManager.getUserBetsMap(), bettingManager.getPrincipalHash(), caller), []);
    var totalWagered : Nat = 0;
    var totalWon : Nat = 0;
    var wins : Nat = 0;
    var losses : Nat = 0;
    var pending : Nat = 0;

    for (betId in allBetIds.vals()) {
      switch (Map.get(bettingManager.getBetsMap(), bettingManager.getNatHash(), betId)) {
        case (?bet) {
          switch (bet.status) {
            case (#Won) {
              wins += 1;
              totalWagered += bet.amount;
              switch (bet.potentialPayout) {
                case (?payout) { totalWon += payout };
                case (null) {};
              };
            };
            case (#Lost) {
              losses += 1;
              totalWagered += bet.amount;
            };
            case (#Pending or #Active) { pending += 1 };
            case (#Refunded) {
              totalWagered += bet.amount;
              totalWon += bet.amount;
            };
          };
        };
        case (null) {};
      };
    };

    let netProfit : Int = totalWon - totalWagered;
    let settledBets = wins + losses;
    let winRate : Float = if (settledBets > 0) {
      Float.fromInt(wins) / Float.fromInt(settledBets) * 100.0;
    } else {
      0.0;
    };
    let roi : Float = if (totalWagered > 0) {
      (Float.fromInt(totalWon) / Float.fromInt(totalWagered) - 1.0) * 100.0;
    } else {
      0.0;
    };

    // Convert bets to web-friendly format
    let webBets = Array.map<BettingTypes.Bet, { bet_id : Nat; race_id : Nat; token_index : Nat; bet_type : Text; amount_icp : Text; amount_e8s : Nat; status : Text; timestamp : Int; payout : ?{ payout_icp : Text; payout_e8s : Nat; roi_percent : Text } }>(
      userBets,
      func(bet) {
        let statusText = switch (bet.status) {
          case (#Pending) "Pending";
          case (#Active) "Active";
          case (#Won) "Won";
          case (#Lost) "Lost";
          case (#Refunded) "Refunded";
        };

        let betTypeText = switch (bet.betType) {
          case (#Win) "Win";
          case (#Place) "Place";
          case (#Show) "Show";
        };

        let amountIcp = Float.fromInt(bet.amount) / 100_000_000.0;

        let payoutInfo = switch (bet.potentialPayout) {
          case (?payout) {
            let payoutIcp = Float.fromInt(payout) / 100_000_000.0;
            let betRoi = if (bet.amount > 0) {
              (Float.fromInt(payout) / Float.fromInt(bet.amount) - 1.0) * 100.0;
            } else {
              0.0;
            };
            ?{
              payout_icp = Float.format(#fix 2, payoutIcp);
              payout_e8s = payout;
              roi_percent = Float.format(#fix 1, betRoi) # "%";
            };
          };
          case (null) { null };
        };

        {
          bet_id = bet.betId;
          race_id = bet.raceId;
          token_index = bet.tokenIndex;
          bet_type = betTypeText;
          amount_icp = Float.format(#fix 2, amountIcp);
          amount_e8s = bet.amount;
          status = statusText;
          timestamp = bet.timestamp;
          payout = payoutInfo;
        };
      },
    );

    {
      bets = webBets;
      hasMore = paginatedResult.hasMore;
      total = paginatedResult.total;
      summary = {
        total_bets = paginatedResult.total;
        wins = wins;
        losses = losses;
        pending = pending;
        total_wagered_icp = Float.format(#fix 2, Float.fromInt(totalWagered) / 100_000_000.0);
        total_won_icp = Float.format(#fix 2, Float.fromInt(totalWon) / 100_000_000.0);
        net_profit_icp = Float.format(#fix 2, Float.fromInt(netProfit) / 100_000_000.0);
        roi_percent = Float.format(#fix 1, roi) # "%";
        win_rate_percent = Float.format(#fix 1, winRate) # "%";
      };
    };
  };

  /// Place a bet for UI
  public shared ({ caller }) func web_betting_place_bet(
    raceId : Nat,
    tokenIndex : Nat,
    betType : BettingTypes.BetType,
    amountE8s : Nat,
  ) : async Result.Result<{ betId : Nat; currentOdds : Float; potentialPayout : Nat }, Text> {
    // Validate amount
    if (amountE8s < 1_000_000) {
      return #err("Minimum bet is 0.01 ICP");
    };
    if (amountE8s > 10_000_000_000) {
      return #err("Maximum bet is 100 ICP");
    };

    // Get pool
    let pool = switch (bettingManager.getPool(raceId)) {
      case (?p) { p };
      case (null) { return #err("Betting pool not found") };
    };

    // Check status
    if (pool.status != #Open) {
      return #err("Betting is not currently open for this race");
    };

    // Check timing
    let now = Time.now();
    if (now < pool.bettingOpensAt or now >= pool.bettingClosesAt) {
      return #err("Outside betting window");
    };

    // Check bot is in race
    let botInRace = Array.find<Nat>(pool.entrants, func(t) { t == tokenIndex });
    if (botInRace == null) {
      return #err("Bot #" # Nat.toText(tokenIndex) # " is not entered in this race");
    };

    // Check user hasn't exceeded per-race limit (100 ICP)
    let userBetsInRace = bettingManager.getUserBetsForRaceDetailed(caller, raceId);
    var userTotal : Nat = 0;
    for (bet in userBetsInRace.vals()) {
      userTotal += bet.amount;
    };
    if (userTotal + amountE8s > 10_000_000_000) {
      return #err("Maximum 100 ICP total per race");
    };

    // Transfer ICP from user to betting pool subaccount
    let ledgerCanisterId = switch (icpLedgerCanisterId) {
      case (?id) { id };
      case (null) { return #err("ICP Ledger not configured") };
    };

    let ledger = actor (Principal.toText(ledgerCanisterId)) : actor {
      icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
    };

    let poolSubaccount = bettingManager.getPoolSubaccount(raceId);

    let transferResult = try {
      await ledger.icrc2_transfer_from({
        from = { owner = caller; subaccount = null };
        to = { owner = thisPrincipal; subaccount = ?poolSubaccount };
        amount = amountE8s;
        fee = null;
        memo = null;
        created_at_time = null;
        spender_subaccount = null;
      });
    } catch (e) {
      return #err("Transfer failed: " # Error.message(e));
    };

    switch (transferResult) {
      case (#Ok(blockIndex)) {
        // Record bet
        let betResult = bettingManager.placeBet(caller, raceId, tokenIndex, betType, amountE8s);
        switch (betResult) {
          case (#ok(betId)) {
            // Calculate current odds
            let odds = bettingManager.calculateOdds(raceId, tokenIndex, betType);
            let potentialPayout = Float.toInt(Float.fromInt(amountE8s) * odds);

            #ok({
              betId = betId;
              currentOdds = odds;
              potentialPayout = Int.abs(potentialPayout);
            });
          };
          case (#err(msg)) {
            // Transfer succeeded but bet recording failed - this shouldn't happen
            // Funds are in pool subaccount, could be refunded manually if needed
            #err("Bet recording failed: " # msg);
          };
        };
      };
      case (#Err(err)) {
        let errMsg = switch (err) {
          case (#BadFee { expected_fee }) {
            "Bad fee, expected: " # Nat.toText(expected_fee);
          };
          case (#InsufficientFunds { balance }) {
            "Insufficient funds, balance: " # Nat.toText(balance);
          };
          case (#InsufficientAllowance { allowance }) {
            "Insufficient allowance: " # Nat.toText(allowance) # ". Please approve the racing canister first.";
          };
          case (#TooOld) { "Transfer too old" };
          case (#CreatedInFuture { ledger_time }) {
            "Transfer created in future";
          };
          case (#Duplicate { duplicate_of }) { "Duplicate transfer" };
          case (#TemporarilyUnavailable) { "Ledger temporarily unavailable" };
          case (#GenericError { error_code; message }) {
            "Error " # Nat.toText(error_code) # ": " # message;
          };
          case _ { "Transfer failed" };
        };
        #err(errMsg);
      };
    };
  };

  /// List betting pools for UI
  public query func web_betting_list_pools(
    statusFilter : ?BettingTypes.PoolStatus,
    limit : Nat,
  ) : async {
    pools : [{
      raceId : Nat;
      status : BettingTypes.PoolStatus;
      totalPooled : Nat;
      totalBets : Nat;
      bettingOpensAt : Int;
      bettingClosesAt : Int;
    }];
  } {
    let allPools = bettingManager.listPools(statusFilter, limit);

    let simplified = Array.map<BettingTypes.BettingPool, { raceId : Nat; status : BettingTypes.PoolStatus; totalPooled : Nat; totalBets : Nat; bettingOpensAt : Int; bettingClosesAt : Int }>(
      allPools,
      func(pool) {
        {
          raceId = pool.raceId;
          status = pool.status;
          totalPooled = pool.winPool + pool.placePool + pool.showPool;
          totalBets = pool.betIds.size();
          bettingOpensAt = pool.bettingOpensAt;
          bettingClosesAt = pool.bettingClosesAt;
        };
      },
    );

    { pools = simplified };
  };
};
