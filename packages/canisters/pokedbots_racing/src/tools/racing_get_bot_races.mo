import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Iter "mo:base/Iter";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import RacingSimulator "../RacingSimulator";
import TimeUtils "../TimeUtils";

module {
  public func config() : McpTypes.Tool = {
    name = "racing_get_bot_races";
    title = ?"Get Bot's Race Entries";
    description = ?"Show races that a specific bot is entered in. Returns 5 races per page. Filter by status category and use cursor-based pagination.\n\n**TIMESTAMP FORMAT:** All timestamps (start_time_utc, entry_deadline_utc, created_at_utc) are in UTC ISO 8601 format (e.g., '2024-12-17T20:00:00Z'). Times are already in UTC timezone.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_index", Json.obj([("type", Json.str("number")), ("description", Json.str("The token index of the bot to check race entries for"))])), ("category", Json.obj([("type", Json.str("string")), ("enum", Json.arr([Json.str("upcoming"), Json.str("in_progress"), Json.str("completed"), Json.str("all")])), ("description", Json.str("Optional: Filter by race status. Default: all"))])), ("after_race_id", Json.obj([("type", Json.str("number")), ("description", Json.str("Optional: Race ID to start after. Returns the next page of races after this ID."))]))])),
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
      let tokenIndexOpt = Result.toOption(Json.getAsNat(_args, "token_index"));
      let categoryOpt = Result.toOption(Json.getAsText(_args, "category"));
      let afterRaceIdOpt = Result.toOption(Json.getAsNat(_args, "after_race_id"));

      switch (tokenIndexOpt) {
        case (?tokenIndex) {
          let nftId = Nat.toText(tokenIndex);
          let now = Time.now();
          let pageSize = 5;

          // Get all races and filter for this bot
          let allRaces = ctx.raceManager.getAllRaces();

          var upcomingRaces : [RacingSimulator.Race] = [];
          var inProgressRaces : [RacingSimulator.Race] = [];
          var completedRaces : [RacingSimulator.Race] = [];

          for (race in allRaces.vals()) {
            // Check if this bot is in the race
            let isInRace = Array.find<RacingSimulator.RaceEntry>(
              race.entries,
              func(entry) { entry.nftId == nftId },
            );

            switch (isInRace) {
              case (?_) {
                // Bot is in this race - categorize by status
                switch (race.status) {
                  case (#Upcoming) {
                    upcomingRaces := Array.append(upcomingRaces, [race]);
                  };
                  case (#InProgress) {
                    inProgressRaces := Array.append(inProgressRaces, [race]);
                  };
                  case (#Completed) {
                    completedRaces := Array.append(completedRaces, [race]);
                  };
                  case (#Cancelled) {}; // Skip cancelled
                };
              };
              case (null) {}; // Bot not in this race
            };
          };

          // Sort races by race ID (descending for completed, ascending for upcoming)
          upcomingRaces := Array.sort<RacingSimulator.Race>(
            upcomingRaces,
            func(a, b) { Nat.compare(a.raceId, b.raceId) },
          );
          inProgressRaces := Array.sort<RacingSimulator.Race>(
            inProgressRaces,
            func(a, b) { Nat.compare(a.raceId, b.raceId) },
          );
          completedRaces := Array.sort<RacingSimulator.Race>(
            completedRaces,
            func(a, b) { Nat.compare(b.raceId, a.raceId) }, // Reverse for most recent first
          );

          // Select races based on category filter
          let category = switch (categoryOpt) {
            case (?cat) { cat };
            case (null) { "all" };
          };

          var selectedRaces : [RacingSimulator.Race] = [];
          let racesType : Text = category;

          selectedRaces := switch (category) {
            case ("upcoming") { upcomingRaces };
            case ("in_progress") { inProgressRaces };
            case ("completed") { completedRaces };
            case (_) {
              // "all": combine all races, sorted by status priority then ID
              Array.append(
                Array.append(inProgressRaces, upcomingRaces),
                completedRaces,
              );
            };
          };

          // Apply cursor-based pagination
          var startIdx = 0;
          switch (afterRaceIdOpt) {
            case (?afterRaceId) {
              // Find the position after the cursor race
              label finding for (i in selectedRaces.keys()) {
                if (selectedRaces[i].raceId == afterRaceId) {
                  startIdx := i + 1;
                  break finding;
                };
              };
            };
            case (null) {};
          };

          let totalRaces = selectedRaces.size();
          let endIdx = Nat.min(startIdx + pageSize, totalRaces);

          var races : [RacingSimulator.Race] = [];
          if (startIdx < totalRaces) {
            races := Array.subArray(selectedRaces, startIdx, endIdx - startIdx);
          };

          // Build races array
          var racesArray : [Json.Json] = [];
          for (race in races.vals()) {
            let classText = switch (race.raceClass) {
              case (#Scrap) { "Scrap" };
              case (#Junker) { "Junker" };
              case (#Raider) { "Raider" };
              case (#Elite) { "Elite" };
              case (#SilentKlan) { "Silent Klan" };
            };

            let terrainText = switch (race.terrain) {
              case (#ScrapHeaps) { "Scrap Heaps" };
              case (#WastelandSand) { "Wasteland Sand" };
              case (#MetalRoads) { "Metal Roads" };
            };

            let statusText = switch (race.status) {
              case (#Upcoming) { "Upcoming" };
              case (#InProgress) { "In Progress" };
              case (#Completed) { "Completed" };
              case (#Cancelled) { "Cancelled" };
            };

            // Build race JSON based on status
            let totalPrizePool = race.prizePool + race.platformBonus;
            let prizePoolDecimal = (totalPrizePool % 100_000_000) / 1_000_000;
            let prizePoolDecimalStr = if (prizePoolDecimal < 10) {
              "0" # Nat.toText(prizePoolDecimal);
            } else { Nat.toText(prizePoolDecimal) };

            var raceFields : [(Text, Json.Json)] = [
              ("race_id", Json.int(race.raceId)),
              ("name", Json.str(race.name)),
              ("status", Json.str(statusText)),
              ("class", Json.str(classText)),
              ("terrain", Json.str(terrainText)),
              ("distance_km", Json.int(race.distance)),
              ("prize_pool_icp", Json.str(Text.concat(Nat.toText(totalPrizePool / 100_000_000), "." # prizePoolDecimalStr))),
              ("entries", Json.int(race.entries.size())),
              ("max_entries", Json.int(race.maxEntries)),
            ];

            // Add time info for upcoming races
            if (race.status == #Upcoming) {
              let timeUntilStart = race.startTime - now;
              let hoursUntilStart = timeUntilStart / 3_600_000_000_000;
              let minutesUntilStart = (timeUntilStart % 3_600_000_000_000) / 60_000_000_000;
              raceFields := Array.append(
                raceFields,
                [
                  ("starts_in_hours", Json.int(hoursUntilStart)),
                  ("starts_in_minutes", Json.int(minutesUntilStart)),
                ],
              );
            };

            // Add result info for completed races
            if (race.status == #Completed) {
              var position : ?Nat = null;
              var finalTime : ?Float = null;
              var prizeAmount : ?Nat = null;

              switch (race.results) {
                case (?results) {
                  let botResult = Array.find<RacingSimulator.RaceResult>(
                    results,
                    func(r) { r.nftId == nftId },
                  );
                  switch (botResult) {
                    case (?result) {
                      position := ?result.position;
                      finalTime := ?result.finalTime;
                      prizeAmount := ?result.prizeAmount;
                    };
                    case (null) {};
                  };
                };
                case (null) {};
              };

              raceFields := Array.append(
                raceFields,
                [
                  ("position", switch (position) { case (?p) { Json.int(p) }; case (null) { Json.nullable() } }),
                  ("final_time_seconds", switch (finalTime) { case (?t) { let tInt = Float.toInt(t * 1000.0); Json.str(Text.concat(Nat.toText(Int.abs(tInt) / 1000), "." # Nat.toText((Int.abs(tInt) % 1000) / 100))) }; case (null) { Json.nullable() } }),
                  ("prize_won_icp", switch (prizeAmount) { case (?p) { let decimal = (p % 100_000_000) / 1_000_000; let decimalStr = if (decimal < 10) { "0" # Nat.toText(decimal) } else { Nat.toText(decimal) }; Json.str(Text.concat(Nat.toText(p / 100_000_000), "." # decimalStr)) }; case (null) { Json.nullable() } }),
                ],
              );
            };

            let raceJson = Json.obj(raceFields);
            racesArray := Array.append(racesArray, [raceJson]);
          };

          let response = Json.obj([
            ("bot_nft_id", Json.str(nftId)),
            ("category", Json.str(category)),
            ("total_in_category", Json.int(totalRaces)),
            ("total_upcoming", Json.int(upcomingRaces.size())),
            ("total_in_progress", Json.int(inProgressRaces.size())),
            ("total_completed", Json.int(completedRaces.size())),
            ("showing", Json.int(races.size())),
            ("has_more", Json.bool(endIdx < totalRaces)),
            (
              "next_cursor",
              if (endIdx < totalRaces and races.size() > 0) {
                Json.int(races[races.size() - 1].raceId);
              } else {
                Json.nullable();
              },
            ),
            ("races", Json.arr(racesArray)),
          ]);

          ToolContext.makeSuccess(response, cb);
        };
        case (null) {
          return ToolContext.makeError("Invalid token_index. Must be a number.", cb);
        };
      };
    };
  };
};
