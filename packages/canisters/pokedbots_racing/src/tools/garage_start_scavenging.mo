import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Time "mo:base/Time";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import PokedBotsGarage "../PokedBotsGarage";
import ExtIntegration "../ExtIntegration";

module {
  public func config() : McpTypes.Tool = {
    name = "garage_start_scavenging";
    title = ?"Start Scavenging Mission";
    description = ?"Send your PokedBot out into the wasteland to scavenge for parts. No ICP cost - only battery consumption.\n\n**SCAVENGING MODES:**\n• **Continuous (no duration)**: Accumulates rewards every 15 minutes automatically. Retrieve bot and collect rewards on demand with garage_complete_scavenging.\n• **Timed (duration_minutes)**: Set a specific duration (e.g., 60, 120, 180 minutes). Bot auto-returns when time expires.\n• Bot dies at 0 battery OR 0 condition → loses ALL pending rewards\n\n**Accumulation Rates (per 15 minutes):**\n• Base: 2.5 parts, 5.0 battery, 2.0 condition\n• Each part is individually rolled based on zone percentages AND faction bonuses\n• Rates affected by zone multipliers, stat bonuses, and faction bonuses\n• Speed stat increases parts yield (up to +10% at 100 Speed)\n• Power Core reduces battery drain (up to -75% at 100 Power Core, exponential scaling)\n• Stability reduces condition loss in dangerous zones (up to -75% at 100 Stability, exponential scaling)\n• Acceleration increases world buff chance (up to +60% at 100 Acceleration)\n\n**Zones (ask user to choose):**\n• ScrapHeaps: Safe (1.0x parts, 1.0x battery, 1.0x condition) → 40% Universal Parts, 60% specialized (15% each)\n  - Per hour: ~10 parts, ~20 battery, ~8 condition (before bonuses)\n• AbandonedSettlements: Moderate (1.6x parts, 2.0x battery, 2.0x condition) → 40% Universal Parts, 60% specialized (15% each)\n  - Per hour: ~16 parts, ~40 battery, ~16 condition (before bonuses)\n• DeadMachineFields: Dangerous (2.5x parts, 3.5x battery, 3.5x condition) → 40% Universal Parts, 60% specialized (15% each)\n  - Per hour: ~25 parts, ~70 battery, ~28 condition (before bonuses)\n• RepairBay: Maintenance (0x parts, 2.0x battery, RESTORES +12-18 condition/hour) → No parts earned, but restores condition over time\n  - Per hour: ~0 parts, ~40 battery, +12-18 condition (with bonuses)\n  - Bypasses 12h repair cooldown, good for bots under 50% condition\n• ChargingStation: Free Charging (0x parts, RESTORES +1 battery per tick) → No parts earned, but restores battery over time\n  - Per 15 min: +1 battery (4 per hour, 25 hours for full charge from 0)\n  - Bypasses 6h recharge cooldown and 0.1 ICP cost, good for patient players\n  - Can't race or scavenge while charging, but FREE alternative to instant recharge\n\n**Faction Bonuses (NEW!):**\n• **Speed Specialists** (Bee, Wild): +30% Speed Chips\n• **Power Specialists** (Blackhole, Golden): +30% Power Core Fragments\n• **Acceleration Specialists** (Game, Animal): +30% Thruster Kits\n• **Stability Specialists** (Industrial, Box): +30% Gyro Modules\n• **Balanced Factions** (Dead, Master, Murder, Food, UltimateMaster, Ultimate): +15% Universal Parts\n• Other factions: no bonus\n\n**Part Types Explained:**\n• **Universal Parts** = Wildcard, use for ANY upgrade (Speed/PowerCore/Accel/Stability)\n• **Specialized Parts** = Locked to specific upgrade (Speed Chips only for Speed, Power Core Fragments only for Power Core, Thruster Kits only for Acceleration, Gyro Modules only for Stability)\n• **Faction-Modified Distribution** = Each part is rolled individually - faction bonuses increase chances of getting your faction's specialty parts\n\n**Strategy:** All zones have same 40% Universal / 60% Specialized split. Harder zones = MORE total parts (1.6x → 2.5x) but higher battery/condition costs. Faction choice now matters - specialize in parts your faction excels at finding, trade with others for parts you need. Higher stats improve efficiency dramatically with exponential scaling. Use ChargingStation to save ICP if you have time to wait!\n\n**World Buff:**\n• Base 2.0% chance per 15-minute check (up to 3.2% with max Acceleration) = ~8% per hour\n• ONLY earned during accumulation checks (not on completion to prevent spam abuse)\n• ONLY available in scavenging zones (ScrapHeaps, AbandonedSettlements, DeadMachineFields)\n• NOT available in maintenance zones (RepairBay, ChargingStation)\n• Strength scales with hours elapsed (2-4 stat points)\n• Buffs expire in 48 hours if not used\n• Blackhole faction gets +3 Speed/Accel BONUS on top of regular world buff\n• ⚠️ NERFED: Much rarer now, almost impossible to get in under 1 hour\n\n**If user doesn't specify zone, ASK them which zone they prefer before calling this tool!**";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_index", Json.obj([("type", Json.str("number")), ("description", Json.str("The token index of the PokedBot to send scavenging"))])), ("zone", Json.obj([("type", Json.str("string")), ("enum", Json.arr([Json.str("ScrapHeaps"), Json.str("AbandonedSettlements"), Json.str("DeadMachineFields"), Json.str("RepairBay"), Json.str("ChargingStation")])), ("description", Json.str("Zone difficulty and rewards. RepairBay restores condition, ChargingStation restores battery (both free)."))])), ("duration_minutes", Json.obj([("type", Json.str("number")), ("description", Json.str("Optional: Duration in minutes for the scavenging mission (e.g., 60, 120, 180). If not specified, bot will scavenge continuously until manually retrieved."))]))])),
      ("required", Json.arr([Json.str("token_index"), Json.str("zone")])),
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

      // Parse arguments
      let tokenIndex = switch (Result.toOption(Json.getAsNat(_args, "token_index"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: token_index", cb);
        };
        case (?idx) { idx };
      };

      let zoneStr = switch (Result.toOption(Json.getAsText(_args, "zone"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: zone", cb);
        };
        case (?val) { val };
      };

      // Parse zone
      let zone : PokedBotsGarage.ScavengingZone = switch (zoneStr) {
        case ("ScrapHeaps") { #ScrapHeaps };
        case ("AbandonedSettlements") { #AbandonedSettlements };
        case ("DeadMachineFields") { #DeadMachineFields };
        case ("RepairBay") { #RepairBay };
        case ("ChargingStation") { #ChargingStation };
        case (_) {
          return ToolContext.makeError("Invalid zone. Must be ScrapHeaps, AbandonedSettlements, DeadMachineFields, RepairBay, or ChargingStation", cb);
        };
      };

      // Parse optional duration
      let durationMinutes = Result.toOption(Json.getAsNat(_args, "duration_minutes"));

      // Verify ownership via EXT (source of truth) - check user's wallet
      let walletAccountId = ExtIntegration.principalToAccountIdentifier(user, null);
      let ownerResult = try {
        await ctx.extCanister.bearer(ExtIntegration.encodeTokenIdentifier(Nat32.fromNat(tokenIndex), ctx.extCanisterId));
      } catch (_) {
        return ToolContext.makeError("Failed to verify ownership", cb);
      };
      switch (ownerResult) {
        case (#err(_)) {
          return ToolContext.makeError("This PokedBot does not exist.", cb);
        };
        case (#ok(currentOwner)) {
          if (currentOwner != walletAccountId) {
            return ToolContext.makeError("You do not own this PokedBot.", cb);
          };
        };
      };

      // Get bot stats
      let garage = ctx.garageManager;
      switch (garage.getStats(tokenIndex)) {
        case (null) {
          return ToolContext.makeError("Bot not initialized for racing. Use garage_initialize_pokedbot first.", cb);
        };
        case (?botStats) {
          // Check if already on a mission
          switch (botStats.activeMission) {
            case (?_) {
              return ToolContext.makeError("Bot is already on a scavenging mission", cb);
            };
            case (null) {};
          };

          // Start mission with optional duration
          let now = Time.now();
          switch (garage.startScavengingMission(tokenIndex, zone, now, durationMinutes)) {
            case (#err(e)) {
              return ToolContext.makeError(e, cb);
            };
            case (#ok(_)) {
              // Schedule first accumulation in 15 minutes
              let next15Min = now + (15 * 60 * 1_000_000_000);
              ignore ctx.timerTool.setActionSync<system>(
                Int.abs(next15Min),
                {
                  actionType = "scavenge_accumulate";
                  params = to_candid (tokenIndex);
                },
              );

              let zoneDesc = switch (zone) {
                case (#ScrapHeaps) { "Scrap Heaps (Safe)" };
                case (#AbandonedSettlements) {
                  "Abandoned Settlements (Moderate)";
                };
                case (#DeadMachineFields) { "Dead Machine Fields (Dangerous)" };
                case (#RepairBay) { "Repair Bay (Maintenance)" };
                case (#ChargingStation) { "Charging Station (Free Charging)" };
              };

              let (modeDesc, modeMsg) = switch (durationMinutes) {
                case (null) {
                  ("Continuous", "Retrieve bot anytime with garage_complete_scavenging.");
                };
                case (?duration) {
                  ("Timed (" # Nat.toText(duration) # " minutes)", "Bot will auto-return after " # Nat.toText(duration) # " minutes.");
                };
              };

              let response = Json.obj([
                ("token_index", Json.int(tokenIndex)),
                ("zone", Json.str(zoneDesc)),
                ("mode", Json.str(modeDesc)),
                ("accumulation_interval", Json.str("15 minutes")),
                ("base_rates", Json.str("5.0 parts (randomized distribution), 2.0 battery, 1.0 condition per 15min")),
                ("stat_bonuses", Json.str("Speed: up to +10% parts | Power Core: up to -20% battery | Stability: up to -25% condition | Accel: up to +60% buff chance")),
                ("world_buff_chance", Json.str("2%-3.2% per check (scales with Acceleration stat)")),
                ("message", Json.str("🔧 Bot sent out to scavenge in " # zoneDesc # ". Rewards accumulate every 15 minutes with randomized part distribution. " # modeMsg # " WARNING: Bot dies at 0 battery OR condition = lose ALL pending rewards!")),
              ]);

              ToolContext.makeSuccess(response, cb);
            };
          };
        };
      };
    };
  };
};
