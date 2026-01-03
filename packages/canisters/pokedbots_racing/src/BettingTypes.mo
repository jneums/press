import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";

/// Betting System Types
/// Types for pari-mutuel betting on PokedBots races
module {

  // ===== BET TYPES =====

  public type BetType = {
    #Win; // Bot finishes 1st
    #Place; // Bot finishes top 3
    #Show; // Bot finishes top 5
  };

  public type BetStatus = {
    #Pending; // Race hasn't started yet
    #Active; // Race in progress
    #Won; // Bet won, payout issued
    #Lost; // Bet lost
    #Refunded; // Race cancelled or no winners
  };

  public type Bet = {
    betId : Nat;
    userId : Principal;
    raceId : Nat;
    tokenIndex : Nat; // Bot being bet on
    betType : BetType;
    amount : Nat; // ICP (e8s)
    timestamp : Int;
    potentialPayout : ?Nat; // Calculated after settlement
    status : BetStatus;
    paid : Bool; // Whether payout was transferred
  };

  // ===== BETTING POOL TYPES =====

  public type PoolStatus = {
    #Pending; // Race exists but registration not closed yet
    #Open; // Betting window active (registration closed, race not started)
    #Closed; // Race started, no more bets accepted
    #Settled; // Race completed, payouts distributed
    #Cancelled; // Race cancelled (refund all bets)
  };

  public type BettingPool = {
    raceId : Nat;
    subaccount : Blob; // Derived from raceId for dedicated pool funds
    status : PoolStatus;

    // Race context (cached from race data)
    entrants : [Nat]; // Bot token indices in race
    raceClass : Text; // "Scrap", "Junker", etc.
    distance : Nat; // Race distance in km
    terrain : Text; // Terrain type

    // Pool balances (verified against subaccount balance)
    winPool : Nat; // Total ICP bet on Win
    placePool : Nat; // Total ICP bet on Place (top 3)
    showPool : Nat; // Total ICP bet on Show (top 5)
    totalPooled : Nat; // Sum of all pools

    // Pool breakdown by bot (for odds calculation)
    winBetsByBot : [(Nat, Nat)]; // (tokenIndex, total ICP bet on this bot to win)
    placeBetsByBot : [(Nat, Nat)];
    showBetsByBot : [(Nat, Nat)];

    // Bet IDs in this pool
    betIds : [Nat];

    // Timing
    bettingOpensAt : Int; // Unix timestamp (when registration closed)
    bettingClosesAt : Int; // Unix timestamp (when race starts)

    // Settlement
    results : ?RaceResults;
    payoutsCompleted : Bool;
    failedPayouts : [FailedPayout];
    rakeDistributed : Bool;
  };

  public type RaceResults = {
    rankings : [Nat]; // Token indices in finish order
    fetchedAt : Int;
  };

  public type FailedPayout = {
    betId : Nat;
    userId : Principal;
    amount : Nat;
    error : Text;
    attempts : Nat;
    lastAttempt : Int;
  };

  // ===== ODDS & CALCULATIONS =====

  public type Odds = {
    tokenIndex : Nat;
    winOdds : Float; // e.g., 3.2x
    placeOdds : Float; // e.g., 1.8x
    showOdds : Float; // e.g., 1.3x
    winPool : Nat; // Total bet on this bot to win
    placePool : Nat;
    showPool : Nat;
  };

  public type PayoutCalculation = {
    betId : Nat;
    userId : Principal;
    betAmount : Nat;
    payout : Nat;
    roi : Float; // Return on investment multiplier
  };

  // ===== USER STATS =====

  public type BetTypeStats = {
    count : Nat;
    wagered : Nat; // Total ICP bet (e8s)
    won : Nat; // Total ICP won (e8s)
    winRate : Float; // Percentage of winning bets
  };

  public type UserBettingStats = {
    userId : Principal;
    totalBets : Nat;
    totalWagered : Nat; // Total ICP bet (e8s)
    totalWon : Nat; // Total ICP won (e8s)
    netProfit : Int; // totalWon - totalWagered
    winRate : Float; // Percentage of winning bets
    bestROI : Float; // Best return on investment for single bet
    currentStreak : Int; // Positive = winning streak, negative = losing streak
    longestWinStreak : Nat;
    longestLoseStreak : Nat;

    // Breakdown by bet type
    winBets : BetTypeStats;
    placeBets : BetTypeStats;
    showBets : BetTypeStats;

    // Top performances
    biggestWin : Nat; // Largest single payout (e8s)
    biggestWinRaceId : ?Nat;

    // Updated timestamp
    lastBetAt : Int;
    lastWinAt : ?Int;
  };

  // ===== LEADERBOARD =====

  public type LeaderboardEntry = {
    rank : Nat;
    userId : Principal;
    displayName : ?Text; // Optional username
    metricValue : Float; // The metric being ranked by
    totalBets : Nat;
    totalWagered : Nat;
    totalWon : Nat;
    winRate : Float;
  };

  public type LeaderboardMetric = {
    #Profit; // Net profit
    #ROI; // Return on investment
    #Volume; // Total wagered
    #WinRate; // Win rate percentage
  };

  public type TimeRange = {
    #AllTime;
    #ThirtyDays;
    #SevenDays;
  };

  // ===== PLATFORM METRICS =====

  public type PlatformBettingMetrics = {
    totalPools : Nat;
    settledPools : Nat;
    totalBets : Nat;
    totalVolume : Nat; // Total ICP wagered (e8s)
    totalPayouts : Nat; // Total ICP paid out (e8s)
    totalRake : Nat; // Total rake collected (e8s)
    rakeToRacing : Nat; // 8% to racing prize pools (e8s)
    rakeToPlatform : Nat; // 2% to platform treasury (e8s)
    uniqueBettors : Nat;
    averagePoolSize : Nat;
    largestPool : Nat;
    largestPayout : Nat;
    lastUpdated : Int;
  };
};
