import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Error "mo:base/Error";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import PokedBotsGarage "../PokedBotsGarage";
import ExtIntegration "../ExtIntegration";
import IcpLedger "../IcpLedger";
import UsernameValidator "../UsernameValidator";

module {
  // Registration cost: 0.1 ICP + 0.0001 ICP fee
  let REGISTRATION_COST = 10000000 : Nat; // 0.1 ICP in e8s
  let TRANSFER_FEE = 10000 : Nat; // 0.0001 ICP in e8s

  public func config() : McpTypes.Tool = {
    name = "garage_initialize_pokedbot";
    title = ?"Register PokedBot Racing License";
    description = ?"Register your PokedBot for a wasteland racing license (0.1 ICP registration fee, one-time). Reveals faction and racing stats based on NFT traits.\n\n**RACE CLASS BRACKETS (Determined by RATING only):**\nRating = average of 4 max stats (Speed/PowerCore/Accel/Stability)\n• 50+ = SilentKlan\n• 40-49 = Elite  \n• 30-39 = Raider\n• 20-29 = Junker\n• 0-19 = Scrap\n\n**IMPORTANT:** Race class eligibility is based ONLY on rating (stat average), NOT ELO.\nELO (1100-1900) is assigned for matchmaking within your class but does NOT determine which races you can enter.\n\nRequired before entering races. Requires ICRC-2 approval. Use help_get_compendium tool for faction bonuses.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_index", Json.obj([("type", Json.str("number")), ("description", Json.str("The token index of the PokedBot to register for racing (e.g., 4079)"))])), ("name", Json.obj([("type", Json.str("string")), ("description", Json.str("Optional: Custom name for your bot (max 30 characters). Can be changed later by re-registering."))]))])),
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
        case (?idx) { idx };
      };

      // Parse optional name
      let customName = switch (Result.toOption(Json.getAsText(_args, "name"))) {
        case (null) { null };
        case (?name) {
          // Validate username
          switch (UsernameValidator.validateUsername(name)) {
            case (?error) {
              return ToolContext.makeError(error, cb);
            };
            case (null) { ?name };
          };
        };
      };

      let tokenIndexNat32 = Nat32.fromNat(tokenIndex);

      // Check if already registered
      switch (ctx.garageManager.getStats(tokenIndex)) {
        case (?existingStats) {
          // If already initialized by the same user, allow renaming
          if (Principal.equal(existingStats.ownerPrincipal, user)) {
            // Update just the name if provided
            switch (customName) {
              case (?newName) {
                let _ = ctx.garageManager.updateBotName(tokenIndex, ?newName);
                return ToolContext.makeTextSuccess("✅ Bot renamed to: " # newName, cb);
              };
              case (null) {
                return ToolContext.makeError("This PokedBot already has a racing license. Use garage_get_robot_details to view its stats, or provide a 'name' to rename it.", cb);
              };
            };
          };
          // If owned by someone else, verify new ownership and update owner
          // (This handles the transfer case - preserve all stats except owner)

          // Verify ownership via EXT canister - check user's wallet
          let walletAccountId = ExtIntegration.principalToAccountIdentifier(user, null);

          let ownerResult = try {
            await ctx.extCanister.bearer(ExtIntegration.encodeTokenIdentifier(tokenIndexNat32, ctx.extCanisterId));
          } catch (_) {
            return ToolContext.makeError("Failed to verify ownership", cb);
          };

          switch (ownerResult) {
            case (#err(_)) {
              return ToolContext.makeError("This PokedBot does not exist.", cb);
            };
            case (#ok(currentOwner)) {
              if (currentOwner != walletAccountId) {
                return ToolContext.makeError("You do not own this PokedBot. It must be in your wallet to register.", cb);
              };
            };
          };

          // Update owner (transfer case) - preserve all other stats
          let _ = ctx.garageManager.updateBotOwner(tokenIndex, user);

          return ToolContext.makeTextSuccess("🔄 **OWNERSHIP UPDATED**\n\nPokedBot #" # Nat.toText(tokenIndex) # " has been registered to your account. All racing stats and upgrades have been preserved.", cb);
        };
        case (null) {
          // Not yet initialized - proceed with first-time initialization
        };
      };

      // Verify ownership via EXT canister before initializing - check user's wallet
      let walletAccountId = ExtIntegration.principalToAccountIdentifier(user, null);

      let ownerResult = try {
        await ctx.extCanister.bearer(ExtIntegration.encodeTokenIdentifier(tokenIndexNat32, ctx.extCanisterId));
      } catch (_) {
        return ToolContext.makeError("Failed to verify ownership", cb);
      };

      switch (ownerResult) {
        case (#err(_)) {
          return ToolContext.makeError("This PokedBot does not exist.", cb);
        };
        case (#ok(currentOwner)) {
          if (currentOwner != walletAccountId) {
            return ToolContext.makeError("You do not own this PokedBot. It must be in your wallet to initialize.", cb);
          };
        };
      };

      // Get ICP Ledger canister ID from context
      let ledgerId = switch (ctx.icpLedgerCanisterId()) {
        case (?id) { id };
        case (null) {
          return ToolContext.makeError("ICP Ledger not configured", cb);
        };
      };

      // Pull payment via ICRC-2 (0.1 ICP registration fee)
      let icpLedger = actor (Principal.toText(ledgerId)) : actor {
        icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
      };
      let totalCost = REGISTRATION_COST + TRANSFER_FEE;

      let blockIndex = try {
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
            let errorMsg = switch (error) {
              case (#InsufficientFunds { balance }) {
                "Insufficient funds. Balance: " # Nat.toText(balance) # " e8s, Required: " # Nat.toText(totalCost) # " e8s";
              };
              case (#InsufficientAllowance { allowance }) {
                "Insufficient ICRC-2 allowance. Current: " # Nat.toText(allowance) # " e8s, Required: " # Nat.toText(totalCost) # " e8s. Please approve the canister first.";
              };
              case (#BadFee { expected_fee }) {
                "Bad fee. Expected: " # Nat.toText(expected_fee) # " e8s";
              };
              case _ { "Transfer failed" };
            };
            return ToolContext.makeError(errorMsg, cb);
          };
          case (#Ok(blockIdx)) { blockIdx };
        };
      } catch (e) {
        return ToolContext.makeError("Payment failed: " # Error.message(e), cb);
      };

      // Initialize racing stats (faction will be derived from metadata automatically)
      let racingStats = ctx.garageManager.initializeBot(
        tokenIndex,
        user,
        null, // Let it auto-derive faction from metadata
        customName,
      );

      // Get faction for display
      let faction = racingStats.faction;

      let factionText = switch (faction) {
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

      let factionMessage = switch (faction) {
        // Ultra-Rare
        case (#UltimateMaster) {
          "🏆 Racing License Approved: ULTIMATE-MASTER TYPE! The rarest classification. Apex predator of the wasteland. Legendary status confirmed.";
        };
        case (#Wild) {
          "🦾 Racing License Approved: WILD TYPE! Deranged systems from the 2453 solar flare. Unpredictable chaos engine. Ultra-rare classification.";
        };
        case (#Golden) {
          "✨ Racing License Approved: GOLDEN TYPE! Superior golden-forged chassis. Delta City's elite. Ultra-rare classification.";
        };
        case (#Ultimate) {
          "⚡ Racing License Approved: ULTIMATE TYPE! Peak performance design. Advanced tech superiority. Ultra-rare classification.";
        };
        // Super-Rare
        case (#Blackhole) {
          "🌌 Racing License Approved: BLACKHOLE TYPE! Reality-warping MetalRoads specialist. Super-rare void tech classification.";
        };
        case (#Dead) {
          "💀 Racing License Approved: DEAD TYPE! Resurrected from the scrap tombs. Eerie resilience. Super-rare classification.";
        };
        case (#Master) {
          "🎯 Racing License Approved: MASTER TYPE! Mysterious Europa Base 7 connection. Elite performance. Super-rare classification.";
        };
        // Rare
        case (#Bee) {
          "🐝 Racing License Approved: BEE TYPE! Hive-mind acceleration systems. Swarm intelligence rare-class.";
        };
        case (#Food) {
          "🍔 Racing License Approved: FOOD TYPE! Built from ancient fast-food machinery. Surprisingly durable rare-class.";
        };
        case (#Box) {
          "📦 Racing License Approved: BOX TYPE! Scrap heap master. Recycled excellence. Rare-class classification.";
        };
        case (#Murder) {
          "🔪 Racing License Approved: MURDER TYPE! Combat-grade aggression core. Built for destruction. Rare-class classification.";
        };
        // Common
        case (#Game) {
          "🎮 Racing License Approved: GAME TYPE! Entertainment tech heritage. WastelandSand specialist. Common classification.";
        };
        case (#Animal) {
          "🦎 Racing License Approved: ANIMAL TYPE! Organic-synthetic hybrid design. Balanced performance. Common classification.";
        };
        case (#Industrial) {
          "⚙️ Racing License Approved: INDUSTRIAL TYPE! Heavy machinery foundation. Reliable workhorse. Common classification.";
        };
      };

      // Get current stats (base + bonuses)
      let currentStats = ctx.garageManager.getCurrentStats(racingStats);

      // Get faction mechanics explanation
      let factionMechanics = switch (racingStats.faction) {
        case (#UltimateMaster) {
          "MECHANICS: +15% all stats, 2x upgrade bonus chance, -40% decay. Supreme performance.";
        };
        case (#Wild) {
          "MECHANICS: +20% Acceleration, -10% Stability, +30% decay. High-risk chaos engine.";
        };
        case (#Golden) {
          "MECHANICS: +15% all stats when condition ≥90%. Requires pristine maintenance.";
        };
        case (#Ultimate) {
          "MECHANICS: +12% Speed, +12% Acceleration. Peak performance baseline.";
        };
        case (#Blackhole) {
          "MECHANICS: +12% on MetalRoads terrain. 'Void Energy' = superior highway efficiency. Power Core reduces battery drain.";
        };
        case (#Dead) {
          "MECHANICS: +10% Power Core, +8% Stability. Necro-resilience improves energy efficiency.";
        };
        case (#Master) {
          "MECHANICS: +12% Speed, +8% Power Core. Precision engineering from Europa Base 7.";
        };
        case (#Bee) {
          "MECHANICS: +10% Acceleration. Hive-mind swarm optimization.";
        };
        case (#Food) {
          "MECHANICS: +8% Condition recovery. Energy-efficient sustenance systems.";
        };
        case (#Box) {
          "MECHANICS: +10% on ScrapHeaps terrain. Recycled parts excel in rough conditions.";
        };
        case (#Murder) {
          "MECHANICS: +8% Speed, +8% Acceleration. Combat-grade aggression core.";
        };
        case (#Game) {
          "MECHANICS: +8% on WastelandSand terrain. Entertainment tech optimized for sand.";
        };
        case (#Animal) {
          "MECHANICS: +6% balanced stats. Organic-synthetic hybrid stability.";
        };
        case (#Industrial) {
          "MECHANICS: +5% Power Core, +5% Stability. Reliable workhorse design.";
        };
      };

      // Build JSON response
      let response = Json.obj([
        ("token_index", Json.int(tokenIndex)),
        ("name", switch (customName) { case (?n) { Json.str(n) }; case (null) { Json.nullable() } }),
        ("faction", Json.str(factionText)),
        ("payment", Json.obj([("amount", Json.str("0.1 ICP")), ("fee", Json.str("0.0001 ICP")), ("total", Json.str("0.1001 ICP")), ("block_index", Json.int(blockIndex))])),
        ("stats", Json.obj([("speed", Json.int(currentStats.speed)), ("power_core", Json.int(currentStats.powerCore)), ("acceleration", Json.int(currentStats.acceleration)), ("stability", Json.int(currentStats.stability))])),
        ("starting_elo", Json.int(racingStats.eloRating)),
        ("battery", Json.int(racingStats.battery)),
        ("condition", Json.int(racingStats.condition)),
        ("status", Json.str("Racing license registered! Ready for wasteland competition.")),
        ("license_status", Json.str("REGISTERED")),
        ("faction_message", Json.str(factionMessage)),
        ("faction_mechanics", Json.str(factionMechanics)),
        ("energy_note", Json.str("POWER CORE STAT = ENERGY EFFICIENCY: Higher Power Core reduces battery drain during races. At PC=100: only 30% normal battery consumption (3.3x more races per charge).")),
      ]);

      ToolContext.makeSuccess(response, cb);
    };
  };
};
