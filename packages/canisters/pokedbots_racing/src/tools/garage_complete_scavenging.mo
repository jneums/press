import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Array "mo:base/Array";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import PokedBotsGarage "../PokedBotsGarage";
import ExtIntegration "../ExtIntegration";

module {
  public func config() : McpTypes.Tool = {
    name = "garage_complete_scavenging";
    title = ?"Complete Scavenging Mission";
    description = ?"Retrieve your PokedBot from scavenging and collect accumulated rewards. Can be called anytime.\n\n**Rewards:**\n• Parts distributed across multiple types (Speed Chips, Power Core Fragments, Thruster Kits, Gyro Modules, Universal Parts)\n• All zones have same 40% Universal / 60% Specialized split (harder zones give MORE total parts)\n• All pending parts awarded to inventory\n• World buff chance: 3.75% per 15-min check, strength scales with time\n• Faction-specific bonuses and specials applied\n\n**RETRIEVE ON DEMAND:**\n• Retrieve anytime - no waiting required\n• Rewards accumulate every 15 minutes automatically\n• Ends mission and stops accumulation\n• Returns total hours elapsed and parts collected";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_index", Json.obj([("type", Json.str("number")), ("description", Json.str("The token index of the PokedBot to retrieve from scavenging"))]))])),
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

      // Parse arguments
      let tokenIndex = switch (Result.toOption(Json.getAsNat(_args, "token_index"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: token_index", cb);
        };
        case (?idx) { idx };
      };

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

      // Complete mission (forces final accumulation)
      let garage = ctx.garageManager;
      let now = Time.now();

      switch (garage.completeScavengingMissionV2(tokenIndex, now)) {
        case (#err(e)) {
          return ToolContext.makeError(e, cb);
        };
        case (#ok(result)) {
          // Cancel all pending scavenge_accumulate timers for this bot
          let scavengeTimers = ctx.timerTool.getActionsByFilter(#ByType("scavenge_accumulate"));
          for ((timerId, timerAction) in scavengeTimers.vals()) {
            let timerTokenOpt : ?Nat = from_candid (timerAction.params);
            switch (timerTokenOpt) {
              case (?timerToken) {
                if (timerToken == tokenIndex) {
                  ignore ctx.timerTool.cancelActionsByIds<system>([timerId.id]);
                };
              };
              case (null) {};
            };
          };
          // Build parts breakdown
          let partsBreakdown = "Speed Chips: " # Nat.toText(result.speedChips) #
          ", Power Cells: " # Nat.toText(result.powerCoreFragments) #
          ", Thruster Kits: " # Nat.toText(result.thrusterKits) #
          ", Gyro Units: " # Nat.toText(result.gyroModules) #
          ", Universal: " # Nat.toText(result.universalParts);

          // Format hours elapsed
          let hoursElapsed = result.hoursOut;
          let hoursText = if (hoursElapsed < 1) {
            "< 1 hour";
          } else {
            Nat.toText(hoursElapsed) # " hours";
          };

          let response = Json.obj([
            ("token_index", Json.int(tokenIndex)),
            ("hours_elapsed", Json.int(result.hoursOut)),
            ("total_parts", Json.int(result.totalParts)),
            ("speed_chips", Json.int(result.speedChips)),
            ("power_core_fragments", Json.int(result.powerCoreFragments)),
            ("thruster_kits", Json.int(result.thrusterKits)),
            ("gyro_modules", Json.int(result.gyroModules)),
            ("universal_parts", Json.int(result.universalParts)),
            ("parts_breakdown", Json.str(partsBreakdown)),
            ("message", Json.str("✅ Bot retrieved! Time out: " # hoursText # ". Collected " # Nat.toText(result.totalParts) # " parts: " # partsBreakdown)),
          ]);

          ToolContext.makeSuccess(response, cb);
        };
      };
    };
  };
};
