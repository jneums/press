import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Error "mo:base/Error";
import Float "mo:base/Float";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import PokedBotsGarage "../PokedBotsGarage";
import IcpLedger "../IcpLedger";
import ExtIntegration "../ExtIntegration";
import WastelandFlavor "WastelandFlavor";

module {
  let TRANSFER_FEE = 10000 : Nat;

  public func config() : McpTypes.Tool = {
    name = "garage_cancel_upgrade";
    title = ?"Cancel Upgrade";
    description = ?"Cancel an in-progress upgrade session and receive a full refund. The timer progress is lost as punishment, but you get back 100% of what you paid (ICP or parts). Use this if you need to race urgently or made a mistake.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_index", Json.obj([("type", Json.str("number")), ("description", Json.str("The token index of the PokedBot with the active upgrade to cancel"))]))])),
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
        case (null) { return ToolContext.makeError("Missing token_index", cb) };
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
          return ToolContext.makeError("This PokedBot is not initialized for racing.", cb);
        };
        case (?stats) { stats };
      };

      // Check for active upgrade
      let upgradeSession = switch (ctx.garageManager.getActiveUpgrade(tokenIndex)) {
        case (null) {
          return ToolContext.makeError("No active upgrade to cancel.", cb);
        };
        case (?session) { session };
      };

      // Process refund based on payment method
      let refundText = if (upgradeSession.paymentMethod == "icp") {
        // Refund ICP (full amount)
        if (upgradeSession.costPaid > TRANSFER_FEE) {
          // Get ICP Ledger canister ID from context
          let ledgerId = switch (ctx.icpLedgerCanisterId()) {
            case (?id) { id };
            case (null) {
              return ToolContext.makeError("ICP Ledger not configured", cb);
            };
          };

          // Create actor reference to ICP Ledger
          let icpLedger = actor (Principal.toText(ledgerId)) : actor {
            icrc1_transfer : shared IcpLedger.TransferArg -> async IcpLedger.Result;
          };

          let refundAmount = upgradeSession.costPaid - TRANSFER_FEE; // Deduct one transfer fee
          let transferResult = try {
            await icpLedger.icrc1_transfer({
              from_subaccount = null;
              to = { owner = user; subaccount = null };
              amount = refundAmount;
              fee = ?TRANSFER_FEE;
              memo = null;
              created_at_time = null;
            });
          } catch (e) {
            return ToolContext.makeError("Failed to process ICP refund: " # Error.message(e), cb);
          };

          switch (transferResult) {
            case (#Err(e)) {
              return ToolContext.makeError("ICP refund failed: " # debug_show (e), cb);
            };
            case (#Ok(_)) {
              let icpAmount = Float.fromInt(Int.abs(refundAmount)) / 100_000_000.0;
              "Refunded " # Float.toText(icpAmount) # " ICP (minus transfer fee)";
            };
          };
        } else {
          "No ICP to refund (amount too small)";
        };
      } else {
        // Refund parts of the correct type based on upgrade type
        let partType : PokedBotsGarage.PartType = switch (upgradeSession.upgradeType) {
          case (#Velocity) { #SpeedChip };
          case (#PowerCore) { #PowerCoreFragment };
          case (#Thruster) { #ThrusterKit };
          case (#Gyro) { #GyroModule };
        };
        ctx.garageManager.addParts(user, partType, upgradeSession.partsUsed);
        "Refunded " # Nat.toText(upgradeSession.partsUsed) # " parts to your inventory";
      };

      // Clear the upgrade session and update bot stats
      ctx.garageManager.clearUpgrade(tokenIndex);
      ctx.garageManager.setUpgradeEndsAt(tokenIndex, null);

      // Reset cooldowns so user can immediately recharge/repair after canceling
      // The punishment is the lost time on the upgrade timer, not being stuck on cooldowns
      let updatedStats = {
        racingStats with
        lastRecharged = null;
        lastRepaired = null;
      };
      ctx.garageManager.updateStats(tokenIndex, updatedStats);

      let upgradeTypeName = switch (upgradeSession.upgradeType) {
        case (#Velocity) { "Velocity" };
        case (#PowerCore) { "Power Core" };
        case (#Thruster) { "Thruster" };
        case (#Gyro) { "Gyro" };
      };

      let botName = switch (racingStats.name) {
        case (?name) { name };
        case (null) { "Bot #" # Nat.toText(tokenIndex) };
      };

      let response = WastelandFlavor.cancelUpgrade(
        botName,
        upgradeTypeName,
        refundText,
      );

      return cb(#ok({ content = [#text({ text = response; annotations = null })]; isError = false; structuredContent = null }));
    };
  };
};
