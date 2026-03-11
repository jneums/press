import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Map "mo:map/Map";
import { nhash; phash } "mo:map/Map";

import PressTypes "./PressTypes";

module {
  type Article = PressTypes.Article;
  type ArticleStatus = PressTypes.ArticleStatus;
  type AgentStats = PressTypes.AgentStats;
  type MediaAsset = PressTypes.MediaAsset;

  /// Manager for Article lifecycle
  public class ArticleManager(
    articlesTriage : Map.Map<Nat, Article>,
    articlesArchive : Map.Map<Nat, Article>,
    agentStats : Map.Map<Principal, AgentStats>,
    mediaAssets : Map.Map<Nat, MediaAsset>,
    nextArticleIdVar : Nat,
    nextAssetIdVar : Nat,
  ) {

    private var nextArticleId : Nat = nextArticleIdVar;
    private var nextAssetId : Nat = nextAssetIdVar;

    /// Submit a new article to triage
    public func submitArticle(
      briefId : Text,
      agent : Principal,
      title : Text,
      content : Text,
    ) : Nat {
      let now = Time.now();
      let articleId = nextArticleId;
      nextArticleId += 1;

      let article : Article = {
        articleId = articleId;
        briefId = briefId;
        agent = agent;
        title = title;
        content = content;
        mediaAssets = []; // Will be populated during media ingestion
        submittedAt = now;
        reviewedAt = null;
        reviewer = null;
        status = #draft; // Start as draft, agent must approve to send to curator
        rejectionReason = null;
        bountyPaid = 0;
        revisionsRequested = 0;
        currentRevision = 0;
        revisionHistory = [];
        revisionSubmissions = [];
        selectedForRevision = false;
      };

      ignore Map.put(articlesTriage, nhash, articleId, article);

      // Update agent stats
      let stats = switch (Map.get(agentStats, phash, agent)) {
        case (?existing) {
          let updated : AgentStats = {
            agent = agent;
            totalSubmitted = existing.totalSubmitted + 1;
            totalApproved = existing.totalApproved;
            totalRejected = existing.totalRejected;
            totalExpired = existing.totalExpired;
            totalEarned = existing.totalEarned;
            averageReviewTime = existing.averageReviewTime;
            firstSubmission = existing.firstSubmission;
            lastSubmission = now;
          };
          updated;
        };
        case null {
          let newStats : AgentStats = {
            agent = agent;
            totalSubmitted = 1;
            totalApproved = 0;
            totalRejected = 0;
            totalExpired = 0;
            totalEarned = 0;
            averageReviewTime = 0;
            firstSubmission = now;
            lastSubmission = now;
          };
          newStats;
        };
      };
      ignore Map.put(agentStats, phash, agent, stats);

      articleId;
    };

    /// Approve an article and move to archive
    public func approveArticle(
      articleId : Nat,
      reviewer : Principal,
      bountyPaid : Nat,
    ) : Result.Result<(), Text> {
      switch (Map.get(articlesTriage, nhash, articleId)) {
        case (?article) {
          let now = Time.now();
          let reviewTime = now - article.submittedAt;

          let approved = {
            articleId = article.articleId;
            briefId = article.briefId;
            agent = article.agent;
            title = article.title;
            content = article.content;
            mediaAssets = article.mediaAssets;
            submittedAt = article.submittedAt;
            reviewedAt = ?now;
            reviewer = ?reviewer;
            status = #approved;
            rejectionReason = null;
            bountyPaid = bountyPaid;
            revisionsRequested = article.revisionsRequested;
            currentRevision = article.currentRevision;
            revisionHistory = article.revisionHistory;
            revisionSubmissions = article.revisionSubmissions;
            selectedForRevision = article.selectedForRevision;
          };

          // Move from triage to archive
          ignore Map.remove(articlesTriage, nhash, articleId);
          ignore Map.put(articlesArchive, nhash, articleId, approved);

          // Update agent stats
          switch (Map.get(agentStats, phash, article.agent)) {
            case (?stats) {
              let reviewTimeNat = Int.abs(reviewTime);
              let newAvgTime = if (stats.totalApproved == 0) {
                reviewTimeNat;
              } else {
                (stats.averageReviewTime * stats.totalApproved + reviewTimeNat) / (stats.totalApproved + 1);
              };

              let updatedStats : AgentStats = {
                agent = stats.agent;
                totalSubmitted = stats.totalSubmitted;
                totalApproved = stats.totalApproved + 1;
                totalRejected = stats.totalRejected;
                totalExpired = stats.totalExpired;
                totalEarned = stats.totalEarned + bountyPaid;
                averageReviewTime = newAvgTime;
                firstSubmission = stats.firstSubmission;
                lastSubmission = stats.lastSubmission;
              };
              ignore Map.put(agentStats, phash, article.agent, updatedStats);
            };
            case null {};
          };

          #ok();
        };
        case null {
          #err("Article not found in triage");
        };
      };
    };

    /// Reject an article and move to archive
    public func rejectArticle(
      articleId : Nat,
      reviewer : Principal,
      reason : Text,
    ) : Result.Result<(), Text> {
      switch (Map.get(articlesTriage, nhash, articleId)) {
        case (?article) {
          let now = Time.now();

          let rejected = {
            articleId = article.articleId;
            briefId = article.briefId;
            agent = article.agent;
            title = article.title;
            content = article.content;
            mediaAssets = article.mediaAssets;
            submittedAt = article.submittedAt;
            reviewedAt = ?now;
            reviewer = ?reviewer;
            status = #rejected;
            rejectionReason = ?reason;
            bountyPaid = 0;
            revisionsRequested = article.revisionsRequested;
            currentRevision = article.currentRevision;
            revisionHistory = article.revisionHistory;
            revisionSubmissions = article.revisionSubmissions;
            selectedForRevision = article.selectedForRevision;
          };

          // Move from triage to archive
          ignore Map.remove(articlesTriage, nhash, articleId);
          ignore Map.put(articlesArchive, nhash, articleId, rejected);

          // Update agent stats
          switch (Map.get(agentStats, phash, article.agent)) {
            case (?stats) {
              let updatedStats : AgentStats = {
                agent = stats.agent;
                totalSubmitted = stats.totalSubmitted;
                totalApproved = stats.totalApproved;
                totalRejected = stats.totalRejected + 1;
                totalExpired = stats.totalExpired;
                totalEarned = stats.totalEarned;
                averageReviewTime = stats.averageReviewTime;
                firstSubmission = stats.firstSubmission;
                lastSubmission = stats.lastSubmission;
              };
              ignore Map.put(agentStats, phash, article.agent, updatedStats);
            };
            case null {};
          };

          #ok();
        };
        case null {
          #err("Article not found in triage");
        };
      };
    };

    /// Request revisions for an article (curator selects article and requests changes)
    public func requestRevision(
      articleId : Nat,
      curator : Principal,
      feedback : Text,
    ) : Result.Result<(), Text> {
      switch (Map.get(articlesTriage, nhash, articleId)) {
        case (?article) {
          // Check if maximum revisions already reached
          if (article.revisionsRequested >= 3) {
            return #err("Maximum number of revisions (3) already reached");
          };

          // Check if article is in a valid state for revision request
          if (article.status != #pending and article.status != #revisionSubmitted) {
            return #err("Article is not in a state that allows revision requests");
          };

          let now = Time.now();
          let newRevisionNumber = article.revisionsRequested + 1;

          let revisionRequest : PressTypes.RevisionRequest = {
            requestedAt = now;
            requestedBy = curator;
            feedback = feedback;
            revisionNumber = newRevisionNumber;
          };

          // Create updated article with revision request
          let updatedArticle = {
            articleId = article.articleId;
            briefId = article.briefId;
            agent = article.agent;
            title = article.title;
            content = article.content;
            mediaAssets = article.mediaAssets;
            submittedAt = article.submittedAt;
            reviewedAt = article.reviewedAt;
            reviewer = ?curator;
            status = #revisionRequested;
            rejectionReason = article.rejectionReason;
            bountyPaid = article.bountyPaid;
            revisionsRequested = newRevisionNumber;
            currentRevision = article.currentRevision;
            revisionHistory = Array.append(article.revisionHistory, [revisionRequest]);
            revisionSubmissions = article.revisionSubmissions;
            selectedForRevision = true; // Mark as selected
          };

          ignore Map.put(articlesTriage, nhash, articleId, updatedArticle);
          #ok();
        };
        case null {
          #err("Article not found in triage");
        };
      };
    };

    /// Submit a revision for an article (agent responds to revision request)
    public func submitRevision(
      articleId : Nat,
      agent : Principal,
      revisedContent : Text,
    ) : Result.Result<(), Text> {
      switch (Map.get(articlesTriage, nhash, articleId)) {
        case (?article) {
          // Verify the agent owns this article
          if (article.agent != agent) {
            return #err("Only the article author can submit revisions");
          };

          // Check if a revision was actually requested
          if (article.status != #revisionRequested) {
            return #err("No revision has been requested for this article");
          };

          let now = Time.now();
          let revisionNumber = article.revisionsRequested; // Current revision number

          let revisionSubmission : PressTypes.RevisionSubmission = {
            submittedAt = now;
            content = revisedContent;
            revisionNumber = revisionNumber;
          };

          // Create updated article with the revision
          let updatedArticle = {
            articleId = article.articleId;
            briefId = article.briefId;
            agent = article.agent;
            title = article.title;
            content = revisedContent; // Update content with revised version
            mediaAssets = article.mediaAssets;
            submittedAt = article.submittedAt;
            reviewedAt = article.reviewedAt;
            reviewer = article.reviewer;
            status = #revisionSubmitted;
            rejectionReason = article.rejectionReason;
            bountyPaid = article.bountyPaid;
            revisionsRequested = article.revisionsRequested;
            currentRevision = revisionNumber;
            revisionHistory = article.revisionHistory;
            revisionSubmissions = Array.append(article.revisionSubmissions, [revisionSubmission]);
            selectedForRevision = article.selectedForRevision;
          };

          ignore Map.put(articlesTriage, nhash, articleId, updatedArticle);
          #ok();
        };
        case null {
          #err("Article not found in triage");
        };
      };
    };

    /// Get articles eligible for auto-approval
    /// Returns articles that have used all 3 revisions AND 48h have passed since last revision submission
    /// This protects authors from malicious curators who never finalize after max revisions
    public func getArticlesForAutoApproval(now : Int) : [Article] {
      let fortyEightHours : Int = 48 * 60 * 60 * 1_000_000_000; // 48 hours in nanoseconds
      let buffer = Buffer.Buffer<Article>(0);

      for ((_, article) in Map.entries(articlesTriage)) {
        // Must have used all 3 revisions
        if (article.revisionsRequested >= 3 and article.status == #revisionSubmitted) {
          // Check if 48 hours have passed since last revision submission
          if (article.revisionSubmissions.size() > 0) {
            let lastSubmission = article.revisionSubmissions[article.revisionSubmissions.size() - 1];
            if (now - lastSubmission.submittedAt > fortyEightHours) {
              buffer.add(article);
            };
          };
        };
      };

      Buffer.toArray(buffer);
    };

    /// Janitor: purge expired articles from triage
    /// - Drafts (not yet approved by agent): expire after 72h
    /// - Pending/Revision articles (waiting for curator): expire after 48h
    public func purgeExpiredArticles() : Nat {
      let now = Time.now();
      let fortyEightHours : Int = 48 * 60 * 60 * 1_000_000_000; // 48 hours in nanoseconds
      let seventyTwoHours : Int = 72 * 60 * 60 * 1_000_000_000; // 72 hours in nanoseconds
      let buffer = Buffer.Buffer<Nat>(0);

      // Find expired articles (different TTL for drafts vs pending)
      for ((id, article) in Map.entries(articlesTriage)) {
        let ttl = if (article.status == #draft) { seventyTwoHours } else {
          fortyEightHours;
        };
        if (now - article.submittedAt > ttl) {
          buffer.add(id);
        };
      };

      // Remove them and update stats
      for (id in buffer.vals()) {
        switch (Map.remove(articlesTriage, nhash, id)) {
          case (?article) {
            // Update agent stats
            switch (Map.get(agentStats, phash, article.agent)) {
              case (?stats) {
                let updatedStats : AgentStats = {
                  agent = stats.agent;
                  totalSubmitted = stats.totalSubmitted;
                  totalApproved = stats.totalApproved;
                  totalRejected = stats.totalRejected;
                  totalExpired = stats.totalExpired + 1;
                  totalEarned = stats.totalEarned;
                  averageReviewTime = stats.averageReviewTime;
                  firstSubmission = stats.firstSubmission;
                  lastSubmission = stats.lastSubmission;
                };
                ignore Map.put(agentStats, phash, article.agent, updatedStats);
              };
              case null {};
            };
          };
          case null {};
        };
      };

      buffer.size();
    };

    /// Check if an article is nearing expiry (for reminders)
    /// Returns: (hoursRemaining, shouldShowReminder)
    /// - Drafts: 72h TTL, reminder at 48h (24h remaining)
    /// - Pending: 48h TTL, reminder at 24h (24h remaining)
    public func getArticleExpiryInfo(articleId : Nat) : ?(Int, Bool) {
      switch (Map.get(articlesTriage, nhash, articleId)) {
        case (?article) {
          let now = Time.now();
          let oneHour : Int = 60 * 60 * 1_000_000_000;
          let ttlHours = if (article.status == #draft) { 72 } else { 48 };
          let reminderAtHours = if (article.status == #draft) { 48 } else { 24 }; // Remind when this many hours have passed

          let elapsedNanos = now - article.submittedAt;
          let elapsedHours = elapsedNanos / oneHour;
          let remainingHours = ttlHours - elapsedHours;
          let shouldRemind = elapsedHours >= reminderAtHours;

          ?(remainingHours, shouldRemind);
        };
        case null { null };
      };
    };

    /// Get all articles in triage
    public func getTriageArticles() : [Article] {
      let buffer = Buffer.Buffer<Article>(0);
      for ((id, article) in Map.entries(articlesTriage)) {
        buffer.add(article);
      };
      Buffer.toArray(buffer);
    };

    /// Get a specific article
    public func getArticle(articleId : Nat) : ?Article {
      switch (Map.get(articlesTriage, nhash, articleId)) {
        case (?article) { ?article };
        case null { Map.get(articlesArchive, nhash, articleId) };
      };
    };

    /// Get agent stats
    public func getAgentStats(agent : Principal) : ?AgentStats {
      Map.get(agentStats, phash, agent);
    };

    /// Get top agents by total earnings
    public func getTopAgents(limit : Nat) : [AgentStats] {
      let buffer = Buffer.Buffer<AgentStats>(0);
      for ((_, stats) in Map.entries(agentStats)) {
        buffer.add(stats);
      };

      // Sort by totalEarned descending
      let allStats = Buffer.toArray(buffer);
      let sorted = Array.sort<AgentStats>(
        allStats,
        func(a, b) {
          if (a.totalEarned > b.totalEarned) { #less } else if (a.totalEarned < b.totalEarned) {
            #greater;
          } else { #equal };
        },
      );

      // Return top N
      let actualLimit = if (sorted.size() < limit) { sorted.size() } else {
        limit;
      };
      Array.tabulate<AgentStats>(actualLimit, func(i) { sorted[i] });
    };

    /// Get next article ID (for external reference)
    public func getNextArticleId() : Nat {
      nextArticleId;
    };

    /// Get next asset ID (for external reference)
    public func getNextAssetId() : Nat {
      nextAssetId;
    };

    /// Increment asset ID and return the new one
    public func allocateAssetId() : Nat {
      let id = nextAssetId;
      nextAssetId += 1;
      id;
    };

    /// Register a media asset
    public func registerMediaAsset(asset : MediaAsset) : () {
      ignore Map.put(mediaAssets, nhash, asset.assetId, asset);
    };

    /// Get a media asset
    public func getMediaAsset(assetId : Nat) : ?MediaAsset {
      Map.get(mediaAssets, nhash, assetId);
    };

    /// Get articles by agent (from both triage and archive)
    public func getArticlesByAgent(agent : Principal) : [Article] {
      let buffer = Buffer.Buffer<Article>(10);

      // Get from triage
      for ((_, article) in Map.entries(articlesTriage)) {
        if (Principal.equal(article.agent, agent)) {
          buffer.add(article);
        };
      };

      // Get from archive
      for ((_, article) in Map.entries(articlesArchive)) {
        if (Principal.equal(article.agent, agent)) {
          buffer.add(article);
        };
      };

      Buffer.toArray(buffer);
    };

    /// Get articles by brief ID (only approved articles for public display)
    public func getArticlesByBrief(briefId : Text) : [Article] {
      let buffer = Buffer.Buffer<Article>(10);

      // Only include approved articles from archive
      for ((_, article) in Map.entries(articlesArchive)) {
        if (article.briefId == briefId) {
          switch (article.status) {
            case (#approved) {
              buffer.add(article);
            };
            case _ {};
          };
        };
      };

      Buffer.toArray(buffer);
    };

    /// Attach media assets to an article
    public func attachMediaAssets(articleId : Nat, assetIds : [Nat]) : Result.Result<(), Text> {
      let article = switch (Map.get(articlesTriage, nhash, articleId)) {
        case (?a) { a };
        case null {
          switch (Map.get(articlesArchive, nhash, articleId)) {
            case (?a) { a };
            case null { return #err("Article not found") };
          };
        };
      };

      let updated = {
        articleId = article.articleId;
        briefId = article.briefId;
        agent = article.agent;
        title = article.title;
        content = article.content;
        mediaAssets = assetIds;
        submittedAt = article.submittedAt;
        reviewedAt = article.reviewedAt;
        reviewer = article.reviewer;
        status = article.status;
        rejectionReason = article.rejectionReason;
        bountyPaid = article.bountyPaid;
        revisionsRequested = article.revisionsRequested;
        currentRevision = article.currentRevision;
        revisionHistory = article.revisionHistory;
        revisionSubmissions = article.revisionSubmissions;
        selectedForRevision = article.selectedForRevision;
      };

      // Update in the correct map
      switch (article.status) {
        case (#pending) {
          ignore Map.put(articlesTriage, nhash, articleId, updated);
        };
        case _ {
          ignore Map.put(articlesArchive, nhash, articleId, updated);
        };
      };

      #ok();
    };

    /// Agent approves their draft article to send to curator queue
    /// Returns the briefId on success so caller can increment submittedCount
    public func approveDraftToPending(
      articleId : Nat,
      agent : Principal,
    ) : Result.Result<Text, Text> {
      switch (Map.get(articlesTriage, nhash, articleId)) {
        case (?article) {
          // Verify the agent owns this article
          if (article.agent != agent) {
            return #err("Only the article author can approve their draft");
          };

          // Verify article is in draft status
          if (article.status != #draft) {
            return #err("Only draft articles can be approved to pending");
          };

          // Update status to pending
          let updatedArticle = {
            articleId = article.articleId;
            briefId = article.briefId;
            agent = article.agent;
            title = article.title;
            content = article.content;
            mediaAssets = article.mediaAssets;
            submittedAt = Time.now(); // Update submittedAt to now (when actually submitted to curator)
            reviewedAt = article.reviewedAt;
            reviewer = article.reviewer;
            status = #pending; // Move to pending for curator review
            rejectionReason = article.rejectionReason;
            bountyPaid = article.bountyPaid;
            revisionsRequested = article.revisionsRequested;
            currentRevision = article.currentRevision;
            revisionHistory = article.revisionHistory;
            revisionSubmissions = article.revisionSubmissions;
            selectedForRevision = article.selectedForRevision;
          };

          ignore Map.put(articlesTriage, nhash, articleId, updatedArticle);
          #ok(article.briefId); // Return briefId so caller can increment submittedCount
        };
        case null {
          #err("Article not found");
        };
      };
    };

    /// Agent updates their draft article content
    public func updateDraftArticle(
      articleId : Nat,
      agent : Principal,
      newTitle : Text,
      newContent : Text,
    ) : Result.Result<(), Text> {
      switch (Map.get(articlesTriage, nhash, articleId)) {
        case (?article) {
          // Verify the agent owns this article
          if (article.agent != agent) {
            return #err("Only the article author can update their draft");
          };

          // Verify article is in draft status
          if (article.status != #draft) {
            return #err("Only draft articles can be edited");
          };

          // Update the article
          let updatedArticle = {
            articleId = article.articleId;
            briefId = article.briefId;
            agent = article.agent;
            title = newTitle;
            content = newContent;
            mediaAssets = article.mediaAssets;
            submittedAt = article.submittedAt;
            reviewedAt = article.reviewedAt;
            reviewer = article.reviewer;
            status = article.status;
            rejectionReason = article.rejectionReason;
            bountyPaid = article.bountyPaid;
            revisionsRequested = article.revisionsRequested;
            currentRevision = article.currentRevision;
            revisionHistory = article.revisionHistory;
            revisionSubmissions = article.revisionSubmissions;
            selectedForRevision = article.selectedForRevision;
          };

          ignore Map.put(articlesTriage, nhash, articleId, updatedArticle);
          #ok();
        };
        case null {
          #err("Article not found");
        };
      };
    };

    /// Agent deletes their draft article
    public func deleteDraftArticle(
      articleId : Nat,
      agent : Principal,
    ) : Result.Result<(), Text> {
      switch (Map.get(articlesTriage, nhash, articleId)) {
        case (?article) {
          // Verify the agent owns this article
          if (article.agent != agent) {
            return #err("Only the article author can delete their draft");
          };

          // Verify article is in draft status
          if (article.status != #draft) {
            return #err("Only draft articles can be deleted");
          };

          // Remove from triage
          ignore Map.remove(articlesTriage, nhash, articleId);
          #ok();
        };
        case null {
          #err("Article not found");
        };
      };
    };

    /// Reject all pending articles for a brief (except the one just approved)
    /// Used when a brief's slots are filled to auto-reject remaining submissions
    public func rejectPendingArticlesForBrief(
      briefId : Text,
      exceptArticleId : ?Nat,
      reviewer : Principal,
      reason : Text,
    ) : Nat {
      let now = Time.now();
      let articlesToReject = Buffer.Buffer<Nat>(0);

      // Find all pending articles for this brief
      for ((id, article) in Map.entries(articlesTriage)) {
        if (article.briefId == briefId) {
          // Skip the article that was just approved
          switch (exceptArticleId) {
            case (?excludeId) {
              if (id == excludeId) {
                // Skip this one
              } else {
                // Check if it's in a pending-like state (not already rejected/approved)
                switch (article.status) {
                  case (#pending or #draft or #revisionRequested or #revisionSubmitted) {
                    articlesToReject.add(id);
                  };
                  case _ {};
                };
              };
            };
            case null {
              // No exception, check all
              switch (article.status) {
                case (#pending or #draft or #revisionRequested or #revisionSubmitted) {
                  articlesToReject.add(id);
                };
                case _ {};
              };
            };
          };
        };
      };

      // Reject each article
      for (id in articlesToReject.vals()) {
        switch (Map.get(articlesTriage, nhash, id)) {
          case (?article) {
            let rejected = {
              articleId = article.articleId;
              briefId = article.briefId;
              agent = article.agent;
              title = article.title;
              content = article.content;
              mediaAssets = article.mediaAssets;
              submittedAt = article.submittedAt;
              reviewedAt = ?now;
              reviewer = ?reviewer;
              status = #rejected;
              rejectionReason = ?reason;
              bountyPaid = 0;
              revisionsRequested = article.revisionsRequested;
              currentRevision = article.currentRevision;
              revisionHistory = article.revisionHistory;
              revisionSubmissions = article.revisionSubmissions;
              selectedForRevision = article.selectedForRevision;
            };

            // Move from triage to archive
            ignore Map.remove(articlesTriage, nhash, id);
            ignore Map.put(articlesArchive, nhash, id, rejected);

            // Update agent stats
            switch (Map.get(agentStats, phash, article.agent)) {
              case (?stats) {
                let updatedStats : AgentStats = {
                  agent = stats.agent;
                  totalSubmitted = stats.totalSubmitted;
                  totalApproved = stats.totalApproved;
                  totalRejected = stats.totalRejected + 1;
                  totalExpired = stats.totalExpired;
                  totalEarned = stats.totalEarned;
                  averageReviewTime = stats.averageReviewTime;
                  firstSubmission = stats.firstSubmission;
                  lastSubmission = stats.lastSubmission;
                };
                ignore Map.put(agentStats, phash, article.agent, updatedStats);
              };
              case null {};
            };
          };
          case null {};
        };
      };

      articlesToReject.size();
    };
  };
};
