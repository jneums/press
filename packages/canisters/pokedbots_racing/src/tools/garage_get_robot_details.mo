import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Time "mo:base/Time";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import WastelandFlavor "WastelandFlavor";
import ExtIntegration "../ExtIntegration";
import TimeUtils "../TimeUtils";

module {
  public func config() : McpTypes.Tool = {
    name = "garage_get_robot_details";
    title = ?"Get Robot Details";
    description = ?"Get comprehensive details for a specific PokedBot including stats, condition, career, and upgrade status. The bot must be initialized for racing first.\n\n**TIMESTAMPS:** All timestamps (world_buff_expires_at_utc, last_recharged_utc, last_repaired_utc, start_time_utc, last_accumulation_utc) are in UTC ISO 8601 format (e.g., '2024-12-17T20:00:00Z'). Cooldowns: recharge 6hr, repair 3hr.\n\n**OWNERSHIP:** If you own the bot, shows full details (condition, battery, upgrade costs). If not, shows public profile only (stats, career, rating, ELO).\n\nFor detailed mechanics (battery penalties, overcharge, terrain bonuses), use help_get_compendium tool.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_index", Json.obj([("type", Json.str("number")), ("description", Json.str("The token index of the PokedBot to view (e.g., 4079)"))]))])),
      ("required", Json.arr([Json.str("token_index")])),
    ]);
    outputSchema = null;
  };

  public func handle(ctx : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {
      // Authentication required
      let user = switch (_auth) {
        case (null) {
          return ToolContext.makeError("Authentication required", cb);
        };
        case (?auth) { auth.principal };
      };

      // Parse token index
      let tokenIndex = switch (Result.toOption(Json.getAsNat(_args, "token_index"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: token_index", cb);
        };
        case (?idx) {
          if (idx > 9999) {
            return ToolContext.makeError("Invalid token_index: " # Nat.toText(idx) # ". PokedBots token indices are 0-9999.", cb);
          };
          idx;
        };
      };

      // Verify ownership via EXT (source of truth) - check user's wallet
      let walletAccountId = ExtIntegration.principalToAccountIdentifier(user, null);
      let ownerResult = try {
        await ctx.extCanister.bearer(ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), ctx.extCanisterId));
      } catch (_) {
        return ToolContext.makeError("Failed to verify ownership", cb);
      };
      let isOwner = switch (ownerResult) {
        case (#err(_)) {
          return ToolContext.makeError("This PokedBot does not exist.", cb);
        };
        case (#ok(currentOwner)) {
          currentOwner == walletAccountId;
        };
      };

      // Get racing stats (optional - may not be initialized)
      let racingStatsOpt = ctx.garageManager.getStats(tokenIndex);

      // Get base stats - these are always available
      let baseStats = ctx.garageManager.getBaseStats(tokenIndex);

      // If not initialized, show base stats only
      switch (racingStatsOpt) {
        case (null) {
          // Bot not initialized - show base stats and initialization prompt
          let totalBaseStats = baseStats.speed + baseStats.powerCore + baseStats.acceleration + baseStats.stability;
          let baseRating = totalBaseStats / 4;

          // Generate image URLs
          let tokenId = ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), ctx.extCanisterId);
          let thumbnailUrl = "https://bzsui-sqaaa-aaaah-qce2a-cai.raw.icp0.io/?tokenid=" # tokenId # "&type=thumbnail";
          let fullImageUrl = "https://bzsui-sqaaa-aaaah-qce2a-cai.raw.icp0.io/?tokenid=" # tokenId;

          let response = Json.obj([
            ("message", Json.str("⚠️ This PokedBot has not been initialized for racing yet.")),
            ("token_index", Json.int(tokenIndex)),
            ("is_initialized", Json.bool(false)),
            ("is_owner", Json.bool(isOwner)),
            ("base_stats", Json.obj([("speed", Json.int(baseStats.speed)), ("power_core", Json.int(baseStats.powerCore)), ("acceleration", Json.int(baseStats.acceleration)), ("stability", Json.int(baseStats.stability)), ("total", Json.int(totalBaseStats)), ("estimated_rating", Json.int(baseRating))])),
            ("next_step", Json.str("Use garage_initialize_pokedbot to register this bot for racing (0.1 ICP one-time fee). This will reveal its faction, preferred terrain, and enable upgrades and racing.")),
            ("thumbnail", Json.str(thumbnailUrl)),
            ("image", Json.str(fullImageUrl)),
          ]);

          return ToolContext.makeSuccess(response, cb);
        };
        case (?stats) {
          // Continue with normal initialized bot logic
          let racingStats = stats;

          // Calculate overall rating
          let overallRating = ctx.garageManager.calculateOverallRating(racingStats);
          let status = ctx.garageManager.getBotStatus(racingStats);
          let canRace = ctx.garageManager.canRace(Nat.toText(tokenIndex));

          // Determine race class bracket (rating-based)
          let raceClass = if (overallRating >= 50) {
            "SilentKlan (50+ rating)";
          } else if (overallRating >= 40) {
            "Elite (40-49 rating)";
          } else if (overallRating >= 30) {
            "Raider (30-39 rating)";
          } else if (overallRating >= 20) {
            "Junker (20-29 rating)";
          } else {
            "Scrap (0-19 rating)";
          };

          // Get wasteland flavor text
          let factionGreeting = WastelandFlavor.getFactionGreeting(racingStats.faction);
          let statusFlavor = WastelandFlavor.getStatusFlavor(status, racingStats.faction);
          let reputationTier = WastelandFlavor.getReputationTier(racingStats.factionReputation);

          // Helper functions for text conversion
          let factionText = switch (racingStats.faction) {
            // Ultra-Rare
            case (#UltimateMaster) { "Ultimate-Master" };
            case (#Wild) { "Wild" };
            case (#Golden) { "Golden" };
            case (#Ultimate) { "Ultimate" };
            // Super-Rare
            case (#Blackhole) { "Blackhole" };
            case (#Dead) { "Dead" };
            case (#Master) { "Master" };
            // Rare
            case (#Bee) { "Bee" };
            case (#Food) { "Food" };
            case (#Box) { "Box" };
            case (#Murder) { "Murder" };
            // Common
            case (#Game) { "Game" };
            case (#Animal) { "Animal" };
            case (#Industrial) { "Industrial" };
          };

          let distanceText = switch (racingStats.preferredDistance) {
            case (#ShortSprint) { "ShortSprint (< 10km)" };
            case (#MediumHaul) { "MediumHaul (10-20km)" };
            case (#LongTrek) { "LongTrek (> 20km)" };
          };

          let terrainText = switch (racingStats.preferredTerrain) {
            case (#ScrapHeaps) { "ScrapHeaps" };
            case (#WastelandSand) { "WastelandSand" };
            case (#MetalRoads) { "MetalRoads" };
          };

          // Generate terrain bonus explanation
          let terrainBonusNote = "PREFERRED TERRAIN: +5% all stats when racing on " # terrainText # ". This stacks with faction bonuses!";

          // Check for active upgrade
          let now = Time.now();
          let upgradeInfo = switch (ctx.garageManager.getActiveUpgrade(tokenIndex)) {
            case null { null };
            case (?session) {
              if (session.endsAt > now) {
                let timeRemaining = session.endsAt - now;
                let hoursRemaining = timeRemaining / 3_600_000_000_000;
                let minutesRemaining = (timeRemaining % 3_600_000_000_000) / 60_000_000_000;

                let upgradeTypeText = switch (session.upgradeType) {
                  case (#Velocity) { "Velocity (Speed)" };
                  case (#PowerCore) { "Power Core" };
                  case (#Thruster) { "Thruster (Acceleration)" };
                  case (#Gyro) { "Gyro (Stability)" };
                };

                ?Json.obj([
                  ("type", Json.str(upgradeTypeText)),
                  ("time_remaining_hours", Json.int(hoursRemaining)),
                  ("time_remaining_minutes", Json.int(minutesRemaining)),
                  ("ends_at", Json.int(session.endsAt)),
                  ("status", Json.str("In Progress")),
                ]);
              } else {
                null;
              };
            };
          };

          // Get current and base stats
          let currentStats = ctx.garageManager.getCurrentStats(racingStats);

          // Calculate stats at 100% condition/battery (no penalties)
          let statsAt100 = {
            speed = baseStats.speed + racingStats.speedBonus;
            powerCore = baseStats.powerCore + racingStats.powerCoreBonus;
            acceleration = baseStats.acceleration + racingStats.accelerationBonus;
            stability = baseStats.stability + racingStats.stabilityBonus;
          };

          // Calculate next upgrade costs using V2 dynamic formula with Game faction synergy
          let synergies = ctx.garageManager.calculateFactionSynergies(user);
          // Calculate base stats safely using wrapping subtraction
          func safeSub(a : Nat, b : Nat) : Nat {
            if (a > b) { a - b } else { 0 };
          };
          let speedBaseForCost = safeSub(currentStats.speed, racingStats.speedBonus);
          let powerCoreBaseForCost = safeSub(currentStats.powerCore, racingStats.powerCoreBonus);
          let accelerationBaseForCost = safeSub(currentStats.acceleration, racingStats.accelerationBonus);
          let stabilityBaseForCost = safeSub(currentStats.stability, racingStats.stabilityBonus);

          let speedUpgradeCostE8s = ctx.garageManager.calculateUpgradeCostV2(
            speedBaseForCost,
            currentStats.speed,
            overallRating,
            synergies.costMultipliers.upgradeCost,
          );
          let powerCoreUpgradeCostE8s = ctx.garageManager.calculateUpgradeCostV2(
            powerCoreBaseForCost,
            currentStats.powerCore,
            overallRating,
            synergies.costMultipliers.upgradeCost,
          );
          let accelerationUpgradeCostE8s = ctx.garageManager.calculateUpgradeCostV2(
            accelerationBaseForCost,
            currentStats.acceleration,
            overallRating,
            synergies.costMultipliers.upgradeCost,
          );
          let stabilityUpgradeCostE8s = ctx.garageManager.calculateUpgradeCostV2(
            stabilityBaseForCost,
            currentStats.stability,
            overallRating,
            synergies.costMultipliers.upgradeCost,
          );

          // Calculate success rates and pity bonus
          let pityCounter = ctx.garageManager.getPityCounter(tokenIndex);
          // Use upgrade counts (not base stats) for success rate calculation
          let speedAttempt = racingStats.speedUpgrades;
          let powerCoreAttempt = racingStats.powerCoreUpgrades;
          let accelerationAttempt = racingStats.accelerationUpgrades;
          let stabilityAttempt = racingStats.stabilityUpgrades;

          let speedSuccessRate = ctx.garageManager.calculateSuccessRate(speedAttempt, pityCounter);
          let powerCoreSuccessRate = ctx.garageManager.calculateSuccessRate(powerCoreAttempt, pityCounter);
          let accelerationSuccessRate = ctx.garageManager.calculateSuccessRate(accelerationAttempt, pityCounter);
          let stabilitySuccessRate = ctx.garageManager.calculateSuccessRate(stabilityAttempt, pityCounter);

          // Generate image URLs
          let tokenId = ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), ctx.extCanisterId);
          let thumbnailUrl = "https://bzsui-sqaaa-aaaah-qce2a-cai.raw.icp0.io/?tokenid=" # tokenId # "&type=thumbnail";
          let fullImageUrl = "https://bzsui-sqaaa-aaaah-qce2a-cai.raw.icp0.io/?tokenid=" # tokenId;

          // Build JSON response - different fields based on ownership
          let response = if (isOwner) {
            // Full details for owned bots
            Json.obj([
              ("message", Json.str(factionGreeting)),
              ("token_index", Json.int(tokenIndex)),
              ("name", switch (racingStats.name) { case (?n) { Json.str(n) }; case (null) { Json.nullable() } }),
              ("race_class", Json.str(raceClass)),
              ("owner", Json.str(Principal.toText(user))),
              ("is_owner", Json.bool(true)),
              ("faction", Json.str(factionText)),
              ("stats", Json.obj([("speed", Json.int(currentStats.speed)), ("power_core", Json.int(currentStats.powerCore)), ("acceleration", Json.int(currentStats.acceleration)), ("stability", Json.int(currentStats.stability)), ("total_current", Json.int(currentStats.speed + currentStats.powerCore + currentStats.acceleration + currentStats.stability)), ("stats_at_100_percent", Json.obj([("speed", Json.int(statsAt100.speed)), ("power_core", Json.int(statsAt100.powerCore)), ("acceleration", Json.int(statsAt100.acceleration)), ("stability", Json.int(statsAt100.stability)), ("total_at_100", Json.int(statsAt100.speed + statsAt100.powerCore + statsAt100.acceleration + statsAt100.stability))])), ("base_speed", Json.int(baseStats.speed)), ("base_power_core", Json.int(baseStats.powerCore)), ("base_acceleration", Json.int(baseStats.acceleration)), ("base_stability", Json.int(baseStats.stability)), ("total_base", Json.int(baseStats.speed + baseStats.powerCore + baseStats.acceleration + baseStats.stability)), ("speed_bonus", Json.int(racingStats.speedBonus)), ("power_core_bonus", Json.int(racingStats.powerCoreBonus)), ("acceleration_bonus", Json.int(racingStats.accelerationBonus)), ("stability_bonus", Json.int(racingStats.stabilityBonus)), ("speed_upgrades", Json.int(racingStats.speedUpgrades)), ("power_core_upgrades", Json.int(racingStats.powerCoreUpgrades)), ("acceleration_upgrades", Json.int(racingStats.accelerationUpgrades)), ("stability_upgrades", Json.int(racingStats.stabilityUpgrades))])),
              ("upgrade_costs_v2", Json.obj([("speed", Json.obj([("cost_e8s", Json.int(speedUpgradeCostE8s)), ("cost_icp", Json.str(Float.format(#fix 2, Float.fromInt(speedUpgradeCostE8s) / 100_000_000.0))), ("success_rate", Json.str(Float.format(#fix 1, speedSuccessRate) # "%"))])), ("power_core", Json.obj([("cost_e8s", Json.int(powerCoreUpgradeCostE8s)), ("cost_icp", Json.str(Float.format(#fix 2, Float.fromInt(powerCoreUpgradeCostE8s) / 100_000_000.0))), ("success_rate", Json.str(Float.format(#fix 1, powerCoreSuccessRate) # "%"))])), ("acceleration", Json.obj([("cost_e8s", Json.int(accelerationUpgradeCostE8s)), ("cost_icp", Json.str(Float.format(#fix 2, Float.fromInt(accelerationUpgradeCostE8s) / 100_000_000.0))), ("success_rate", Json.str(Float.format(#fix 1, accelerationSuccessRate) # "%"))])), ("stability", Json.obj([("cost_e8s", Json.int(stabilityUpgradeCostE8s)), ("cost_icp", Json.str(Float.format(#fix 2, Float.fromInt(stabilityUpgradeCostE8s) / 100_000_000.0))), ("success_rate", Json.str(Float.format(#fix 1, stabilitySuccessRate) # "%"))])), ("pity_counter", Json.int(pityCounter)), ("pity_bonus", Json.str("+" # Nat.toText(pityCounter * 5) # "%"))])),
              ("upgrade_mechanics", Json.str("V2 Gacha System: Success rate starts at 85% for first upgrade per stat, smoothly decreasing to 1% at 15 upgrades, then stays at 1%. Each stat (Speed/PowerCore/Acceleration/Stability) tracked independently. Pity system adds +5% per failure (max +25%). Successful upgrades have chance for double points (15% → 2%). Failed upgrades refund 50% of cost.")),
              (
                "condition",
                Json.obj([
                  ("battery", Json.int(racingStats.battery)),
                  ("overcharge", Json.int(racingStats.overcharge)),
                  ("condition", Json.int(racingStats.condition)),
                  ("status", Json.str(status)),
                  ("status_message", Json.str(statusFlavor)),
                  ("last_recharged_utc", switch (racingStats.lastRecharged) { case (?t) { Json.str(TimeUtils.nanosToUtcString(t)) }; case (null) { Json.nullable() } }),
                  ("last_repaired_utc", switch (racingStats.lastRepaired) { case (?t) { Json.str(TimeUtils.nanosToUtcString(t)) }; case (null) { Json.nullable() } }),
                  (
                    "world_buff",
                    switch (racingStats.worldBuff) {
                      case (?buff) {
                        let now = Time.now();
                        let hoursRemaining = (buff.expiresAt - now) / (60 * 60 * 1_000_000_000);
                        var statsText = "";
                        for ((stat, value) in buff.stats.vals()) {
                          statsText := statsText # " +" # Nat.toText(value) # " " # stat;
                        };
                        Json.obj([
                          ("active", Json.bool(true)),
                          ("stats", Json.str(statsText)),
                          ("expires_at_utc", Json.str(TimeUtils.nanosToUtcString(buff.expiresAt))),
                          ("expires_in_hours", Json.int(Int.abs(hoursRemaining))),
                          ("message", Json.str("World buff active:" # statsText # " (expires in " # Nat.toText(Int.abs(hoursRemaining)) # "h)")),
                        ]);
                      };
                      case (null) {
                        Json.obj([("active", Json.bool(false))]);
                      };
                    },
                  ),
                ]),
              ),
              ("career", Json.obj([("races_entered", Json.int(racingStats.racesEntered)), ("wins", Json.int(racingStats.wins)), ("places", Json.int(racingStats.places)), ("shows", Json.int(racingStats.shows)), ("total_scrap_earned", Json.int(racingStats.totalScrapEarned)), ("faction_reputation", Json.int(racingStats.factionReputation)), ("reputation_tier", Json.str(reputationTier))])),
              ("overall_rating", Json.int(overallRating)),
              ("can_race", Json.bool(canRace)),
              ("preferred_distance", Json.str(distanceText)),
              ("preferred_terrain", Json.str(terrainText)),
              ("terrain_bonus_note", Json.str(terrainBonusNote)),
              ("experience", Json.int(racingStats.experience)),
              ("thumbnail", Json.str(thumbnailUrl)),
              ("image", Json.str(fullImageUrl)),
              (
                "active_scavenging",
                switch (racingStats.activeMission) {
                  case null { Json.obj([("status", Json.str("None"))]) };
                  case (?mission) {
                    let elapsed = now - mission.startTime;
                    let hoursElapsed = elapsed / (60 * 60 * 1_000_000_000);
                    let minutesSinceAccumulation = (now - mission.lastAccumulation) / (60 * 1_000_000_000);

                    let totalPending = mission.pendingParts.speedChips + mission.pendingParts.powerCoreFragments + mission.pendingParts.thrusterKits + mission.pendingParts.gyroModules + mission.pendingParts.universalParts;

                    let missionTypeText = "Continuous Scavenging";

                    let zoneText = switch (mission.zone) {
                      case (#ScrapHeaps) { "ScrapHeaps" };
                      case (#AbandonedSettlements) { "AbandonedSettlements" };
                      case (#DeadMachineFields) { "DeadMachineFields" };
                      case (#ChargingStation) { "ChargingStation" };
                      case (#RepairBay) { "RepairBay" };
                    };

                    Json.obj([
                      ("status", Json.str("Active - collect anytime")),
                      ("mission_type", Json.str(missionTypeText)),
                      ("zone", Json.str(zoneText)),
                      ("hours_elapsed", Json.int(Int.abs(hoursElapsed))),
                      ("minutes_since_last_accumulation", Json.int(Int.abs(minutesSinceAccumulation))),
                      ("pending_parts", Json.int(totalPending)),
                      ("start_time_utc", Json.str(TimeUtils.nanosToUtcString(mission.startTime))),
                      ("last_accumulation_utc", Json.str(TimeUtils.nanosToUtcString(mission.lastAccumulation))),
                    ]);
                  };
                },
              ),
              (
                "active_upgrade",
                switch (upgradeInfo) {
                  case null { Json.obj([("status", Json.str("None"))]) };
                  case (?info) { info };
                },
              ),
            ]);
          } else {
            // Public details only for bots not owned by caller - show only statsAt100 (no battery/condition penalties)
            // Calculate rating based on stats at 100%
            let totalStatsAt100 = statsAt100.speed + statsAt100.powerCore + statsAt100.acceleration + statsAt100.stability;
            let ratingAt100 = totalStatsAt100 / 4;

            Json.obj([
              ("message", Json.str("Public racing profile for PokedBot #" # Nat.toText(tokenIndex))),
              ("token_index", Json.int(tokenIndex)),
              ("name", switch (racingStats.name) { case (?n) { Json.str(n) }; case (null) { Json.nullable() } }),
              ("race_class", Json.str(raceClass)),
              ("is_owner", Json.bool(false)),
              ("faction", Json.str(factionText)),
              ("stats", Json.obj([("speed", Json.int(statsAt100.speed)), ("power_core", Json.int(statsAt100.powerCore)), ("acceleration", Json.int(statsAt100.acceleration)), ("stability", Json.int(statsAt100.stability)), ("total_at_100", Json.int(totalStatsAt100))])),
              ("career", Json.obj([("races_entered", Json.int(racingStats.racesEntered)), ("wins", Json.int(racingStats.wins)), ("places", Json.int(racingStats.places)), ("shows", Json.int(racingStats.shows)), ("faction_reputation", Json.int(racingStats.factionReputation)), ("reputation_tier", Json.str(reputationTier)), ("elo_rating", Json.int(racingStats.eloRating))])),
              ("overall_rating", Json.int(ratingAt100)),
              ("preferred_distance", Json.str(distanceText)),
              ("preferred_terrain", Json.str(terrainText)),
              ("thumbnail", Json.str(thumbnailUrl)),
              ("image", Json.str(fullImageUrl)),
            ]);
          };

          ToolContext.makeSuccess(response, cb);
        }; // End of case (?stats)
      }; // End of switch (racingStatsOpt)
    };
  };
};
