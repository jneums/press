import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Text "mo:base/Text";
import Array "mo:base/Array";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import BettingTypes "../BettingTypes";

module {

  public func config() : McpTypes.Tool = {
    name = "betting_get_my_bets";
    title = ?"Get My Betting History";
    description = ?"View your betting history including active bets, settled bets, and performance stats.\n\n**INFORMATION PROVIDED:**\n• All your bets (active and settled)\n• Bet status (Pending, Won, Lost, Refunded)\n• Actual payouts for won bets\n• Return on investment (ROI) for each bet\n• Total performance metrics\n\n**BET STATUSES:**\n• Pending: Race hasn't started yet, bet is active\n• Active: Race in progress\n• Won: Bot finished in winning position, payout issued\n• Lost: Bot didn't finish in winning position\n• Refunded: Race cancelled or special circumstances\n\n**USE CASES:**\n• Track active bets\n• Review past performance\n• Calculate total profit/loss\n• See which bet types work best for you";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      (
        "properties",
        Json.obj([
          ("limit", Json.obj([("type", Json.str("number")), ("description", Json.str("Maximum number of bets to return (default 20, max 100)"))])),
        ]),
      ),
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

      let user = switch (_auth) {
        case (null) {
          return ToolContext.makeError("Authentication required", cb);
        };
        case (?auth) { auth.principal };
      };

      // Parse limit (default 20, max 100)
      let limit = switch (Result.toOption(Json.getAsNat(_args, "limit"))) {
        case (null) { 20 };
        case (?l) {
          if (l > 100) { 100 } else { l };
        };
      };

      // Get user's bets
      let bets = ctx.bettingManager.getUserBets(user, limit);

      if (bets.size() == 0) {
        return ToolContext.makeTextSuccess("You haven't placed any bets yet. Use betting_list_pools to find races to bet on!", cb);
      };

      // Calculate summary stats
      var totalWagered : Nat = 0;
      var totalWon : Nat = 0;
      var winCount : Nat = 0;
      var lossCount : Nat = 0;
      var pendingCount : Nat = 0;

      for (bet in bets.vals()) {
        totalWagered += bet.amount;

        switch (bet.status) {
          case (#Won) {
            winCount += 1;
            switch (bet.potentialPayout) {
              case (?payout) { totalWon += payout };
              case null {};
            };
          };
          case (#Lost) { lossCount += 1 };
          case (#Pending) { pendingCount += 1 };
          case (#Active) { pendingCount += 1 };
          case (#Refunded) {
            totalWon += bet.amount; // Refund counts as getting money back
          };
        };
      };

      // Calculate net profit as Int to handle negative values
      let netProfit : Int = totalWon - totalWagered;
      let roi = if (totalWagered > 0) {
        (Float.fromInt(totalWon) / Float.fromInt(totalWagered) - 1.0) * 100.0;
      } else {
        0.0;
      };

      // Convert bets to JSON
      let betsJson = Array.map<BettingTypes.Bet, Json.Json>(
        bets,
        func(bet) : Json.Json {
          let statusText = switch (bet.status) {
            case (#Pending) "Pending";
            case (#Active) "Active";
            case (#Won) "Won";
            case (#Lost) "Lost";
            case (#Refunded) "Refunded";
          };

          let betTypeText = switch (bet.betType) {
            case (#Win) "Win";
            case (#Place) "Place";
            case (#Show) "Show";
          };

          let amountIcp = Float.fromInt(bet.amount) / 100_000_000.0;

          let payoutInfo = switch (bet.potentialPayout) {
            case (?payout) {
              let payoutIcp = Float.fromInt(payout) / 100_000_000.0;
              let betRoi = if (bet.amount > 0) {
                (Float.fromInt(payout) / Float.fromInt(bet.amount) - 1.0) * 100.0;
              } else {
                0.0;
              };
              Json.obj([
                ("payout_icp", Json.str(Float.format(#fix 2, payoutIcp))),
                ("payout_e8s", Json.int(payout)),
                ("roi_percent", Json.str(Float.format(#fix 1, betRoi))),
              ]);
            };
            case null { Json.nullable() };
          };

          Json.obj([
            ("bet_id", Json.int(bet.betId)),
            ("race_id", Json.int(bet.raceId)),
            ("token_index", Json.int(bet.tokenIndex)),
            ("bet_type", Json.str(betTypeText)),
            ("amount_icp", Json.str(Float.format(#fix 2, amountIcp))),
            ("amount_e8s", Json.int(bet.amount)),
            ("status", Json.str(statusText)),
            ("timestamp", Json.int(bet.timestamp)),
            ("payout", payoutInfo),
          ]);
        },
      );

      let response = Json.obj([
        ("bets", Json.arr(betsJson)),
        ("count", Json.int(bets.size())),
        ("summary", Json.obj([("total_bets", Json.int(bets.size())), ("wins", Json.int(winCount)), ("losses", Json.int(lossCount)), ("pending", Json.int(pendingCount)), ("total_wagered_icp", Json.str(Float.format(#fix 2, Float.fromInt(totalWagered) / 100_000_000.0))), ("total_won_icp", Json.str(Float.format(#fix 2, Float.fromInt(totalWon) / 100_000_000.0))), ("net_profit_icp", Json.str(Float.format(#fix 2, Float.fromInt(netProfit) / 100_000_000.0))), ("roi_percent", Json.str(Float.format(#fix 1, roi))), ("win_rate_percent", Json.str(Float.format(#fix 1, if (winCount + lossCount > 0) { (Float.fromInt(winCount) / Float.fromInt(winCount + lossCount)) * 100.0 } else { 0.0 })))])),
      ]);

      ToolContext.makeSuccess(response, cb);
    };
  };
};
