import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Map "mo:map/Map";
import { nhash; phash } "mo:map/Map";
import BettingTypes "./BettingTypes";
import RacingSimulator "./RacingSimulator";

/// BettingManager - Pari-mutuel betting system for PokedBots races
/// Handles pool creation, bet placement, odds calculation, and settlement
module {

  type BettingPool = BettingTypes.BettingPool;
  type Bet = BettingTypes.Bet;
  type BetType = BettingTypes.BetType;
  type BetStatus = BettingTypes.BetStatus;
  type PoolStatus = BettingTypes.PoolStatus;
  type RaceResults = BettingTypes.RaceResults;
  type Odds = BettingTypes.Odds;
  type PayoutCalculation = BettingTypes.PayoutCalculation;
  type FailedPayout = BettingTypes.FailedPayout;
  type UserBettingStats = BettingTypes.UserBettingStats;
  type BetTypeStats = BettingTypes.BetTypeStats;
  type Race = RacingSimulator.Race;

  // Constants
  private let RAKE_PERCENT : Float = 0.10; // 10% rake
  private let RACING_RAKE_SHARE : Float = 0.80; // 80% of rake to racing (8% of total)
  private let PLATFORM_RAKE_SHARE : Float = 0.20; // 20% of rake to platform (2% of total)
  private let MIN_BET : Nat = 10_000_000; // 0.1 ICP (e8s)
  private let MAX_BET : Nat = 10_000_000_000; // 100 ICP (e8s)
  private let MAX_BET_PER_RACE : Nat = 10_000_000_000; // 100 ICP total per user per race
  private let ICP_TRANSFER_FEE : Nat = 10_000; // 0.0001 ICP (e8s)

  public class BettingManager(
    pools : Map.Map<Nat, BettingPool>,
    bets : Map.Map<Nat, Bet>,
    userBets : Map.Map<Principal, [Nat]>,
    userStats : Map.Map<Principal, UserBettingStats>,
    nextBetIdVar : Nat,
    platformTreasury : Principal,
    icpLedgerPrincipal : Principal,
  ) {

    // Use provided stable maps directly
    private var nextBetId : Nat = nextBetIdVar;

    // ===== SUBACCOUNT UTILITIES =====

    /// Derive a unique 32-byte subaccount for a race's betting pool
    public func getPoolSubaccount(raceId : Nat) : Blob {
      let bytes = Buffer.Buffer<Nat8>(32);

      // Encode raceId into first 8 bytes (big-endian Nat64)
      let raceIdNat64 = Nat64.fromNat(raceId);
      bytes.add(Nat8.fromNat(Nat64.toNat((raceIdNat64 >> 56) & 0xFF)));
      bytes.add(Nat8.fromNat(Nat64.toNat((raceIdNat64 >> 48) & 0xFF)));
      bytes.add(Nat8.fromNat(Nat64.toNat((raceIdNat64 >> 40) & 0xFF)));
      bytes.add(Nat8.fromNat(Nat64.toNat((raceIdNat64 >> 32) & 0xFF)));
      bytes.add(Nat8.fromNat(Nat64.toNat((raceIdNat64 >> 24) & 0xFF)));
      bytes.add(Nat8.fromNat(Nat64.toNat((raceIdNat64 >> 16) & 0xFF)));
      bytes.add(Nat8.fromNat(Nat64.toNat((raceIdNat64 >> 8) & 0xFF)));
      bytes.add(Nat8.fromNat(Nat64.toNat(raceIdNat64 & 0xFF)));

      // Add identifier for betting pool (vs other subaccount types)
      bytes.add(0x42); // 'B' for Betting
      bytes.add(0x45); // 'E'
      bytes.add(0x54); // 'T'

      // Pad remaining bytes with zeros to reach 32 bytes
      while (bytes.size() < 32) {
        bytes.add(0);
      };

      Blob.fromArray(Buffer.toArray(bytes));
    };

    // ===== POOL MANAGEMENT =====

    /// Create a new betting pool for a race
    public func createPool(race : Race) : Result.Result<BettingPool, Text> {
      // Check if pool already exists
      switch (Map.get(pools, nhash, race.raceId)) {
        case (?existing) {
          return #err("Pool already exists for race " # Nat.toText(race.raceId));
        };
        case null {};
      };

      // Extract entrant token indices
      let entrants = Array.map<RacingSimulator.RaceEntry, Nat>(
        race.entries,
        func(entry) : Nat {
          // nftId is just the token index as text (e.g., "182")
          Option.get(Nat.fromText(entry.nftId), 0);
        },
      );

      let raceClassText = switch (race.raceClass) {
        case (#Scrap) "Scrap";
        case (#Junker) "Junker";
        case (#Raider) "Raider";
        case (#Elite) "Elite";
        case (#SilentKlan) "SilentKlan";
      };

      let terrainText = switch (race.terrain) {
        case (#ScrapHeaps) "ScrapHeaps";
        case (#WastelandSand) "WastelandSand";
        case (#MetalRoads) "MetalRoads";
      };

      // Determine pool status based on current time
      let now = Time.now();
      let poolStatus = if (now < race.entryDeadline) {
        #Pending; // Registration still open, betting not yet available
      } else if (now >= race.entryDeadline and now < race.startTime) {
        #Open; // Registration closed, betting window active
      } else {
        #Closed; // Race has started
      };

      let pool : BettingPool = {
        raceId = race.raceId;
        subaccount = getPoolSubaccount(race.raceId);
        status = poolStatus;
        entrants = entrants;
        raceClass = raceClassText;
        distance = race.distance;
        terrain = terrainText;
        winPool = 0;
        placePool = 0;
        showPool = 0;
        totalPooled = 0;
        winBetsByBot = [];
        placeBetsByBot = [];
        showBetsByBot = [];
        betIds = [];
        bettingOpensAt = race.entryDeadline;
        bettingClosesAt = race.startTime;
        results = null;
        payoutsCompleted = false;
        failedPayouts = [];
        rakeDistributed = false;
      };

      Map.set(pools, nhash, race.raceId, pool);
      #ok(pool);
    };

    /// Get a betting pool by race ID
    public func getPool(raceId : Nat) : ?BettingPool {
      Map.get(pools, nhash, raceId);
    };

    /// Get all pools with optional status filter
    public func listPools(statusFilter : ?PoolStatus, limit : Nat) : [BettingPool] {
      let allPools = Iter.toArray(Map.vals(pools));

      let filtered = switch (statusFilter) {
        case null { allPools };
        case (?status) {
          Array.filter<BettingPool>(allPools, func(p) { p.status == status });
        };
      };

      let sorted = Array.sort<BettingPool>(
        filtered,
        func(a, b) { Int.compare(b.bettingOpensAt, a.bettingOpensAt) },
      );

      if (sorted.size() <= limit) {
        sorted;
      } else {
        Array.tabulate<BettingPool>(limit, func(i) { sorted[i] });
      };
    };

    /// Close betting for a pool (called when race starts)
    public func closePool(raceId : Nat) : Result.Result<(), Text> {
      switch (Map.get(pools, nhash, raceId)) {
        case null { #err("Pool not found") };
        case (?pool) {
          if (pool.status != #Open) {
            return #err("Pool is not open");
          };

          let updatedPool = {
            pool with
            status = #Closed;
          };

          Map.set(pools, nhash, raceId, updatedPool);
          #ok();
        };
      };
    };

    /// Open betting for a pool (called when registration closes)
    public func openPool(raceId : Nat) : Result.Result<(), Text> {
      switch (Map.get(pools, nhash, raceId)) {
        case null { #err("Pool not found") };
        case (?pool) {
          if (pool.status != #Pending) {
            return #err("Pool is not pending");
          };

          let updatedPool = {
            pool with
            status = #Open;
          };

          Map.set(pools, nhash, raceId, updatedPool);
          #ok();
        };
      };
    };

    // ===== BET PLACEMENT =====

    /// Place a bet on a bot in a race
    /// Note: Caller must handle ICRC-2 transfer before calling this
    public func placeBet(
      userId : Principal,
      raceId : Nat,
      tokenIndex : Nat,
      betType : BetType,
      amount : Nat,
    ) : Result.Result<Nat, Text> {

      // Validate amount
      if (amount < MIN_BET) {
        return #err("Minimum bet is 0.1 ICP");
      };
      if (amount > MAX_BET) {
        return #err("Maximum bet is 100 ICP");
      };

      // Get pool
      let pool = switch (Map.get(pools, nhash, raceId)) {
        case null { return #err("Betting pool not found") };
        case (?p) { p };
      };

      // Check pool status
      if (pool.status != #Open) {
        return #err("Betting is not open for this race");
      };

      // Check timing
      let now = Time.now();
      if (now < pool.bettingOpensAt) {
        return #err("Betting has not opened yet");
      };
      if (now >= pool.bettingClosesAt) {
        return #err("Betting has closed");
      };

      // Check bot is in race
      let botInRace = Array.find<Nat>(pool.entrants, func(idx) { idx == tokenIndex });
      if (botInRace == null) {
        return #err("Bot is not entered in this race");
      };

      // Check user's total bets for this race
      let userBetsForRace = getUserBetsForRace(userId, raceId);
      var totalBetAmount : Nat = 0;
      for (betId in userBetsForRace.vals()) {
        switch (Map.get(bets, nhash, betId)) {
          case (?bet) { totalBetAmount += bet.amount };
          case null {};
        };
      };

      if (totalBetAmount + amount > MAX_BET_PER_RACE) {
        return #err("Maximum 100 ICP total per race");
      };

      // Create bet
      let betId = nextBetId;
      nextBetId += 1;

      let bet : Bet = {
        betId = betId;
        userId = userId;
        raceId = raceId;
        tokenIndex = tokenIndex;
        betType = betType;
        amount = amount;
        timestamp = now;
        potentialPayout = null;
        status = #Pending;
        paid = false;
      };

      Map.set(bets, nhash, betId, bet);

      // Update user bets index
      let existingBets = Option.get(Map.get(userBets, phash, userId), []);
      Map.set(userBets, phash, userId, Array.append(existingBets, [betId]));

      // Update pool
      let updatedBetIds = Array.append(pool.betIds, [betId]);

      let updatedPool = switch (betType) {
        case (#Win) {
          {
            pool with
            winPool = pool.winPool + amount;
            totalPooled = pool.totalPooled + amount;
            winBetsByBot = updateBotBets(pool.winBetsByBot, tokenIndex, amount);
            betIds = updatedBetIds;
          };
        };
        case (#Place) {
          {
            pool with
            placePool = pool.placePool + amount;
            totalPooled = pool.totalPooled + amount;
            placeBetsByBot = updateBotBets(pool.placeBetsByBot, tokenIndex, amount);
            betIds = updatedBetIds;
          };
        };
        case (#Show) {
          {
            pool with
            showPool = pool.showPool + amount;
            totalPooled = pool.totalPooled + amount;
            showBetsByBot = updateBotBets(pool.showBetsByBot, tokenIndex, amount);
            betIds = updatedBetIds;
          };
        };
      };

      Map.set(pools, nhash, raceId, updatedPool);

      #ok(betId);
    };

    /// Helper to update bot bets array
    private func updateBotBets(botBets : [(Nat, Nat)], tokenIndex : Nat, amount : Nat) : [(Nat, Nat)] {
      let buffer = Buffer.Buffer<(Nat, Nat)>(botBets.size() + 1);
      var found = false;

      for ((idx, total) in botBets.vals()) {
        if (idx == tokenIndex) {
          buffer.add((idx, total + amount));
          found := true;
        } else {
          buffer.add((idx, total));
        };
      };

      if (not found) {
        buffer.add((tokenIndex, amount));
      };

      Buffer.toArray(buffer);
    };

    /// Get user's bet IDs for a specific race
    /// Get user's bets for a specific race (returns bet IDs)
    public func getUserBetsForRace(userId : Principal, raceId : Nat) : [Nat] {
      let allUserBets = Option.get(Map.get(userBets, phash, userId), []);
      Array.filter<Nat>(
        allUserBets,
        func(betId) {
          switch (Map.get(bets, nhash, betId)) {
            case (?bet) { bet.raceId == raceId };
            case null { false };
          };
        },
      );
    };

    /// Get user's bet objects for a specific race
    public func getUserBetsForRaceDetailed(userId : Principal, raceId : Nat) : [Bet] {
      let betIds = getUserBetsForRace(userId, raceId);
      let betBuffer = Buffer.Buffer<Bet>(0);
      for (betId in betIds.vals()) {
        switch (Map.get(bets, nhash, betId)) {
          case (?bet) { betBuffer.add(bet) };
          case (null) {};
        };
      };
      Buffer.toArray(betBuffer);
    };

    // ===== ODDS CALCULATION =====

    /// Calculate current odds for all bots in a pool
    public func calculateAllOdds(raceId : Nat) : [Odds] {
      switch (Map.get(pools, nhash, raceId)) {
        case null { [] };
        case (?pool) {
          Array.map<Nat, Odds>(
            pool.entrants,
            func(tokenIndex) {
              calculateBotOdds(pool, tokenIndex);
            },
          );
        };
      };
    };

    /// Calculate odds for a specific bot and bet type
    public func calculateOdds(raceId : Nat, tokenIndex : Nat, betType : BetType) : Float {
      switch (Map.get(pools, nhash, raceId)) {
        case null { 0.0 };
        case (?pool) {
          let odds = calculateBotOdds(pool, tokenIndex);
          switch (betType) {
            case (#Win) { odds.winOdds };
            case (#Place) { odds.placeOdds };
            case (#Show) { odds.showOdds };
          };
        };
      };
    };

    /// Calculate odds for a specific bot
    private func calculateBotOdds(pool : BettingPool, tokenIndex : Nat) : Odds {
      let winBetTotal = getBotBetTotal(pool.winBetsByBot, tokenIndex);
      let placeBetTotal = getBotBetTotal(pool.placeBetsByBot, tokenIndex);
      let showBetTotal = getBotBetTotal(pool.showBetsByBot, tokenIndex);

      // Calculate odds (payout multiplier)
      let winOdds = if (winBetTotal == 0 or pool.winPool == 0) {
        0.0;
      } else {
        let netPool = Float.fromInt(pool.winPool) * (1.0 - RAKE_PERCENT);
        netPool / Float.fromInt(winBetTotal);
      };

      let placeOdds = if (placeBetTotal == 0 or pool.placePool == 0) {
        0.0;
      } else {
        let netPool = Float.fromInt(pool.placePool) * (1.0 - RAKE_PERCENT);
        netPool / Float.fromInt(placeBetTotal);
      };

      let showOdds = if (showBetTotal == 0 or pool.showPool == 0) {
        0.0;
      } else {
        let netPool = Float.fromInt(pool.showPool) * (1.0 - RAKE_PERCENT);
        netPool / Float.fromInt(showBetTotal);
      };

      {
        tokenIndex = tokenIndex;
        winOdds = winOdds;
        placeOdds = placeOdds;
        showOdds = showOdds;
        winPool = winBetTotal;
        placePool = placeBetTotal;
        showPool = showBetTotal;
      };
    };

    /// Get total bets on a bot
    private func getBotBetTotal(botBets : [(Nat, Nat)], tokenIndex : Nat) : Nat {
      switch (Array.find<(Nat, Nat)>(botBets, func((idx, _)) { idx == tokenIndex })) {
        case (?(_, total)) { total };
        case null { 0 };
      };
    };

    // ===== SETTLEMENT =====

    /// Settle bets for a completed race
    /// Returns (successful payouts, failed payouts, total rake)
    public func settleBets(
      raceId : Nat,
      rankings : [Nat],
    ) : async Result.Result<(Nat, Nat, Nat), Text> {
      let pool = switch (Map.get(pools, nhash, raceId)) {
        case (?p) { p };
        case null { return #err("Pool not found") };
      };

      // Can only settle closed pools
      if (pool.status != #Closed) {
        return #err("Pool must be closed before settlement");
      };

      // Get all bets for this pool
      let allBets = Buffer.Buffer<Bet>(0);
      for ((betId, bet) in Map.entries(bets)) {
        if (bet.raceId == raceId) {
          allBets.add(bet);
        };
      };

      let betsList = Buffer.toArray(allBets);

      // Calculate total rake (10%)
      let totalPooled = pool.winPool + pool.placePool + pool.showPool;
      let totalRakeFloat = Float.fromInt(totalPooled) * RAKE_PERCENT;
      let totalRake = Int.abs(Float.toInt(totalRakeFloat));

      // Calculate net pools after rake (90% of each pool)
      let netWinPool = Int.abs(Float.toInt(Float.fromInt(pool.winPool) * (1.0 - RAKE_PERCENT)));
      let netPlacePool = Int.abs(Float.toInt(Float.fromInt(pool.placePool) * (1.0 - RAKE_PERCENT)));
      let netShowPool = Int.abs(Float.toInt(Float.fromInt(pool.showPool) * (1.0 - RAKE_PERCENT)));

      // Determine winners
      let winner = if (rankings.size() > 0) { rankings[0] } else { 0 };
      let top3 = if (rankings.size() >= 3) {
        [rankings[0], rankings[1], rankings[2]];
      } else {
        rankings;
      };
      let top5 = if (rankings.size() >= 5) {
        [rankings[0], rankings[1], rankings[2], rankings[3], rankings[4]];
      } else {
        rankings;
      };

      // Check if anyone bet on the winners (for refund scenarios)
      var totalWinBetsOnWinner : Nat = 0;
      var totalPlaceBetsOnTop3 : Nat = 0;
      var totalShowBetsOnTop5 : Nat = 0;

      for (bet in betsList.vals()) {
        switch (bet.betType) {
          case (#Win) {
            if (bet.tokenIndex == winner) {
              totalWinBetsOnWinner += bet.amount;
            };
          };
          case (#Place) {
            let inTop3 = Array.find<Nat>(top3, func(t) { t == bet.tokenIndex });
            if (inTop3 != null) {
              totalPlaceBetsOnTop3 += bet.amount;
            };
          };
          case (#Show) {
            let inTop5 = Array.find<Nat>(top5, func(t) { t == bet.tokenIndex });
            if (inTop5 != null) {
              totalShowBetsOnTop5 += bet.amount;
            };
          };
        };
      };

      // Calculate payouts for each bet
      var successfulPayouts = 0;
      var failedPayouts = 0;

      for (bet in betsList.vals()) {
        var payout : Nat = 0;
        var isWinner = false;
        var isRefund = false;

        switch (bet.betType) {
          case (#Win) {
            if (bet.tokenIndex == winner) {
              // Win bet on actual winner - payout if others also bet on winner
              if (totalWinBetsOnWinner > 0) {
                payout := (bet.amount * netWinPool) / totalWinBetsOnWinner;
                isWinner := true;
              };
            } else if (totalWinBetsOnWinner == 0) {
              // No one bet on winner - refund all Win bets
              payout := bet.amount;
              isRefund := true;
            };
          };
          case (#Place) {
            // Check if bot finished in top 3
            let inTop3 = Array.find<Nat>(top3, func(t) { t == bet.tokenIndex });
            if (inTop3 != null) {
              // Place bet on top 3 finisher - payout if others also bet on top 3
              if (totalPlaceBetsOnTop3 > 0) {
                payout := (bet.amount * netPlacePool) / totalPlaceBetsOnTop3;
                isWinner := true;
              };
            } else if (totalPlaceBetsOnTop3 == 0) {
              // No one bet on top 3 - refund all Place bets
              payout := bet.amount;
              isRefund := true;
            };
          };
          case (#Show) {
            // Check if bot finished in top 5
            let inTop5 = Array.find<Nat>(top5, func(t) { t == bet.tokenIndex });
            if (inTop5 != null) {
              // Show bet on top 5 finisher - payout if others also bet on top 5
              if (totalShowBetsOnTop5 > 0) {
                payout := (bet.amount * netShowPool) / totalShowBetsOnTop5;
                isWinner := true;
              };
            } else if (totalShowBetsOnTop5 == 0) {
              // No one bet on top 5 - refund all Show bets
              payout := bet.amount;
              isRefund := true;
            };
          };
        };

        // Update bet status and payout
        let status = if (isWinner) {
          #Won;
        } else if (isRefund) {
          #Refunded;
        } else {
          #Lost;
        };

        let updatedBet = {
          bet with
          status = status;
          potentialPayout = if (isWinner or isRefund) { ?payout } else { null };
        };
        ignore Map.put(bets, nhash, bet.betId, updatedBet);

        // If winner or refund, attempt payout
        if ((isWinner or isRefund) and payout > ICP_TRANSFER_FEE) {
          try {
            // Create actor reference to ICP Ledger
            let ledger = actor (Principal.toText(icpLedgerPrincipal)) : actor {
              icrc1_transfer : shared {
                from_subaccount : ?Blob;
                to : { owner : Principal; subaccount : ?Blob };
                amount : Nat;
                fee : ?Nat;
                memo : ?Blob;
                created_at_time : ?Nat64;
              } -> async {
                #Ok : Nat;
                #Err : {
                  #BadFee : { expected_fee : Nat };
                  #BadBurn : { min_burn_amount : Nat };
                  #InsufficientFunds : { balance : Nat };
                  #TooOld;
                  #CreatedInFuture : { ledger_time : Nat64 };
                  #Duplicate : { duplicate_of : Nat };
                  #TemporarilyUnavailable;
                  #GenericError : { error_code : Nat; message : Text };
                };
              };
            };

            // Subtract fee from payout so user receives (payout - fee) and pool is debited exactly payout
            let amountToSend = Int.abs(payout - ICP_TRANSFER_FEE);

            let poolSubaccount = getPoolSubaccount(raceId);
            let transferResult = await ledger.icrc1_transfer({
              from_subaccount = ?poolSubaccount;
              to = { owner = bet.userId; subaccount = null };
              amount = amountToSend;
              fee = ?ICP_TRANSFER_FEE;
              memo = null;
              created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            });

            switch (transferResult) {
              case (#Ok(_)) {
                successfulPayouts += 1;
              };
              case (#Err(_)) {
                failedPayouts += 1;
              };
            };
          } catch (_) {
            failedPayouts += 1;
          };
        };
      };

      // Update pool status to settled
      let settledPool = {
        pool with
        status = #Settled;
      };
      ignore Map.put(pools, nhash, raceId, settledPool);

      #ok(successfulPayouts, failedPayouts, totalRake);
    };

    // ===== GETTERS =====

    public func getBet(betId : Nat) : ?Bet {
      Map.get(bets, nhash, betId);
    };

    public func getUserBets(userId : Principal, limit : Nat) : [Bet] {
      let betIds = Option.get(Map.get(userBets, phash, userId), []);
      let userBetsArray = Array.mapFilter<Nat, Bet>(
        betIds,
        func(id) {
          Map.get(bets, nhash, id);
        },
      );

      let sorted = Array.sort<Bet>(
        userBetsArray,
        func(a, b) { Int.compare(b.timestamp, a.timestamp) },
      );

      if (sorted.size() <= limit) {
        sorted;
      } else {
        Array.tabulate<Bet>(limit, func(i) { sorted[i] });
      };
    };

    public func getUserBetsPaginated(userId : Principal, limit : Nat, offset : Nat) : {
      bets : [Bet];
      hasMore : Bool;
      total : Nat;
    } {
      let betIds = Option.get(Map.get(userBets, phash, userId), []);
      let userBetsArray = Array.mapFilter<Nat, Bet>(
        betIds,
        func(id) {
          Map.get(bets, nhash, id);
        },
      );

      let sorted = Array.sort<Bet>(
        userBetsArray,
        func(a, b) { Int.compare(b.timestamp, a.timestamp) },
      );

      let total = sorted.size();
      let endIndex = Nat.min(offset + limit, total);
      let hasMore = endIndex < total;

      if (offset >= total) {
        { bets = []; hasMore = false; total = total };
      } else {
        let pageBets = Array.tabulate<Bet>(
          endIndex - offset,
          func(i) { sorted[offset + i] },
        );
        { bets = pageBets; hasMore = hasMore; total = total };
      };
    };

    public func getUserStats(userId : Principal) : ?UserBettingStats {
      Map.get(userStats, phash, userId);
    };

    public func getNextBetId() : Nat {
      nextBetId;
    };

    public func setNextBetId(id : Nat) {
      nextBetId := id;
    };

    // Public getters for maps (needed for paginated endpoint)
    public func getUserBetsMap() : Map.Map<Principal, [Nat]> {
      userBets;
    };

    public func getBetsMap() : Map.Map<Nat, Bet> {
      bets;
    };

    public func getPrincipalHash() : Map.HashUtils<Principal> {
      phash;
    };

    public func getNatHash() : Map.HashUtils<Nat> {
      nhash;
    };
  };
};
