import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Int "mo:base/Int";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";

import ToolContext "./ToolContext";
import ExtIntegration "../ExtIntegration";

module {
  public func config() : McpTypes.Tool = {
    name = "browse_pokedbots";
    title = ?"Browse PokedBots Marketplace";
    description = ?"Browse available PokedBots NFTs for sale with detailed stats. Filter by faction, min/max rating, or proven winners. Sort by price, rating, or win rate. Returns 5 listings per page.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("tokenIndex", Json.obj([("type", Json.str("number")), ("description", Json.str("Get details for a specific token index"))])), ("after", Json.obj([("type", Json.str("number")), ("description", Json.str("Show listings after this token index (pagination)"))])), ("faction", Json.obj([("type", Json.str("string")), ("description", Json.str("Filter by faction: UltimateMaster, Wild, Golden, Ultimate, Blackhole, Dead, Master, Bee, Food, Box, Murder, Game, Animal, or Industrial")), ("enum", Json.arr([Json.str("UltimateMaster"), Json.str("Wild"), Json.str("Golden"), Json.str("Ultimate"), Json.str("Blackhole"), Json.str("Dead"), Json.str("Master"), Json.str("Bee"), Json.str("Food"), Json.str("Box"), Json.str("Murder"), Json.str("Game"), Json.str("Animal"), Json.str("Industrial")]))])), ("minRating", Json.obj([("type", Json.str("number")), ("description", Json.str("Minimum overall rating (30-100)"))])), ("maxPrice", Json.obj([("type", Json.str("number")), ("description", Json.str("Maximum price in ICP"))])), ("minWins", Json.obj([("type", Json.str("number")), ("description", Json.str("Minimum number of race wins"))])), ("minWinRate", Json.obj([("type", Json.str("number")), ("description", Json.str("Minimum win rate percentage (0-100)"))])), ("sortBy", Json.obj([("type", Json.str("string")), ("description", Json.str("Sort results by: price, rating, winRate, or wins (default: price)")), ("enum", Json.arr([Json.str("price"), Json.str("rating"), Json.str("winRate"), Json.str("wins")]))])), ("sortDesc", Json.obj([("type", Json.str("boolean")), ("description", Json.str("Sort descending (highest first). Default varies by sortBy."))]))])),
    ]);
    outputSchema = null;
  };

  public func handle(context : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {
      // Check if requesting specific token
      let specificTokenIndex = switch (Result.toOption(Json.getAsNat(_args, "tokenIndex"))) {
        case (?idx) { ?Nat32.fromNat(idx) };
        case (null) { null };
      };

      // Parse filter parameters
      let afterTokenIndex = switch (Result.toOption(Json.getAsNat(_args, "after"))) {
        case (?idx) { ?Nat32.fromNat(idx) };
        case (null) { null };
      };

      let factionFilter = Result.toOption(Json.getAsText(_args, "faction"));
      let minRating = Result.toOption(Json.getAsNat(_args, "minRating"));
      let maxPrice = Result.toOption(Json.getAsFloat(_args, "maxPrice"));
      let minWins = Result.toOption(Json.getAsNat(_args, "minWins"));
      let minWinRate = Result.toOption(Json.getAsFloat(_args, "minWinRate"));
      let sortBy = switch (Result.toOption(Json.getAsText(_args, "sortBy"))) {
        case (?s) { s };
        case (null) { "price" };
      };
      let sortDesc = switch (Result.toOption(Json.getAsBool(_args, "sortDesc"))) {
        case (?d) { d };
        case (null) {
          // Default sort direction depends on sortBy
          switch (sortBy) {
            case ("price") { false }; // Price: lowest first
            case ("rating") { true }; // Rating: highest first
            case ("winRate") { true }; // Win rate: highest first
            case ("wins") { true }; // Wins: most first
            case (_) { false };
          };
        };
      };

      let pageSize = 5;

      // Get cached listings
      let listingsResult = await context.getMarketplaceListings();

      if (listingsResult.size() == 0) {
        return ToolContext.makeTextSuccess("No PokedBots are currently listed for sale on the marketplace.", cb);
      };

      // If specific token requested, find and return just that one
      switch (specificTokenIndex) {
        case (?tokenIdx) {
          // Find the specific listing
          let found = Array.find<(Nat32, ExtIntegration.Listing, ExtIntegration.Metadata)>(
            listingsResult,
            func((idx, _, _)) : Bool { idx == tokenIdx },
          );

          switch (found) {
            case (null) {
              return ToolContext.makeError("Token #" # Nat32.toText(tokenIdx) # " is not currently listed for sale.", cb);
            };
            case (?(tokenIndex, listing, _metadata)) {
              // Get stats for this token
              let baseStats = context.garageManager.getBaseStats(Nat32.toNat(tokenIndex));
              let racingStats = context.garageManager.getStats(Nat32.toNat(tokenIndex));
              let priceICP = Float.fromInt(Nat64.toNat(listing.price)) / 100000000.0;

              // Build response with stats
              let response : McpTypes.JsonValue = switch (racingStats) {
                case (?stats) {
                  // Bot has racing history
                  let rating = context.garageManager.calculateOverallRating(stats);
                  let winRate = if (stats.racesEntered > 0) {
                    Float.fromInt(stats.wins) / Float.fromInt(stats.racesEntered) * 100.0;
                  } else { 0.0 };

                  let factionText = switch (stats.faction) {
                    case (#UltimateMaster) { "UltimateMaster" };
                    case (#Wild) { "Wild" };
                    case (#Golden) { "Golden" };
                    case (#Ultimate) { "Ultimate" };
                    case (#Blackhole) { "Blackhole" };
                    case (#Dead) { "Dead" };
                    case (#Master) { "Master" };
                    case (#Bee) { "Bee" };
                    case (#Food) { "Food" };
                    case (#Box) { "Box" };
                    case (#Murder) { "Murder" };
                    case (#Game) { "Game" };
                    case (#Animal) { "Animal" };
                    case (#Industrial) { "Industrial" };
                  };

                  let terrainText = switch (stats.preferredTerrain) {
                    case (#ScrapHeaps) { "ScrapHeaps" };
                    case (#WastelandSand) { "WastelandSand" };
                    case (#MetalRoads) { "MetalRoads" };
                  };

                  let distanceText = switch (stats.preferredDistance) {
                    case (#ShortSprint) { "ShortSprint" };
                    case (#MediumHaul) { "MediumHaul" };
                    case (#LongTrek) { "LongTrek" };
                  };

                  let podiums = stats.wins + stats.places + stats.shows;

                  Json.obj([
                    ("token_index", Json.int(Nat32.toNat(tokenIndex))),
                    ("price_icp", Json.str(Float.format(#fix 4, priceICP))),
                    ("stats", Json.obj([("faction", Json.str(factionText)), ("base_speed", Json.int(baseStats.speed)), ("base_power_core", Json.int(baseStats.powerCore)), ("base_acceleration", Json.int(baseStats.acceleration)), ("base_stability", Json.int(baseStats.stability)), ("overall_rating", Json.int(rating)), ("races_entered", Json.int(stats.racesEntered)), ("wins", Json.int(stats.wins)), ("podiums", Json.int(podiums)), ("win_rate", Json.str(Float.format(#fix 1, winRate))), ("preferred_terrain", Json.str(terrainText)), ("preferred_distance", Json.str(distanceText))])),
                    ("message", Json.str("Found token #" # Nat32.toText(tokenIdx) # " listed for " # Float.format(#fix 2, priceICP) # " ICP")),
                  ]);
                };
                case (null) {
                  // Uninitialized bot - show base stats only
                  let avgStat = (baseStats.speed + baseStats.powerCore + baseStats.acceleration + baseStats.stability) / 4;

                  Json.obj([
                    ("token_index", Json.int(Nat32.toNat(tokenIndex))),
                    ("price_icp", Json.str(Float.format(#fix 4, priceICP))),
                    ("stats", Json.obj([("base_speed", Json.int(baseStats.speed)), ("base_power_core", Json.int(baseStats.powerCore)), ("base_acceleration", Json.int(baseStats.acceleration)), ("base_stability", Json.int(baseStats.stability)), ("overall_rating", Json.int(avgStat)), ("races_entered", Json.int(0)), ("wins", Json.int(0)), ("podiums", Json.int(0)), ("win_rate", Json.str("0.0"))])),
                    ("message", Json.str("Found token #" # Nat32.toText(tokenIdx) # " listed for " # Float.format(#fix 2, priceICP) # " ICP (not yet initialized for racing)")),
                  ]);
                };
              };

              return ToolContext.makeSuccess(response, cb);
            };
          };
        };
        case (null) {
          // Continue with normal browse logic
        };
      };

      // Enrich listings with racing stats
      type EnrichedListing = {
        tokenIndex : Nat32;
        listing : ExtIntegration.Listing;
        metadata : ExtIntegration.Metadata;
        stats : ?{
          faction : Text;
          baseSpeed : Nat;
          basePowerCore : Nat;
          baseAcceleration : Nat;
          baseStability : Nat;
          overallRating : Nat;
          racesEntered : Nat;
          wins : Nat;
          podiums : Nat;
          winRate : Float;
          preferredTerrain : Text;
          preferredDistance : Text;
        };
      };

      var enrichedListings : [EnrichedListing] = [];

      for ((tokenIndex, listing, metadata) in listingsResult.vals()) {
        // Always get base stats from metadata
        let baseStats = context.garageManager.getBaseStats(Nat32.toNat(tokenIndex));
        let racingStats = context.garageManager.getStats(Nat32.toNat(tokenIndex));

        let statsInfo = switch (racingStats) {
          case (?stats) {
            // Bot has racing history
            let rating = context.garageManager.calculateOverallRating(stats);
            let winRate = if (stats.racesEntered > 0) {
              Float.fromInt(stats.wins) / Float.fromInt(stats.racesEntered) * 100.0;
            } else { 0.0 };

            let factionText = switch (stats.faction) {
              // Ultra-Rare
              case (#UltimateMaster) { "UltimateMaster" };
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

            let terrainText = switch (stats.preferredTerrain) {
              case (#ScrapHeaps) { "ScrapHeaps" };
              case (#WastelandSand) { "WastelandSand" };
              case (#MetalRoads) { "MetalRoads" };
            };

            let distanceText = switch (stats.preferredDistance) {
              case (#ShortSprint) { "ShortSprint" };
              case (#MediumHaul) { "MediumHaul" };
              case (#LongTrek) { "LongTrek" };
            };

            let podiums = stats.wins + stats.places + stats.shows;

            ?{
              faction = factionText;
              baseSpeed = baseStats.speed;
              basePowerCore = baseStats.powerCore;
              baseAcceleration = baseStats.acceleration;
              baseStability = baseStats.stability;
              overallRating = rating;
              racesEntered = stats.racesEntered;
              wins = stats.wins;
              podiums = podiums;
              winRate = winRate;
              preferredTerrain = terrainText;
              preferredDistance = distanceText;
            };
          };
          case (null) {
            // No racing history yet - show base stats with derived info from metadata
            let nftMetadata = context.getNFTMetadata(Nat32.toNat(tokenIndex));

            // Derive faction from actual NFT metadata
            let derivedFaction = switch (nftMetadata) {
              case (?meta) {
                // Use actual metadata to derive faction (Type trait)
                func getTrait(name : Text) : ?Text {
                  let found = Array.find<(Text, Text)>(meta, func(t) { Text.toLowercase(t.0) == Text.toLowercase(name) });
                  switch (found) {
                    case (?(_, value)) { ?value };
                    case null { null };
                  };
                };

                switch (getTrait("type")) {
                  // Ultra-Rare (case-insensitive matching)
                  case (?t) {
                    let lowerType = Text.toLowercase(t);
                    if (lowerType == "ultimate-master") { #UltimateMaster } else if (lowerType == "wild") {
                      #Wild;
                    } else if (lowerType == "golden") { #Golden } else if (lowerType == "ultimate") {
                      #Ultimate;
                    }
                    // Super-Rare
                    else if (lowerType == "blackhole") { #Blackhole } else if (lowerType == "dead") {
                      #Dead;
                    } else if (lowerType == "master") { #Master }
                    // Rare
                    else if (lowerType == "bee") {
                      #Bee;
                    } else if (lowerType == "food") { #Food } else if (lowerType == "box") {
                      #Box;
                    } else if (lowerType == "murder") { #Murder }
                    // Common
                    else if (lowerType == "game") {
                      #Game;
                    } else if (lowerType == "animal") { #Animal } else if (lowerType == "industrial") {
                      #Industrial;
                    } else { #Industrial };
                  };
                  case (null) { #Industrial };
                };
              };
              case (null) {
                // Fallback if no metadata - default to Industrial
                #Industrial;
              };
            };

            // Calculate simple rating from base stats average
            let avgStat = (baseStats.speed + baseStats.powerCore + baseStats.acceleration + baseStats.stability) / 4;
            let derivedRating = avgStat; // Base rating is just the average

            // Debug: log to see actual stat values
            // Debug.print("Token " # Nat32.toText(tokenIndex) # " base stats: SPD=" # Nat.toText(baseStats.speed) # " PWR=" # Nat.toText(baseStats.powerCore) # " ACC=" # Nat.toText(baseStats.acceleration) # " STB=" # Nat.toText(baseStats.stability) # " AVG=" # Nat.toText(avgStat));

            let factionText = switch (derivedFaction) {
              // Ultra-Rare
              case (#UltimateMaster) { "UltimateMaster" };
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

            // Derive terrain preference from Background trait in metadata
            let terrainText = switch (nftMetadata) {
              case (?meta) {
                // Look for Background trait
                let background = Array.find<(Text, Text)>(
                  meta,
                  func(trait) { Text.toLowercase(trait.0) == "background" },
                );

                switch (background) {
                  case (?(_, value)) {
                    let bg = Text.toLowercase(value);

                    // Map background colors to terrain types
                    // Warm/sandy/earthy → WastelandSand
                    if (
                      Text.contains(bg, #text "brown") or
                      Text.contains(bg, #text "red") or
                      Text.contains(bg, #text "yellow") or
                      Text.contains(bg, #text "bones")
                    ) {
                      "WastelandSand";
                    } else if (
                      Text.contains(bg, #text "blue") or
                      Text.contains(bg, #text "purple") or
                      Text.contains(bg, #text "grey") or
                      Text.contains(bg, #text "gray") or
                      Text.contains(bg, #text "teal")
                    ) {
                      "MetalRoads";
                    } else if (
                      Text.contains(bg, #text "black") or
                      Text.contains(bg, #text "green") or
                      Text.contains(bg, #text "planet") or
                      Text.contains(bg, #text "stars") or
                      Text.contains(bg, #text "gold")
                    ) {
                      "ScrapHeaps";
                    } else {
                      let choice = Nat32.toNat(tokenIndex) % 3;
                      if (choice == 0) { "ScrapHeaps" } else if (choice == 1) {
                        "MetalRoads";
                      } else { "WastelandSand" };
                    };
                  };
                  case null {
                    // Fallback: use token index for variety
                    let choice = Nat32.toNat(tokenIndex) % 3;
                    if (choice == 0) { "ScrapHeaps" } else if (choice == 1) {
                      "MetalRoads";
                    } else { "WastelandSand" };
                  };
                };
              };
              case null {
                // No metadata available, use token index
                let choice = Nat32.toNat(tokenIndex) % 3;
                if (choice == 0) { "ScrapHeaps" } else if (choice == 1) {
                  "MetalRoads";
                } else { "WastelandSand" };
              };
            };

            // Derive distance preference from stats (lowered thresholds for more variety)
            let distanceText = if (baseStats.powerCore > 55 and baseStats.speed < 50) {
              "LongTrek";
            } else if (baseStats.speed > 55 and baseStats.powerCore < 50) {
              "ShortSprint";
            } else {
              "MediumHaul";
            };

            ?{
              faction = factionText;
              baseSpeed = baseStats.speed;
              basePowerCore = baseStats.powerCore;
              baseAcceleration = baseStats.acceleration;
              baseStability = baseStats.stability;
              overallRating = derivedRating;
              racesEntered = 0;
              wins = 0;
              podiums = 0;
              winRate = 0.0;
              preferredTerrain = terrainText;
              preferredDistance = distanceText;
            };
          };
        };

        enrichedListings := Array.append(enrichedListings, [{ tokenIndex = tokenIndex; listing = listing; metadata = metadata; stats = statsInfo }]);
      };

      // Apply filters
      var filteredListings = enrichedListings;

      // Filter by faction
      switch (factionFilter) {
        case (?faction) {
          filteredListings := Array.filter<EnrichedListing>(
            filteredListings,
            func(l) {
              switch (l.stats) {
                case (?s) { s.faction == faction };
                case (null) { false };
              };
            },
          );
        };
        case (null) {};
      };

      // Filter by min rating
      switch (minRating) {
        case (?rating) {
          filteredListings := Array.filter<EnrichedListing>(
            filteredListings,
            func(l) {
              switch (l.stats) {
                case (?s) { s.overallRating >= rating };
                case (null) { false };
              };
            },
          );
        };
        case (null) {};
      };

      // Filter by max price
      switch (maxPrice) {
        case (?price) {
          let priceInt = Float.toInt(price * 100_000_000.0);
          if (priceInt >= 0) {
            let maxPriceE8s = Nat64.fromNat(Int.abs(priceInt));
            filteredListings := Array.filter<EnrichedListing>(
              filteredListings,
              func(l) { l.listing.price <= maxPriceE8s },
            );
          };
        };
        case (null) {};
      };

      // Filter by min wins
      switch (minWins) {
        case (?wins) {
          filteredListings := Array.filter<EnrichedListing>(
            filteredListings,
            func(l) {
              switch (l.stats) {
                case (?s) { s.wins >= wins };
                case (null) { false };
              };
            },
          );
        };
        case (null) {};
      };

      // Filter by min win rate
      switch (minWinRate) {
        case (?rate) {
          filteredListings := Array.filter<EnrichedListing>(
            filteredListings,
            func(l) {
              switch (l.stats) {
                case (?s) { s.winRate >= rate };
                case (null) { false };
              };
            },
          );
        };
        case (null) {};
      };

      if (filteredListings.size() == 0) {
        return ToolContext.makeTextSuccess("No PokedBots match your search criteria.", cb);
      };

      // Sort listings
      let sortedListings = Array.sort<EnrichedListing>(
        filteredListings,
        func(a, b) {
          let comparison = switch (sortBy) {
            case ("price") {
              Nat64.compare(a.listing.price, b.listing.price);
            };
            case ("rating") {
              switch (a.stats, b.stats) {
                case (?statsA, ?statsB) {
                  Nat.compare(statsA.overallRating, statsB.overallRating);
                };
                case (?_, null) { #greater };
                case (null, ?_) { #less };
                case (null, null) { #equal };
              };
            };
            case ("winRate") {
              switch (a.stats, b.stats) {
                case (?statsA, ?statsB) {
                  Float.compare(statsA.winRate, statsB.winRate);
                };
                case (?_, null) { #greater };
                case (null, ?_) { #less };
                case (null, null) { #equal };
              };
            };
            case ("wins") {
              switch (a.stats, b.stats) {
                case (?statsA, ?statsB) {
                  Nat.compare(statsA.wins, statsB.wins);
                };
                case (?_, null) { #greater };
                case (null, ?_) { #less };
                case (null, null) { #equal };
              };
            };
            case (_) { Nat64.compare(a.listing.price, b.listing.price) };
          };

          if (sortDesc) {
            switch (comparison) {
              case (#less) { #greater };
              case (#greater) { #less };
              case (#equal) { #equal };
            };
          } else {
            comparison;
          };
        },
      );

      // Find start position based on 'after' token
      var startIdx = 0;
      switch (afterTokenIndex) {
        case (?afterToken) {
          label findLoop for (i in sortedListings.keys()) {
            if (sortedListings[i].tokenIndex == afterToken) {
              startIdx := i + 1;
              break findLoop;
            };
          };
        };
        case (null) {};
      };

      let totalListings = sortedListings.size();
      let endIdx = Nat.min(startIdx + pageSize, totalListings);

      if (startIdx >= totalListings) {
        return ToolContext.makeTextSuccess(
          "No more listings available after token #" # debug_show (afterTokenIndex),
          cb,
        );
      };

      // Format page results
      let extCanisterId = context.extCanisterId;
      let pageListings = Array.tabulate<Text>(
        endIdx - startIdx,
        func(i) {
          let idx = startIdx + i;
          let listing = sortedListings[idx];
          let priceIcp = Float.fromInt(Nat64.toNat(listing.listing.price)) / 100_000_000.0;

          let tokenId = ExtIntegration.encodeTokenIdentifier(listing.tokenIndex, extCanisterId);
          let imageUrl = "https://bzsui-sqaaa-aaaah-qce2a-cai.raw.icp0.io/?tokenid=" # tokenId # "&type=thumbnail";

          var details = "🤖 Token #" # Nat32.toText(listing.tokenIndex) # "\n";
          details #= "   💰 Price: " # Float.format(#fix 2, priceIcp) # " ICP\n";

          switch (listing.stats) {
            case (?stats) {
              let ratingLabel = if (stats.racesEntered > 0) { "Rating" } else {
                "Base";
              };
              details #= "   ⚡ " # ratingLabel # ": " # Nat.toText(stats.overallRating) # "/100";
              details #= " | 🏆 " # stats.faction # "\n";
              details #= "   📊 Stats: SPD " # Nat.toText(stats.baseSpeed);
              details #= " | PWR " # Nat.toText(stats.basePowerCore);
              details #= " | ACC " # Nat.toText(stats.baseAcceleration);
              details #= " | STB " # Nat.toText(stats.baseStability) # "\n";
              if (stats.racesEntered > 0) {
                // Calculate losses (racesEntered should always be >= wins, but use saturating subtraction to be safe)
                let racesInt = Int.abs(stats.racesEntered);
                let winsInt = Int.abs(stats.wins);
                let lossesInt = racesInt - winsInt;
                let losses = Int.abs(lossesInt);
                details #= "   🏁 Record: " # Nat.toText(stats.wins) # "W-" # Nat.toText(losses) # "L";
                details #= " (" # Float.format(#fix 1, stats.winRate) # "% win rate)\n";
              } else {
                details #= "   🏁 Record: No races yet\n";
              };
              details #= "   🎯 Prefers: " # stats.preferredTerrain # " terrain, " # stats.preferredDistance;
            };
            case (null) {
              details #= "   ⚠️  Error loading stats";
            };
          };

          details #= "\n   🖼️  Image: " # imageUrl;

          details;
        },
      );

      var message = "🏪 PokedBots Marketplace";

      // Show active filters
      var filters : [Text] = [];
      switch (factionFilter) {
        case (?f) { filters := Array.append(filters, ["Faction:" # f]) };
        case (null) {};
      };
      switch (minRating) {
        case (?r) {
          filters := Array.append(filters, ["MinRating:" # Nat.toText(r)]);
        };
        case (null) {};
      };
      switch (maxPrice) {
        case (?p) {
          filters := Array.append(filters, ["MaxPrice:" # Float.format(#fix 2, p) # "ICP"]);
        };
        case (null) {};
      };
      switch (minWins) {
        case (?w) {
          filters := Array.append(filters, ["MinWins:" # Nat.toText(w)]);
        };
        case (null) {};
      };
      switch (minWinRate) {
        case (?r) {
          filters := Array.append(filters, ["MinWinRate:" # Float.format(#fix 0, r) # "%"]);
        };
        case (null) {};
      };

      if (filters.size() > 0) {
        message #= " [" # Text.join(", ", filters.vals()) # "]";
      };
      message #= "\n📈 Sorted by: " # sortBy # (if (sortDesc) { " (high to low)" } else { " (low to high)" });
      message #= "\nShowing " # Nat.toText(endIdx - startIdx) # " of " # Nat.toText(totalListings) # " listings:\n\n";
      message #= Text.join("\n", pageListings.vals());

      // Show next cursor if there are more results
      if (endIdx < totalListings) {
        let lastTokenInPage = sortedListings[endIdx - 1].tokenIndex;
        message #= "\n\n📄 More available. Use: after=" # Nat32.toText(lastTokenInPage);
      } else {
        message #= "\n\n✓ End of listings";
      };

      message #= "\n\n💡 To purchase: use purchase_pokedbot with the token index";
      message #= "\n💡 Filter examples: faction=GodClass, minRating=70, maxPrice=0.5, minWins=5, minWinRate=50";
      message #= "\n💡 Sort examples: sortBy=rating, sortBy=winRate, sortBy=wins (add sortDesc=true for reverse)";

      ToolContext.makeTextSuccess(message, cb);
    };
  };
};
