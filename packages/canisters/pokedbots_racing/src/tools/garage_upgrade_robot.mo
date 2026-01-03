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
import TimerTool "mo:timer-tool";
import ExtIntegration "../ExtIntegration";
import WastelandFlavor "WastelandFlavor";

module {
  let PART_PRICE_E8S = 1_000_000 : Nat; // 0.01 ICP per part (100 parts = 1 ICP)
  let TRANSFER_FEE = 10000 : Nat;
  let UPGRADE_DURATION : Int = 43200000000000; // 12 hours in nanoseconds

  public func config() : McpTypes.Tool = {
    name = "garage_upgrade_robot";
    title = ?"Upgrade Robot";
    description = ?"Start a 12-hour V2 upgrade session with RNG mechanics. Types: Velocity (+Speed), PowerCore (+Power Core), Thruster (+Acceleration), Gyro (+Stability).\n\n**V2 MECHANICS:**\n• Dynamic ICP costs: 0.5 + (stat/40)² × tier premium (0.7-3.5×)\n• Success rates PER STAT: 85% (first upgrade) smoothly decreasing to 1% (at 15 upgrades), then stays at 1%\n• Each stat tracked independently: Speed, Power Core, Acceleration, and Stability each get their own success rate curve\n• Pity system: +5% per consecutive fail (max +25%), persists across deploys\n• Double lottery: 15% → 2% chance for +2 points (disabled after +15 successful upgrades per stat)\n• 50% refund on failure (ICP or parts returned based on payment method)\n• Pay with ICP or parts (100 parts = 1 ICP)\n\nUse garage_get_robot_details to see exact costs/rates. For full V2 mechanics, use help_get_compendium tool.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_index", Json.obj([("type", Json.str("number")), ("description", Json.str("The token index of the PokedBot"))])), ("upgrade_type", Json.obj([("type", Json.str("string")), ("enum", Json.arr([Json.str("Velocity"), Json.str("PowerCore"), Json.str("Thruster"), Json.str("Gyro")])), ("description", Json.str("The type of upgrade"))])), ("payment_method", Json.obj([("type", Json.str("string")), ("enum", Json.arr([Json.str("parts"), Json.str("icp")])), ("description", Json.str("Payment method: parts (from inventory) or icp (ICRC-2 approval required)"))]))])),
      ("required", Json.arr([Json.str("token_index"), Json.str("upgrade_type")])),
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
        case (null) { return ToolContext.makeError("Missing token_index", cb) };
        case (?idx) { idx };
      };

      let upgradeTypeStr = switch (Result.toOption(Json.getAsText(_args, "upgrade_type"))) {
        case (null) { return ToolContext.makeError("Missing upgrade_type", cb) };
        case (?t) { t };
      };

      let paymentMethod = switch (Result.toOption(Json.getAsText(_args, "payment_method"))) {
        case (null) { "parts" }; // Default to parts (earned from racing)
        case (?method) { method };
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

      // Upgrades can be started at any battery/condition level
      let now = Time.now();
      switch (racingStats.upgradeEndsAt) {
        case (?endsAt) {
          if (endsAt > now) {
            return ToolContext.makeError("Upgrade already in progress", cb);
          };
        };
        case (null) {};
      };

      // Parse upgrade type
      let upgradeType : PokedBotsGarage.UpgradeType = switch (upgradeTypeStr) {
        case "Velocity" { #Velocity };
        case "PowerCore" { #PowerCore };
        case "Thruster" { #Thruster };
        case "Gyro" { #Gyro };
        // Fallback for lowercase
        case "velocity" { #Velocity };
        case "power_core" { #PowerCore };
        case "thruster" { #Thruster };
        case "gyro" { #Gyro };
        case _ { #Velocity }; // default
      };

      // Get current stats for cost calculation (V2)
      let currentStats = ctx.garageManager.getCurrentStats(racingStats);
      let overallRating = ctx.garageManager.calculateOverallRating(racingStats);

      // Get base stat and current stat value for this upgrade type
      let (baseStat, currentStatValue) = switch (upgradeType) {
        case (#Velocity) {
          (currentStats.speed - racingStats.speedBonus, currentStats.speed);
        };
        case (#PowerCore) {
          (currentStats.powerCore - racingStats.powerCoreBonus, currentStats.powerCore);
        };
        case (#Thruster) {
          (currentStats.acceleration - racingStats.accelerationBonus, currentStats.acceleration);
        };
        case (#Gyro) {
          (currentStats.stability - racingStats.stabilityBonus, currentStats.stability);
        };
      };

      // Calculate cost using V2 formula with Game faction synergy
      let synergies = ctx.garageManager.calculateFactionSynergies(user);
      let costE8s = ctx.garageManager.calculateUpgradeCostV2(baseStat, currentStatValue, overallRating, synergies.costMultipliers.upgradeCost);
      let totalCost = costE8s + TRANSFER_FEE;

      // Determine part type (for parts payment option)
      let partType : PokedBotsGarage.PartType = switch (upgradeType) {
        case (#Velocity) { #SpeedChip };
        case (#PowerCore) { #PowerCoreFragment };
        case (#Thruster) { #ThrusterKit };
        case (#Gyro) { #GyroModule };
      };

      // Handle payment
      var partsUsed : Nat = 0;
      if (paymentMethod == "parts") {
        // Legacy parts system: 100 parts = 1 ICP
        let partsNeeded = (costE8s / PART_PRICE_E8S) + 1; // Round up
        if (not ctx.garageManager.removeParts(user, partType, partsNeeded)) {
          return ToolContext.makeError("Insufficient parts. Needed: " # Nat.toText(partsNeeded) # " " # debug_show (partType) # " (Universal Parts can substitute). Race on appropriate terrain or go scavenging to earn them!", cb);
        };
        partsUsed := partsNeeded;
      } else {
        // ICP payment
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

        try {
          let transferResult = await icpLedger.icrc2_transfer_from({
            from = { owner = user; subaccount = null };
            to = { owner = ctx.canisterPrincipal; subaccount = null };
            amount = totalCost;
            fee = null;
            memo = null;
            created_at_time = null;
            spender_subaccount = null;
          });

          switch (transferResult) {
            case (#Err(_)) {
              return ToolContext.makeError("Payment failed - check ICRC-2 allowance. Cost: " # Nat.toText(totalCost) # " e8s (" # Float.format(#fix 2, Float.fromInt(totalCost) / 100_000_000.0) # " ICP)", cb);
            };
            case (#Ok(_)) {};
          };
        } catch (e) {
          return ToolContext.makeError("Payment failed: " # Error.message(e), cb);
        };
      };

      // Start upgrade
      let endsAt = now + UPGRADE_DURATION;

      // Get flavor text for this upgrade and faction
      let upgradeFlavor = WastelandFlavor.getUpgradeFlavor(upgradeType, racingStats.faction);

      // Calculate attempt number and success rate with pity
      let attemptNumber = currentStatValue - baseStat;
      let pityCounter = ctx.garageManager.getPityCounter(tokenIndex);
      let successRate = ctx.garageManager.calculateSuccessRate(attemptNumber, pityCounter);

      // Track the upgrade session with V2 parameters (including payment method for refunds)
      ctx.garageManager.startUpgrade(tokenIndex, upgradeType, now, endsAt, pityCounter, costE8s, paymentMethod, partsUsed);

      // Schedule timer to complete the upgrade
      let actionId = ctx.timerTool.setActionSync<system>(
        Int.abs(endsAt),
        {
          actionType = "upgrade_complete";
          params = to_candid (tokenIndex);
        },
      );

      let updatedStats = {
        racingStats with
        upgradeEndsAt = ?endsAt;
      };

      ctx.garageManager.updateStats(tokenIndex, updatedStats);

      // Calculate double point chance
      let doubleChance = Float.max(2.0, 15.0 - (Float.fromInt(attemptNumber) * 0.87));

      let costIcp = Float.fromInt(costE8s) / 100_000_000.0;
      let pityText = if (pityCounter > 0) {
        " (+" # Nat.toText(pityCounter * 5) # "% pity bonus!)";
      } else { "" };

      let response = Json.obj([
        ("token_index", Json.int(tokenIndex)),
        ("upgrade_type", Json.str(upgradeFlavor)),
        ("duration_hours", Json.int(12)),
        ("cost_icp", Json.str(Float.format(#fix 2, costIcp))),
        ("attempt_number", Json.int(attemptNumber + 1)),
        ("success_rate", Json.str(Float.format(#fix 1, successRate) # "%" # pityText)),
        ("double_chance", Json.str(Float.format(#fix 1, doubleChance) # "%")),
        ("message", Json.str("🔧 Upgrade in progress! Success rate: " # Float.format(#fix 1, successRate) # "%" # pityText # ". If successful, " # Float.format(#fix 1, doubleChance) # "% chance for +2 stat points! Check back in 12 hours. Note: Success rate smoothly decreases from 85% to 1% over 15 upgrades per stat.")),
      ]);

      ToolContext.makeSuccess(response, cb);
    };
  };
};
