import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Map "mo:map/Map";
import { nhash } "mo:map/Map";
import PokedBotsGarage "./PokedBotsGarage";
import RacingSimulator "./RacingSimulator";

module {
  public type RaceClass = RacingSimulator.RaceClass;
  public type FactionType = PokedBotsGarage.FactionType;

  // ===== TIME-BASED SEASON/MONTH CALCULATION =====

  // Calculate month ID (YYYYMM) from nanosecond timestamp
  public func getMonthIdFromTime(timestamp : Int) : Nat {
    let NANOS_PER_SECOND : Int = 1_000_000_000;
    let SECONDS_PER_DAY : Int = 86400;

    let seconds = timestamp / NANOS_PER_SECOND;
    var days = seconds / SECONDS_PER_DAY;

    // January 1, 1970 was a Thursday
    // Days in each month (non-leap year)
    let monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    var year = 1970;
    var month = 1;

    // Iterate through years to find the correct year
    label yearLoop loop {
      let isLeapYear = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
      let daysInYear = if (isLeapYear) { 366 } else { 365 };

      if (days < daysInYear) {
        break yearLoop;
      };

      days := days - daysInYear;
      year := year + 1;
    };

    // Find the correct month within the year
    let isLeapYear = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
    label monthLoop for (i in Iter.range(0, 11)) {
      var daysInMonth = monthDays[i];
      if (i == 1 and isLeapYear) {
        daysInMonth := 29; // February in leap year
      };

      if (days < daysInMonth) {
        month := i + 1;
        break monthLoop;
      };

      days := days - daysInMonth;
    };

    (year * 100) + month; // YYYYMM format
  };

  // Calculate season ID from timestamp
  // Seasons are 3 months: Winter (1-3), Spring (4-6), Summer (7-9), Fall (10-12)
  public func getSeasonIdFromTime(timestamp : Int) : Nat {
    let monthId = getMonthIdFromTime(timestamp);
    let month = monthId % 100;
    let year = monthId / 100;

    let seasonInYear = if (month <= 3) { 1 } // Winter
    else if (month <= 6) { 2 } // Spring
    else if (month <= 9) { 3 } // Summer
    else { 4 }; // Fall

    // Season ID format: YYYYS (e.g., 20251 = 2025 Winter, 20254 = 2025 Fall)
    (year * 10) + seasonInYear;
  };

  // ===== LEADERBOARD TYPES =====

  public type LeaderboardType = {
    #Monthly : Nat; // Month identifier (YYYYMM)
    #Season : Nat; // Season ID
    #AllTime;
    #Faction : FactionType;
    #Division : RaceClass;
  };

  public type TrendDirection = {
    #Up : Nat; // Positions gained
    #Down : Nat; // Positions lost
    #Stable;
    #New; // First appearance
  };

  public type LeaderboardEntry = {
    tokenIndex : Nat;
    owner : Principal;
    points : Nat;
    wins : Nat;
    podiums : Nat; // Top 3 finishes
    races : Nat;
    winRate : Float; // wins / races
    avgPosition : Float;
    totalEarnings : Nat; // ICP e8s
    bestFinish : Nat; // Best position ever
    currentStreak : Int; // Positive for wins, negative for losses
    rank : Nat;
    previousRank : ?Nat;
    trend : TrendDirection;
    lastRaceTime : Int;
  };

  // Points awarded by position
  public func getPointsForPosition(position : Nat, multiplier : Float) : Nat {
    let basePoints = switch (position) {
      case (1) { 25 };
      case (2) { 18 };
      case (3) { 15 };
      case (4) { 12 };
      case (5) { 10 };
      case (6) { 8 };
      case (7 or 8) { 6 };
      case (9 or 10) { 4 };
      case (_) { 2 }; // Participation points
    };

    Int.abs(Float.toInt(Float.fromInt(basePoints) * multiplier));
  };

  // ===== LEADERBOARD MANAGER =====

  public class LeaderboardManager(
    initMonthlyBoards : Map.Map<Nat, Map.Map<Nat, LeaderboardEntry>>, // monthId -> (tokenIndex -> entry)
    initSeasonBoards : Map.Map<Nat, Map.Map<Nat, LeaderboardEntry>>, // seasonId -> (tokenIndex -> entry)
    initAllTimeBoard : Map.Map<Nat, LeaderboardEntry>, // tokenIndex -> entry
    initFactionBoards : Map.Map<Text, Map.Map<Nat, LeaderboardEntry>>, // factionName -> (tokenIndex -> entry)
    getRaceClassCallback : (Nat) -> RaceClass, // Callback to get current race class for a bot
  ) {
    private let monthlyBoards = initMonthlyBoards;
    private let seasonBoards = initSeasonBoards;
    private let allTimeBoard = initAllTimeBoard;
    private let factionBoards = initFactionBoards;

    // Current active season (calculated from time)
    private var currentSeasonId : Nat = 1;
    private var currentMonthId : Nat = 202411; // YYYYMM format

    // Update current season/month based on timestamp
    public func updateCurrentPeriods(timestamp : Int) {
      currentSeasonId := getSeasonIdFromTime(timestamp);
      currentMonthId := getMonthIdFromTime(timestamp);
    };

    // Get current season/month IDs
    public func getCurrentSeasonId() : Nat { currentSeasonId };
    public func getCurrentMonthId() : Nat { currentMonthId };

    // Get maps for stable storage
    public func getMonthlyBoards() : Map.Map<Nat, Map.Map<Nat, LeaderboardEntry>> {
      monthlyBoards;
    };

    public func getSeasonBoards() : Map.Map<Nat, Map.Map<Nat, LeaderboardEntry>> {
      seasonBoards;
    };

    public func getAllTimeBoard() : Map.Map<Nat, LeaderboardEntry> {
      allTimeBoard;
    };

    public func getFactionBoards() : Map.Map<Text, Map.Map<Nat, LeaderboardEntry>> {
      factionBoards;
    };

    // Deprecated: kept for backward compatibility
    public func setCurrentSeason(seasonId : Nat) {
      currentSeasonId := seasonId;
    };

    public func setCurrentMonth(monthId : Nat) {
      currentMonthId := monthId;
    };

    // Get or create a leaderboard for a specific type
    private func getOrCreateBoard(lbType : LeaderboardType) : Map.Map<Nat, LeaderboardEntry> {
      switch (lbType) {
        case (#Monthly(monthId)) {
          switch (Map.get(monthlyBoards, nhash, monthId)) {
            case (?board) { board };
            case (null) {
              let newBoard = Map.new<Nat, LeaderboardEntry>();
              ignore Map.put(monthlyBoards, nhash, monthId, newBoard);
              newBoard;
            };
          };
        };
        case (#Season(seasonId)) {
          switch (Map.get(seasonBoards, nhash, seasonId)) {
            case (?board) { board };
            case (null) {
              let newBoard = Map.new<Nat, LeaderboardEntry>();
              ignore Map.put(seasonBoards, nhash, seasonId, newBoard);
              newBoard;
            };
          };
        };
        case (#AllTime) {
          allTimeBoard;
        };
        case (#Faction(faction)) {
          let factionKey = factionToText(faction);
          switch (Map.get(factionBoards, Map.thash, factionKey)) {
            case (?board) { board };
            case (null) {
              let newBoard = Map.new<Nat, LeaderboardEntry>();
              ignore Map.put(factionBoards, Map.thash, factionKey, newBoard);
              newBoard;
            };
          };
        };
        case (#Division(_)) {
          // Division leaderboards are filtered views of season boards
          getOrCreateBoard(#Season(currentSeasonId));
        };
      };
    };

    // Helper to convert faction to text key
    private func factionToText(faction : FactionType) : Text {
      switch (faction) {
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
    };

    // Record race result for leaderboard
    public func recordRaceResult(
      tokenIndex : Nat,
      owner : Principal,
      position : Nat,
      _totalRacers : Nat,
      earnings : Nat,
      pointsMultiplier : Float,
      faction : FactionType,
      raceTime : Int,
    ) {
      let points = getPointsForPosition(position, pointsMultiplier);
      let isWin = position == 1;
      let isPodium = position <= 3;

      // Calculate the correct period IDs from the race time
      let raceMonthId = getMonthIdFromTime(raceTime);
      let raceSeasonId = getSeasonIdFromTime(raceTime);

      // Update monthly leaderboard
      updateLeaderboardEntry(
        #Monthly(raceMonthId),
        tokenIndex,
        owner,
        points,
        isWin,
        isPodium,
        position,
        earnings,
        faction,
        raceTime,
      );

      // Update season leaderboard
      updateLeaderboardEntry(
        #Season(raceSeasonId),
        tokenIndex,
        owner,
        points,
        isWin,
        isPodium,
        position,
        earnings,
        faction,
        raceTime,
      );

      // Update all-time leaderboard
      updateLeaderboardEntry(
        #AllTime,
        tokenIndex,
        owner,
        points,
        isWin,
        isPodium,
        position,
        earnings,
        faction,
        raceTime,
      );

      // Update faction leaderboard
      updateLeaderboardEntry(
        #Faction(faction),
        tokenIndex,
        owner,
        points,
        isWin,
        isPodium,
        position,
        earnings,
        faction,
        raceTime,
      );
    };

    // Update a single leaderboard entry
    private func updateLeaderboardEntry(
      lbType : LeaderboardType,
      tokenIndex : Nat,
      owner : Principal,
      points : Nat,
      isWin : Bool,
      isPodium : Bool,
      position : Nat,
      earnings : Nat,
      _faction : FactionType,
      raceTime : Int,
    ) {
      let board = getOrCreateBoard(lbType);

      let existing = Map.get(board, nhash, tokenIndex);

      let entry = switch (existing) {
        case (?e) {
          // Update existing entry
          let newWins = if (isWin) { e.wins + 1 } else { e.wins };
          let newPodiums = if (isPodium) { e.podiums + 1 } else { e.podiums };
          let newRaces = e.races + 1;
          let newPoints = e.points + points;
          let newEarnings = e.totalEarnings + earnings;

          // Calculate new averages
          let totalPositions = (e.avgPosition * Float.fromInt(e.races)) + Float.fromInt(position);
          let newAvgPosition = totalPositions / Float.fromInt(newRaces);
          let newWinRate = Float.fromInt(newWins) / Float.fromInt(newRaces);

          // Calculate streak
          let newStreak = if (isWin) {
            if (e.currentStreak >= 0) { e.currentStreak + 1 } else { 1 };
          } else {
            if (e.currentStreak <= 0) { e.currentStreak - 1 } else { -1 };
          };

          {
            e with
            points = newPoints;
            wins = newWins;
            podiums = newPodiums;
            races = newRaces;
            winRate = newWinRate;
            avgPosition = newAvgPosition;
            totalEarnings = newEarnings;
            bestFinish = Nat.min(e.bestFinish, position);
            currentStreak = newStreak;
            lastRaceTime = raceTime;
            previousRank = ?e.rank; // Store old rank before recalculation
          };
        };
        case (null) {
          // Create new entry
          {
            tokenIndex = tokenIndex;
            owner = owner;
            points = points;
            wins = if (isWin) { 1 } else { 0 };
            podiums = if (isPodium) { 1 } else { 0 };
            races = 1;
            winRate = if (isWin) { 1.0 } else { 0.0 };
            avgPosition = Float.fromInt(position);
            totalEarnings = earnings;
            bestFinish = position;
            currentStreak = if (isWin) { 1 } else { -1 };
            rank = 0; // Will be calculated
            previousRank = null;
            trend = #New;
            lastRaceTime = raceTime;
          };
        };
      };

      ignore Map.put(board, nhash, tokenIndex, entry);
    };

    // Get leaderboard (sorted and ranked)
    public func getLeaderboard(
      lbType : LeaderboardType,
      limit : ?Nat,
      bracket : ?RaceClass,
    ) : [LeaderboardEntry] {
      let board = getOrCreateBoard(lbType);
      var entries = Iter.toArray(Map.vals(board));

      // Filter by bracket if specified
      entries := switch (bracket) {
        case (?b) {
          Array.filter<LeaderboardEntry>(entries, func(e) { getRaceClassCallback(e.tokenIndex) == b });
        };
        case (null) { entries };
      };

      // Sort by points (descending), then by wins, then by win rate
      entries := Array.sort<LeaderboardEntry>(
        entries,
        func(a, b) {
          if (a.points != b.points) {
            Nat.compare(b.points, a.points) // Descending
          } else if (a.wins != b.wins) {
            Nat.compare(b.wins, a.wins);
          } else {
            Float.compare(b.winRate, a.winRate);
          };
        },
      );

      // Assign ranks and calculate trends
      entries := Array.mapEntries<LeaderboardEntry, LeaderboardEntry>(
        entries,
        func(entry, index) {
          let newRank = index + 1;
          let trend = switch (entry.previousRank) {
            case (?prevRank) {
              if (newRank < prevRank) {
                #Up(Int.abs(prevRank - newRank));
              } else if (newRank > prevRank) {
                #Down(Int.abs(newRank - prevRank));
              } else {
                #Stable;
              };
            };
            case (null) { #New };
          };

          {
            entry with
            rank = newRank;
            trend = trend;
          };
        },
      );

      // Update ranks in storage
      for (entry in entries.vals()) {
        ignore Map.put(board, nhash, entry.tokenIndex, entry);
      };

      // Apply limit if specified
      switch (limit) {
        case (?l) {
          if (l < entries.size()) {
            Array.tabulate<LeaderboardEntry>(l, func(i) { entries[i] });
          } else {
            entries;
          };
        };
        case (null) { entries };
      };
    };

    // Get entry for specific bot
    public func getEntryForBot(lbType : LeaderboardType, tokenIndex : Nat) : ?LeaderboardEntry {
      let board = getOrCreateBoard(lbType);
      Map.get(board, nhash, tokenIndex);
    };

    // Get rank for specific bot
    public func getRankForBot(lbType : LeaderboardType, tokenIndex : Nat) : ?Nat {
      let leaderboard = getLeaderboard(lbType, null, null);
      let found = Array.find<LeaderboardEntry>(
        leaderboard,
        func(e) { e.tokenIndex == tokenIndex },
      );
      switch (found) {
        case (?entry) { ?entry.rank };
        case (null) { null };
      };
    };

    // Get top N qualifiers for championship
    public func getTopQualifiers(seasonId : Nat, division : RaceClass, count : Nat) : [Nat] {
      let leaderboard = getLeaderboard(#Season(seasonId), ?count, ?division);
      Array.map<LeaderboardEntry, Nat>(
        leaderboard,
        func(e) { e.tokenIndex },
      );
    };

    // Reset monthly leaderboard (called at start of new month)
    public func resetMonthlyLeaderboard(newMonthId : Nat) {
      currentMonthId := newMonthId;
      let newBoard = Map.new<Nat, LeaderboardEntry>();
      ignore Map.put(monthlyBoards, nhash, newMonthId, newBoard);
    };

    // Start new season
    public func startNewSeason(newSeasonId : Nat) {
      currentSeasonId := newSeasonId;
      let newBoard = Map.new<Nat, LeaderboardEntry>();
      ignore Map.put(seasonBoards, nhash, newSeasonId, newBoard);
    };

    // Clear all leaderboards (used when recalculating from scratch)
    public func clearAllLeaderboards() {
      // Clear all monthly boards
      for ((monthId, _board) in Map.entries(monthlyBoards)) {
        ignore Map.remove(monthlyBoards, nhash, monthId);
      };

      // Clear all season boards
      for ((seasonId, _board) in Map.entries(seasonBoards)) {
        ignore Map.remove(seasonBoards, nhash, seasonId);
      };

      // Clear all-time board
      for ((tokenIndex, _entry) in Map.entries(allTimeBoard)) {
        ignore Map.remove(allTimeBoard, nhash, tokenIndex);
      };

      // Clear all faction boards
      for ((factionKey, board) in Map.entries(factionBoards)) {
        for ((tokenIndex, _entry) in Map.entries(board)) {
          ignore Map.remove(board, nhash, tokenIndex);
        };
      };
    };
  };
};
