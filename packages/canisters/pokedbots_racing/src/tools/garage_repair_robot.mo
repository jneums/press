import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Error "mo:base/Error";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import PokedBotsGarage "../PokedBotsGarage";
import IcpLedger "../IcpLedger";
import ExtIntegration "../ExtIntegration";

module {
  let REPAIR_COST = 5000000 : Nat; // 0.05 ICP
  let TRANSFER_FEE = 10000 : Nat;
  let REPAIR_COOLDOWN : Int = 10800000000000; // 3 hours in nanoseconds

  public func config() : McpTypes.Tool = {
    name = "garage_repair_robot";
    title = ?"Repair Robot Condition";
    description = ?"Repair a robot to restore condition. Costs 0.05 ICP + 0.0001 ICP transfer fee. Restores 25 Condition. Cooldown: 3 hours.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_index", Json.obj([("type", Json.str("number")), ("description", Json.str("The token index of the PokedBot to repair"))]))])),
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
      let user = switch (_auth) {
        case (null) {
          return ToolContext.makeError("Authentication required", cb);
        };
        case (?auth) { auth.principal };
      };

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

      // Get racing stats
      let racingStats = switch (ctx.garageManager.getStats(tokenIndex)) {
        case (null) {
          return ToolContext.makeError("This PokedBot is not initialized for racing. Use garage_initialize_pokedbot first.", cb);
        };
        case (?stats) { stats };
      };

      // Check if bot is currently scavenging
      switch (racingStats.activeMission) {
        case (?mission) {
          return ToolContext.makeError("Cannot repair while bot is on a scavenging mission. Complete the mission first.", cb);
        };
        case (null) {};
      };

      let now = Time.now();
      switch (racingStats.lastRepaired) {
        case (?lastTime) {
          if (now - lastTime < REPAIR_COOLDOWN) {
            return ToolContext.makeError("Repair cooldown active", cb);
          };
        };
        case (null) {};
      };

      // Get ICP Ledger canister ID from context
      let ledgerId = switch (ctx.icpLedgerCanisterId()) {
        case (?id) { id };
        case (null) {
          return ToolContext.makeError("ICP Ledger not configured", cb);
        };
      };

      let icpLedger = actor (Principal.toText(ledgerId)) : actor {
        icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
      };

      // Apply Industrial faction synergy discount to repair cost
      let synergies = ctx.garageManager.calculateFactionSynergies(user);
      let repairCostWithSynergy = Nat.max(1_000_000, Int.abs(Float.toInt(Float.fromInt(REPAIR_COST) * synergies.costMultipliers.repairCost)));
      let totalCost = repairCostWithSynergy + TRANSFER_FEE;

      try {
        let transferResult = await icpLedger.icrc2_transfer_from({
          from = { owner = user; subaccount = null };
          to = { owner = ctx.canisterPrincipal; subaccount = null };
          amount = totalCost;
          fee = ?TRANSFER_FEE;
          memo = null;
          created_at_time = null;
          spender_subaccount = null;
        });

        switch (transferResult) {
          case (#Err(error)) {
            return ToolContext.makeError("Payment failed", cb);
          };
          case (#Ok(blockIndex)) {
            let conditionRestored = Nat.min(25, 100 - racingStats.condition);

            let updatedStats = {
              racingStats with
              condition = Nat.min(100, racingStats.condition + 25);
              lastRepaired = ?now;
            };

            ctx.garageManager.updateStats(tokenIndex, updatedStats);

            let costIcp = Float.fromInt(repairCostWithSynergy) / 100_000_000.0;
            let response = Json.obj([
              ("token_index", Json.int(tokenIndex)),
              ("action", Json.str("Repair Condition")),
              ("condition_restored", Json.int(conditionRestored)),
              ("new_condition", Json.int(updatedStats.condition)),
              ("cost_icp", Json.str(Float.toText(costIcp))),
              ("message", Json.str("🔧 Repairs complete. Condition at " # Nat.toText(updatedStats.condition) # "%")),
            ]);

            ToolContext.makeSuccess(response, cb);
          };
        };
      } catch (e) {
        return ToolContext.makeError("Payment failed: " # Error.message(e), cb);
      };
    };
  };
};
