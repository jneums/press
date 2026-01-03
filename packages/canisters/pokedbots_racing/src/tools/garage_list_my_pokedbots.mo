import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Time "mo:base/Time";
import Array "mo:base/Array";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";

import ToolContext "./ToolContext";
import ExtIntegration "../ExtIntegration";
import RacingSimulator "../RacingSimulator";

module {
  let RECHARGE_COOLDOWN : Int = 21600000000000; // 6 hours in nanoseconds
  let REPAIR_COOLDOWN : Int = 43200000000000; // 12 hours in nanoseconds
  public func config() : McpTypes.Tool = {
    name = "garage_list_my_pokedbots";
    title = ?"List My PokedBots";
    description = ?"List all PokedBots in your wallet with detailed stats, full power stats, racing status, scavenging status, and overall ratings";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([])),
    ]);
    outputSchema = null;
  };

  public func handler(ctx : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {
      let userPrincipal = switch (_auth) {
        case (?auth) { auth.principal };
        case (null) {
          return ToolContext.makeError("Authentication required", cb);
        };
      };

      // Check user's wallet (non-custodial)
      let walletAccountId = ExtIntegration.principalToAccountIdentifier(userPrincipal, null);
      let tokensResult = await ExtIntegration.getOwnedTokens(ctx.extCanister, walletAccountId);

      // Get user inventory first (always show this)
      let inventory = ctx.garageManager.getUserInventory(userPrincipal);

      let message = switch (tokensResult) {
        case (#err(msg)) {
          var result = "🤖 Empty Garage\n\n";
          result #= "📦 Parts Inventory:\n";
          result #= "   🏎️  Speed Chips: " # Nat.toText(inventory.speedChips) # "\n";
          result #= "   ⚡ Power Cells: " # Nat.toText(inventory.powerCoreFragments) # "\n";
          result #= "   🚀 Thruster Kits: " # Nat.toText(inventory.thrusterKits) # "\n";
          result #= "   🎯 Gyro Units: " # Nat.toText(inventory.gyroModules) # "\n";
          result #= "   ⭐ Universal Parts: " # Nat.toText(inventory.universalParts) # "\n\n";
          result #= "✨ Collection Bonuses:\n";
          result #= "   None (collect faction bots for bonuses)\n\n";
          result #= "No PokedBots found in your wallet.\n\nWallet ID: " # walletAccountId;
          result;
        };
        case (#ok(tokens)) {
          if (tokens.size() == 0) {
            var result = "🤖 Empty Garage\n\n";
            result #= "📦 Parts Inventory:\n";
            result #= "   🏎️  Speed Chips: " # Nat.toText(inventory.speedChips) # "\n";
            result #= "   ⚡ Power Cells: " # Nat.toText(inventory.powerCoreFragments) # "\n";
            result #= "   🚀 Thruster Kits: " # Nat.toText(inventory.thrusterKits) # "\n";
            result #= "   🎯 Gyro Units: " # Nat.toText(inventory.gyroModules) # "\n";
            result #= "   ⭐ Universal Parts: " # Nat.toText(inventory.universalParts) # "\n\n";
            result #= "✨ Collection Bonuses:\n";
            result #= "   None (collect faction bots for bonuses)\n\n";
            result #= "No PokedBots found in your wallet.\n\nWallet ID: " # walletAccountId;
            result;
          } else {
            var msg = "🤖 Your Garage\n\n";

            // Add inventory summary
            msg #= "📦 Parts Inventory (earned from racing):\n";
            msg #= "   🏎️  Speed Chips: " # Nat.toText(inventory.speedChips) # " (from MetalRoads races)\n";
            msg #= "   ⚡ Power Cells: " # Nat.toText(inventory.powerCoreFragments) # " (from ScrapHeaps races)\n";
            msg #= "   🚀 Thruster Kits: " # Nat.toText(inventory.thrusterKits) # " (from WastelandSand races)\n";
            msg #= "   🎯 Gyro Units: " # Nat.toText(inventory.gyroModules) # " (from WastelandSand races)\n";
            msg #= "   ⭐ Universal Parts: " # Nat.toText(inventory.universalParts) # "\n\n";

            // Calculate and display collection bonuses (faction synergies)
            let synergies = ctx.garageManager.calculateFactionSynergies(userPrincipal);
            msg #= "✨ Collection Bonuses (apply to ALL bots):\n";

            // Stat bonuses
            var hasStatBonuses = false;
            var totalSpeed : Nat = 0;
            var totalPowerCore : Nat = 0;
            var totalAccel : Nat = 0;
            var totalStability : Nat = 0;
            for ((faction, bonusStats) in synergies.statBonuses.vals()) {
              totalSpeed += bonusStats.speed;
              totalPowerCore += bonusStats.powerCore;
              totalAccel += bonusStats.acceleration;
              totalStability += bonusStats.stability;
            };
            if (totalSpeed > 0) {
              msg #= "   🏎️  +" # Nat.toText(totalSpeed) # " Speed\n";
              hasStatBonuses := true;
            };
            if (totalPowerCore > 0) {
              msg #= "   ⚡ +" # Nat.toText(totalPowerCore) # " Power Core\n";
              hasStatBonuses := true;
            };
            if (totalAccel > 0) {
              msg #= "   🚀 +" # Nat.toText(totalAccel) # " Acceleration\n";
              hasStatBonuses := true;
            };
            if (totalStability > 0) {
              msg #= "   🎯 +" # Nat.toText(totalStability) # " Stability\n";
              hasStatBonuses := true;
            };

            // Cost/yield bonuses
            let upgradeDiscount = Float.toInt((1.0 - synergies.costMultipliers.upgradeCost) * 100.0);
            let repairDiscount = Float.toInt((1.0 - synergies.costMultipliers.repairCost) * 100.0);
            let cooldownReduction = Float.toInt((1.0 - synergies.costMultipliers.rechargeCooldown) * 100.0);
            let partsBoost = Float.toInt((synergies.yieldMultipliers.scavengingParts - 1.0) * 100.0);
            let prizeBoost = Float.toInt((synergies.yieldMultipliers.racePrizes - 1.0) * 100.0);
            let drainReduction = Float.toInt((1.0 - synergies.drainMultipliers.scavengingDrain) * 100.0);

            if (upgradeDiscount > 0) {
              msg #= "   💰 -" # Int.toText(upgradeDiscount) # "% Upgrade Costs\n";
              hasStatBonuses := true;
            };
            if (repairDiscount > 0) {
              msg #= "   🔧 -" # Int.toText(repairDiscount) # "% Repair Costs\n";
              hasStatBonuses := true;
            };
            if (cooldownReduction > 0) {
              msg #= "   ⏱️  -" # Int.toText(cooldownReduction) # "% Recharge Cooldown\n";
              hasStatBonuses := true;
            };
            if (partsBoost > 0) {
              msg #= "   📦 +" # Int.toText(partsBoost) # "% Scavenging Parts\n";
              hasStatBonuses := true;
            };
            if (prizeBoost > 0) {
              msg #= "   🏆 +" # Int.toText(prizeBoost) # "% Race Prizes\n";
              hasStatBonuses := true;
            };
            if (drainReduction > 0) {
              msg #= "   🛡️  -" # Int.toText(drainReduction) # "% Scavenging Drain\n";
              hasStatBonuses := true;
            };

            if (not hasStatBonuses) {
              msg #= "   None (collect more faction bots for bonuses)\n";
            };
            msg #= "\n";

            msg #= "Found " # Nat32.toText(Nat32.fromNat(tokens.size())) # " PokedBot(s)\n\n";

            for (tokenIndex in tokens.vals()) {
              let tokenId = ExtIntegration.encodeTokenIdentifier(tokenIndex, ctx.extCanisterId);
              let thumbnailUrl = "https://bzsui-sqaaa-aaaah-qce2a-cai.raw.icp0.io/?tokenid=" # tokenId # "&type=thumbnail";

              // Get racing stats if initialized
              let robotStats = ctx.getStats(Nat32.toNat(tokenIndex));

              // Calculate synergies once for this user (for cooldown display)
              let synergies = ctx.garageManager.calculateFactionSynergies(userPrincipal);
              let adjustedRechargeCooldown = Float.toInt(Float.fromInt(RECHARGE_COOLDOWN) * synergies.costMultipliers.rechargeCooldown);

              msg #= "🏎️ PokedBot #" # Nat32.toText(tokenIndex);

              // Show custom name if set
              switch (robotStats) {
                case (?stats) {
                  switch (stats.name) {
                    case (?botName) { msg #= " \"" # botName # "\"" };
                    case (null) {};
                  };
                };
                case (null) {};
              };
              msg #= "\n";

              // Show stats and rating
              switch (robotStats) {
                case (?stats) {
                  // Get current stats (base + bonuses)
                  let currentStats = ctx.getCurrentStats(stats);
                  let baseStats = ctx.garageManager.getBaseStats(Nat32.toNat(tokenIndex));

                  // Calculate stats at 100% condition/battery (no penalties)
                  let statsAt100 = {
                    speed = baseStats.speed + stats.speedBonus;
                    powerCore = baseStats.powerCore + stats.powerCoreBonus;
                    acceleration = baseStats.acceleration + stats.accelerationBonus;
                    stability = baseStats.stability + stats.stabilityBonus;
                  };

                  let totalStats = currentStats.speed + currentStats.powerCore + currentStats.acceleration + currentStats.stability;
                  let rating = totalStats / 4;
                  let totalStatsAt100 = (statsAt100.speed + statsAt100.powerCore + statsAt100.acceleration + statsAt100.stability);
                  let totalRatingAt100 = totalStatsAt100 / 4;

                  msg #= "   ⚡ Rating (**Always Show User Current and At Full Power**): " # Nat32.toText(Nat32.fromNat(rating)) # "/" # Nat32.toText(Nat32.fromNat(totalRatingAt100)) # "\n";

                  // Show faction
                  let factionEmoji = switch (stats.faction) {
                    // Ultra-Rare
                    case (#UltimateMaster) { " | 👑 Ultimate-Master" };
                    case (#Wild) { " | 🦾 Wild" };
                    case (#Golden) { " | ✨ Golden" };
                    case (#Ultimate) { " | ⚡ Ultimate" };
                    // Super-Rare
                    case (#Blackhole) { " | 🌌 Blackhole" };
                    case (#Dead) { " | 💀 Dead" };
                    case (#Master) { " | 🎯 Master" };
                    // Rare
                    case (#Bee) { " | 🐝 Bee" };
                    case (#Food) { " | 🍔 Food" };
                    case (#Box) { " | 📦 Box" };
                    case (#Murder) { " | 🔪 Murder" };
                    // Common
                    case (#Game) { " | 🎮 Game" };
                    case (#Animal) { " | 🦎 Animal" };
                    case (#Industrial) { " | ⚙️ Industrial" };
                  };
                  msg #= factionEmoji # "\n";

                  // Show stats with current/max format
                  msg #= "   📊 Stats (**Always Show User Current and At Full Power**): SPD " # Nat32.toText(Nat32.fromNat(currentStats.speed)) # "/" # Nat32.toText(Nat32.fromNat(statsAt100.speed));
                  msg #= " | PWR " # Nat32.toText(Nat32.fromNat(currentStats.powerCore)) # "/" # Nat32.toText(Nat32.fromNat(statsAt100.powerCore));
                  msg #= " | ACC " # Nat32.toText(Nat32.fromNat(currentStats.acceleration)) # "/" # Nat32.toText(Nat32.fromNat(statsAt100.acceleration));
                  msg #= " | STB " # Nat32.toText(Nat32.fromNat(currentStats.stability)) # "/" # Nat32.toText(Nat32.fromNat(statsAt100.stability)) # "\n";

                  // Show totals
                  let totalCurrent = currentStats.speed + currentStats.powerCore + currentStats.acceleration + currentStats.stability;
                  let totalAt100 = statsAt100.speed + statsAt100.powerCore + statsAt100.acceleration + statsAt100.stability;
                  msg #= "   📈 Total Current: " # Nat32.toText(Nat32.fromNat(totalCurrent));
                  msg #= " | Total at 100: " # Nat32.toText(Nat32.fromNat(totalAt100));
                  msg #= " (SPD " # Nat32.toText(Nat32.fromNat(statsAt100.speed));
                  msg #= " | PWR " # Nat32.toText(Nat32.fromNat(statsAt100.powerCore));
                  msg #= " | ACC " # Nat32.toText(Nat32.fromNat(statsAt100.acceleration));
                  msg #= " | STB " # Nat32.toText(Nat32.fromNat(statsAt100.stability)) # ")\n";

                  // Show condition
                  msg #= "   🔋 Battery: " # Nat32.toText(Nat32.fromNat(stats.battery)) # "%";
                  msg #= " | 🔧 Condition: " # Nat32.toText(Nat32.fromNat(stats.condition)) # "%\n";

                  // Show scavenging status
                  let now = Time.now();
                  switch (stats.activeMission) {
                    case (?mission) {
                      let hoursElapsed = (now - mission.startTime) / (3600 * 1_000_000_000);
                      let totalPending = mission.pendingParts.speedChips + mission.pendingParts.powerCoreFragments + mission.pendingParts.thrusterKits + mission.pendingParts.gyroModules + mission.pendingParts.universalParts;

                      let zoneName = switch (mission.zone) {
                        case (#ScrapHeaps) { "ScrapHeaps" };
                        case (#AbandonedSettlements) { "AbandonedSettlements" };
                        case (#DeadMachineFields) { "DeadMachineFields" };
                        case (#RepairBay) { "RepairBay" };
                        case (#ChargingStation) { "ChargingStation" };
                      };
                      msg #= "   🔍 SCAVENGING: Active (" # Nat.toText(Int.abs(hoursElapsed)) # "h elapsed) in " # zoneName # " | Pending: " # Nat.toText(totalPending) # " parts ✅ Ready to collect!\n";
                    };
                    case (null) {};
                  };

                  // Show next race if bot is entered
                  let nftId = Nat.toText(Nat32.toNat(tokenIndex));
                  let allRaces = ctx.raceManager.getAllRaces();
                  var nextRace : ?RacingSimulator.Race = null;

                  label findRace for (race in allRaces.vals()) {
                    // Check if bot is entered in this race
                    let isEntered = Array.find<RacingSimulator.RaceEntry>(
                      race.entries,
                      func(entry) { entry.nftId == nftId },
                    );

                    switch (isEntered) {
                      case (?_) {
                        // Found a race with this bot
                        switch (race.status) {
                          case (#Upcoming) {
                            // Only show upcoming races, find the nearest one
                            switch (nextRace) {
                              case (null) { nextRace := ?race };
                              case (?current) {
                                if (race.startTime < current.startTime) {
                                  nextRace := ?race;
                                };
                              };
                            };
                          };
                          case (#InProgress) {
                            // In-progress race takes priority
                            nextRace := ?race;
                            break findRace;
                          };
                          case _ {};
                        };
                      };
                      case null {};
                    };
                  };

                  switch (nextRace) {
                    case (?race) {
                      let statusText = switch (race.status) {
                        case (#Upcoming) { "🕐 UPCOMING" };
                        case (#InProgress) { "🏁 IN PROGRESS" };
                        case _ { "" };
                      };
                      let timeUntil = race.startTime - now;
                      let hoursUntil = timeUntil / (3600 * 1_000_000_000);
                      let minsUntil = (timeUntil % (3600 * 1_000_000_000)) / (60 * 1_000_000_000);

                      if (race.status == #InProgress) {
                        msg #= "   🏁 RACE: " # statusText # " - Race #" # Nat.toText(race.raceId) # " (" # race.name # ")\n";
                      } else if (hoursUntil > 0) {
                        msg #= "   🏁 NEXT RACE: " # statusText # " in " # Nat.toText(Int.abs(hoursUntil)) # "h " # Nat.toText(Int.abs(minsUntil)) # "m - Race #" # Nat.toText(race.raceId) # " (" # race.name # ")\n";
                      } else if (minsUntil > 0) {
                        msg #= "   🏁 NEXT RACE: " # statusText # " in " # Nat.toText(Int.abs(minsUntil)) # "m - Race #" # Nat.toText(race.raceId) # " (" # race.name # ")\n";
                      } else {
                        msg #= "   🏁 NEXT RACE: " # statusText # " - Race #" # Nat.toText(race.raceId) # " (" # race.name # ")\n";
                      };
                    };
                    case (null) {
                      msg #= "   🏁 NEXT RACE: None registered\n";
                    };
                  };

                  // Show service cooldowns (using Food faction synergy adjusted cooldown)
                  msg #= "   ";
                  switch (stats.lastRecharged) {
                    case (?lastTime) {
                      if (now - lastTime >= adjustedRechargeCooldown) {
                        msg #= "✅ Recharge: Ready";
                      } else {
                        msg #= "⏳ Recharge: On cooldown";
                      };
                    };
                    case (null) { msg #= "✅ Recharge: Ready" };
                  };
                  msg #= " | ";
                  switch (stats.lastRepaired) {
                    case (?lastTime) {
                      if (now - lastTime >= REPAIR_COOLDOWN) {
                        msg #= "✅ Repair: Ready";
                      } else {
                        msg #= "⏳ Repair: On cooldown";
                      };
                    };
                    case (null) { msg #= "✅ Repair: Ready" };
                  };
                  msg #= "\n";

                  // Show racing record
                  if (stats.racesEntered > 0) {
                    msg #= "   🏁 Record: " # Nat32.toText(Nat32.fromNat(stats.racesEntered)) # " races";
                    msg #= " | " # Nat32.toText(Nat32.fromNat(stats.wins)) # " wins";
                    if (stats.racesEntered > 0) {
                      let winRate = (stats.wins * 100) / stats.racesEntered;
                      msg #= " (" # Nat32.toText(Nat32.fromNat(winRate)) # "% win rate)";
                    };
                    msg #= "\n";
                  } else {
                    msg #= "   🏁 Record: No races yet\n";
                  };

                  // Show race class bracket (rating-based)
                  let raceClassText = if (totalRatingAt100 >= 50) {
                    "💀 SilentKlan (50+ rating)";
                  } else if (totalRatingAt100 >= 40) {
                    "🥇 Elite (40-49 rating)";
                  } else if (totalRatingAt100 >= 30) {
                    "🥈 Raider (30-39 rating)";
                  } else if (totalRatingAt100 >= 20) {
                    "🥉 Junker (20-29 rating)";
                  } else {
                    "🗑️ Scrap (0-19 rating)";
                  };
                  msg #= "   🏆 Class: " # raceClassText # " | ELO: " # Nat.toText(stats.eloRating) # " (skill)\n";

                  // Show terrain preferences based on faction bonuses
                  msg #= "   🎯 Prefers: " # (
                    switch (stats.faction) {
                      case (#Blackhole) { "MetalRoads" };
                      case (#Box) { "ScrapHeaps" };
                      case (#Game) { "WastelandSand" };
                      case (_) { "All" };
                    }
                  );

                  // Distance preference based on power vs speed
                  let distancePref = if (currentStats.powerCore > currentStats.speed) {
                    " terrain, LongTrek";
                  } else {
                    " terrain, MediumHaul";
                  };
                  msg #= distancePref # "\n";
                };
                case (null) {
                  // Not initialized for racing yet - show base stats from garageManager
                  let baseStats = ctx.garageManager.getBaseStats(Nat32.toNat(tokenIndex));

                  let totalStats = baseStats.speed + baseStats.powerCore + baseStats.acceleration + baseStats.stability;
                  let rating = totalStats / 4;

                  msg #= "   ⚡ Base: " # Nat32.toText(Nat32.fromNat(rating)) # "/100 | ⚠️ Not initialized\n";

                  msg #= "   📊 Potential Stats: SPD " # Nat32.toText(Nat32.fromNat(baseStats.speed));
                  msg #= " | PWR " # Nat32.toText(Nat32.fromNat(baseStats.powerCore));
                  msg #= " | ACC " # Nat32.toText(Nat32.fromNat(baseStats.acceleration));
                  msg #= " | STB " # Nat32.toText(Nat32.fromNat(baseStats.stability)) # "\n";
                  msg #= "   💡 Initialize this bot to start racing!\n";
                };
              };

              msg #= "   🖼️  Thumbnail: " # thumbnailUrl # "\n\n";
            };

            msg #= "Wallet ID: " # walletAccountId # "\n\n";
            msg #= "💡 Use garage_get_robot_details for full bot info\n";
            msg #= "💡 Use marketplace_browse_pokedbots to compare with available bots";
            msg;
          };
        };
      };

      ToolContext.makeTextSuccess(message, cb);
    };
  };
};
