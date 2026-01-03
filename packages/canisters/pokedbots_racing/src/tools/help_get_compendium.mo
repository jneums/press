import Result "mo:base/Result";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";

module {
  public func config() : McpTypes.Tool = {
    name = "help_get_compendium";
    title = ?"PokedBots Racing Compendium";
    description = ?"Get comprehensive reference information about factions, mechanics, and systems. Call this once at the start of conversations to understand game mechanics.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("section", Json.obj([("type", Json.str("string")), ("enum", Json.arr([Json.str("all"), Json.str("core"), Json.str("factions"), Json.str("battery"), Json.str("terrain"), Json.str("upgrades"), Json.str("scavenging")])), ("description", Json.str("Which section to retrieve (default: all)"))]))])),
      ("required", Json.arr([])),
    ]);
    outputSchema = null;
  };

  public func handle(ctx : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {

      let section = switch (Result.toOption(Json.getAsText(_args, "section"))) {
        case (null) { "all" };
        case (?s) { s };
      };

      let coreConceptsInfo = "**CORE CONCEPTS:**\n\n**CORE RACING STATS (The 4 Stats That Matter):**\n• Speed - Top speed capability\n• Power Core - Energy efficiency (reduces battery drain)\n• Acceleration - Launch power\n• Stability - Handling and durability\n\n**Bot Rating = Average of all 4 stats**\n• Rating increases by +1 for every +4 total stat points\n• Example: 20/20/20/20 = Rating 20\n• Specialization: Can push one stat high (e.g., 60/20/20/20 = Rating 30)\n• Balanced: Spread evenly (e.g., 30/30/30/30 = Rating 30)\n\n**RACE CLASS SYSTEM (CRITICAL - READ CAREFULLY):**\n• **Rating determines which races you can enter** (class/bracket system):\n  - Rating 50+ → SilentKlan races\n  - Rating 40-49 → Elite races\n  - Rating 30-39 → Raider races\n  - Rating 20-29 → Junker races\n  - Rating 0-19 → Scrap races\n• **ELO is separate** - only used for matchmaking WITHIN your rating-based class\n• **To enter Elite races:** You need Rating 40-49 (NOT ELO 40-49)\n• **Example:** A bot with Rating 45 and ELO 1200 can enter Elite races (rating determines eligibility)\n\n**Resources (NOT stats, consumed/restored):**\n• Battery - Fuel for racing, restored via recharge (0.1 ICP, 6hr cooldown)\n• Condition - Wear/tear, restored via repair (0.05 ICP, 3hr cooldown)\n• Low battery/condition hurt performance but don't affect rating\n• Battery/condition only impact race performance temporarily";

      let factionInfo = "**FACTION BONUSES:**\n\n**Ultra-Rare Factions:**\n• UltimateMaster: +15% all stats, -25% to -40% decay rates\n• Wild: +20% Accel, -10% Stability\n• Golden: +15% all stats when condition ≥90% (pristine maintenance required)\n• Ultimate: +12% Speed/Accel\n\n**Super-Rare Factions:**\n• Blackhole: +12% on MetalRoads terrain, world buffs grant +3 Speed/Accel BONUS on top of regular buff\n• Dead: +10% PowerCore, +8% Stability, -15% decay\n• Master: +12% Speed, +8% PowerCore, every 10th scavenge mission doubles parts\n\n**Rare Factions:**\n• Bee: +10% Acceleration\n• Food: +8% condition recovery\n• Box: +10% on ScrapHeaps terrain, 5% chance to triple scavenging parts\n• Murder: +8% Speed/Accel\n\n**Common Factions:**\n• Game: +8% on WastelandSand terrain, +10 parts every 5th scavenge\n• Animal: +6% balanced all stats\n• Industrial: +5% PowerCore/Stability";

      let batteryInfo = "**BATTERY MECHANICS (aka 'Energy'):**\n\n**Power Core = Energy Efficiency:**\nHigher Power Core reduces battery drain logarithmically:\n• powerCore=20: 70% drain\n• powerCore=40: 52% drain\n• powerCore=100: 30% drain (3.3x more races per battery)\n\n**BATTERY PENALTIES (affects Speed/Acceleration):**\n• 80-100%: No penalty (1.0x)\n• 50-80%: -0% to -25% (0.75x-1.0x linear)\n• 25-50%: -25% to -50% (0.50x-0.75x) ← 29% = ~46% reduction!\n• 10-25%: -50% to -75% (0.25x-0.50x)\n• 0-10%: -75% to -90% (0.10x-0.25x) resurrection sickness\n\n**Recharge:** 0.1 ICP, restores 75 battery, 6hr cooldown\n\n**OVERCHARGE MECHANIC:**\n• Formula: (100 - battery) × 0.75 × [0.5 + condition/200 + random(-0.2, +0.2)]\n• High condition = reliable. Low condition = RNG wildcard\n• Consumed in next race:\n  - Speed/Accel: +0.3% per 1% overcharge (max +22.5% at 75%)\n  - Stability/PowerCore: -0.2% per 1% overcharge (max -15%)\n• Strategy: Low battery + high condition = consistent big boost";

      let terrainInfo = "**TERRAIN BONUSES:**\n\n**Preferred Terrain:** +5% all stats when racing on bot's preferred terrain (derived from NFT background color)\n\n**Faction Terrain Bonuses (stack with preferred):**\n• Blackhole: +12% on MetalRoads\n• Golden: +15% all stats when condition ≥90%\n• Box: +10% on ScrapHeaps\n• Game: +8% on WastelandSand\n\n**Race Terrain Effects:**\n• ScrapHeaps: 1.0x battery drain, 1.0-1.5x condition wear\n• WastelandSand: 1.1x battery drain, 1.1-1.5x condition wear\n• MetalRoads: 1.2x battery drain, 1.2-1.5x condition wear";

      let upgradeInfo = "**UPGRADE SYSTEM V2 (Gacha-Style RNG):**\n\n**Payment Methods (Choose Either):**\n• **ICP Payment:** Direct payment via ICRC-2 approval, instant processing\n• **Parts Payment:** Use parts from inventory (earned via racing/scavenging)\n  - Speed Chips → Velocity upgrades\n  - Power Core Fragments → PowerCore upgrades\n  - Thruster Kits → Thruster upgrades\n  - Gyro Modules → Gyro upgrades\n  - Universal Parts → Can substitute for ANY type\n• **Conversion Rate:** 100 parts = 1 ICP equivalent\n\n**Upgrade Cost Scaling:**\n• Formula: baseCost = 0.5 + (currentStat/40)² × [0.5 + (rating/40)^1.5]\n• Costs increase with BOTH current stat value AND bot rating\n• Higher individual stat = exponentially more expensive\n• Same rating gain costs MUCH less when spreading across stats\n• Example for +1 rating (+4 total stat points):\n  - Balanced (20→21 on 4 stats): ~2.8 ICP total\n  - Specialized (50→54 on 1 stat): ~12+ ICP total\n• Premium scales smoothly with rating (no harsh breakpoints):\n  - Rating 20: 0.86× premium (~0.43 ICP base)\n  - Rating 40: 1.5× premium (~0.75 ICP base)\n  - Rating 60: 2.37× premium (~1.19 ICP base)\n  - Rating 80: 3.36× premium (~1.68 ICP base)\n  - Rating 100: 4.48× premium (~2.24 ICP base)\n\n**Success Rates (RNG-Based, PER STAT):**\n• Each stat tracked independently (Speed, Power Core, Acceleration, Stability)\n• Smooth curve: 85% (first upgrade) → 1% (at 15 upgrades), then stays at 1%\n• Formula: 85% - (upgradeCount × 5.6%), minimum 1%\n• Examples:\n  - 0 upgrades: 85.0%\n  - 5 upgrades: 57.0%\n  - 10 upgrades: 29.0%\n  - 15 upgrades: 1.0%\n  - 16+ upgrades: 1.0% (soft cap)\n\n**Pity System:**\n• +5% success per consecutive failure (max +25%)\n• Resets on any success\n• Can boost late-game 1% → 26% after 5 fails\n\n**Double Point Lottery:**\n• 15% → 2% chance (upgrades 0-15), then 0%\n• Awards +2 stat points instead of +1\n• Disabled completely after +15 upgrades per stat\n• Creates exciting 'jackpot' moments\n\n**50% Refund on Failure (Both Payment Methods):**\n• ICP: 50% refunded automatically via prize distribution\n• Parts: 50% returned directly to inventory\n• Reduces financial risk for both payment types\n• Refund matches payment method used\n\n**Duration:** 12 hours (can race during upgrade)";

      let scavengingInfo = "**SCAVENGING SYSTEM:**\n\n**Mission Types:**\n• ShortExpedition (5h): 15-35 parts, 10 battery\n• DeepSalvage (11h): 40-80 parts, 20 battery\n• WastelandExpedition (23h): 100-200 parts, 40 battery\n\n**Zones & Part Distribution:**\n• ScrapHeaps: Safe (1.0x multipliers, 40% universal parts)\n• AbandonedSettlements: Moderate (1.4x parts, 1.1x battery, 1.15x condition, 25% universal)\n• DeadMachineFields: Dangerous (2.0x parts, 1.2x battery, 1.3x condition, 10% universal)\n\n**Part Types:** Speed Chips, Power Core Fragments, Thruster Kits, Gyro Modules, Universal Parts\n\n**STAT-BASED BONUSES:**\n• Power Core (Energy Efficiency):\n  - 80+: -20% battery cost\n  - 50-79: -10% battery cost\n  - <50: Normal cost\n• Condition (Consistency):\n  - 80+: Tight variance (90-110%, ±10%)\n  - 50-79: Normal variance (80-120%, ±20%)\n  - <50: Wide variance (70-130%, ±30% risky/swingy)\n• Stability (Durability in Dangerous Zones):\n  - 70+ in DeadMachineFields: -25% condition loss\n  - Otherwise: Normal condition loss\n\n**World Buff Chance (RARE - ~4% per hour):**\n• 1% per 15-min accumulation check (up to 1.6% with max Acceleration)\n• NOT awarded on completion (prevents spam abuse)\n• Buffs: <3h: +2 speed | 3-8h: +3 speed, +2 accel | 8h+: +4 speed, +3 accel, +2 power\n• Expires in 48h if unused\n• Almost impossible to get in under 1 hour\n\n**Faction Bonuses (Parts Multipliers):**\n• UltimateMaster: 1.20x all zones, -30% battery, 15% double parts, +20 battery return, +15% Universal Parts (scavenging)\n• Golden: 15% chance to double parts, +30% Power Core Fragments (scavenging)\n• Ultimate: 1.15x all zones, -15% mission time, +15% Universal Parts (scavenging)\n• Wild: 1.25x WastelandSand, 2x world buff potency (50% proc chance), -40% condition loss, +30% Speed Chips (scavenging)\n• Blackhole: 1.10x all zones, world buffs grant +3 Speed/Accel bonus ON TOP of regular buff, +50% condition damage, +30% Power Core Fragments (scavenging)\n• Dead: 1.40x DeadMachineFields (1.10x others), -50% condition loss, +15% Universal Parts (scavenging)\n• Master: 1.12x all zones, -25% battery, every 10th mission doubles parts, +15% Universal Parts (scavenging)\n• Bee: 1.08x AbandonedSettlements, +10% on 23h, shared buffs if 2+ Bee bots, +30% Speed Chips (scavenging)\n• Food: 1.12x ScrapHeaps/Settlements, -20% battery, +30% world buff strength, +15% Universal Parts (scavenging)\n• Box: 1.05x all zones, 5% chance to triple parts, +30% Gyro Modules (scavenging)\n• Murder: 1.15x DeadMachineFields, +20% condition damage, +15% Universal Parts (scavenging)\n• Game: 1.0x base, +10 parts every 5th mission, +30% Thruster Kits (scavenging)\n• Animal: 1.08x WastelandSand, -15% condition loss on 11h/23h, buffs last 2 races, +30% Thruster Kits (scavenging)\n• Industrial: 1.05x all zones, -10% battery, reduced variance (90-110% instead of 80-120%), +30% Gyro Modules (scavenging)\n\n**Scavenging Part Specializations:**\n• Speed Specialists (Bee, Wild): +30% more Speed Chips\n• Power Specialists (Blackhole, Golden): +30% more Power Core Fragments\n• Acceleration Specialists (Game, Animal): +30% more Thruster Kits\n• Stability Specialists (Industrial, Box): +30% more Gyro Modules\n• Balanced Factions (Dead, Master, Murder, Food, UltimateMaster, Ultimate): +15% more Universal Parts";

      let content = if (section == "all") {
        coreConceptsInfo # "\n\n" # factionInfo # "\n\n" # batteryInfo # "\n\n" # terrainInfo # "\n\n" # upgradeInfo # "\n\n" # scavengingInfo;
      } else if (section == "core") {
        coreConceptsInfo;
      } else if (section == "factions") {
        factionInfo;
      } else if (section == "battery") {
        batteryInfo;
      } else if (section == "terrain") {
        terrainInfo;
      } else if (section == "upgrades") {
        upgradeInfo;
      } else if (section == "scavenging") {
        scavengingInfo;
      } else {
        "Invalid section";
      };

      let response = Json.obj([
        ("section", Json.str(section)),
        ("content", Json.str(content)),
      ]);

      ToolContext.makeSuccess(response, cb);
    };
  };
};
