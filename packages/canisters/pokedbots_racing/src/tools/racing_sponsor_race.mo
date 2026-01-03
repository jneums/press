import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Error "mo:base/Error";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import IcpLedger "../IcpLedger";

module {
  let TRANSFER_FEE = 10000 : Nat;

  public func config() : McpTypes.Tool = {
    name = "racing_sponsor_race";
    title = ?"Sponsor Race";
    description = ?"Sponsor a wasteland race by adding ICP to its prize pool. Your sponsorship will be publicly displayed on the race, and winners will know who supported the event. Only Upcoming races can be sponsored.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("race_id", Json.obj([("type", Json.str("number")), ("description", Json.str("The race ID to sponsor"))])), ("amount_icp", Json.obj([("type", Json.str("number")), ("description", Json.str("Amount of ICP to contribute (e.g., 1.5 for 1.5 ICP). Minimum 0.1 ICP."))])), ("message", Json.obj([("type", Json.str("string")), ("description", Json.str("Optional sponsor message to display (max 100 chars)"))]))])),
      ("required", Json.arr([Json.str("race_id"), Json.str("amount_icp")])),
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

      // Parse arguments
      let raceId = switch (Result.toOption(Json.getAsNat(_args, "race_id"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: race_id", cb);
        };
        case (?id) { id };
      };

      let amountIcp = switch (Result.toOption(Json.getAsFloat(_args, "amount_icp"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: amount_icp", cb);
        };
        case (?amt) { amt };
      };

      // Convert ICP to e8s (1 ICP = 100,000,000 e8s)
      let amountE8s = Int.abs(Float.toInt(amountIcp * 100_000_000.0));

      // Minimum 0.1 ICP (10,000,000 e8s)
      if (amountE8s < 10_000_000) {
        return ToolContext.makeError("Minimum sponsorship is 0.1 ICP", cb);
      };

      // Parse optional message
      let message = switch (Result.toOption(Json.getAsText(_args, "message"))) {
        case (null) { null };
        case (?msg) {
          if (Text.size(msg) > 100) {
            return ToolContext.makeError("Sponsor message must be 100 characters or less", cb);
          };
          ?msg;
        };
      };

      // Get race
      let race = switch (ctx.raceManager.getRace(raceId)) {
        case (null) {
          return ToolContext.makeError("Race not found", cb);
        };
        case (?r) { r };
      };

      // Only allow sponsoring upcoming races
      switch (race.status) {
        case (#Upcoming) {};
        case (#InProgress) {
          return ToolContext.makeError("Cannot sponsor a race that has already started", cb);
        };
        case (#Completed) {
          return ToolContext.makeError("Cannot sponsor a completed race", cb);
        };
        case (#Cancelled) {
          return ToolContext.makeError("Cannot sponsor a cancelled race", cb);
        };
      };

      // Process payment using ICRC-2 transfer_from
      let ledgerCanisterId = switch (ctx.icpLedgerCanisterId()) {
        case (?id) { id };
        case (null) {
          return ToolContext.makeError("ICP Ledger not configured", cb);
        };
      };
      let icpLedger = actor (Principal.toText(ledgerCanisterId)) : actor {
        icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
      };

      try {
        let transferResult = await icpLedger.icrc2_transfer_from({
          from = { owner = user; subaccount = null };
          to = { owner = ctx.canisterPrincipal; subaccount = null };
          amount = amountE8s;
          fee = null;
          memo = null;
          created_at_time = null;
          spender_subaccount = null;
        });

        switch (transferResult) {
          case (#Err(error)) {
            let errorMsg = switch (error) {
              case (#InsufficientAllowance { allowance }) {
                "Insufficient ICRC-2 allowance. Approved: " # Nat.toText(allowance) # " e8s, needed: " # Nat.toText(amountE8s + TRANSFER_FEE) # " e8s";
              };
              case (#InsufficientFunds { balance }) {
                "Insufficient ICP balance: " # Nat.toText(balance) # " e8s";
              };
              case (_) { "Payment failed" };
            };
            return ToolContext.makeError(errorMsg, cb);
          };
          case (#Ok(_blockIndex)) {
            // Payment successful, add sponsor
            switch (ctx.raceManager.addSponsor(raceId, user, amountE8s, message)) {
              case (?updatedRace) {
                let now = Time.now();
                let timeUntilStart = updatedRace.startTime - now;
                let hoursUntilStart = timeUntilStart / 3_600_000_000_000;

                let classText = switch (updatedRace.raceClass) {
                  case (#Scrap) { "Scrap" };
                  case (#Junker) { "Junker" };
                  case (#Raider) { "Raider" };
                  case (#Elite) { "Elite" };
                  case (#SilentKlan) { "Silent Klan Invitational" };
                };

                // Calculate sponsor tier
                let tier = if (amountE8s >= 500_000_000) {
                  "🏆 PLATINUM";
                } else if (amountE8s >= 200_000_000) {
                  "🥇 GOLD";
                } else if (amountE8s >= 50_000_000) {
                  "🥈 SILVER";
                } else {
                  "🥉 BRONZE";
                };

                let response = Json.obj([
                  ("message", Json.str("💰 **SPONSORSHIP CONFIRMED**")),
                  ("sponsor_tier", Json.str(tier)),
                  ("race_id", Json.int(raceId)),
                  ("race_name", Json.str(updatedRace.name)),
                  ("race_class", Json.str(classText)),
                  ("your_contribution_icp", Json.str(Text.concat(Nat.toText(amountE8s / 100_000_000), "." # Nat.toText((amountE8s % 100_000_000) / 1_000_000)))),
                  ("new_prize_pool_icp", Json.str(Text.concat(Nat.toText((updatedRace.prizePool + updatedRace.platformBonus) / 100_000_000), "." # Nat.toText(((updatedRace.prizePool + updatedRace.platformBonus) % 100_000_000) / 1_000_000)))),
                  ("total_sponsors", Json.int(updatedRace.sponsors.size())),
                  ("entries_so_far", Json.int(updatedRace.entries.size())),
                  ("max_entries", Json.int(updatedRace.maxEntries)),
                  ("starts_in_hours", Json.int(hoursUntilStart)),
                  ("wasteland_message", Json.str("🌟 Your generosity echoes across the wasteland. The racers will remember this.")),
                ]);

                ToolContext.makeSuccess(response, cb);
              };
              case (null) {
                return ToolContext.makeError("Failed to add sponsorship", cb);
              };
            };
          };
        };
      } catch (e) {
        return ToolContext.makeError("Payment failed: " # Error.message(e), cb);
      };
    };
  };
};
