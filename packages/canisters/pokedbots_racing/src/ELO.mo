import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Array "mo:base/Array";

module {
  // ELO rating system for PokedBots Racing
  // Implements multi-bot ELO calculations for race results

  /// K-factor determines how much ratings change per race
  /// Higher K for newer bots (more volatile), lower for veterans (more stable)
  public func getKFactor(racesEntered : Nat) : Float {
    if (racesEntered < 20) { 10.0 } // New bots: high volatility
    else if (racesEntered < 50) { 8.0 } // Mid-level: moderate changes
    else { 6.0 }; // Veterans: stable ratings
  };

  /// Calculate expected score for bot A vs bot B
  /// Returns probability (0.0 to 1.0) that bot A will beat bot B
  public func calculateExpectedScore(ratingA : Nat, ratingB : Nat) : Float {
    let diff = Float.fromInt(
      if (ratingA >= ratingB) {
        ratingA - ratingB;
      } else {
        ratingB - ratingA;
      }
    );
    let sign = if (ratingA >= ratingB) { 1.0 } else { -1.0 };
    let exponent = sign * diff / 400.0;

    // Expected score: 1 / (1 + 10^(-diff/400))
    1.0 / (1.0 + (10.0 ** (-exponent)));
  };

  /// Calculate ELO change for a single pairwise comparison
  /// winner: true if bot A beat bot B, false otherwise
  public func calculateEloChange(
    ratingA : Nat,
    ratingB : Nat,
    racesEnteredA : Nat,
    winner : Bool,
  ) : Int {
    let kFactor = getKFactor(racesEnteredA);
    let expected = calculateExpectedScore(ratingA, ratingB);
    let actual : Float = if (winner) { 1.0 } else { 0.0 };

    // ELO change = K * (actual - expected)
    let change = kFactor * (actual - expected);
    Float.toInt(Float.nearest(change));
  };

  /// Calculate ELO changes for all bots in a race result
  /// Takes array of (tokenIndex, currentElo, racesEntered, finalPosition)
  /// Returns array of (tokenIndex, eloChange)
  public func calculateMultiBotEloChanges(
    results : [(Nat, Nat, Nat, Nat)] // (tokenIndex, elo, races, position)
  ) : [(Nat, Int)] {
    let size = results.size();
    if (size < 2) { return [] }; // Need at least 2 bots to compare

    // Store cumulative ELO changes for each bot
    var changes : [(Nat, Int)] = Array.tabulate<(Nat, Int)>(
      size,
      func(i : Nat) : (Nat, Int) { (results[i].0, 0) },
    );

    // Calculate pairwise comparisons for all bots
    for (i in results.keys()) {
      for (j in results.keys()) {
        if (i != j) {
          let (_tokenA, eloA, racesA, posA) = results[i];
          let (_tokenB, eloB, _, posB) = results[j];

          // Did bot A beat bot B? (lower position = better)
          let aWon = posA < posB;

          // Calculate ELO change for this pairwise comparison
          let eloChange = calculateEloChange(eloA, eloB, racesA, aWon);

          // Add to cumulative change
          changes := Array.tabulate<(Nat, Int)>(
            size,
            func(idx : Nat) : (Nat, Int) {
              if (idx == i) {
                let (token, currentChange) = changes[idx];
                (token, currentChange + eloChange);
              } else {
                changes[idx];
              };
            },
          );
        };
      };
    };

    changes;
  };

  /// Apply ELO change to current rating (ensures rating stays >= 100)
  public func applyEloChange(currentRating : Nat, change : Int) : Nat {
    // Convert current rating to Int for safe arithmetic
    let currentInt : Int = currentRating;
    let newRatingInt = currentInt + change;

    // Clamp to minimum of 100
    let finalRating = if (newRatingInt < 100) { 100 } else {
      Int.abs(newRatingInt);
    };
    finalRating;
  };
};
