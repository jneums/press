import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Time "mo:base/Time";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import BettingTypes "../BettingTypes";

module {

  public func config() : McpTypes.Tool = {
    name = "betting_get_pool_info";
    title = ?"Get Pool Details & Live Odds";
    description = ?"Get detailed information about a specific betting pool including live odds for all entrants. Use this before placing bets to see current payout multipliers.\n\n**INFORMATION PROVIDED:**\n• Pool status and race details\n• Live odds for each bot (Win/Place/Show)\n• Current pool sizes by bet type\n• Total bets and unique bettors\n• Betting window timing\n• Entrant list with current odds\n\n**ODDS EXPLANATION:**\n• Odds show potential payout multiplier (e.g., 3.2x means 3.2 ICP per 1 ICP bet)\n• Odds change as more bets are placed\n• Higher odds = less money bet on that bot = higher risk/reward\n• Pari-mutuel system: you're betting against other bettors, not the house";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      (
        "properties",
        Json.obj([
          ("race_id", Json.obj([("type", Json.str("number")), ("description", Json.str("The race ID to get pool info for"))])),
        ]),
      ),
      ("required", Json.arr([Json.str("race_id")])),
    ]);
    outputSchema = null;
  };

  public func handle(ctx : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {

      // Parse race ID
      let raceId = switch (Result.toOption(Json.getAsNat(_args, "race_id"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: race_id", cb);
        };
        case (?id) { id };
      };

      // Get pool
      let pool = switch (ctx.bettingManager.getPool(raceId)) {
        case (null) {
          return ToolContext.makeError("Betting pool not found for race " # Nat.toText(raceId), cb);
        };
        case (?p) { p };
      };

      // Calculate live odds
      let odds = ctx.bettingManager.calculateAllOdds(raceId);

      let now = Time.now();

      let statusText = switch (pool.status) {
        case (#Pending) "Pending";
        case (#Open) "Open";
        case (#Closed) "Closed";
        case (#Settled) "Settled";
        case (#Cancelled) "Cancelled";
      };

      let timeInfo = if (pool.status == #Pending) {
        let secondsUntilOpen = (pool.bettingOpensAt - now) / 1_000_000_000;
        if (secondsUntilOpen > 0) {
          let minutes = Int.abs(secondsUntilOpen) / 60;
          "Opens in " # Nat.toText(minutes) # " minutes (when registration closes)";
        } else {
          "Opening soon";
        };
      } else if (pool.status == #Open) {
        let secondsUntilClose = (pool.bettingClosesAt - now) / 1_000_000_000;
        if (secondsUntilClose > 0) {
          let minutes = Int.abs(secondsUntilClose) / 60;
          "Closes in " # Nat.toText(minutes) # " minutes (when race starts)";
        } else {
          "Closing soon";
        };
      } else if (pool.status == #Closed) {
        "Race in progress";
      } else if (pool.status == #Settled) {
        switch (pool.results) {
          case (?results) { "Race completed" };
          case null { "Settling..." };
        };
      } else {
        "Cancelled";
      };

      // Create entrant odds array
      let entrantOddsJson = Array.map<BettingTypes.Odds, Json.Json>(
        odds,
        func(o) : Json.Json {
          Json.obj([
            ("token_index", Json.int(o.tokenIndex)),
            ("win_odds", Json.str(Float.format(#fix 2, o.winOdds))),
            ("place_odds", Json.str(Float.format(#fix 2, o.placeOdds))),
            ("show_odds", Json.str(Float.format(#fix 2, o.showOdds))),
            ("win_pool_icp", Json.str(Float.format(#fix 2, Float.fromInt(o.winPool) / 100_000_000.0))),
            ("place_pool_icp", Json.str(Float.format(#fix 2, Float.fromInt(o.placePool) / 100_000_000.0))),
            ("show_pool_icp", Json.str(Float.format(#fix 2, Float.fromInt(o.showPool) / 100_000_000.0))),
          ]);
        },
      );

      // Results if settled
      let resultsJson = switch (pool.results) {
        case null { Json.nullable() };
        case (?results) {
          Json.obj([
            ("rankings", Json.arr(Array.map<Nat, Json.Json>(results.rankings, func(idx) { Json.int(idx) }))),
            ("winner", if (results.rankings.size() > 0) { Json.int(results.rankings[0]) } else { Json.nullable() }),
            (
              "top_3",
              Json.arr(
                Array.map<Nat, Json.Json>(
                  Array.tabulate<Nat>(
                    if (results.rankings.size() < 3) { results.rankings.size() } else {
                      3;
                    },
                    func(i) { results.rankings[i] },
                  ),
                  func(idx) { Json.int(idx) },
                )
              ),
            ),
            (
              "top_5",
              Json.arr(
                Array.map<Nat, Json.Json>(
                  Array.tabulate<Nat>(
                    if (results.rankings.size() < 5) { results.rankings.size() } else {
                      5;
                    },
                    func(i) { results.rankings[i] },
                  ),
                  func(idx) { Json.int(idx) },
                )
              ),
            ),
          ]);
        };
      };

      let response = Json.obj([
        ("race_id", Json.int(pool.raceId)),
        ("status", Json.str(statusText)),
        ("time_info", Json.str(timeInfo)),
        ("race_class", Json.str(pool.raceClass)),
        ("distance_km", Json.int(pool.distance)),
        ("terrain", Json.str(pool.terrain)),
        ("entrants_count", Json.int(pool.entrants.size())),
        ("total_pool_icp", Json.str(Float.format(#fix 2, Float.fromInt(pool.totalPooled) / 100_000_000.0))),
        ("win_pool_icp", Json.str(Float.format(#fix 2, Float.fromInt(pool.winPool) / 100_000_000.0))),
        ("place_pool_icp", Json.str(Float.format(#fix 2, Float.fromInt(pool.placePool) / 100_000_000.0))),
        ("show_pool_icp", Json.str(Float.format(#fix 2, Float.fromInt(pool.showPool) / 100_000_000.0))),
        ("total_bets", Json.int(pool.betIds.size())),
        ("betting_opens_at", Json.int(pool.bettingOpensAt)),
        ("betting_closes_at", Json.int(pool.bettingClosesAt)),
        ("entrant_odds", Json.arr(entrantOddsJson)),
        ("results", resultsJson),
        ("payouts_completed", Json.bool(pool.payoutsCompleted)),
        ("failed_payouts_count", Json.int(pool.failedPayouts.size())),
      ]);

      ToolContext.makeSuccess(response, cb);
    };
  };
};
