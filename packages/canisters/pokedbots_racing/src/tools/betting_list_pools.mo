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
    name = "betting_list_pools";
    title = ?"List Betting Pools";
    description = ?"List betting pools for races. Filter by pool status (Open, Closed, Settled) or race class. Shows current pool sizes, entrants, and betting deadlines.\n\n**POOL STATUSES:**\n• Open: Currently accepting bets (between registration close and race start)\n• Closed: Race in progress, no more bets accepted\n• Settled: Race completed, payouts distributed\n• Pending: Pool created but betting not yet open\n\n**USE CASES:**\n• Find races to bet on (status=Open)\n• Check completed races for results (status=Settled)\n• Monitor pool sizes and participation\n• View betting opportunities by race class";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      (
        "properties",
        Json.obj([
          ("status_filter", Json.obj([("type", Json.str("string")), ("enum", Json.arr([Json.str("Open"), Json.str("Closed"), Json.str("Settled"), Json.str("Pending")])), ("description", Json.str("Filter by pool status (optional)"))])),
          ("limit", Json.obj([("type", Json.str("number")), ("description", Json.str("Maximum number of pools to return (default 10, max 50)"))])),
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

      // Parse optional status filter
      let statusFilter : ?BettingTypes.PoolStatus = switch (Result.toOption(Json.getAsText(_args, "status_filter"))) {
        case (null) { null };
        case (?statusText) {
          switch (statusText) {
            case ("Open") { ?#Open };
            case ("Closed") { ?#Closed };
            case ("Settled") { ?#Settled };
            case ("Pending") { ?#Pending };
            case (_) { null };
          };
        };
      };

      // Parse limit (default 10, max 50)
      let limit = switch (Result.toOption(Json.getAsNat(_args, "limit"))) {
        case (null) { 10 };
        case (?l) {
          if (l > 50) { 50 } else { l };
        };
      };

      // Get pools from betting manager
      let pools = ctx.bettingManager.listPools(statusFilter, limit);

      if (pools.size() == 0) {
        let message = switch (statusFilter) {
          case (?#Open) {
            "No betting pools are currently open. Pools open 1 hour before races start.";
          };
          case (?#Closed) {
            "No betting pools are currently closed (race in progress).";
          };
          case (?#Settled) {
            "No settled pools found. Check back after races complete.";
          };
          case (?#Pending) {
            "No pending pools. Pools are created when race registration closes.";
          };
          case (?#Cancelled) { "No cancelled pools found." };
          case null { "No betting pools found." };
        };

        return ToolContext.makeTextSuccess(message, cb);
      };

      let now = Time.now();
      let poolsJson = Array.map<BettingTypes.BettingPool, Json.Json>(
        pools,
        func(pool) : Json.Json {
          let statusText = switch (pool.status) {
            case (#Pending) "Pending";
            case (#Open) "Open";
            case (#Closed) "Closed";
            case (#Settled) "Settled";
            case (#Cancelled) "Cancelled";
          };

          let timeUntilClose : ?Text = if (pool.status == #Open) {
            let secondsRemaining = (pool.bettingClosesAt - now) / 1_000_000_000;
            if (secondsRemaining > 0) {
              let minutes = Int.abs(secondsRemaining) / 60;
              ?("Closes in " # Nat.toText(minutes) # " minutes");
            } else {
              ?("Closing soon");
            };
          } else {
            null;
          };

          let totalPoolIcp = Float.fromInt(pool.totalPooled) / 100_000_000.0;

          let timeUntilCloseJson = switch (timeUntilClose) {
            case (?msg) { Json.str(msg) };
            case null { Json.nullable() };
          };

          Json.obj([
            ("race_id", Json.int(pool.raceId)),
            ("status", Json.str(statusText)),
            ("race_class", Json.str(pool.raceClass)),
            ("distance_km", Json.int(pool.distance)),
            ("terrain", Json.str(pool.terrain)),
            ("entrants_count", Json.int(pool.entrants.size())),
            ("entrants", Json.arr(Array.map<Nat, Json.Json>(pool.entrants, func(idx) { Json.int(idx) }))),
            ("total_pool_icp", Json.str(Float.format(#fix 2, totalPoolIcp))),
            ("win_pool_icp", Json.str(Float.format(#fix 2, Float.fromInt(pool.winPool) / 100_000_000.0))),
            ("place_pool_icp", Json.str(Float.format(#fix 2, Float.fromInt(pool.placePool) / 100_000_000.0))),
            ("show_pool_icp", Json.str(Float.format(#fix 2, Float.fromInt(pool.showPool) / 100_000_000.0))),
            ("bets_count", Json.int(pool.betIds.size())),
            ("betting_opens_at", Json.int(pool.bettingOpensAt)),
            ("betting_closes_at", Json.int(pool.bettingClosesAt)),
            ("time_until_close", timeUntilCloseJson),
          ]);
        },
      );

      let response = Json.obj([
        ("pools", Json.arr(poolsJson)),
        ("count", Json.int(pools.size())),
        (
          "filter",
          switch (statusFilter) {
            case (?#Open) { Json.str("Open") };
            case (?#Closed) { Json.str("Closed") };
            case (?#Settled) { Json.str("Settled") };
            case (?#Pending) { Json.str("Pending") };
            case (?#Cancelled) { Json.str("Cancelled") };
            case null { Json.str("All") };
          },
        ),
      ]);

      ToolContext.makeSuccess(response, cb);
    };
  };
};
