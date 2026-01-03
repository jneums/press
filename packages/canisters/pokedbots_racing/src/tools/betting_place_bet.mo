import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Error "mo:base/Error";
import Blob "mo:base/Blob";
import Array "mo:base/Array";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import BettingTypes "../BettingTypes";
import IcpLedger "../IcpLedger";

module {
  public func config() : McpTypes.Tool = {
    name = "betting_place_bet";
    title = ?"Place Bet on Race";
    description = ?"Place a bet on a PokedBot in an upcoming race. Bets are paid via ICRC-2 approval (same approval as race entry fees). You can bet on Win (1st place), Place (top 3), or Show (top 5).\n\n**BET TYPES:**\n• Win: Bot finishes 1st place (higher payout, higher risk)\n• Place: Bot finishes in top 3 (medium payout, medium risk)\n• Show: Bot finishes in top 5 (lower payout, lower risk)\n\n**BETTING LIMITS:**\n• Minimum bet: 0.1 ICP per bet\n• Maximum bet: 100 ICP per bet\n• Maximum total: 100 ICP per race (across all bet types)\n\n**BETTING WINDOW:**\n• Opens when race registration closes (1 hour before race)\n• Closes when race starts\n• Check pool status before betting\n\n**PAYOUT SYSTEM:**\n• Pari-mutuel: Pool-based betting with proportional payouts\n• 10% rake: 8% added to race prize pool, 2% to platform\n• Automatic payouts: Winners receive ICP automatically after race settlement\n• Live odds: View current odds with betting_get_pool_info\n\n**REQUIREMENTS:**\n• Must approve racing canister for ICP transfers (ICRC-2)\n• Same approval covers both racing entry fees and betting\n• Bot must be entered in the race\n• Pool must be open for betting";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      (
        "properties",
        Json.obj([
          ("race_id", Json.obj([("type", Json.str("number")), ("description", Json.str("The race ID to bet on"))])),
          ("token_index", Json.obj([("type", Json.str("number")), ("description", Json.str("The bot's token index to bet on"))])),
          ("bet_type", Json.obj([("type", Json.str("string")), ("enum", Json.arr([Json.str("Win"), Json.str("Place"), Json.str("Show")])), ("description", Json.str("Bet type: Win (1st), Place (top 3), or Show (top 5)"))])),
          ("amount_icp", Json.obj([("type", Json.str("number")), ("description", Json.str("Amount to bet in ICP (e.g., 0.5 for 0.5 ICP). Min 0.1, max 100."))])),
        ]),
      ),
      ("required", Json.arr([Json.str("race_id"), Json.str("token_index"), Json.str("bet_type"), Json.str("amount_icp")])),
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

      let tokenIndex = switch (Result.toOption(Json.getAsNat(_args, "token_index"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: token_index", cb);
        };
        case (?idx) { idx };
      };

      let betTypeText = switch (Result.toOption(Json.getAsText(_args, "bet_type"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: bet_type", cb);
        };
        case (?t) { t };
      };

      let amountIcp = switch (Result.toOption(Json.getAsFloat(_args, "amount_icp"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: amount_icp", cb);
        };
        case (?a) { a };
      };

      // Parse bet type
      let betType : BettingTypes.BetType = switch (betTypeText) {
        case ("Win") { #Win };
        case ("Place") { #Place };
        case ("Show") { #Show };
        case (_) {
          return ToolContext.makeError("Invalid bet_type. Must be Win, Place, or Show", cb);
        };
      };

      // Convert ICP to e8s
      if (amountIcp < 0.1) {
        return ToolContext.makeError("Minimum bet is 0.1 ICP", cb);
      };
      if (amountIcp > 100.0) {
        return ToolContext.makeError("Maximum bet is 100 ICP", cb);
      };

      let amountE8s = Int.abs(Float.toInt(amountIcp * 100_000_000.0));

      // Validate amount limits BEFORE any transfer
      if (amountE8s < 10_000_000) {
        // 0.1 ICP minimum
        return ToolContext.makeError("Minimum bet is 0.1 ICP", cb);
      };
      if (amountE8s > 10_000_000_000) {
        // 100 ICP maximum
        return ToolContext.makeError("Maximum bet is 100 ICP", cb);
      };

      // Get betting pool
      let pool = switch (ctx.bettingManager.getPool(raceId)) {
        case (null) {
          return ToolContext.makeError("Betting pool not found for this race. Pool opens when registration closes.", cb);
        };
        case (?p) { p };
      };

      // Check pool status
      switch (pool.status) {
        case (#Pending) {
          return ToolContext.makeError("Betting has not opened yet. Opens when race registration closes.", cb);
        };
        case (#Closed) {
          return ToolContext.makeError("Betting is closed. Race has started.", cb);
        };
        case (#Settled) {
          return ToolContext.makeError("Race is already completed.", cb);
        };
        case (#Cancelled) {
          return ToolContext.makeError("Race was cancelled.", cb);
        };
        case (#Open) {}; // Continue
      };

      // Check timing
      let now = Time.now();
      if (now < pool.bettingOpensAt) {
        return ToolContext.makeError("Betting has not opened yet", cb);
      };
      if (now >= pool.bettingClosesAt) {
        return ToolContext.makeError("Betting has closed", cb);
      };

      // Check bot is in race
      let botInRace = Array.find<Nat>(pool.entrants, func(idx) { idx == tokenIndex });
      if (botInRace == null) {
        return ToolContext.makeError("Bot #" # Nat.toText(tokenIndex) # " is not entered in this race", cb);
      };

      // Check user's total bets on this race don't exceed limit
      let userBets = ctx.bettingManager.getUserBets(user, 1000); // Get all user bets
      var totalBetOnRace : Nat = 0;
      for (bet in userBets.vals()) {
        if (bet.raceId == raceId) {
          totalBetOnRace += bet.amount;
        };
      };
      if (totalBetOnRace + amountE8s > 10_000_000_000) {
        // 100 ICP total per race
        return ToolContext.makeError("Total bets on this race cannot exceed 100 ICP. Current total: " # Float.toText(Float.fromInt(totalBetOnRace) / 100_000_000.0) # " ICP", cb);
      };

      // ALL VALIDATIONS PASSED - Now execute the transfer

      // Get ICP ledger canister ID
      let icpLedgerCanisterId = switch (ctx.icpLedgerCanisterId()) {
        case (null) {
          return ToolContext.makeError("ICP Ledger not configured", cb);
        };
        case (?id) { id };
      };

      // Create ICP Ledger actor
      let icpLedger = actor (Principal.toText(icpLedgerCanisterId)) : actor {
        icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
      };

      // Calculate pool subaccount for transfer destination
      let poolSubaccount = ctx.bettingManager.getPoolSubaccount(raceId);

      // Execute ICRC-2 transfer_from to move ICP from user to pool subaccount
      let transferResult = try {
        await icpLedger.icrc2_transfer_from({
          spender_subaccount = null;
          from = {
            owner = user;
            subaccount = null;
          };
          to = {
            owner = ctx.canisterPrincipal;
            subaccount = ?poolSubaccount;
          };
          amount = amountE8s;
          fee = null;
          memo = null;
          created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
        });
      } catch (e) {
        return ToolContext.makeError("Transfer failed: " # Error.message(e), cb);
      };

      switch (transferResult) {
        case (#Err(error)) {
          let errorMsg = switch (error) {
            case (#InsufficientFunds { balance }) {
              "Insufficient funds. Balance: " # Nat.toText(balance) # " e8s";
            };
            case (#InsufficientAllowance { allowance }) {
              "Insufficient allowance. Current allowance: " # Nat.toText(allowance) # " e8s. Please approve the racing canister for ICP transfers first.";
            };
            case (#BadFee { expected_fee }) {
              "Bad fee. Expected: " # Nat.toText(expected_fee) # " e8s";
            };
            case (#BadBurn { min_burn_amount }) {
              "Bad burn amount. Min: " # Nat.toText(min_burn_amount) # " e8s";
            };
            case (#Duplicate { duplicate_of }) {
              "Duplicate transfer detected";
            };
            case (#CreatedInFuture { ledger_time }) {
              "Created in future. Ledger time: " # Nat64.toText(ledger_time);
            };
            case (#TooOld) {
              "Transfer too old";
            };
            case (#TemporarilyUnavailable) {
              "Ledger temporarily unavailable. Please try again.";
            };
            case (#GenericError { error_code; message }) {
              "Transfer error: " # message;
            };
          };
          return ToolContext.makeError(errorMsg, cb);
        };
        case (#Ok(blockIndex)) {
          // Transfer successful, now record the bet
          switch (ctx.bettingManager.placeBet(user, raceId, tokenIndex, betType, amountE8s)) {
            case (#err(msg)) {
              // Bet placement failed - funds are in pool but bet not recorded
              // Admin will need to handle this edge case
              return ToolContext.makeError("Bet placement failed: " # msg # " (Transfer succeeded but bet not recorded - contact support)", cb);
            };
            case (#ok(betId)) {
              // Success! Calculate current odds for display
              let odds = ctx.bettingManager.calculateAllOdds(raceId);

              let botOdds = switch (Array.find<BettingTypes.Odds>(odds, func(o) { o.tokenIndex == tokenIndex })) {
                case (?o) {
                  switch (betType) {
                    case (#Win) { o.winOdds };
                    case (#Place) { o.placeOdds };
                    case (#Show) { o.showOdds };
                  };
                };
                case null { 1.0 }; // Default odds if not found
              };

              let response = Json.obj([
                ("success", Json.bool(true)),
                ("bet_id", Json.int(betId)),
                ("race_id", Json.int(raceId)),
                ("token_index", Json.int(tokenIndex)),
                ("bet_type", Json.str(betTypeText)),
                ("amount_icp", Json.str(Float.format(#fix 2, amountIcp))),
                ("amount_e8s", Json.int(amountE8s)),
                ("current_odds", Json.str(Float.format(#fix 2, botOdds))),
                ("potential_payout_icp", Json.str(Float.format(#fix 2, amountIcp * botOdds))),
                ("block_index", Json.int(blockIndex)),
                ("message", Json.str("Bet placed successfully! Your bet will be settled automatically when the race completes. Current odds: " # Float.toText(botOdds) # "x")),
              ]);

              ToolContext.makeSuccess(response, cb);
            };
          };
        };
      };
    };
  };
};
