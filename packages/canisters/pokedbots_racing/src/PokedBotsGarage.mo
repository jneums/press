import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Map "mo:map/Map";
import { nhash; phash } "mo:map/Map";
import RacingSimulator "./RacingSimulator";
import ELO "./ELO";

/// PokedBotsGarage - Collection-Specific Racing Logic
/// Handles PokedBots NFT stats, factions, upgrades, and marketplace integration
module {
  // ===== POKEDBOTS-SPECIFIC TYPES =====

  public type FactionType = {
    // Ultra-Rare (1-45 bots)
    #UltimateMaster; // 1 bot
    #Wild; // 5 bots
    #Golden; // 27 bots
    #Ultimate; // 45 bots

    // Super-Rare (244-640 bots)
    #Blackhole; // 244 bots
    #Dead; // 382 bots
    #Master; // 640 bots

    // Rare (717-999 bots)
    #Bee; // 717 bots
    #Food; // 778 bots
    #Box; // 798 bots
    #Murder; // 999 bots

    // Common (1654-2009 bots)
    #Game; // 1654 bots
    #Animal; // 1701 bots
    #Industrial; // 2009 bots
  };

  public type Distance = {
    #ShortSprint;
    #MediumHaul;
    #LongTrek;
  };

  public type Terrain = RacingSimulator.Terrain;

  public type PokedBotRacingStats = {
    tokenIndex : Nat;
    ownerPrincipal : Principal;
    faction : FactionType;
    name : ?Text; // Optional custom name for the bot

    // Upgrade bonuses
    speedBonus : Nat;
    powerCoreBonus : Nat;
    accelerationBonus : Nat;
    stabilityBonus : Nat;

    // Upgrade counts (for progressive costs)
    speedUpgrades : Nat;
    powerCoreUpgrades : Nat;
    accelerationUpgrades : Nat;
    stabilityUpgrades : Nat;

    // Respec system
    respecCount : Nat; // Number of times bot has been respecced (affects cost)

    // Dynamic stats
    battery : Nat;
    condition : Nat;
    experience : Nat;
    overcharge : Nat; // Overcharge (0-75%), earned by recharging at low battery, consumed in next race for stat boost

    // Preferences
    preferredDistance : Distance;
    preferredTerrain : Terrain;

    // Career stats
    racesEntered : Nat;
    wins : Nat;
    places : Nat;
    shows : Nat;
    totalScrapEarned : Nat; // Total ICP earnings from races (legacy naming)
    factionReputation : Nat;
    eloRating : Nat; // ELO rating for skill-based matchmaking (default 1500)

    // Timestamps
    activatedAt : Int;
    lastDecayed : Int;
    lastRecharged : ?Int;
    lastRepaired : ?Int;
    lastDiagnostics : ?Int;
    lastRaced : ?Int;
    upgradeEndsAt : ?Int;
    listedForSale : Bool;

    // Scavenging stats
    scavengingMissions : Nat; // Total missions completed
    totalPartsScavenged : Nat; // Lifetime parts found
    scavengingReputation : Nat; // Separate progression from racing
    bestHaul : Nat; // Biggest single mission haul
    activeMission : ?ScavengingMission; // Current mission if any
    worldBuff : ?WorldBuff; // Active world buff if any
    lastMissionRewards : ?{
      // Last completed mission summary
      totalParts : Nat;
      speedChips : Nat;
      powerCoreFragments : Nat;
      thrusterKits : Nat;
      gyroModules : Nat;
      universalParts : Nat;
      hoursOut : Nat;
      completedAt : Int;
      zone : ScavengingZone;
    };
  };

  public type UpgradeType = {
    #Velocity;
    #PowerCore;
    #Thruster;
    #Gyro;
  };

  public type UpgradeSession = {
    tokenIndex : Nat;
    upgradeType : UpgradeType;
    startedAt : Int;
    endsAt : Int;
    consecutiveFails : Nat; // For pity system
    costPaid : Nat; // In e8s, for refunds (ICP only)
    paymentMethod : Text; // "icp" or "parts"
    partsUsed : Nat; // Number of parts consumed (for parts payment refunds)
  };

  public type UpgradeResult = {
    success : Bool;
    pointsAwarded : Nat; // 0, 1, or 2
    refundAmount : Nat; // In e8s
    newPityCounter : Nat;
  };

  // Scavenging System Types
  // Removed - continuous scavenging has no fixed durations
  // public type ScavengingMissionType = {
  //   #ShortExpedition; // 5 hours
  //   #DeepSalvage; // 11 hours
  //   #WastelandExpedition; // 23 hours
  // };

  public type ScavengingZone = {
    #ScrapHeaps; // 1.0x multipliers (safe)
    #AbandonedSettlements; // 1.2x battery, 1.3x condition, 1.4x parts
    #DeadMachineFields; // 1.5x battery, 1.8x condition, 2.0x parts
    #RepairBay; // 1.0x battery drain, restores condition instead of gathering parts
    #ChargingStation; // No battery drain, restores +1 battery per tick (free charging)
  };

  // Continuous scavenging mission - toggle on/off, accumulate rewards every 15 minutes
  public type ScavengingMission = {
    missionId : Nat;
    tokenIndex : Nat;
    zone : ScavengingZone; // Locked at start, cannot change without ending mission
    startTime : Int; // When mission started (calculate hours elapsed from this)
    lastAccumulation : Int; // Last time rewards were accumulated (15-min intervals)
    durationMinutes : ?Nat; // Optional: auto-complete after this many minutes (null = continuous)
    // Pending rewards (accumulated but not yet collected - LOST if bot dies)
    pendingParts : {
      speedChips : Nat;
      powerCoreFragments : Nat;
      thrusterKits : Nat;
      gyroModules : Nat;
      universalParts : Nat;
    };
    pendingConditionRestored : Nat; // For RepairBay missions - condition points restored so far
    pendingBatteryRestored : Nat; // For ChargingStation missions - battery points restored so far
  };

  public type WorldBuff = {
    stats : [(Text, Nat)]; // e.g., [("speed", 3), ("acceleration", 2)]
    appliedAt : Int; // When buff was earned
    expiresAt : Int; // 48 hours from appliedAt
  };

  public type PartType = {
    #SpeedChip;
    #PowerCoreFragment;
    #ThrusterKit;
    #GyroModule;
    #UniversalPart;
  };

  public type UserInventory = {
    owner : Principal;
    speedChips : Nat;
    powerCoreFragments : Nat;
    thrusterKits : Nat;
    gyroModules : Nat;
    universalParts : Nat;
  };

  // Import stat derivation functions from Racing module (we'll keep these here)
  // These will be extracted and cleaned up

  /// Hash text to number for deterministic randomness
  private func _hashText(text : Text) : Nat {
    var hash : Nat = 0;
    for (char in text.chars()) {
      hash := (hash * 31 + Nat32.toNat(Char.toNat32(char))) % 1000000;
    };
    hash;
  };

  /// Hash nat for deterministic randomness
  private func hashNat(n : Nat) : Nat {
    let a = n * 2654435761;
    let b = a % 4294967296;
    let c = (b * 1103515245 + 12345) % 2147483648;
    c;
  };

  // ===== POKEDBOTS GARAGE MANAGER =====

  public class PokedBotsGarageManager(
    initStats : Map.Map<Nat, PokedBotRacingStats>,
    initActiveUpgrades : Map.Map<Nat, UpgradeSession>,
    initUserInventories : Map.Map<Principal, UserInventory>,
    initPityCounters : Map.Map<Nat, Nat>,
    statsProvider : {
      getNFTMetadata : (Nat) -> ?[(Text, Text)];
      getPrecomputedStats : (Nat) -> ?{
        speed : Nat;
        powerCore : Nat;
        acceleration : Nat;
        stability : Nat;
        faction : FactionType;
      };
    },
  ) {
    private let stats = initStats;
    private let activeUpgrades = initActiveUpgrades;
    private let userInventories = initUserInventories;
    private let pityCounters = initPityCounters;

    // Mission ID counter for scavenging
    private var nextMissionId : Nat = 0;

    public func getNextMissionId() : Nat {
      let id = nextMissionId;
      nextMissionId += 1;
      id;
    };

    // ===== RACING STATS PROVIDER IMPLEMENTATION =====

    /// Apply faction terrain bonuses for racing
    private func applyTerrainBonus(stats : { speed : Nat; powerCore : Nat; acceleration : Nat; stability : Nat }, faction : FactionType, terrain : Terrain, condition : Nat) : {
      speed : Nat;
      powerCore : Nat;
      acceleration : Nat;
      stability : Nat;
    } {
      var speed = stats.speed;
      var powerCore = stats.powerCore;
      var acceleration = stats.acceleration;
      var stability = stats.stability;

      // Apply faction bonuses
      switch (faction) {
        // Ultra-Rare Factions
        case (#UltimateMaster) {
          speed := Int.abs(Float.toInt(Float.fromInt(speed) * 1.15));
          powerCore := Int.abs(Float.toInt(Float.fromInt(powerCore) * 1.15));
          acceleration := Int.abs(Float.toInt(Float.fromInt(acceleration) * 1.15));
          stability := Int.abs(Float.toInt(Float.fromInt(stability) * 1.15));
        };
        case (#Wild) {
          acceleration := Int.abs(Float.toInt(Float.fromInt(acceleration) * 1.20));
          stability := Int.abs(Float.toInt(Float.fromInt(stability) * 0.90));
        };
        case (#Golden) {
          if (condition >= 90) {
            speed := Int.abs(Float.toInt(Float.fromInt(speed) * 1.15));
            powerCore := Int.abs(Float.toInt(Float.fromInt(powerCore) * 1.15));
            acceleration := Int.abs(Float.toInt(Float.fromInt(acceleration) * 1.15));
            stability := Int.abs(Float.toInt(Float.fromInt(stability) * 1.15));
          };
        };
        case (#Ultimate) {
          speed := Int.abs(Float.toInt(Float.fromInt(speed) * 1.12));
          acceleration := Int.abs(Float.toInt(Float.fromInt(acceleration) * 1.12));
        };

        // Super-Rare Factions
        case (#Blackhole) {
          if (terrain == #MetalRoads) {
            speed := Int.abs(Float.toInt(Float.fromInt(speed) * 1.12));
            powerCore := Int.abs(Float.toInt(Float.fromInt(powerCore) * 1.12));
            acceleration := Int.abs(Float.toInt(Float.fromInt(acceleration) * 1.12));
            stability := Int.abs(Float.toInt(Float.fromInt(stability) * 1.12));
          };
        };
        case (#Dead) {
          powerCore := Int.abs(Float.toInt(Float.fromInt(powerCore) * 1.10));
          stability := Int.abs(Float.toInt(Float.fromInt(stability) * 1.08));
        };
        case (#Master) {
          speed := Int.abs(Float.toInt(Float.fromInt(speed) * 1.12));
          powerCore := Int.abs(Float.toInt(Float.fromInt(powerCore) * 1.08));
        };

        // Rare Factions
        case (#Bee) {
          acceleration := Int.abs(Float.toInt(Float.fromInt(acceleration) * 1.10));
        };
        case (#Box) {
          if (terrain == #ScrapHeaps) {
            speed := Int.abs(Float.toInt(Float.fromInt(speed) * 1.10));
            powerCore := Int.abs(Float.toInt(Float.fromInt(powerCore) * 1.10));
            acceleration := Int.abs(Float.toInt(Float.fromInt(acceleration) * 1.10));
            stability := Int.abs(Float.toInt(Float.fromInt(stability) * 1.10));
          };
        };
        case (#Murder) {
          speed := Int.abs(Float.toInt(Float.fromInt(speed) * 1.08));
          acceleration := Int.abs(Float.toInt(Float.fromInt(acceleration) * 1.08));
        };

        // Common Factions
        case (#Game) {
          if (terrain == #WastelandSand) {
            speed := Int.abs(Float.toInt(Float.fromInt(speed) * 1.08));
            powerCore := Int.abs(Float.toInt(Float.fromInt(powerCore) * 1.08));
            acceleration := Int.abs(Float.toInt(Float.fromInt(acceleration) * 1.08));
            stability := Int.abs(Float.toInt(Float.fromInt(stability) * 1.08));
          };
        };
        case (#Animal) {
          speed := Int.abs(Float.toInt(Float.fromInt(speed) * 1.06));
          powerCore := Int.abs(Float.toInt(Float.fromInt(powerCore) * 1.06));
          acceleration := Int.abs(Float.toInt(Float.fromInt(acceleration) * 1.06));
          stability := Int.abs(Float.toInt(Float.fromInt(stability) * 1.06));
        };
        case (#Industrial) {
          powerCore := Int.abs(Float.toInt(Float.fromInt(powerCore) * 1.05));
          stability := Int.abs(Float.toInt(Float.fromInt(stability) * 1.05));
        };

        // Food faction has no racing bonuses (condition recovery only)
        case (#Food) {};
      };

      {
        speed = Nat.min(100, speed);
        powerCore = Nat.min(100, powerCore);
        acceleration = Nat.min(100, acceleration);
        stability = Nat.min(100, stability);
      };
    };

    /// Get racing stats for the generic racing simulator (without terrain bonuses)
    public func getRacingStats(nftId : Text) : ?RacingSimulator.RacingStats {
      let tokenIndex = Nat.fromText(nftId);
      switch (tokenIndex) {
        case (?idx) {
          switch (Map.get(stats, nhash, idx)) {
            case (?botStats) {
              let current = getCurrentStats(botStats);
              ?{
                speed = current.speed;
                powerCore = current.powerCore;
                acceleration = current.acceleration;
                stability = current.stability;
              };
            };
            case (null) { null };
          };
        };
        case (null) { null };
      };
    };

    /// Get racing stats WITH terrain bonuses applied
    public func getRacingStatsWithTerrain(nftId : Text, terrain : Terrain) : ?RacingSimulator.RacingStats {
      let tokenIndex = Nat.fromText(nftId);
      switch (tokenIndex) {
        case (?idx) {
          switch (Map.get(stats, nhash, idx)) {
            case (?botStats) {
              // Note: Bot might have been pulled from scavenging when entering race
              // No special handling needed here - proceed with normal stat calculation

              let current = getCurrentStats(botStats);
              let boosted = applyTerrainBonus(current, botStats.faction, terrain, botStats.condition);

              // Apply preferred terrain bonus (+5% if racing on preferred terrain)
              let finalStats = if (botStats.preferredTerrain == terrain) {
                {
                  speed = Nat.max(1, Int.abs(Float.toInt(Float.fromInt(boosted.speed) * 1.05)));
                  powerCore = Nat.max(1, Int.abs(Float.toInt(Float.fromInt(boosted.powerCore) * 1.05)));
                  acceleration = Nat.max(1, Int.abs(Float.toInt(Float.fromInt(boosted.acceleration) * 1.05)));
                  stability = Nat.max(1, Int.abs(Float.toInt(Float.fromInt(boosted.stability) * 1.05)));
                };
              } else {
                boosted;
              };

              ?{
                speed = finalStats.speed;
                powerCore = finalStats.powerCore;
                acceleration = finalStats.acceleration;
                stability = finalStats.stability;
              };
            };
            case (null) { null };
          };
        };
        case (null) { null };
      };
    };

    /// Get racing stats at 100% battery/condition with terrain bonuses (for simulator)
    /// This matches what the frontend sees via get_bot_profile
    public func getStatsAt100WithTerrain(nftId : Text, terrain : Terrain) : ?RacingSimulator.RacingStats {
      let tokenIndex = Nat.fromText(nftId);
      switch (tokenIndex) {
        case (?idx) {
          switch (Map.get(stats, nhash, idx)) {
            case (?botStats) {
              // Get base stats + bonuses (no battery/condition penalties)
              let baseStats = getBaseStats(idx);
              let statsAt100 = {
                speed = baseStats.speed + botStats.speedBonus;
                powerCore = baseStats.powerCore + botStats.powerCoreBonus;
                acceleration = baseStats.acceleration + botStats.accelerationBonus;
                stability = baseStats.stability + botStats.stabilityBonus;
              };

              // Apply faction terrain bonuses (condition=100 for Golden faction bonus)
              let boosted = applyTerrainBonus(statsAt100, botStats.faction, terrain, 100);

              // Apply preferred terrain bonus (+5% if racing on preferred terrain)
              let finalStats = if (botStats.preferredTerrain == terrain) {
                {
                  speed = Nat.max(1, Int.abs(Float.toInt(Float.fromInt(boosted.speed) * 1.05)));
                  powerCore = Nat.max(1, Int.abs(Float.toInt(Float.fromInt(boosted.powerCore) * 1.05)));
                  acceleration = Nat.max(1, Int.abs(Float.toInt(Float.fromInt(boosted.acceleration) * 1.05)));
                  stability = Nat.max(1, Int.abs(Float.toInt(Float.fromInt(boosted.stability) * 1.05)));
                };
              } else {
                boosted;
              };

              ?{
                speed = finalStats.speed;
                powerCore = finalStats.powerCore;
                acceleration = finalStats.acceleration;
                stability = finalStats.stability;
              };
            };
            case (null) { null };
          };
        };
        case (null) { null };
      };
    };

    /// Check if bot can race (always true if initialized)
    public func canRace(nftId : Text) : Bool {
      let tokenIndex = Nat.fromText(nftId);
      switch (tokenIndex) {
        case (?idx) {
          switch (Map.get(stats, nhash, idx)) {
            case (?botStats) { true };
            case (null) { false };
          };
        };
        case (null) { false };
      };
    };

    /// Record race result (update career stats)
    public func recordRaceResult(nftId : Text, position : Nat, _racers : Nat, prize : Nat) {
      let tokenIndex = Nat.fromText(nftId);
      switch (tokenIndex) {
        case (?idx) {
          switch (Map.get(stats, nhash, idx)) {
            case (?botStats) {
              let updatedStats = {
                botStats with
                racesEntered = botStats.racesEntered + 1;
                wins = if (position == 1) { botStats.wins + 1 } else {
                  botStats.wins;
                };
                places = if (position == 2) { botStats.places + 1 } else {
                  botStats.places;
                };
                shows = if (position == 3) { botStats.shows + 1 } else {
                  botStats.shows;
                };
                totalScrapEarned = botStats.totalScrapEarned + prize; // Tracks total ICP earnings
                experience = botStats.experience + (if (position == 1) { 20 } else if (position <= 3) { 10 } else { 5 });
                factionReputation = botStats.factionReputation + (if (position == 1) { 10 } else if (position <= 3) { 5 } else { 2 });
                lastRaced = ?Time.now();
              };
              updateStats(idx, updatedStats);
            };
            case (null) {};
          };
        };
        case (null) {};
      };
    };

    /// Calculate and apply ELO changes for all race participants
    /// Should be called once with all race results before individual recordRaceResult calls
    // Combined function to update both ELO and race stats in a single operation
    // This prevents the race condition where sequential updates overwrite each other
    public func applyRaceEloChanges(results : [(Text, Nat)]) : [(Nat, Int)] {
      // results: [(nftId, position)]

      // Convert to format needed for ELO calculation: (tokenIndex, currentElo, racesEntered, position)
      let eloInputs = Array.mapFilter<(Text, Nat), (Nat, Nat, Nat, Nat)>(
        results,
        func((nftId, position) : (Text, Nat)) : ?(Nat, Nat, Nat, Nat) {
          switch (Nat.fromText(nftId)) {
            case (?tokenIndex) {
              switch (Map.get(stats, nhash, tokenIndex)) {
                case (?botStats) {
                  ?(tokenIndex, botStats.eloRating, botStats.racesEntered, position);
                };
                case (null) { null };
              };
            };
            case (null) { null };
          };
        },
      );

      // Calculate ELO changes for all participants
      let eloChanges = ELO.calculateMultiBotEloChanges(eloInputs);

      // Apply ELO changes to each bot
      for ((tokenIndex, eloChange) in eloChanges.vals()) {
        switch (Map.get(stats, nhash, tokenIndex)) {
          case (?botStats) {
            let newElo = ELO.applyEloChange(botStats.eloRating, eloChange);
            let updatedStats = {
              botStats with
              eloRating = newElo;
            };
            updateStats(tokenIndex, updatedStats);
          };
          case (null) {};
        };
      };

      // Return the ELO changes for logging/debugging
      eloChanges;
    };

    // Update race stats (wins/places/shows/earnings) while preserving ELO
    // This version reads CURRENT stats (including ELO update) and only modifies race stats
    public func recordRaceResultWithElo(
      nftId : Text,
      position : Nat,
      fieldSize : Nat,
      earnings : Nat,
    ) {
      switch (Nat.fromText(nftId)) {
        case (?tokenIndex) {
          // Get CURRENT stats (which includes ELO update from applyRaceEloChanges)
          switch (Map.get(stats, nhash, tokenIndex)) {
            case (?botStats) {
              let updatedStats = {
                botStats with
                racesEntered = botStats.racesEntered + 1;
                wins = if (position == 1) { botStats.wins + 1 } else {
                  botStats.wins;
                };
                places = if (position == 2) { botStats.places + 1 } else {
                  botStats.places;
                };
                shows = if (position == 3) { botStats.shows + 1 } else {
                  botStats.shows;
                };
                totalScrapEarned = botStats.totalScrapEarned + earnings;
                experience = botStats.experience + (if (position <= 3) { 10 } else { 5 });
                factionReputation = botStats.factionReputation + (if (position == 1) { 5 } else if (position <= 3) { 2 } else { 1 });
                lastRaced = ?Time.now();
              };
              updateStats(tokenIndex, updatedStats);
            };
            case (null) {};
          };
        };
        case (null) {};
      };
    };

    /// Calculate weighted terrain modifiers based on track composition
    /// Returns (batteryMod, conditionMod) based on segment terrain distribution
    private func calculateTrackTerrainModifiers(trackId : Nat) : (Float, Float) {
      // Get track template from RacingSimulator
      let trackOpt = RacingSimulator.getTrack(trackId);

      switch (trackOpt) {
        case (null) {
          // Fallback to neutral if track not found
          (1.0, 1.0);
        };
        case (?track) {
          // Calculate weighted average based on segment lengths
          var totalLength : Nat = 0;
          var weightedBatteryMod : Float = 0.0;
          var weightedConditionMod : Float = 0.0;

          // Terrain modifiers
          let terrainMods = func(terrain : RacingSimulator.Terrain) : (Float, Float) {
            switch (terrain) {
              case (#ScrapHeaps) { (1.2, 1.5) }; // Rough: +20% battery, +50% condition
              case (#WastelandSand) { (1.1, 1.2) }; // Sandy: +10% battery, +20% condition
              case (#MetalRoads) { (1.0, 1.0) }; // Smooth: normal
            };
          };

          // Calculate weighted average
          for (segment in track.segments.vals()) {
            let (batteryMod, conditionMod) = terrainMods(segment.terrain);
            let segmentLength = segment.length;
            totalLength += segmentLength;
            weightedBatteryMod += Float.fromInt(segmentLength) * batteryMod;
            weightedConditionMod += Float.fromInt(segmentLength) * conditionMod;
          };

          // Apply laps multiplier
          let totalTrackLength = totalLength * track.laps;
          let avgBatteryMod = weightedBatteryMod * Float.fromInt(track.laps) / Float.fromInt(totalTrackLength);
          let avgConditionMod = weightedConditionMod * Float.fromInt(track.laps) / Float.fromInt(totalTrackLength);

          (avgBatteryMod, avgConditionMod);
        };
      };
    };

    /// Apply race costs (battery drain and condition wear)
    /// Costs scale with distance, track terrain composition, and finishing position
    /// Battery drain is inversely proportional to power core level (higher power core = more efficient = less drain)
    public func applyRaceCosts(nftId : Text, distance : Nat, trackId : Nat, position : Nat) {
      let tokenIndex = Nat.fromText(nftId);
      switch (tokenIndex) {
        case (?idx) {
          switch (Map.get(stats, nhash, idx)) {
            case (?botStats) {
              // Get current stats (base + bonuses)
              let currentStats = getCurrentStats(botStats);
              let powerCore = currentStats.powerCore;
              let speed = currentStats.speed;
              let stability = currentStats.stability;
              let acceleration = currentStats.acceleration;

              // Battery drain scales linearly with distance
              // Formula: 2.5 battery per km (e.g., 4km = 10, 10km = 25, 20km = 50)
              // This is ~50% higher than before for consistency
              let baseBatteryDrain = Float.toInt(Float.fromInt(distance) * 2.5);

              // Calculate weighted terrain modifiers from track composition
              let (terrainBatteryMod, terrainConditionMod) = calculateTrackTerrainModifiers(trackId);

              // STAT SCALING: Higher total stats = higher battery consumption
              // Total stats: speed + stability + acceleration (typically 60-240 range)
              // Formula: 1.0 + (totalStats / 300) gives 1.2x to 1.8x multiplier
              // At 60 total stats (low): 1.2x drain
              // At 150 total stats (mid): 1.5x drain
              // At 240 total stats (high): 1.8x drain
              let totalStats = speed + stability + acceleration;
              let statScalingMultiplier = 1.0 + (Float.fromInt(totalStats) / 300.0);

              // Power Core efficiency: Higher power core reduces battery drain (NERFED)
              // Reduced from 70% max reduction to 30% max reduction
              // At powerCore 1 (min): ~100% drain (1.0x multiplier)
              // At powerCore 20 (avg beginner): ~85% drain (0.85x multiplier)
              // At powerCore 40 (solid): ~79% drain (0.79x multiplier)
              // At powerCore 80 (god mode): ~74% drain (0.74x multiplier)
              // At powerCore 100 (max): ~70% drain (0.70x multiplier) - only 1.4x more efficient
              // Formula: multiplier = 1.0 - (0.30 * log(powerCore) / log(100))
              let normalizedPowerCore = Float.max(1.0, Float.fromInt(powerCore));
              let logEffect = Float.min(0.30, 0.30 * (Float.log(normalizedPowerCore) / Float.log(100.0)));
              let efficiencyMultiplier = 1.0 - logEffect;

              // Condition penalty: Poor condition reduces power core efficiency
              // At 100 condition: no penalty (1.0x)
              // At 50 condition: +25% drain (1.25x)
              // At 0 condition: +50% drain (1.5x)
              // Formula: penalty = 1.0 + ((100 - condition) / 200)
              let conditionPenalty = 1.0 + (Float.fromInt(100 - botStats.condition) / 200.0);

              let totalBatteryDrain = Float.toInt(Float.fromInt(baseBatteryDrain) * terrainBatteryMod * statScalingMultiplier * efficiencyMultiplier * conditionPenalty);
              let finalBatteryDrain = Nat.min(botStats.battery, Int.abs(totalBatteryDrain));

              // Condition wear scales linearly with distance
              // Formula: 1.2 condition per km (e.g., 4km = 4.8, 10km = 12, 20km = 24)
              // All racers pay the same - position doesn't affect wear
              let baseConditionWear = Float.toInt(Float.fromInt(distance) * 1.2);

              // Terrain modifier already calculated from track composition above

              // STAT SCALING: Higher speed/stability = higher condition wear
              // Use same multiplier as battery drain for consistency
              let totalConditionWear = Float.toInt(Float.fromInt(baseConditionWear) * terrainConditionMod * statScalingMultiplier);
              let finalConditionWear = Nat.min(botStats.condition, Int.abs(totalConditionWear));

              // CONSUME overcharge and world buff after race
              let updatedStats = {
                botStats with
                battery = Nat.sub(botStats.battery, finalBatteryDrain);
                condition = Nat.sub(botStats.condition, finalConditionWear);
                overcharge = 0; // Overcharge consumed after race
                worldBuff = null; // World buff consumed after race
              };
              updateStats(idx, updatedStats);
            };
            case (null) {};
          };
        };
        case (null) {};
      };
    };

    // ===== GARAGE-SPECIFIC FUNCTIONS =====

    /// Initialize a new PokedBot for racing
    public func initializeBot(
      tokenIndex : Nat,
      owner : Principal,
      factionOverride : ?FactionType,
      customName : ?Text,
    ) : PokedBotRacingStats {
      let metadata = statsProvider.getNFTMetadata(tokenIndex);

      // Get faction from precomputed stats or use override
      let faction = switch (factionOverride) {
        case (?f) { f };
        case (null) {
          switch (statsProvider.getPrecomputedStats(tokenIndex)) {
            case (?precomputed) { precomputed.faction };
            case (null) {
              // Fallback: distribute across all 14 factions
              let mod = tokenIndex % 100;
              if (mod < 1) { #UltimateMaster } else if (mod < 2) { #Wild } else if (mod < 5) {
                #Golden;
              } else if (mod < 10) { #Ultimate } else if (mod < 15) {
                #Blackhole;
              } else if (mod < 20) { #Dead } else if (mod < 30) { #Master } else if (mod < 38) {
                #Bee;
              } else if (mod < 46) { #Food } else if (mod < 54) { #Box } else if (mod < 64) {
                #Murder;
              } else if (mod < 78) { #Game } else if (mod < 92) { #Animal } else {
                #Industrial;
              };
            };
          };
        };
      };

      // Get base stats
      let baseStats = getBaseStats(tokenIndex);

      // Calculate overall rating from base stats: (speed + powerCore + acceleration + stability) / 4
      let totalStats = baseStats.speed + baseStats.powerCore + baseStats.acceleration + baseStats.stability;
      let averageRating = totalStats / 4;

      // Map rating to starting ELO:
      // 50+ rating = SilentKlan tier (1900 ELO)
      // 40-49 rating = Elite tier (1700 ELO)
      // 40+ rating = Elite tier (1700 ELO)
      // 30-39 rating = Raider tier (1500 ELO)
      // 20-29 rating = Junker tier (1300 ELO)
      // <20 rating = Scrap tier (1100 ELO)
      let startingElo = if (averageRating >= 50) {
        1900; // SilentKlan tier
      } else if (averageRating >= 40) {
        1700; // Elite tier
      } else if (averageRating >= 30) {
        1500; // Raider tier
      } else if (averageRating >= 20) {
        1300; // Junker tier
      } else {
        1100; // Scrap tier
      };

      let now = Time.now();

      let racingStats : PokedBotRacingStats = {
        tokenIndex = tokenIndex;
        ownerPrincipal = owner;
        faction = faction;
        name = customName;
        speedBonus = 0;
        powerCoreBonus = 0;
        accelerationBonus = 0;
        stabilityBonus = 0;
        speedUpgrades = 0;
        powerCoreUpgrades = 0;
        accelerationUpgrades = 0;
        stabilityUpgrades = 0;
        respecCount = 0;
        battery = 100;
        condition = 100;
        experience = 0;
        overcharge = 0;
        preferredDistance = derivePreferredDistance(baseStats.powerCore, baseStats.speed);
        preferredTerrain = switch (metadata) {
          case (?traits) { derivePreferredTerrain(traits) };
          case (null) {
            let hash = hashNat(tokenIndex);
            let choice = hash % 3;
            if (choice == 0) { #ScrapHeaps } else if (choice == 1) {
              #MetalRoads;
            } else { #WastelandSand };
          };
        };
        racesEntered = 0;
        wins = 0;
        places = 0;
        shows = 0;
        totalScrapEarned = 0;
        factionReputation = 0;
        eloRating = startingElo; // Start based on bot quality (1200-1800)
        activatedAt = now;
        lastDecayed = now; // Initialize decay tracking
        lastRecharged = null;
        lastRepaired = null;
        lastDiagnostics = null;
        lastRaced = null;
        upgradeEndsAt = null;
        listedForSale = false;

        // Scavenging stats (initialized to defaults)
        scavengingMissions = 0;
        totalPartsScavenged = 0;
        scavengingReputation = 0;
        bestHaul = 0;
        activeMission = null;
        worldBuff = null;
        lastMissionRewards = null;
      };

      ignore Map.put(stats, nhash, tokenIndex, racingStats);
      racingStats;
    };

    /// Get stats for a bot (checks and expires world buffs automatically)
    public func getStats(tokenIndex : Nat) : ?PokedBotRacingStats {
      switch (Map.get(stats, nhash, tokenIndex)) {
        case (null) { null };
        case (?botStats) {
          // Check if world buff has expired
          switch (botStats.worldBuff) {
            case (?buff) {
              let now = Time.now();
              if (now >= buff.expiresAt) {
                // Buff has expired, remove it
                let updatedStats = {
                  botStats with
                  worldBuff = null;
                };
                updateStats(tokenIndex, updatedStats);
                return ?updatedStats;
              };
            };
            case (null) {};
          };
          ?botStats;
        };
      };
    };

    /// Update stats
    public func updateStats(tokenIndex : Nat, newStats : PokedBotRacingStats) {
      ignore Map.put(stats, nhash, tokenIndex, newStats);
    };

    /// Update bot name
    public func updateBotName(tokenIndex : Nat, newName : ?Text) : ?PokedBotRacingStats {
      switch (getStats(tokenIndex)) {
        case (null) { null };
        case (?botStats) {
          let updatedStats = { botStats with name = newName };
          updateStats(tokenIndex, updatedStats);
          ?updatedStats;
        };
      };
    };

    /// Update bot owner (for transfers)
    public func updateBotOwner(tokenIndex : Nat, newOwner : Principal) : ?PokedBotRacingStats {
      switch (getStats(tokenIndex)) {
        case (null) { null };
        case (?botStats) {
          let updatedStats = { botStats with ownerPrincipal = newOwner };
          updateStats(tokenIndex, updatedStats);
          ?updatedStats;
        };
      };
    };

    /// Update upgrade ends at timestamp
    public func setUpgradeEndsAt(tokenIndex : Nat, endsAt : ?Int) {
      switch (getStats(tokenIndex)) {
        case (null) {};
        case (?botStats) {
          let updatedStats = { botStats with upgradeEndsAt = endsAt };
          updateStats(tokenIndex, updatedStats);
        };
      };
    };

    /// Check if initialized
    public func isInitialized(tokenIndex : Nat) : Bool {
      Option.isSome(Map.get(stats, nhash, tokenIndex));
    };

    /// Get all bots for owner
    public func getBotsForOwner(owner : Principal) : [PokedBotRacingStats] {
      let allStats = Map.vals(stats);
      Array.filter<PokedBotRacingStats>(
        Iter.toArray(allStats),
        func(s) { Principal.equal(s.ownerPrincipal, owner) },
      );
    };

    /// Get base stats from precomputed or metadata
    public func getBaseStats(tokenIndex : Nat) : {
      speed : Nat;
      powerCore : Nat;
      acceleration : Nat;
      stability : Nat;
    } {
      switch (statsProvider.getPrecomputedStats(tokenIndex)) {
        case (?precomputed) {
          {
            speed = precomputed.speed;
            powerCore = precomputed.powerCore;
            acceleration = precomputed.acceleration;
            stability = precomputed.stability;
          };
        };
        case (null) {
          // Fallback: simple hash-based stats (precomputed should always exist in production)
          let seed = hashNat(tokenIndex);
          let baseSeed = seed % 100;
          {
            speed = (baseSeed * 70 / 100) + 30;
            powerCore = ((seed / 100) % 100 * 70 / 100) + 30;
            acceleration = ((seed / 10000) % 100 * 70 / 100) + 30;
            stability = ((seed / 1000000) % 100 * 70 / 100) + 30;
          };
        };
      };
    };

    /// Get current stats (base + bonuses)
    public func getCurrentStats(botStats : PokedBotRacingStats) : {
      speed : Nat;
      powerCore : Nat;
      acceleration : Nat;
      stability : Nat;
    } {
      let base = getBaseStats(botStats.tokenIndex);

      // Calculate faction synergy bonuses from owner's collection
      // These are "garage aura" bonuses - ALL bots benefit from the owner's collection
      let synergies = calculateFactionSynergies(botStats.ownerPrincipal);

      // Sum up all stat bonuses from all active synergies
      var synergySpeed : Nat = 0;
      var synergyPowerCore : Nat = 0;
      var synergyAcceleration : Nat = 0;
      var synergyStability : Nat = 0;

      for ((faction, bonusStats) in synergies.statBonuses.vals()) {
        synergySpeed += bonusStats.speed;
        synergyPowerCore += bonusStats.powerCore;
        synergyAcceleration += bonusStats.acceleration;
        synergyStability += bonusStats.stability;
      };

      // Apply battery penalty to speed and acceleration (energy-dependent stats)
      // Battery penalties - softer at high levels, harsh when critical
      // 80-100% battery = no penalty (1.0x)
      // 50% battery = -15% stats (0.85x) - still competitive
      // 25% battery = -40% stats (0.60x) - noticeably slow
      // 10% battery = -70% stats (0.30x) - desperate
      // 0% battery = -90% stats (0.10x) - "resurrection sickness"
      let batteryPenalty = if (botStats.battery >= 80) {
        1.0;
      } else if (botStats.battery >= 50) {
        // Linear scale from 0.85 to 1.0 between 50-80 battery (light penalty)
        0.85 + ((Float.fromInt(botStats.battery) - 50.0) / 30.0) * 0.15;
      } else if (botStats.battery >= 25) {
        // Linear scale from 0.60 to 0.85 between 25-50 battery (moderate penalty)
        0.60 + ((Float.fromInt(botStats.battery) - 25.0) / 25.0) * 0.25;
      } else if (botStats.battery >= 10) {
        // Linear scale from 0.30 to 0.60 between 10-25 battery (heavy penalty)
        0.30 + ((Float.fromInt(botStats.battery) - 10.0) / 15.0) * 0.30;
      } else {
        // Critical: 0-10% battery = 0.10 to 0.30 multiplier (resurrection sickness)
        0.10 + (Float.fromInt(botStats.battery) / 10.0) * 0.20;
      };

      // Apply condition penalty to powerCore and stability (mechanical wear stats)
      // HARSH PENALTIES - Damaged bots perform poorly!
      // 100% condition = no penalty (1.0x)
      // 70% condition = -20% stats (0.80x)
      // 50% condition = -40% stats (0.60x)
      // 25% condition = -70% stats (0.30x)
      // 0% condition = -90% stats (0.10x) - critical damage
      let conditionPenalty = if (botStats.condition >= 90) {
        1.0;
      } else if (botStats.condition >= 70) {
        // Linear scale from 0.80 to 1.0 between 70-90 condition
        0.80 + ((Float.fromInt(botStats.condition) - 70.0) / 20.0) * 0.20;
      } else if (botStats.condition >= 50) {
        // Linear scale from 0.60 to 0.80 between 50-70 condition
        0.60 + ((Float.fromInt(botStats.condition) - 50.0) / 20.0) * 0.20;
      } else if (botStats.condition >= 25) {
        // Linear scale from 0.30 to 0.60 between 25-50 condition
        0.30 + ((Float.fromInt(botStats.condition) - 25.0) / 25.0) * 0.30;
      } else {
        // Critical: 0-25% condition = 0.10 to 0.30 multiplier (falling apart)
        0.10 + (Float.fromInt(botStats.condition) / 25.0) * 0.20;
      };

      // OVERCHARGE BONUSES (consumed in next race)
      // Speed: +0.3% per 1% overcharge (max +22.5% at 75% overcharge)
      // Acceleration: +0.3% per 1% overcharge (max +22.5% at 75% overcharge)
      // Stability: -0.2% per 1% overcharge (max -15% at 75% overcharge)
      // PowerCore: -0.2% per 1% overcharge (max -15% at 75% overcharge)
      let overchargeBonus = Float.fromInt(botStats.overcharge) / 100.0; // 0.0 to 0.75
      let speedOvercharge = 1.0 + (overchargeBonus * 0.3); // 1.0 to 1.225
      let accelOvercharge = 1.0 + (overchargeBonus * 0.3); // 1.0 to 1.225
      let stabilityOvercharge = 1.0 - (overchargeBonus * 0.2); // 1.0 to 0.85
      let powerCoreOvercharge = 1.0 - (overchargeBonus * 0.2); // 1.0 to 0.85

      // WORLD BUFF BONUSES (from scavenging missions, expires in 48h)
      // Apply flat stat bonuses from world buffs
      var speedBuff : Nat = 0;
      var powerCoreBuff : Nat = 0;
      var accelerationBuff : Nat = 0;
      var stabilityBuff : Nat = 0;

      switch (botStats.worldBuff) {
        case (?buff) {
          // Apply each stat buff
          for ((stat, value) in buff.stats.vals()) {
            switch (stat) {
              case ("speed") { speedBuff := value };
              case ("powerCore") { powerCoreBuff := value };
              case ("acceleration") { accelerationBuff := value };
              case ("stability") { stabilityBuff := value };
              case (_) {}; // Ignore unknown stats
            };
          };
        };
        case (null) {}; // No buff active
      };

      // Apply penalties to appropriate stats, then add synergy bonuses and world buffs
      let speedWithPenalty = Float.toInt(Float.fromInt(base.speed + botStats.speedBonus) * batteryPenalty * speedOvercharge) + speedBuff + synergySpeed;
      let accelerationWithPenalty = Float.toInt(Float.fromInt(base.acceleration + botStats.accelerationBonus) * batteryPenalty * accelOvercharge) + accelerationBuff + synergyAcceleration;
      let powerCoreWithPenalty = Float.toInt(Float.fromInt(base.powerCore + botStats.powerCoreBonus) * conditionPenalty * powerCoreOvercharge) + powerCoreBuff + synergyPowerCore;
      let stabilityWithPenalty = Float.toInt(Float.fromInt(base.stability + botStats.stabilityBonus) * conditionPenalty * stabilityOvercharge) + stabilityBuff + synergyStability;

      {
        speed = Nat.min(100, Int.abs(speedWithPenalty));
        powerCore = Nat.min(100, Int.abs(powerCoreWithPenalty));
        acceleration = Nat.min(100, Int.abs(accelerationWithPenalty));
        stability = Nat.min(100, Int.abs(stabilityWithPenalty));
      };
    };

    /// Calculate overall rating
    public func calculateOverallRating(botStats : PokedBotRacingStats) : Nat {
      let current = getCurrentStats(botStats);
      (current.speed + current.powerCore + current.acceleration + current.stability) / 4;
    };

    /// Calculate rating at 100% condition (for race class eligibility)
    /// This ensures bots don't drop out of their class due to temporary condition
    public func calculateRatingAt100(botStats : PokedBotRacingStats) : Nat {
      let base = getBaseStats(botStats.tokenIndex);
      let speed = base.speed + botStats.speedBonus;
      let powerCore = base.powerCore + botStats.powerCoreBonus;
      let acceleration = base.acceleration + botStats.accelerationBonus;
      let stability = base.stability + botStats.stabilityBonus;
      (speed + powerCore + acceleration + stability) / 4;
    };

    /// Get bot status
    public func getBotStatus(botStats : PokedBotRacingStats) : Text {
      if (botStats.condition < 25) { "Critical Malfunction" } else if (botStats.condition < 50) {
        "Needs Repair";
      } else if (botStats.battery < 30) { "Low Battery" } else if (botStats.condition >= 70 and botStats.battery >= 50) {
        "Ready";
      } else { "Maintenance Required" };
    };

    // ===== UPGRADE SYSTEM =====

    /// Start upgrade session
    /// Start upgrade session with V2 parameters
    public func startUpgrade(
      tokenIndex : Nat,
      upgradeType : UpgradeType,
      startedAt : Int,
      endsAt : Int,
      consecutiveFails : Nat,
      costPaid : Nat,
      paymentMethod : Text,
      partsUsed : Nat,
    ) {
      let session : UpgradeSession = {
        tokenIndex = tokenIndex;
        upgradeType = upgradeType;
        startedAt = startedAt;
        endsAt = endsAt;
        consecutiveFails = consecutiveFails;
        costPaid = costPaid;
        paymentMethod = paymentMethod;
        partsUsed = partsUsed;
      };
      Map.set(activeUpgrades, nhash, tokenIndex, session);
    };

    /// Get active upgrade
    public func getActiveUpgrade(tokenIndex : Nat) : ?UpgradeSession {
      Map.get(activeUpgrades, nhash, tokenIndex);
    };

    /// Clear upgrade
    public func clearUpgrade(tokenIndex : Nat) {
      Map.delete(activeUpgrades, nhash, tokenIndex);
    };

    /// Get pity counter for a bot (from last session if it failed)
    /// Stored in stable memory to persist across canister upgrades
    public func getPityCounter(tokenIndex : Nat) : Nat {
      switch (Map.get(pityCounters, nhash, tokenIndex)) {
        case (?count) { count };
        case null { 0 };
      };
    };

    public func setPityCounter(tokenIndex : Nat, count : Nat) {
      if (count > 0) {
        Map.set(pityCounters, nhash, tokenIndex, count);
      } else {
        Map.delete(pityCounters, nhash, tokenIndex);
      };
    };

    /// Expose hash function for RNG in main.mo
    public func hashForRNG(n : Nat) : Nat {
      hashNat(n);
    };

    // ===== BATTERY RECHARGE SYSTEM =====

    /// Apply hourly battery recharge
    public func applyRecharge(tokenIndex : Nat, now : Int) : ?PokedBotRacingStats {
      switch (getStats(tokenIndex)) {
        case (?botStats) {
          if (Option.isSome(botStats.upgradeEndsAt)) {
            return ?botStats;
          };

          let rechargeMultiplier : Float = switch (botStats.faction) {
            // Ultra-rare: faster recharge
            case (#UltimateMaster) { 1.4 };
            case (#Golden) { 1.3 };
            case (#Ultimate) { 1.25 };
            case (#Wild) { 0.7 }; // Wild bots recharge slower
            // Super-rare: moderate recharge boost
            case (#Blackhole or #Dead or #Master) { 1.15 };
            // Rare: slight recharge boost
            case (#Bee or #Food or #Box or #Murder) { 1.05 };
            // Common: standard recharge
            case (_) { 1.0 };
          };

          // Calculate hours elapsed since last decay
          let hoursSinceLastDecay = Int.abs((now - botStats.lastDecayed) / 3_600_000_000_000);

          // Battery recharges naturally over time: +0.3 per hour (instead of decaying)
          // This means ~33 hours to recover 10 battery (one race worth)
          // Condition stays the same (only degrades during actual racing)
          let totalBatteryRecharge = Float.toInt(Float.fromInt(hoursSinceLastDecay) * 0.3 * rechargeMultiplier);

          // Cap battery at 100
          let newBattery = Nat.min(100, botStats.battery + Int.abs(totalBatteryRecharge));

          let updatedStats = {
            botStats with
            battery = newBattery;
            lastDecayed = now;
          };

          updateStats(tokenIndex, updatedStats);
          ?updatedStats;
        };
        case (null) { null };
      };
    };

    /// Apply battery recharge to all bots
    public func applyRechargeToAll(now : Int) : Nat {
      let allBots = Map.entries(stats);
      var decayedCount : Nat = 0;

      for ((tokenIndex, _) in allBots) {
        switch (applyRecharge(tokenIndex, now)) {
          case (?_) { decayedCount += 1 };
          case (null) {};
        };
      };

      decayedCount;
    };

    // ===== HELPER FUNCTIONS =====
    // Note: Stats are loaded from precomputed data via statsProvider.getPrecomputedStats()
    // These fallback functions are only used if precomputed data is missing (should never happen in production)

    private func derivePreferredDistance(powerCore : Nat, speed : Nat) : Distance {
      if (powerCore > 55 and speed < 50) { #LongTrek } else if (speed > 55 and powerCore < 50) {
        #ShortSprint;
      } else { #MediumHaul };
    };

    private func derivePreferredTerrain(metadata : [(Text, Text)]) : Terrain {
      let background = Array.find<(Text, Text)>(
        metadata,
        func(trait) { Text.toLowercase(trait.0) == "background" },
      );

      switch (background) {
        case (?(_, value)) {
          let bg = Text.toLowercase(value);

          // MetalRoads: Purple shades, darker blues, teals (industrial/tech aesthetic)
          if (
            Text.contains(bg, #text "purple") or
            Text.contains(bg, #text "teal") or
            Text.contains(bg, #text "dark blue") or
            Text.contains(bg, #text "grey blue")
          ) {
            #MetalRoads;
          }
          // WastelandSand: Warm colors, light/mid blues, reds (desert/sand aesthetic)
          else if (
            Text.contains(bg, #text "red") or
            Text.contains(bg, #text "yellow") or
            Text.contains(bg, #text "bones") or
            Text.contains(bg, #text "light blue") or
            (Text.contains(bg, #text "blue") and not Text.contains(bg, #text "dark") and not Text.contains(bg, #text "grey"))
          ) {
            #WastelandSand;
          }
          // ScrapHeaps: Greys, browns, blacks, darks, greens (junkyard aesthetic)
          else {
            #ScrapHeaps;
          };
        };
        case (null) {
          let hash = hashNat(0);
          let choice = hash % 3;
          if (choice == 0) { #ScrapHeaps } else if (choice == 1) { #MetalRoads } else {
            #WastelandSand;
          };
        };
      };
    };

    // ===== INVENTORY SYSTEM =====

    /// Get user inventory (or create default if missing)
    public func getUserInventory(user : Principal) : UserInventory {
      switch (Map.get(userInventories, phash, user)) {
        case (?inv) { inv };
        case (null) {
          let newInv : UserInventory = {
            owner = user;
            speedChips = 0;
            powerCoreFragments = 0;
            thrusterKits = 0;
            gyroModules = 0;
            universalParts = 0;
          };
          ignore Map.put(userInventories, phash, user, newInv);
          newInv;
        };
      };
    };

    /// Add parts to user inventory
    public func addParts(user : Principal, partType : PartType, amount : Nat) {
      let inv = getUserInventory(user);
      let updatedInv = switch (partType) {
        case (#SpeedChip) { { inv with speedChips = inv.speedChips + amount } };
        case (#PowerCoreFragment) {
          { inv with powerCoreFragments = inv.powerCoreFragments + amount };
        };
        case (#ThrusterKit) {
          { inv with thrusterKits = inv.thrusterKits + amount };
        };
        case (#GyroModule) {
          { inv with gyroModules = inv.gyroModules + amount };
        };
        case (#UniversalPart) {
          { inv with universalParts = inv.universalParts + amount };
        };
      };
      ignore Map.put(userInventories, phash, user, updatedInv);
    };

    /// Refund parts to user (same as addParts, just clearer naming for refund context)
    public func refundParts(user : Principal, partType : PartType, amount : Nat) {
      addParts(user, partType, amount);
    };

    /// Set user inventory directly (for transfers and other operations)
    public func setUserInventory(user : Principal, inventory : UserInventory) {
      ignore Map.put(userInventories, phash, user, inventory);
    };

    /// Remove parts from user inventory (returns false if insufficient)
    /// Universal Parts can substitute for any specific part type
    public func removeParts(user : Principal, partType : PartType, amount : Nat) : Bool {
      let inv = getUserInventory(user);
      let currentAmount = switch (partType) {
        case (#SpeedChip) { inv.speedChips };
        case (#PowerCoreFragment) { inv.powerCoreFragments };
        case (#ThrusterKit) { inv.thrusterKits };
        case (#GyroModule) { inv.gyroModules };
        case (#UniversalPart) { inv.universalParts };
      };

      // Try to use specific part type first
      if (currentAmount >= amount) {
        let updatedInv = switch (partType) {
          case (#SpeedChip) {
            { inv with speedChips = inv.speedChips - amount };
          };
          case (#PowerCoreFragment) {
            { inv with powerCoreFragments = inv.powerCoreFragments - amount };
          };
          case (#ThrusterKit) {
            { inv with thrusterKits = inv.thrusterKits - amount };
          };
          case (#GyroModule) {
            { inv with gyroModules = Nat.sub(inv.gyroModules, amount) };
          };
          case (#UniversalPart) {
            { inv with universalParts = Nat.sub(inv.universalParts, amount) };
          };
        };
        ignore Map.put(userInventories, phash, user, updatedInv);
        return true;
      };

      // If specific part is insufficient, try combining with Universal Parts
      if (partType != #UniversalPart) {
        let deficit = amount - currentAmount; // How many we're short

        if (inv.universalParts >= deficit) {
          // Use all specific parts + universal parts to make up the difference
          let updatedInv = switch (partType) {
            case (#SpeedChip) {
              {
                inv with
                speedChips = 0; // Use all specific parts
                universalParts = inv.universalParts - deficit; // Fill gap with universal
              };
            };
            case (#PowerCoreFragment) {
              {
                inv with
                powerCoreFragments = 0;
                universalParts = inv.universalParts - deficit;
              };
            };
            case (#ThrusterKit) {
              {
                inv with
                thrusterKits = 0;
                universalParts = inv.universalParts - deficit;
              };
            };
            case (#GyroModule) {
              {
                inv with
                gyroModules = 0;
                universalParts = inv.universalParts - deficit;
              };
            };
            case (#UniversalPart) {
              inv; // Should never reach here
            };
          };
          ignore Map.put(userInventories, phash, user, updatedInv);
          return true;
        };
      } else {
        return false; // Not enough universal parts
      };

      false; // Insufficient parts even with universal substitution
    };

    /// Calculate upgrade cost based on current upgrade count
    /// Original scrap progression: 100 -> 200 -> 300 -> 900 -> 2700 -> 8100 parts (at 100 parts = 1 ICP)
    /// ICP equivalent: 1.0 -> 2.0 -> 3.0 -> 9.0 -> 27.0 -> 81.0 ICP
    // ===== UPGRADE SYSTEM V2 COST CALCULATION =====

    /// Get premium multiplier based on overall rating (continuous scaling)
    /// Uses actual rating value (0-100+) for smooth progression
    /// Formula: 0.5 + (rating / 40)^1.5
    /// Examples: rating 20 = 0.86×, rating 40 = 1.5×, rating 60 = 2.37×, rating 80 = 3.36×, rating 100 = 4.48×
    private func getPremiumMultiplier(rating : Nat) : Float {
      // Continuous scaling: 0.5 + (rating/40)^1.5
      // This creates smooth progression that rewards high ratings without harsh breakpoints
      let ratingFloat = Float.fromInt(rating);
      let scaledRating = ratingFloat / 40.0;
      let premium = 0.5 + (scaledRating ** 1.5);

      // Floor at 0.5× for very low ratings, cap at 5.0× for ultra-high ratings
      Float.max(0.5, Float.min(5.0, premium));
    };

    /// Calculate dynamic upgrade cost in ICP (e8s)
    /// Formula: baseCost = 0.5 + (currentStat / 40.0)^2
    /// finalCost = baseCost × premiumMultiplier
    public func calculateUpgradeCostV2(baseStat : Nat, currentStat : Nat, rating : Nat, synergyMultiplier : Float) : Nat {
      let baseICP = 0.5 + (Float.fromInt(currentStat) / 40.0) ** 2.0;
      let premiumMultiplier = getPremiumMultiplier(rating);
      let finalICP = baseICP * premiumMultiplier * synergyMultiplier;

      // Convert to e8s (1 ICP = 100_000_000 e8s)
      let costE8s = Float.toInt(finalICP * 100_000_000.0);
      Int.abs(costE8s);
    };

    /// Legacy function for backwards compatibility with parts system
    public func calculateUpgradeCost(currentUpgradeCount : Nat) : Nat {
      if (currentUpgradeCount == 0) { 100 } else if (currentUpgradeCount == 1) {
        200;
      } else if (currentUpgradeCount == 2) { 300 } else if (currentUpgradeCount == 3) {
        900;
      } else if (currentUpgradeCount == 4) { 2700 } else { 8100 };
    };

    // ===== PARTS CONVERSION =====

    /// Convert parts from one type to another (25% conversion cost)
    /// Returns #ok on success, #err with error message on failure
    public func convertParts(
      user : Principal,
      fromType : PartType,
      toType : PartType,
      amount : Nat,
    ) : Result.Result<(), Text> {
      // Can't convert to/from the same type
      if (fromType == toType) {
        return #err("Cannot convert parts to the same type");
      };

      // Can't convert Universal Parts (they already work for anything)
      if (fromType == #UniversalPart) {
        return #err("Universal Parts cannot be converted (they work for any upgrade)");
      };

      if (amount == 0) {
        return #err("Amount must be greater than 0");
      };

      let inv = getUserInventory(user);

      // Check if user has enough parts
      let currentAmount = switch (fromType) {
        case (#SpeedChip) { inv.speedChips };
        case (#PowerCoreFragment) { inv.powerCoreFragments };
        case (#ThrusterKit) { inv.thrusterKits };
        case (#GyroModule) { inv.gyroModules };
        case (#UniversalPart) { inv.universalParts };
      };

      if (currentAmount < amount) {
        return #err("Insufficient parts");
      };

      // Calculate conversion with 25% cost (you get 75% of input)
      let convertedAmount = (amount * 3) / 4;
      if (convertedAmount == 0) {
        return #err("Amount too small to convert (need at least 2 parts for 1 output)");
      };

      // Remove source parts
      let invAfterRemoval = switch (fromType) {
        case (#SpeedChip) {
          { inv with speedChips = inv.speedChips - amount };
        };
        case (#PowerCoreFragment) {
          { inv with powerCoreFragments = inv.powerCoreFragments - amount };
        };
        case (#ThrusterKit) {
          { inv with thrusterKits = inv.thrusterKits - amount };
        };
        case (#GyroModule) {
          { inv with gyroModules = inv.gyroModules - amount };
        };
        case (#UniversalPart) {
          { inv with universalParts = inv.universalParts - amount };
        };
      };

      // Add converted parts
      let finalInv = switch (toType) {
        case (#SpeedChip) {
          {
            invAfterRemoval with speedChips = invAfterRemoval.speedChips + convertedAmount
          };
        };
        case (#PowerCoreFragment) {
          {
            invAfterRemoval with powerCoreFragments = invAfterRemoval.powerCoreFragments + convertedAmount;
          };
        };
        case (#ThrusterKit) {
          {
            invAfterRemoval with thrusterKits = invAfterRemoval.thrusterKits + convertedAmount;
          };
        };
        case (#GyroModule) {
          {
            invAfterRemoval with gyroModules = invAfterRemoval.gyroModules + convertedAmount;
          };
        };
        case (#UniversalPart) {
          {
            invAfterRemoval with universalParts = invAfterRemoval.universalParts + convertedAmount;
          };
        };
      };

      ignore Map.put(userInventories, phash, user, finalInv);
      #ok();
    };

    // ===== STABLE STORAGE =====

    public func getStatsMap() : Map.Map<Nat, PokedBotRacingStats> {
      stats;
    };

    public func getActiveUpgradesMap() : Map.Map<Nat, UpgradeSession> {
      activeUpgrades;
    };

    public func getUserInventoriesMap() : Map.Map<Principal, UserInventory> {
      userInventories;
    };

    /// Get upgrade count for a specific stat
    public func getUpgradeCount(tokenIndex : Nat, upgradeType : UpgradeType) : Nat {
      switch (getStats(tokenIndex)) {
        case (?stats) {
          switch (upgradeType) {
            case (#Velocity) { stats.speedUpgrades };
            case (#PowerCore) { stats.powerCoreUpgrades };
            case (#Thruster) { stats.accelerationUpgrades };
            case (#Gyro) { stats.stabilityUpgrades };
          };
        };
        case (null) { 0 };
      };
    };

    // ===== UPGRADE SYSTEM V2 RNG MECHANICS =====

    /// Calculate base success rate based on attempt number
    /// Success rate decreases smoothly: 85% (first upgrade) → 1% (at 15 upgrades), then stays at 1%
    private func calculateBaseSuccessRate(attemptNumber : Nat) : Float {
      if (attemptNumber <= 15) {
        // Linear decrease from 85% to 1% over 15 attempts: 85 - (attemptNumber * 5.6)
        let baseRate = 85.0 - (Float.fromInt(attemptNumber) * 5.6);
        Float.max(1.0, baseRate);
      } else {
        // Stay at 1% after 15 upgrades (soft cap)
        1.0;
      };
    };

    /// Calculate pity bonus based on consecutive failures
    /// +5% per consecutive failure, caps at +25%
    private func calculatePityBonus(consecutiveFails : Nat) : Float {
      if (consecutiveFails == 0) { 0.0 } else {
        Float.min(Float.fromInt(consecutiveFails) * 5.0, 25.0);
      };
    };

    /// Calculate adjusted success rate with pity
    public func calculateSuccessRate(attemptNumber : Nat, consecutiveFails : Nat) : Float {
      let baseRate = calculateBaseSuccessRate(attemptNumber);
      let pityBonus = calculatePityBonus(consecutiveFails);
      Float.min(baseRate + pityBonus, 100.0);
    };

    /// Calculate double point chance based on attempt number
    /// Starts at 15%, decreases by 0.87% per attempt, minimum 2%, disabled after +15
    private func calculateDoubleChance(attemptNumber : Nat) : Float {
      if (attemptNumber > 15) {
        0.0; // No double points beyond +15
      } else {
        let baseChance = 15.0 - (Float.fromInt(attemptNumber) * 0.87);
        Float.max(2.0, baseChance);
      };
    };

    /// Roll for upgrade success using RNG
    /// Returns true if successful based on success rate
    private func rollUpgradeSuccess(successRate : Float, seed : Nat32) : Bool {
      let roll = Nat32.toNat(seed % 100);
      Float.fromInt(roll) < successRate;
    };

    /// Roll for double points using RNG
    /// Returns true if double points should be awarded
    private func rollDoublePoints(doubleChance : Float, seed : Nat32) : Bool {
      let roll = Nat32.toNat((seed / 100) % 100); // Use different part of seed
      Float.fromInt(roll) < doubleChance;
    };

    // ===== RESPEC SYSTEM =====

    /// Calculate respec cost in e8s
    /// Cost = 1 ICP (flat rate)
    public func calculateRespecCost(respecCount : Nat) : Nat {
      100_000_000; // 1 ICP flat rate
    };

    /// Calculate parts refund for a single stat with 40% penalty (60% returned)
    /// Returns the total parts to refund based on all upgrades made to that stat
    private func calculateStatPartsRefund(
      baseStatValue : Nat,
      currentBonus : Nat,
      overallRating : Nat,
      costMultiplier : Float,
    ) : Nat {
      var totalRefund : Nat = 0;
      var upgradedValue = baseStatValue;

      // Calculate the cost of each upgrade point
      for (i in Iter.range(1, currentBonus)) {
        let upgradeCost = calculateUpgradeCostV2(baseStatValue, upgradedValue, overallRating, costMultiplier);
        // Convert ICP cost to parts (100 parts = 1 ICP = 100_000_000 e8s)
        let costInParts = (upgradeCost * 100) / 100_000_000;
        // Apply 40% penalty (return 60%)
        let refundAmount = (costInParts * 60) / 100;
        totalRefund += refundAmount;
        upgradedValue += 1;
      };

      totalRefund;
    };

    /// Respec a bot - reset all upgrades and refund parts (minus penalty)
    /// Returns the parts refunded by type
    public func respecBot(tokenIndex : Nat, owner : Principal) : Result.Result<{ speedPartsRefunded : Nat; powerCorePartsRefunded : Nat; accelerationPartsRefunded : Nat; stabilityPartsRefunded : Nat; totalRefunded : Nat }, Text> {
      switch (Map.get(stats, nhash, tokenIndex)) {
        case (null) { #err("Bot not initialized") };
        case (?botStats) {
          if (botStats.ownerPrincipal != owner) {
            return #err("Not the owner");
          };

          // Can't respec while upgrading
          if (Option.isSome(Map.get(activeUpgrades, nhash, tokenIndex))) {
            return #err("Cannot respec while upgrade is in progress");
          };

          // Can't respec if no upgrades
          if (
            botStats.speedBonus == 0 and botStats.powerCoreBonus == 0 and
            botStats.accelerationBonus == 0 and botStats.stabilityBonus == 0
          ) {
            return #err("No upgrades to respec");
          };

          let baseStats = getBaseStats(tokenIndex);
          let synergies = calculateFactionSynergies(owner);
          let overallRating = (
            baseStats.speed + baseStats.powerCore + baseStats.acceleration + baseStats.stability
          ) / 4;

          // Calculate refunds for each stat
          let speedRefund = calculateStatPartsRefund(
            baseStats.speed,
            botStats.speedBonus,
            overallRating,
            synergies.costMultipliers.upgradeCost,
          );
          let powerCoreRefund = calculateStatPartsRefund(
            baseStats.powerCore,
            botStats.powerCoreBonus,
            overallRating,
            synergies.costMultipliers.upgradeCost,
          );
          let accelerationRefund = calculateStatPartsRefund(
            baseStats.acceleration,
            botStats.accelerationBonus,
            overallRating,
            synergies.costMultipliers.upgradeCost,
          );
          let stabilityRefund = calculateStatPartsRefund(
            baseStats.stability,
            botStats.stabilityBonus,
            overallRating,
            synergies.costMultipliers.upgradeCost,
          );

          // Refund parts to user inventory
          if (speedRefund > 0) {
            addParts(owner, #SpeedChip, speedRefund);
          };
          if (powerCoreRefund > 0) {
            addParts(owner, #PowerCoreFragment, powerCoreRefund);
          };
          if (accelerationRefund > 0) {
            addParts(owner, #ThrusterKit, accelerationRefund);
          };
          if (stabilityRefund > 0) {
            addParts(owner, #GyroModule, stabilityRefund);
          };

          // Reset bot stats (keep pity counter)
          let updatedStats : PokedBotRacingStats = {
            botStats with
            speedBonus = 0;
            powerCoreBonus = 0;
            accelerationBonus = 0;
            stabilityBonus = 0;
            speedUpgrades = 0;
            powerCoreUpgrades = 0;
            accelerationUpgrades = 0;
            stabilityUpgrades = 0;
            respecCount = botStats.respecCount + 1;
          };

          ignore Map.put(stats, nhash, tokenIndex, updatedStats);

          let totalRefunded = speedRefund + powerCoreRefund + accelerationRefund + stabilityRefund;

          #ok({
            speedPartsRefunded = speedRefund;
            powerCorePartsRefunded = powerCoreRefund;
            accelerationPartsRefunded = accelerationRefund;
            stabilityPartsRefunded = stabilityRefund;
            totalRefunded = totalRefunded;
          });
        };
      };
    };

    // ===== CONTINUOUS SCAVENGING SYSTEM =====

    // ===== FACTION SYNERGY SYSTEM =====

    /// Calculate faction synergies for a given owner
    /// Returns bonuses that apply to all bots of matching factions
    public func calculateFactionSynergies(owner : Principal) : {
      statBonuses : [(FactionType, { speed : Nat; powerCore : Nat; acceleration : Nat; stability : Nat })];
      costMultipliers : {
        upgradeCost : Float;
        repairCost : Float;
        rechargeCooldown : Float;
      };
      yieldMultipliers : { scavengingParts : Float; racePrizes : Float };
      drainMultipliers : { scavengingDrain : Float };
    } {
      // Count bots by faction for this owner
      var factionCounts = Map.new<FactionType, Nat>();

      for ((tokenIndex, botStats) in Map.entries(stats)) {
        if (Principal.equal(botStats.ownerPrincipal, owner)) {
          let currentCount = switch (Map.get(factionCounts, factionHashUtils, botStats.faction)) {
            case (?count) { count };
            case (null) { 0 };
          };
          ignore Map.put(factionCounts, factionHashUtils, botStats.faction, currentCount + 1);
        };
      };

      // Calculate stat bonuses per faction
      var statBonuses = Buffer.Buffer<(FactionType, { speed : Nat; powerCore : Nat; acceleration : Nat; stability : Nat })>(0);

      for ((faction, count) in Map.entries(factionCounts)) {
        let bonus = getFactionStatBonus(faction, count);
        if (bonus.speed > 0 or bonus.powerCore > 0 or bonus.acceleration > 0 or bonus.stability > 0) {
          statBonuses.add((faction, bonus));
        };
      };

      // Calculate cost multipliers (applies to ALL bots)
      var upgradeCostMult = 1.0;
      var repairCostMult = 1.0;
      var rechargeCooldownMult = 1.0;
      var scavengingPartsMult = 1.0;
      var racePrizesMult = 1.0;
      var scavengingDrainMult = 1.0;

      for ((faction, count) in Map.entries(factionCounts)) {
        let multipliers = getFactionCostMultipliers(faction, count);
        upgradeCostMult *= multipliers.upgradeCost;
        repairCostMult *= multipliers.repairCost;
        rechargeCooldownMult *= multipliers.rechargeCooldown;
        scavengingPartsMult *= multipliers.scavengingParts;
        racePrizesMult *= multipliers.racePrizes;
        scavengingDrainMult *= multipliers.scavengingDrain;
      };

      {
        statBonuses = Buffer.toArray(statBonuses);
        costMultipliers = {
          upgradeCost = upgradeCostMult;
          repairCost = repairCostMult;
          rechargeCooldown = rechargeCooldownMult;
        };
        yieldMultipliers = {
          scavengingParts = scavengingPartsMult;
          racePrizes = racePrizesMult;
        };
        drainMultipliers = {
          scavengingDrain = scavengingDrainMult;
        };
      };
    };

    /// Get stat bonuses for a faction based on count
    private func getFactionStatBonus(faction : FactionType, count : Nat) : {
      speed : Nat;
      powerCore : Nat;
      acceleration : Nat;
      stability : Nat;
    } {
      switch (faction) {
        // Common factions (no stat bonuses, only cost bonuses)
        case (#Game or #Industrial) {
          { speed = 0; powerCore = 0; acceleration = 0; stability = 0 };
        };
        case (#Animal) {
          if (count >= 16) {
            { speed = 3; powerCore = 3; acceleration = 3; stability = 3 };
          } else if (count >= 8) {
            { speed = 2; powerCore = 2; acceleration = 2; stability = 2 };
          } else if (count >= 4) {
            { speed = 1; powerCore = 1; acceleration = 1; stability = 1 };
          } else {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 0 };
          };
        };

        // Rare factions - stat bonuses at 2/4/6
        case (#Bee) {
          if (count >= 6) {
            { speed = 8; powerCore = 0; acceleration = 0; stability = 0 };
          } else if (count >= 4) {
            { speed = 6; powerCore = 0; acceleration = 0; stability = 0 };
          } else if (count >= 2) {
            { speed = 3; powerCore = 0; acceleration = 0; stability = 0 };
          } else {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 0 };
          };
        };
        case (#Food) {
          { speed = 0; powerCore = 0; acceleration = 0; stability = 0 }; // Cooldown bonus only
        };
        case (#Box) {
          if (count >= 6) {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 8 };
          } else if (count >= 4) {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 6 };
          } else if (count >= 2) {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 3 };
          } else {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 0 };
          };
        };
        case (#Murder) {
          if (count >= 6) {
            { speed = 0; powerCore = 0; acceleration = 8; stability = 0 };
          } else if (count >= 4) {
            { speed = 0; powerCore = 0; acceleration = 6; stability = 0 };
          } else if (count >= 2) {
            { speed = 0; powerCore = 0; acceleration = 3; stability = 0 };
          } else {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 0 };
          };
        };

        // Super-Rare factions - stat bonuses at 2/4/6
        case (#Blackhole) {
          if (count >= 6) {
            { speed = 0; powerCore = 10; acceleration = 0; stability = 0 };
          } else if (count >= 4) {
            { speed = 0; powerCore = 8; acceleration = 0; stability = 0 };
          } else if (count >= 2) {
            { speed = 0; powerCore = 5; acceleration = 0; stability = 0 };
          } else {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 0 };
          };
        };
        case (#Dead) {
          { speed = 0; powerCore = 0; acceleration = 0; stability = 0 }; // Parts bonus only
        };
        case (#Master) {
          if (count >= 6) {
            { speed = 4; powerCore = 4; acceleration = 4; stability = 4 };
          } else if (count >= 4) {
            { speed = 3; powerCore = 3; acceleration = 3; stability = 3 };
          } else if (count >= 2) {
            { speed = 2; powerCore = 2; acceleration = 2; stability = 2 };
          } else {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 0 };
          };
        };

        // Ultra-Rare factions - powerful bonuses at 2/3 or just 1
        case (#Ultimate) {
          if (count >= 3) {
            { speed = 5; powerCore = 0; acceleration = 5; stability = 0 };
          } else if (count >= 2) {
            { speed = 3; powerCore = 0; acceleration = 3; stability = 0 };
          } else {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 0 };
          };
        };
        case (#Golden) {
          { speed = 0; powerCore = 0; acceleration = 0; stability = 0 }; // Prize bonus only
        };
        case (#Wild) {
          if (count >= 2) {
            { speed = 4; powerCore = 4; acceleration = 4; stability = 4 };
          } else {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 0 };
          };
        };
        case (#UltimateMaster) {
          if (count >= 1) {
            { speed = 5; powerCore = 5; acceleration = 5; stability = 5 };
          } else {
            { speed = 0; powerCore = 0; acceleration = 0; stability = 0 };
          };
        };
      };
    };

    /// Get cost/yield multipliers for a faction based on count
    private func getFactionCostMultipliers(faction : FactionType, count : Nat) : {
      upgradeCost : Float;
      repairCost : Float;
      rechargeCooldown : Float;
      scavengingParts : Float;
      racePrizes : Float;
      scavengingDrain : Float;
    } {
      switch (faction) {
        case (#Game) {
          if (count >= 6) {
            {
              upgradeCost = 0.80;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else if (count >= 4) {
            {
              upgradeCost = 0.88;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else if (count >= 2) {
            {
              upgradeCost = 0.95;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          };
        };
        case (#Animal) {
          {
            upgradeCost = 1.0;
            repairCost = 1.0;
            rechargeCooldown = 1.0;
            scavengingParts = 1.0;
            racePrizes = 1.0;
            scavengingDrain = 1.0;
          };
        };
        case (#Industrial) {
          if (count >= 6) {
            {
              upgradeCost = 1.0;
              repairCost = 0.40; // 60% discount - reliable workhorse maintenance
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else if (count >= 4) {
            {
              upgradeCost = 1.0;
              repairCost = 0.60; // 40% discount
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else if (count >= 2) {
            {
              upgradeCost = 1.0;
              repairCost = 0.80; // 20% discount
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          };
        };
        case (#Food) {
          if (count >= 6) {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 0.55;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else if (count >= 4) {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 0.70;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else if (count >= 2) {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 0.85;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          };
        };
        case (#Dead) {
          if (count >= 6) {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.45;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else if (count >= 4) {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.30;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else if (count >= 2) {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.15;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          } else {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          };
        };
        case (#Ultimate) {
          if (count >= 3) {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 0.70;
            };
          } else if (count >= 2) {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 0.85;
            };
          } else {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          };
        };
        case (#Golden) {
          if (count >= 3) {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.15;
              scavengingDrain = 1.0;
            };
          } else if (count >= 2) {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.06;
              scavengingDrain = 1.0;
            };
          } else {
            {
              upgradeCost = 1.0;
              repairCost = 1.0;
              rechargeCooldown = 1.0;
              scavengingParts = 1.0;
              racePrizes = 1.0;
              scavengingDrain = 1.0;
            };
          };
        };
        case (_) {
          {
            upgradeCost = 1.0;
            repairCost = 1.0;
            rechargeCooldown = 1.0;
            scavengingParts = 1.0;
            racePrizes = 1.0;
            scavengingDrain = 1.0;
          };
        };
      };
    };

    /// Hash function for FactionType
    private func factionHash(faction : FactionType) : Nat32 {
      switch (faction) {
        case (#UltimateMaster) { 0 };
        case (#Wild) { 1 };
        case (#Golden) { 2 };
        case (#Ultimate) { 3 };
        case (#Blackhole) { 4 };
        case (#Dead) { 5 };
        case (#Master) { 6 };
        case (#Bee) { 7 };
        case (#Food) { 8 };
        case (#Box) { 9 };
        case (#Murder) { 10 };
        case (#Game) { 11 };
        case (#Animal) { 12 };
        case (#Industrial) { 13 };
      };
    };

    private func factionEqual(a : FactionType, b : FactionType) : Bool {
      factionHash(a) == factionHash(b);
    };

    private let factionHashUtils : Map.HashUtils<FactionType> = (factionHash, factionEqual);

    // ===== SCAVENGING SYSTEM =====

    /// Get accumulation rates per 15-minute interval
    /// These are constant (no diminishing returns - battery is the natural limiter)
    private func get15MinuteRates() : {
      basePartsPer15Min : Float;
      baseBatteryDrain : Float;
      baseConditionLoss : Float;
    } {
      // Base rates: 2.5-5-2 (parts, battery, condition) per 15 minutes
      // Probabilistic rounding preserves exact fractional values over time
      // Zone multipliers and faction bonuses are fully preserved
      {
        basePartsPer15Min = 2.5; // 10 parts/hour (reduced by 50%)
        baseBatteryDrain = 5.0; // 20 battery/hour base
        baseConditionLoss = 2.0; // 8 condition/hour base
      };
    };

    /// Get duration bonus multiplier based on hours elapsed
    /// Rewards longer commitments with improved efficiency
    private func getDurationBonus(hoursElapsed : Int) : Float {
      // Efficiency curve that rewards longer missions:
      // 0-4 hours: 1.0x (base rate)
      // 4-8 hours: 1.1x (+10% parts, -10% costs)
      // 8-12 hours: 1.2x (+20% parts, -20% costs)
      // 12+ hours: 1.3x (+30% parts, -30% costs)
      if (hoursElapsed < 4) {
        1.0; // No bonus for short missions
      } else if (hoursElapsed < 8) {
        1.1; // +10% efficiency
      } else if (hoursElapsed < 12) {
        1.2; // +20% efficiency
      } else {
        1.3; // +30% efficiency for overnight+ missions
      };
    };

    /// Get part distribution percentages by zone
    private func getPartDistributionForZone(zone : ScavengingZone) : [(PartType, Float)] {
      switch (zone) {
        case (#ScrapHeaps) {
          // 40% universal, balanced specialized
          [
            (#UniversalPart, 0.4),
            (#SpeedChip, 0.15),
            (#PowerCoreFragment, 0.15),
            (#ThrusterKit, 0.15),
            (#GyroModule, 0.15),
          ];
        };
        case (#AbandonedSettlements) {
          // 40% universal, balanced specialized (same split, more total parts)
          [
            (#UniversalPart, 0.4),
            (#SpeedChip, 0.15),
            (#PowerCoreFragment, 0.15),
            (#ThrusterKit, 0.15),
            (#GyroModule, 0.15),
          ];
        };
        case (#DeadMachineFields) {
          // 40% universal, balanced specialized (same split, most total parts)
          [
            (#UniversalPart, 0.4),
            (#SpeedChip, 0.15),
            (#PowerCoreFragment, 0.15),
            (#ThrusterKit, 0.15),
            (#GyroModule, 0.15),
          ];
        };
        case (#RepairBay) {
          // No parts awarded in RepairBay (condition restoration only)
          [];
        };
        case (#ChargingStation) {
          // No parts awarded in ChargingStation (battery restoration only)
          [];
        };
      };
    };

    /// Apply faction-based bonuses to part distribution
    /// Each faction specializes in certain part types, shifting probabilities
    private func applyFactionBonus(
      baseDistribution : [(PartType, Float)],
      faction : FactionType,
    ) : [(PartType, Float)] {
      // Define faction specialties (bonus multiplier for specific part type)
      let (bonusType, bonusMultiplier) : (?PartType, Float) = switch (faction) {
        // Speed specialists (+30% Speed Chips)
        case (#Bee or #Wild) { (?#SpeedChip, 1.3) };

        // Power specialists (+30% Power Core Fragments)
        case (#Blackhole or #Golden) { (?#PowerCoreFragment, 1.3) };

        // Acceleration specialists (+30% Thruster Kits)
        case (#Game or #Animal) { (?#ThrusterKit, 1.3) };

        // Stability specialists (+30% Gyro Modules)
        case (#Industrial or #Box) { (?#GyroModule, 1.3) };

        // Balanced factions (+15% Universal Parts)
        case (#Dead or #Master or #Murder or #Food or #UltimateMaster or #Ultimate) {
          (?#UniversalPart, 1.15);
        };

        // Default: no bonus
        case (_) { (null, 1.0) };
      };

      // Apply bonus and renormalize
      switch (bonusType) {
        case (null) { baseDistribution }; // No bonus, return as-is
        case (?targetType) {
          // Apply multiplier to target type
          let boosted = Array.map<(PartType, Float), (PartType, Float)>(
            baseDistribution,
            func((partType, weight)) : (PartType, Float) {
              if (partType == targetType) {
                (partType, weight * bonusMultiplier);
              } else {
                (partType, weight);
              };
            },
          );

          // Renormalize so total = 1.0
          var total = 0.0;
          for ((_, weight) in boosted.vals()) {
            total += weight;
          };

          Array.map<(PartType, Float), (PartType, Float)>(
            boosted,
            func((partType, weight)) : (PartType, Float) {
              (partType, weight / total);
            },
          );
        };
      };
    };

    /// Distribute new parts across types and add to pending
    /// Uses weighted random selection for each part to create variety
    /// Now includes faction bonuses for specialized part drops
    private func distributeParts(
      currentPending : {
        speedChips : Nat;
        powerCoreFragments : Nat;
        thrusterKits : Nat;
        gyroModules : Nat;
        universalParts : Nat;
      },
      newParts : Nat,
      distribution : [(PartType, Float)],
    ) : {
      speedChips : Nat;
      powerCoreFragments : Nat;
      thrusterKits : Nat;
      gyroModules : Nat;
      universalParts : Nat;
    } {
      var speedChips = currentPending.speedChips;
      var powerCoreFragments = currentPending.powerCoreFragments;
      var thrusterKits = currentPending.thrusterKits;
      var gyroModules = currentPending.gyroModules;
      var universalParts = currentPending.universalParts;

      // Roll for each part individually using weighted random
      let now = Time.now();
      var i = 0;
      while (i < newParts) {
        let seed = Int.abs(now + i * 7919); // Prime number for better distribution
        let roll = Float.fromInt(seed % 10000) / 100.0; // 0-100.00

        // Find which part type this roll corresponds to
        var cumulative = 0.0;
        label checkType for ((partType, weight) in distribution.vals()) {
          cumulative += weight * 100.0;
          if (roll < cumulative) {
            switch (partType) {
              case (#SpeedChip) { speedChips += 1 };
              case (#PowerCoreFragment) { powerCoreFragments += 1 };
              case (#ThrusterKit) { thrusterKits += 1 };
              case (#GyroModule) { gyroModules += 1 };
              case (#UniversalPart) { universalParts += 1 };
            };
            break checkType;
          };
        };
        i += 1;
      };

      {
        speedChips;
        powerCoreFragments;
        thrusterKits;
        gyroModules;
        universalParts;
      };
    };

    /// Calculate total pending parts
    private func getTotalPendingParts(pending : { speedChips : Nat; powerCoreFragments : Nat; thrusterKits : Nat; gyroModules : Nat; universalParts : Nat }) : Nat {
      pending.speedChips + pending.powerCoreFragments + pending.thrusterKits + pending.gyroModules + pending.universalParts;
    };

    /// Get zone multipliers
    private func getZoneMultipliers(zone : ScavengingZone) : {
      battery : Float;
      condition : Float;
      parts : Float;
    } {
      switch (zone) {
        // Safe: Best efficiency - for long overnight missions and weaker bots
        case (#ScrapHeaps) { { battery = 1.0; condition = 1.0; parts = 1.0 } };
        // Moderate: 60% more parts but 2x costs - noticeably worse efficiency, only worth for mid-length sessions
        case (#AbandonedSettlements) {
          { battery = 2.0; condition = 2.0; parts = 1.6 };
        };
        // Dangerous: 2.5x parts but 3.5x costs - terrible efficiency (70% as efficient as safe), only for elite Industrial/UltimateMaster bots
        case (#DeadMachineFields) {
          { battery = 3.5; condition = 3.5; parts = 2.5 };
        };
        // Repair Bay: Double battery drain compared to safe zone, but restores condition instead of gathering parts
        // Negative condition value = restoration instead of loss
        case (#RepairBay) {
          { battery = 2.0; condition = -3.0; parts = 0.0 };
        };
        // Charging Station: No battery drain, restores battery instead
        // Negative battery value = restoration instead of loss
        case (#ChargingStation) {
          { battery = -1.0; condition = 1.0; parts = 0.0 };
        };
      };
    };

    /// Get faction bonuses for scavenging (from SCAVENGING_FACTION_BONUSES.md)
    private func getFactionScavengingBonus(faction : FactionType, zone : ScavengingZone) : {
      partsMultiplier : Float;
      batteryMultiplier : Float;
      conditionMultiplier : Float;
    } {
      switch (faction) {
        // Ultra-rare factions
        case (#UltimateMaster) {
          {
            partsMultiplier = 1.20;
            batteryMultiplier = 0.70;
            conditionMultiplier = 1.0;
          };
        };
        case (#Golden) {
          {
            partsMultiplier = 1.0;
            batteryMultiplier = 1.0;
            conditionMultiplier = 1.0;
          };
        }; // Has RNG double instead
        case (#Ultimate) {
          {
            partsMultiplier = 1.15;
            batteryMultiplier = 1.0;
            conditionMultiplier = 1.0;
          };
        }; // Has time reduction special
        case (#Wild) {
          // 1.25x in WastelandSand, but no WastelandSand scavenging zones yet, so 1.0x everywhere
          {
            partsMultiplier = 1.0;
            batteryMultiplier = 1.0;
            conditionMultiplier = 0.60;
          };
        };

        // Super-rare factions
        case (#Blackhole) {
          {
            partsMultiplier = 1.10;
            batteryMultiplier = 1.0;
            conditionMultiplier = 1.1;
          };
        }; // Penalty: +10% condition damage
        case (#Dead) {
          let partsMult = if (zone == #DeadMachineFields) { 1.40 } else { 1.10 };
          {
            partsMultiplier = partsMult;
            batteryMultiplier = 1.0;
            conditionMultiplier = 0.50;
          }; // -50% condition damage
        };
        case (#Master) {
          {
            partsMultiplier = 1.12;
            batteryMultiplier = 0.75;
            conditionMultiplier = 1.0;
          };
        };

        // Rare factions
        case (#Bee) {
          let partsMult = if (zone == #AbandonedSettlements) { 1.08 } else {
            1.0;
          };
          {
            partsMultiplier = partsMult;
            batteryMultiplier = 1.0;
            conditionMultiplier = 1.0;
          };
        };
        case (#Food) {
          let partsMult = if (zone == #ScrapHeaps or zone == #AbandonedSettlements) {
            1.12;
          } else { 1.0 };
          {
            partsMultiplier = partsMult;
            batteryMultiplier = 0.80;
            conditionMultiplier = 1.0;
          };
        };
        case (#Box) {
          {
            partsMultiplier = 1.05;
            batteryMultiplier = 1.0;
            conditionMultiplier = 1.0;
          };
        }; // Has RNG triple
        case (#Murder) {
          let partsMult = if (zone == #DeadMachineFields) { 1.15 } else { 1.0 };
          {
            partsMultiplier = partsMult;
            batteryMultiplier = 1.0;
            conditionMultiplier = 1.2;
          }; // +20% condition damage
        };

        // Common factions
        case (#Game) {
          {
            partsMultiplier = 1.0;
            batteryMultiplier = 1.0;
            conditionMultiplier = 1.0;
          };
        }; // Has milestone bonus
        case (#Animal) {
          // WastelandSand bonus not applicable yet, will add when zones expand
          {
            partsMultiplier = 1.0;
            batteryMultiplier = 1.0;
            conditionMultiplier = 1.0;
          };
        };
        case (#Industrial) {
          {
            partsMultiplier = 1.05;
            batteryMultiplier = 0.90;
            conditionMultiplier = 1.0;
          };
        };
      };
    };

    // ===== NEW CONTINUOUS SCAVENGING FUNCTIONS =====

    /// Accumulate rewards for a bot on scavenging mission (called every 15 minutes by timer)
    public func accumulateScavengingRewards(tokenIndex : Nat, now : Int) : Result.Result<Text, Text> {
      switch (getStats(tokenIndex)) {
        case (null) { #err("Bot not found") };
        case (?botStats) {
          switch (botStats.activeMission) {
            case (null) { #err("No active mission") };
            case (?mission) {
              // Check if bot is dead (0 battery OR 0 condition) - LOSE ALL PENDING REWARDS
              if (botStats.battery == 0 or botStats.condition == 0) {
                let updatedStats = {
                  botStats with
                  activeMission = null;
                };
                updateStats(tokenIndex, updatedStats);
                return #err("Bot died (0 battery or condition) - mission failed, all pending rewards lost");
              };

              // Calculate 15-minute intervals since last accumulation
              let nanosSince = now - mission.lastAccumulation;
              let intervalsSince = nanosSince / (15 * 60 * 1_000_000_000); // 15 minutes in nanos

              if (intervalsSince < 1) {
                return #ok("Not yet 15 minutes elapsed since last accumulation");
              };

              // Get rates and multipliers
              let rates = get15MinuteRates();
              let zoneMultipliers = getZoneMultipliers(mission.zone);
              let factionBonus = getFactionScavengingBonus(botStats.faction, mission.zone);

              // Get synergy bonuses for this owner
              let synergies = calculateFactionSynergies(botStats.ownerPrincipal);

              // Get current stats for stat-based bonuses
              let currentStats = getCurrentStats(botStats);

              // Power Core reduces battery cost (energy efficiency) - AGGRESSIVE scaling for viability
              // At 0: 1.0x (full cost), at 50: 0.65x (-35%), at 75: 0.44x (-56%), at 100: 0.25x (-75%)
              // Formula: 1.0 - (powerCore/100)^1.5 * 0.75
              // This allows high-PC bots to survive 2-3 hours in DMF like normal bots in ScrapHeaps
              let pcScaled = Float.fromInt(currentStats.powerCore) / 100.0;
              let powerCoreBonus = 1.0 - (pcScaled ** 1.5 * 0.75);

              // Stability reduces condition loss in dangerous zones - AGGRESSIVE scaling
              // At 0: 1.0x, at 50: 0.65x (-35%), at 75: 0.44x (-56%), at 100: 0.25x (-75%)
              // Same formula as Power Core for consistency
              let stabilityBonus = if (mission.zone == #DeadMachineFields) {
                let stabScaled = Float.fromInt(currentStats.stability) / 100.0;
                1.0 - (stabScaled ** 1.5 * 0.75);
              } else {
                1.0; // Normal condition loss in safe/moderate zones
              };

              // Speed increases parts yield (faster scavenging) - scales smoothly
              // At 0: 1.0x, at 50: 1.05x (+5%), at 100: 1.10x (+10%)
              let speedBonus = 1.0 + (Float.fromInt(currentStats.speed) / 100.0 * 0.10);

              // Acceleration increases world buff chance - scales smoothly
              // At 0: 2.0%, at 50: 2.6% (+30%), at 100: 3.2% (+60%)
              let accelBuffBonus = 1.0 + (Float.fromInt(currentStats.acceleration) / 100.0 * 0.60);

              // Duration bonus: rewards longer commitments with efficiency curve
              let hoursElapsed = (now - mission.startTime) / (3600 * 1_000_000_000);
              let durationBonus = getDurationBonus(hoursElapsed);

              // Calculate accumulation for this 15-min interval
              // Duration bonus: increases parts yield, reduces battery/condition costs
              // Synergy bonuses: apply collection-wide bonuses to parts and drain
              let partsThis15Min = rates.basePartsPer15Min * zoneMultipliers.parts * factionBonus.partsMultiplier * speedBonus * durationBonus * synergies.yieldMultipliers.scavengingParts;
              let batteryDrain = rates.baseBatteryDrain * zoneMultipliers.battery * factionBonus.batteryMultiplier * powerCoreBonus / durationBonus * synergies.drainMultipliers.scavengingDrain;
              let conditionLoss = rates.baseConditionLoss * zoneMultipliers.condition * factionBonus.conditionMultiplier * stabilityBonus / durationBonus * synergies.drainMultipliers.scavengingDrain;

              // Add variance to battery and condition costs (±20% random variation)
              // This creates more unpredictable resource management - sometimes lucky, sometimes not
              let batteryVariance = Float.fromInt((hashNat(tokenIndex + Int.abs(now)) % 41) - 20) / 100.0; // -20% to +20%
              let conditionVariance = Float.fromInt((hashNat(tokenIndex + Int.abs(now) + 1) % 41) - 20) / 100.0; // -20% to +20%

              let batteryDrainWithVariance = batteryDrain * (1.0 + batteryVariance);
              let conditionLossWithVariance = conditionLoss * (1.0 + conditionVariance);

              Debug.print("SCAVENGE ACCUMULATION bot " # debug_show (tokenIndex) # " zone=" # debug_show (mission.zone) # " baseBattery=" # debug_show (rates.baseBatteryDrain) # " zoneMult=" # debug_show (zoneMultipliers.battery) # " factionMult=" # debug_show (factionBonus.batteryMultiplier) # " powerCoreBonus=" # debug_show (powerCoreBonus) # " durationBonus=" # debug_show (durationBonus) # " variance=" # debug_show (batteryVariance) # " finalDrain=" # debug_show (batteryDrainWithVariance));

              // Probabilistic rounding: use fractional part as probability
              // E.g., 1.9 = 90% chance of 2, 10% chance of 1
              // This preserves the exact expected value over many ticks
              let batteryFloor = Int.abs(Float.toInt(batteryDrainWithVariance));
              let batteryFraction = batteryDrainWithVariance - Float.fromInt(batteryFloor);
              let batteryRng = Float.fromInt(hashNat(tokenIndex + Int.abs(now) + 2) % 100) / 100.0;
              let batteryDrainRounded = if (batteryRng < batteryFraction) {
                batteryFloor + 1;
              } else {
                batteryFloor;
              };

              Debug.print("BATTERY ROUNDING bot " # debug_show (tokenIndex) # " floor=" # debug_show (batteryFloor) # " fraction=" # debug_show (batteryFraction) # " rng=" # debug_show (batteryRng) # " rounded=" # debug_show (batteryDrainRounded));

              // Negative batteryDrain means restoration (Charging Station)
              let newBattery = if (batteryDrainWithVariance < 0.0) {
                // Restoration: add battery (capped at 100)
                Nat.min(100, botStats.battery + batteryDrainRounded);
              } else {
                // Drain: subtract battery (floored at 0)
                if (botStats.battery > batteryDrainRounded) {
                  botStats.battery - batteryDrainRounded;
                } else { 0 };
              };

              // Track how much battery was actually restored (for ChargingStation display)
              let batteryRestored = if (batteryDrainWithVariance < 0.0 and newBattery > botStats.battery) {
                newBattery - botStats.battery;
              } else {
                0;
              };

              // BATTERY DEPLETION DAMAGE: If battery reaches 0 during scavenging, damage condition
              // This penalizes letting bots run completely dry - creates strategic tension
              let batteryDepletionPenalty = if (newBattery == 0 and botStats.battery == 0) {
                // Bot has been at 0% battery - take 5-10 condition damage per 15min tick
                let depletionRng = Float.fromInt(hashNat(tokenIndex + Int.abs(now) + 5) % 6); // 0-5
                Int.abs(Float.toInt(5.0 + depletionRng)); // 5-10 damage
              } else { 0 };

              let conditionFloor = Int.abs(Float.toInt(conditionLossWithVariance));
              let conditionFraction = Float.abs(conditionLossWithVariance) - Float.fromInt(conditionFloor);
              let conditionRng = Float.fromInt(hashNat(tokenIndex + Int.abs(now) + 3) % 100) / 100.0;
              let conditionChangeRounded = if (conditionRng < conditionFraction) {
                conditionFloor + 1;
              } else {
                conditionFloor;
              };

              // Negative conditionLoss means restoration (Repair Bay)
              let newCondition = if (conditionLossWithVariance < 0.0) {
                // Restoration: add condition (capped at 100)
                Nat.min(100, botStats.condition + conditionChangeRounded);
              } else {
                // Loss: subtract condition (floored at 0), plus battery depletion penalty
                let totalConditionLoss = conditionChangeRounded + batteryDepletionPenalty;
                if (botStats.condition > totalConditionLoss) {
                  botStats.condition - totalConditionLoss;
                } else { 0 };
              };

              // Track how much condition was actually restored (for RepairBay display)
              let conditionRestored = if (conditionLossWithVariance < 0.0 and newCondition > botStats.condition) {
                newCondition - botStats.condition;
              } else {
                0;
              };

              // Probabilistic rounding for parts too
              let partsFloor = Int.abs(Float.toInt(partsThis15Min));
              let partsFraction = partsThis15Min - Float.fromInt(partsFloor);
              let partsRng = Float.fromInt(hashNat(tokenIndex + Int.abs(now) + 4) % 100) / 100.0;
              let partsRounded = if (partsRng < partsFraction) {
                partsFloor + 1;
              } else {
                partsFloor;
              };
              let factionBoostedDistribution = applyFactionBonus(
                getPartDistributionForZone(mission.zone),
                botStats.faction,
              );
              let newPendingParts = distributeParts(
                mission.pendingParts,
                partsRounded,
                factionBoostedDistribution,
              );

              // World buff chance: 8% per hour = 2% per 15-min interval
              // Total chance scales with time: hours_elapsed * 8% (capped at 90%)
              // Acceleration stat increases buff chance (at 100 accel: 3.2% instead of 2%)
              // hoursElapsed already calculated above for duration bonus
              // NOTE: World buffs ONLY available in scavenging zones (not RepairBay/ChargingStation)
              let totalBuffChance = Float.min(90.0, Float.fromInt(hoursElapsed) * 8.0);
              let buffRoll = Float.fromInt((Int.abs(now / 1_000_000) * tokenIndex) % 1000) / 10.0; // 0-100

              var newWorldBuff = botStats.worldBuff; // Keep existing buff by default
              var buffMessage = "";

              let isScavengingZone = switch (mission.zone) {
                case (#RepairBay) { false };
                case (#ChargingStation) { false };
                case (_) { true }; // ScrapHeaps, AbandonedSettlements, DeadMachineFields
              };

              let baseBuffChance = 2.0 * accelBuffBonus; // 2% base, up to 3.2% with max accel
              if (isScavengingZone and buffRoll < baseBuffChance) {
                // Acceleration-modified buff chance
                // Buff strength scales with hours elapsed
                let buffStats = if (hoursElapsed <= 3) {
                  [("speed", 2 : Nat)];
                } else if (hoursElapsed <= 8) {
                  [("speed", 3 : Nat), ("acceleration", 2 : Nat)];
                } else {
                  [("speed", 4 : Nat), ("acceleration", 3 : Nat), ("powerCore", 2 : Nat)];
                };

                // Blackhole faction adds +3 speed/accel bonus on top of regular buff
                let finalBuffStats = if (botStats.faction == #Blackhole) {
                  // Add +3 to each stat in buffStats, or add new speed/accel entries
                  let buff = Buffer.Buffer<(Text, Nat)>(buffStats.size() + 2);
                  var hasSpeed = false;
                  var hasAccel = false;

                  for ((stat, value) in buffStats.vals()) {
                    if (stat == "speed") {
                      buff.add(("speed", value + 3));
                      hasSpeed := true;
                    } else if (stat == "acceleration") {
                      buff.add(("acceleration", value + 3));
                      hasAccel := true;
                    } else {
                      buff.add((stat, value));
                    };
                  };

                  // Add speed/accel if not present in original buff
                  if (not hasSpeed) { buff.add(("speed", 3)) };
                  if (not hasAccel) { buff.add(("acceleration", 3)) };

                  Buffer.toArray(buff);
                } else {
                  buffStats;
                };

                newWorldBuff := ?{
                  stats = finalBuffStats;
                  appliedAt = now;
                  expiresAt = now + (48 * 3600 * 1_000_000_000); // 48 hours
                };

                buffMessage := " 🌟 WORLD BUFF DISCOVERED!";
              };

              // Update mission with new pending parts, condition restored, and battery restored
              let updatedMission = {
                mission with
                lastAccumulation = now;
                pendingParts = newPendingParts;
                pendingConditionRestored = mission.pendingConditionRestored + conditionRestored;
                pendingBatteryRestored = mission.pendingBatteryRestored + batteryRestored;
              };

              let updatedStats = {
                botStats with
                battery = newBattery;
                condition = newCondition;
                activeMission = ?updatedMission;
                worldBuff = newWorldBuff;
              };
              updateStats(tokenIndex, updatedStats);

              let totalPending = getTotalPendingParts(newPendingParts);
              #ok("Accumulated " # Float.format(#fix 1, partsThis15Min) # " parts. Battery: " # Nat.toText(newBattery) # ", Condition: " # Nat.toText(newCondition) # ", Total pending: " # Nat.toText(totalPending) # buffMessage);
            };
          };
        };
      };
    };

    // ===== LEGACY SCAVENGING FUNCTIONS (TO BE REPLACED) =====

    /// Start continuous scavenging mission (toggle on)
    /// Optional duration - if provided, mission ends automatically after that many minutes
    /// If no duration, bot scavenges until manually collected or dies
    public func startScavengingMission(
      tokenIndex : Nat,
      zone : ScavengingZone,
      now : Int,
      durationMinutes : ?Nat,
    ) : Result.Result<ScavengingMission, Text> {
      switch (getStats(tokenIndex)) {
        case (null) { #err("Bot not initialized for racing") };
        case (?botStats) {
          // Check if bot is already on a mission
          switch (botStats.activeMission) {
            case (?_) {
              return #err("Bot is already on a scavenging mission - collect rewards first");
            };
            case (null) {};
          };

          // Minimum battery/condition check (need at least 10 to start)
          if (botStats.battery < 10) {
            return #err("Insufficient battery - need at least 10 to start scavenging");
          };
          if (botStats.condition < 10) {
            return #err("Bot too damaged - need at least 10 condition to start scavenging");
          };

          // Create continuous or timed mission
          let missionId = getNextMissionId();
          let mission : ScavengingMission = {
            missionId = missionId;
            tokenIndex = tokenIndex;
            zone = zone; // LOCKED - cannot change without ending mission
            startTime = now;
            lastAccumulation = now;
            durationMinutes = durationMinutes; // Store duration for display/auto-complete
            pendingParts = {
              speedChips = 0;
              powerCoreFragments = 0;
              thrusterKits = 0;
              gyroModules = 0;
              universalParts = 0;
            };
            pendingConditionRestored = 0;
            pendingBatteryRestored = 0;
          };

          // Update bot stats with active mission
          let updatedStats = {
            botStats with
            activeMission = ?mission;
          };
          updateStats(tokenIndex, updatedStats);

          #ok(mission);
        };
      };
    };

    /// Pull bot from active scavenging mission (used when entering races)
    /// V2: Apply 50% penalty to accumulated pending parts, award them, and clear mission
    public func pullFromScavenging(
      tokenIndex : Nat,
      now : Int,
      rng : Nat,
    ) : Result.Result<{ penalties : Text }, Text> {
      switch (getStats(tokenIndex)) {
        case (null) { #err("Bot not found") };
        case (?botStats) {
          switch (botStats.activeMission) {
            case (null) { #err("Bot is not on a scavenging mission") };
            case (?mission) {
              // Force final accumulation before pulling
              ignore accumulateScavengingRewards(tokenIndex, now);

              // Get updated stats with final accumulation
              let finalStats = switch (getStats(tokenIndex)) {
                case (?s) { s };
                case (null) { return #err("Bot disappeared") };
              };
              let finalMission = switch (finalStats.activeMission) {
                case (?m) { m };
                case (null) {
                  return #err("Mission was cleared (bot may have died)");
                };
              };

              // Calculate hours elapsed
              let hoursElapsed = Int.abs((now - finalMission.startTime) / (3600 * 1_000_000_000));

              // Get pending parts with 50% early withdrawal penalty
              let pending = finalMission.pendingParts;
              let penaltyMultiplier = 0.50; // Keep only 50% of parts

              let penalizedSpeedChips = Int.abs(Float.toInt(Float.fromInt(pending.speedChips) * penaltyMultiplier));
              let penalizedPowerCore = Int.abs(Float.toInt(Float.fromInt(pending.powerCoreFragments) * penaltyMultiplier));
              let penalizedThrusterKits = Int.abs(Float.toInt(Float.fromInt(pending.thrusterKits) * penaltyMultiplier));
              let penalizedGyroModules = Int.abs(Float.toInt(Float.fromInt(pending.gyroModules) * penaltyMultiplier));
              let penalizedUniversalParts = Int.abs(Float.toInt(Float.fromInt(pending.universalParts) * penaltyMultiplier));

              let totalPenalizedParts = penalizedSpeedChips + penalizedPowerCore + penalizedThrusterKits + penalizedGyroModules + penalizedUniversalParts;

              // Award penalized parts to inventory
              let owner = botStats.ownerPrincipal;
              if (totalPenalizedParts > 0) {
                addParts(owner, #SpeedChip, penalizedSpeedChips);
                addParts(owner, #PowerCoreFragment, penalizedPowerCore);
                addParts(owner, #ThrusterKit, penalizedThrusterKits);
                addParts(owner, #GyroModule, penalizedGyroModules);
                addParts(owner, #UniversalPart, penalizedUniversalParts);
              };

              // Update bot stats: clear mission
              let updatedStats = {
                finalStats with
                activeMission = null;
                totalPartsScavenged = finalStats.totalPartsScavenged + totalPenalizedParts;
              };
              updateStats(tokenIndex, updatedStats);

              let penaltyText = "⚠️ Pulled from scavenging for race! Time out: " # Nat.toText(hoursElapsed) # "h. Parts awarded (50% penalty): " # Nat.toText(totalPenalizedParts);

              #ok({ penalties = penaltyText });
            };
          };
        };
      };
    };

    /// NEW: Complete continuous scavenging mission (collect rewards anytime)
    public func completeScavengingMissionV2(
      tokenIndex : Nat,
      now : Int,
    ) : Result.Result<{ totalParts : Nat; speedChips : Nat; powerCoreFragments : Nat; thrusterKits : Nat; gyroModules : Nat; universalParts : Nat; hoursOut : Nat }, Text> {
      switch (getStats(tokenIndex)) {
        case (null) { #err("Bot not found") };
        case (?botStats) {
          switch (botStats.activeMission) {
            case (null) { #err("No active mission") };
            case (?mission) {
              // Force final accumulation for any partial interval
              ignore accumulateScavengingRewards(tokenIndex, now);

              // Get updated mission with final accumulation
              let finalStats = switch (getStats(tokenIndex)) {
                case (?s) { s };
                case (null) { return #err("Bot disappeared") };
              };
              let finalMission = switch (finalStats.activeMission) {
                case (?m) { m };
                case (null) {
                  return #err("Mission was cleared (bot may have died)");
                };
              };

              // Calculate total pending parts
              let pending = finalMission.pendingParts;
              var totalParts = getTotalPendingParts(pending);
              let hoursOut = Int.abs((now - finalMission.startTime) / (3600 * 1_000_000_000));

              // Apply faction-specific bonuses to final parts total
              let rngSeed = Int.abs(now % 1000000) + tokenIndex;
              var partsMultiplier : Float = 1.0;

              // Golden faction: 15% chance to double parts
              if (botStats.faction == #Golden and (rngSeed % 100) < 15) {
                partsMultiplier := 2.0;
              };

              // Box faction: 5% chance to triple parts (overrides Golden if both proc)
              if (botStats.faction == #Box and ((rngSeed * 7) % 100) < 5) {
                partsMultiplier := 3.0;
              };

              // Master faction: Every 10th mission doubles parts
              let nextMissionCount = finalStats.scavengingMissions + 1;
              if (botStats.faction == #Master and nextMissionCount % 10 == 0) {
                partsMultiplier := 2.0;
              };

              // Game faction: Every 5th mission +10 parts (additive)
              var bonusParts = 0;
              if (botStats.faction == #Game and nextMissionCount % 5 == 0) {
                bonusParts := 10;
              };

              // Apply multiplier and bonus
              totalParts := Int.abs(Float.toInt(Float.fromInt(totalParts) * partsMultiplier)) + bonusParts;

              // Scale individual part types by the same multiplier
              var finalSpeedChips = Int.abs(Float.toInt(Float.fromInt(pending.speedChips) * partsMultiplier));
              var finalPowerCore = Int.abs(Float.toInt(Float.fromInt(pending.powerCoreFragments) * partsMultiplier));
              var finalThrusterKits = Int.abs(Float.toInt(Float.fromInt(pending.thrusterKits) * partsMultiplier));
              var finalGyroModules = Int.abs(Float.toInt(Float.fromInt(pending.gyroModules) * partsMultiplier));
              var finalUniversalParts = Int.abs(Float.toInt(Float.fromInt(pending.universalParts) * partsMultiplier));

              // Distribute bonus parts to universal if Game faction bonus triggered
              if (bonusParts > 0) {
                finalUniversalParts += bonusParts;
              };

              // Award parts to inventory
              let owner = botStats.ownerPrincipal;
              addParts(owner, #SpeedChip, finalSpeedChips);
              addParts(owner, #PowerCoreFragment, finalPowerCore);
              addParts(owner, #ThrusterKit, finalThrusterKits);
              addParts(owner, #GyroModule, finalGyroModules);
              addParts(owner, #UniversalPart, finalUniversalParts);

              // Update stats - clear mission, update counters, store last mission rewards
              let updatedStats = {
                finalStats with
                activeMission = null;
                scavengingMissions = finalStats.scavengingMissions + 1;
                totalPartsScavenged = finalStats.totalPartsScavenged + totalParts;
                scavengingReputation = finalStats.scavengingReputation + 1;
                bestHaul = if (totalParts > finalStats.bestHaul) {
                  totalParts;
                } else { finalStats.bestHaul };
                lastMissionRewards = ?{
                  totalParts = totalParts;
                  speedChips = finalSpeedChips;
                  powerCoreFragments = finalPowerCore;
                  thrusterKits = finalThrusterKits;
                  gyroModules = finalGyroModules;
                  universalParts = finalUniversalParts;
                  hoursOut = hoursOut;
                  completedAt = now;
                  zone = finalMission.zone;
                };
              };
              updateStats(tokenIndex, updatedStats);

              Debug.print("Set lastMissionRewards for bot " # debug_show (tokenIndex) # ": " # debug_show (totalParts) # " parts");

              #ok({
                totalParts = totalParts;
                speedChips = finalSpeedChips;
                powerCoreFragments = finalPowerCore;
                thrusterKits = finalThrusterKits;
                gyroModules = finalGyroModules;
                universalParts = finalUniversalParts;
                hoursOut = hoursOut;
              });
            };
          };
        };
      };
    };

    /// Check and expire world buffs that are older than 48 hours
    public func checkAndExpireWorldBuff(tokenIndex : Nat, now : Int) : Bool {
      switch (getStats(tokenIndex)) {
        case (null) { false };
        case (?botStats) {
          switch (botStats.worldBuff) {
            case (null) { false };
            case (?buff) {
              if (now >= buff.expiresAt) {
                // Buff has expired, remove it
                let updatedStats = {
                  botStats with
                  worldBuff = null;
                };
                updateStats(tokenIndex, updatedStats);
                true; // Buff was expired
              } else {
                false; // Buff still valid
              };
            };
          };
        };
      };
    };

    /// Consume world buff after a race
    public func consumeWorldBuff(tokenIndex : Nat) {
      switch (getStats(tokenIndex)) {
        case (null) {};
        case (?botStats) {
          let updatedStats = {
            botStats with
            worldBuff = null;
          };
          updateStats(tokenIndex, updatedStats);
        };
      };
    };
  };
};
