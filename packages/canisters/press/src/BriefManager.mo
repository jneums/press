import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Map "mo:map/Map";
import { nhash; thash; phash } "mo:map/Map";
import SHA256 "mo:sha2/Sha256";

import PressTypes "./PressTypes";

module {
  type Brief = PressTypes.Brief;
  type BriefStatus = PressTypes.BriefStatus;
  type CuratorStats = PressTypes.CuratorStats;

  /// Manager for Brief lifecycle
  public class BriefManager(
    briefs : Map.Map<Text, Brief>,
    curatorStats : Map.Map<Principal, CuratorStats>,
    icpLedgerPrincipal : Principal,
    canisterPrincipal : Principal,
    nextBriefIdVar : Nat,
  ) {
    private var nextBriefId : Nat = nextBriefIdVar;

    /// Generate a subaccount for a brief's escrow
    /// Uses SHA256 hash of brief ID to ensure unique 32-byte subaccount
    public func briefIdToSubaccount(briefId : Text) : Blob {
      let idBytes = Blob.toArray(Text.encodeUtf8(briefId));
      let hash = SHA256.fromBlob(#sha256, Blob.fromArray(idBytes));
      hash;
    };

    /// Create a new brief
    /// Returns the brief ID and escrow subaccount for funding
    public func createBrief(
      curator : Principal,
      title : Text,
      description : Text,
      topic : Text,
      requirements : PressTypes.BriefRequirements,
      bountyPerArticle : Nat,
      maxArticles : Nat,
      expiresAt : ?Time.Time,
      initialEscrowBalance : Nat,
      isRecurring : Bool,
      recurrenceIntervalNanos : ?Nat,
    ) : Result.Result<{ briefId : Text; subaccount : Blob }, Text> {

      let now = Time.now();
      let briefId = Nat.toText(nextBriefId);
      nextBriefId += 1;

      let subaccount = briefIdToSubaccount(briefId);

      let brief : Brief = {
        briefId = briefId;
        curator = curator;
        title = title;
        description = description;
        topic = topic;
        requirements = requirements;
        bountyPerArticle = bountyPerArticle;
        maxArticles = maxArticles;
        submittedCount = 0;
        approvedCount = 0;
        status = #open;
        createdAt = now;
        expiresAt = expiresAt;
        escrowSubaccount = subaccount;
        escrowBalance = initialEscrowBalance;
        isRecurring = isRecurring;
        recurrenceIntervalNanos = recurrenceIntervalNanos;
      };

      ignore Map.put(briefs, thash, briefId, brief);

      // Update curator stats
      let stats = switch (Map.get(curatorStats, phash, curator)) {
        case (?existing) {
          let updated : CuratorStats = {
            curator = curator;
            briefsCreated = existing.briefsCreated + 1;
            articlesReviewed = existing.articlesReviewed;
            articlesApproved = existing.articlesApproved;
            articlesRejected = existing.articlesRejected;
            totalBountiesPaid = existing.totalBountiesPaid;
            totalEscrowed = existing.totalEscrowed;
            averageReviewTime = existing.averageReviewTime;
            firstBrief = existing.firstBrief;
            lastActivity = now;
          };
          updated;
        };
        case null {
          let newStats : CuratorStats = {
            curator = curator;
            briefsCreated = 1;
            articlesReviewed = 0;
            articlesApproved = 0;
            articlesRejected = 0;
            totalBountiesPaid = 0;
            totalEscrowed = 0;
            averageReviewTime = 0;
            firstBrief = now;
            lastActivity = now;
          };
          newStats;
        };
      };
      ignore Map.put(curatorStats, phash, curator, stats);

      #ok({ briefId = briefId; subaccount = subaccount });
    };

    /// Renew a recurring brief (reset counts, update expiry)
    public func renewRecurringBrief(briefId : Text) : Result.Result<(), Text> {
      switch (Map.get(briefs, thash, briefId)) {
        case null { #err("Brief not found") };
        case (?brief) {
          if (not brief.isRecurring) {
            return #err("Brief is not recurring");
          };

          let intervalNanos = switch (brief.recurrenceIntervalNanos) {
            case null { return #err("Recurrence interval not set") };
            case (?interval) { interval };
          };

          let now = Time.now();

          // Calculate required escrow for new cycle
          let requiredEscrow = brief.bountyPerArticle * brief.maxArticles;

          // Check if enough escrow balance remains
          if (brief.escrowBalance < requiredEscrow) {
            // Not enough funds, close the brief
            let closedBrief : Brief = {
              briefId = brief.briefId;
              curator = brief.curator;
              title = brief.title;
              description = brief.description;
              topic = brief.topic;
              requirements = brief.requirements;
              bountyPerArticle = brief.bountyPerArticle;
              maxArticles = brief.maxArticles;
              submittedCount = brief.submittedCount;
              approvedCount = brief.approvedCount;
              status = #closed;
              createdAt = brief.createdAt;
              expiresAt = brief.expiresAt;
              escrowSubaccount = brief.escrowSubaccount;
              escrowBalance = brief.escrowBalance;
              isRecurring = brief.isRecurring;
              recurrenceIntervalNanos = brief.recurrenceIntervalNanos;
            };
            ignore Map.put(briefs, thash, briefId, closedBrief);
            return #err("Insufficient escrow for renewal, brief closed");
          };

          // Renew the brief - reset counts and update expiry
          let renewedBrief : Brief = {
            briefId = brief.briefId;
            curator = brief.curator;
            title = brief.title;
            description = brief.description;
            topic = brief.topic;
            requirements = brief.requirements;
            bountyPerArticle = brief.bountyPerArticle;
            maxArticles = brief.maxArticles;
            submittedCount = 0; // Reset
            approvedCount = 0; // Reset
            status = #open;
            createdAt = brief.createdAt;
            expiresAt = ?(now + intervalNanos); // Set new expiry
            escrowSubaccount = brief.escrowSubaccount;
            escrowBalance = brief.escrowBalance; // Keep existing balance
            isRecurring = brief.isRecurring;
            recurrenceIntervalNanos = brief.recurrenceIntervalNanos;
          };

          ignore Map.put(briefs, thash, briefId, renewedBrief);
          #ok();
        };
      };
    };

    /// Update brief escrow balance after deposit detected
    public func updateEscrowBalance(briefId : Text, newBalance : Nat) : Result.Result<(), Text> {
      switch (Map.get(briefs, thash, briefId)) {
        case (?brief) {
          let updated = {
            briefId = brief.briefId;
            curator = brief.curator;
            title = brief.title;
            description = brief.description;
            topic = brief.topic;
            requirements = brief.requirements;
            bountyPerArticle = brief.bountyPerArticle;
            maxArticles = brief.maxArticles;
            submittedCount = brief.submittedCount;
            approvedCount = brief.approvedCount;
            status = brief.status;
            createdAt = brief.createdAt;
            expiresAt = brief.expiresAt;
            escrowSubaccount = brief.escrowSubaccount;
            escrowBalance = newBalance;
            isRecurring = brief.isRecurring;
            recurrenceIntervalNanos = brief.recurrenceIntervalNanos;
          };
          ignore Map.put(briefs, thash, briefId, updated);
          #ok();
        };
        case null {
          #err("Brief not found");
        };
      };
    };

    /// Deduct amount from brief escrow balance (after payment)
    public func deductFromEscrow(briefId : Text, amount : Nat) : Result.Result<(), Text> {
      switch (Map.get(briefs, thash, briefId)) {
        case (?brief) {
          if (brief.escrowBalance < amount) {
            return #err("Insufficient escrow balance");
          };

          let newBalance = brief.escrowBalance - amount;

          let updated = {
            briefId = brief.briefId;
            curator = brief.curator;
            title = brief.title;
            description = brief.description;
            topic = brief.topic;
            requirements = brief.requirements;
            bountyPerArticle = brief.bountyPerArticle;
            maxArticles = brief.maxArticles;
            submittedCount = brief.submittedCount;
            approvedCount = brief.approvedCount;
            status = brief.status;
            createdAt = brief.createdAt;
            expiresAt = brief.expiresAt;
            escrowSubaccount = brief.escrowSubaccount;
            escrowBalance = newBalance;
            isRecurring = brief.isRecurring;
            recurrenceIntervalNanos = brief.recurrenceIntervalNanos;
          };
          ignore Map.put(briefs, thash, briefId, updated);

          // Update curator total escrowed
          switch (Map.get(curatorStats, phash, brief.curator)) {
            case (?stats) {
              let updatedStats : CuratorStats = {
                curator = stats.curator;
                briefsCreated = stats.briefsCreated;
                articlesReviewed = stats.articlesReviewed;
                articlesApproved = stats.articlesApproved;
                articlesRejected = stats.articlesRejected;
                totalBountiesPaid = stats.totalBountiesPaid;
                totalEscrowed = stats.totalEscrowed - amount;
                averageReviewTime = stats.averageReviewTime;
                firstBrief = stats.firstBrief;
                lastActivity = stats.lastActivity;
              };
              ignore Map.put(curatorStats, phash, brief.curator, updatedStats);
            };
            case null {};
          };

          #ok();
        };
        case null {
          #err("Brief not found");
        };
      };
    };

    /// Record that an article was submitted
    public func recordSubmission(briefId : Text) : Result.Result<(), Text> {
      switch (Map.get(briefs, thash, briefId)) {
        case (?brief) {
          let updated = {
            briefId = brief.briefId;
            curator = brief.curator;
            title = brief.title;
            description = brief.description;
            topic = brief.topic;
            requirements = brief.requirements;
            bountyPerArticle = brief.bountyPerArticle;
            maxArticles = brief.maxArticles;
            submittedCount = brief.submittedCount + 1;
            approvedCount = brief.approvedCount;
            status = brief.status;
            createdAt = brief.createdAt;
            expiresAt = brief.expiresAt;
            escrowSubaccount = brief.escrowSubaccount;
            escrowBalance = brief.escrowBalance;
            isRecurring = brief.isRecurring;
            recurrenceIntervalNanos = brief.recurrenceIntervalNanos;
          };
          ignore Map.put(briefs, thash, briefId, updated);
          #ok();
        };
        case null {
          #err("Brief not found");
        };
      };
    };

    /// Add amount to brief escrow balance (for refunds/reversals)
    public func addToEscrow(briefId : Text, amount : Nat) : Result.Result<(), Text> {
      switch (Map.get(briefs, thash, briefId)) {
        case (?brief) {
          let newBalance = brief.escrowBalance + amount;

          let updated = {
            briefId = brief.briefId;
            curator = brief.curator;
            title = brief.title;
            description = brief.description;
            topic = brief.topic;
            requirements = brief.requirements;
            bountyPerArticle = brief.bountyPerArticle;
            maxArticles = brief.maxArticles;
            submittedCount = brief.submittedCount;
            approvedCount = brief.approvedCount;
            status = brief.status;
            createdAt = brief.createdAt;
            expiresAt = brief.expiresAt;
            escrowSubaccount = brief.escrowSubaccount;
            escrowBalance = newBalance;
            isRecurring = brief.isRecurring;
            recurrenceIntervalNanos = brief.recurrenceIntervalNanos;
          };
          ignore Map.put(briefs, thash, briefId, updated);
          #ok();
        };
        case null {
          #err("Brief not found");
        };
      };
    };

    /// Record that an article was approved
    public func recordApproval(briefId : Text, bountyPaid : Nat) : Result.Result<(), Text> {
      switch (Map.get(briefs, thash, briefId)) {
        case (?brief) {
          Debug.print("recordApproval - briefId: " # briefId);
          Debug.print("recordApproval - bountyPaid: " # debug_show (bountyPaid));
          Debug.print("recordApproval - brief.escrowBalance: " # debug_show (brief.escrowBalance));
          Debug.print("recordApproval - brief.bountyPerArticle: " # debug_show (brief.bountyPerArticle));

          // Check if escrow has sufficient balance
          if (brief.escrowBalance < bountyPaid) {
            Debug.print("recordApproval - INSUFFICIENT BALANCE!");
            return #err("Insufficient escrow balance");
          };

          let updated = {
            briefId = brief.briefId;
            curator = brief.curator;
            title = brief.title;
            description = brief.description;
            topic = brief.topic;
            requirements = brief.requirements;
            bountyPerArticle = brief.bountyPerArticle;
            maxArticles = brief.maxArticles;
            submittedCount = brief.submittedCount;
            approvedCount = brief.approvedCount + 1;
            status = if (brief.approvedCount + 1 >= brief.maxArticles) {
              #closed;
            } else { brief.status };
            createdAt = brief.createdAt;
            expiresAt = brief.expiresAt;
            escrowSubaccount = brief.escrowSubaccount;
            escrowBalance = brief.escrowBalance - bountyPaid;
            isRecurring = brief.isRecurring;
            recurrenceIntervalNanos = brief.recurrenceIntervalNanos;
          };
          ignore Map.put(briefs, thash, briefId, updated);

          // Update curator stats
          switch (Map.get(curatorStats, phash, brief.curator)) {
            case (?stats) {
              Debug.print("recordApproval - curator stats.totalEscrowed: " # debug_show (stats.totalEscrowed));
              Debug.print("recordApproval - calculating new totalEscrowed: " # debug_show (stats.totalEscrowed) # " - " # debug_show (bountyPaid));

              // Prevent underflow in totalEscrowed
              let newTotalEscrowed = if (stats.totalEscrowed >= bountyPaid) {
                stats.totalEscrowed - bountyPaid;
              } else {
                Debug.print("recordApproval - WARNING: totalEscrowed < bountyPaid, setting to 0");
                0;
              };

              let updatedStats : CuratorStats = {
                curator = stats.curator;
                briefsCreated = stats.briefsCreated;
                articlesReviewed = stats.articlesReviewed;
                articlesApproved = stats.articlesApproved;
                articlesRejected = stats.articlesRejected;
                totalBountiesPaid = stats.totalBountiesPaid + bountyPaid;
                totalEscrowed = newTotalEscrowed;
                averageReviewTime = stats.averageReviewTime;
                firstBrief = stats.firstBrief;
                lastActivity = Time.now();
              };
              ignore Map.put(curatorStats, phash, brief.curator, updatedStats);
            };
            case null {};
          };

          #ok();
        };
        case null {
          #err("Brief not found");
        };
      };
    };

    /// Close a brief and return remaining escrow balance
    public func closeBrief(briefId : Text) : Result.Result<Nat, Text> {
      switch (Map.get(briefs, thash, briefId)) {
        case (?brief) {
          let updated = {
            briefId = brief.briefId;
            curator = brief.curator;
            title = brief.title;
            description = brief.description;
            topic = brief.topic;
            requirements = brief.requirements;
            bountyPerArticle = brief.bountyPerArticle;
            maxArticles = brief.maxArticles;
            submittedCount = brief.submittedCount;
            approvedCount = brief.approvedCount;
            status = #closed;
            createdAt = brief.createdAt;
            expiresAt = brief.expiresAt;
            escrowSubaccount = brief.escrowSubaccount;
            escrowBalance = brief.escrowBalance;
            isRecurring = brief.isRecurring;
            recurrenceIntervalNanos = brief.recurrenceIntervalNanos;
          };
          ignore Map.put(briefs, thash, briefId, updated);
          #ok(brief.escrowBalance);
        };
        case null {
          #err("Brief not found");
        };
      };
    };

    /// Get all open briefs
    public func getOpenBriefs() : [Brief] {
      let buffer = Buffer.Buffer<Brief>(0);
      for ((id, brief) in Map.entries(briefs)) {
        if (brief.status == #open) {
          buffer.add(brief);
        };
      };
      // Sort by createdAt in reverse chronological order (most recent first)
      buffer.sort(
        func(a : Brief, b : Brief) : { #less; #equal; #greater } {
          if (a.createdAt > b.createdAt) { #less } else if (a.createdAt < b.createdAt) {
            #greater;
          } else { #equal };
        }
      );
      Buffer.toArray(buffer);
    };

    /// Get briefs with filters and pagination
    public func getBriefsFiltered(
      statusFilter : ?BriefStatus,
      topicFilter : ?Text,
      limit : Nat,
      offset : Nat,
    ) : {
      briefs : [Brief];
      total : Nat;
    } {
      let allMatching = Buffer.Buffer<Brief>(0);

      // Collect all matching briefs
      for ((id, brief) in Map.entries(briefs)) {
        var matches = true;

        // Filter by status
        switch (statusFilter) {
          case (?status) {
            if (brief.status != status) {
              matches := false;
            };
          };
          case null {};
        };

        // Filter by topic
        switch (topicFilter) {
          case (?topic) {
            if (brief.topic != topic) {
              matches := false;
            };
          };
          case null {};
        };

        if (matches) {
          allMatching.add(brief);
        };
      };

      let total = allMatching.size();
      let paginated = Buffer.Buffer<Brief>(0);

      // Apply pagination
      var i = offset;
      var count = 0;
      while (i < allMatching.size() and count < limit) {
        paginated.add(allMatching.get(i));
        i += 1;
        count += 1;
      };

      {
        briefs = Buffer.toArray(paginated);
        total = total;
      };
    };

    /// Get all expired recurring briefs that need renewal
    public func getExpiredRecurringBriefs(now : Time.Time) : [Text] {
      let buffer = Buffer.Buffer<Text>(0);
      for ((id, brief) in Map.entries(briefs)) {
        if (brief.status == #open and brief.isRecurring) {
          switch (brief.expiresAt) {
            case (?expiryTime) {
              if (expiryTime <= now) {
                buffer.add(id);
              };
            };
            case null {};
          };
        };
      };
      Buffer.toArray(buffer);
    };

    /// Get a specific brief
    public func getBrief(briefId : Text) : ?Brief {
      Map.get(briefs, thash, briefId);
    };

    /// Get curator stats
    public func getCuratorStats(curator : Principal) : ?CuratorStats {
      Map.get(curatorStats, phash, curator);
    };

    /// Increment submitted count for a brief
    public func incrementSubmittedCount(briefId : Text) : Result.Result<(), Text> {
      switch (Map.get(briefs, thash, briefId)) {
        case (?brief) {
          let updated = {
            briefId = brief.briefId;
            curator = brief.curator;
            title = brief.title;
            description = brief.description;
            topic = brief.topic;
            requirements = brief.requirements;
            bountyPerArticle = brief.bountyPerArticle;
            maxArticles = brief.maxArticles;
            submittedCount = brief.submittedCount + 1;
            approvedCount = brief.approvedCount;
            status = brief.status;
            createdAt = brief.createdAt;
            expiresAt = brief.expiresAt;
            escrowSubaccount = brief.escrowSubaccount;
            escrowBalance = brief.escrowBalance;
            isRecurring = brief.isRecurring;
            recurrenceIntervalNanos = brief.recurrenceIntervalNanos;
          };
          ignore Map.put(briefs, thash, briefId, updated);
          #ok();
        };
        case null {
          #err("Brief not found");
        };
      };
    };

    /// Get next brief ID for persistence
    public func getNextBriefId() : Nat {
      nextBriefId;
    };
  };
};
