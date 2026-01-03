import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Time "mo:base/Time";
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
        status = #pending;
        rejectionReason = null;
        bountyPaid = 0;
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

    /// Janitor: purge expired articles from triage (>48h old)
    public func purgeExpiredArticles() : Nat {
      let now = Time.now();
      let fortyEightHours : Int = 48 * 60 * 60 * 1_000_000_000; // 48 hours in nanoseconds
      let buffer = Buffer.Buffer<Nat>(0);

      // Find expired articles
      for ((id, article) in Map.entries(articlesTriage)) {
        if (now - article.submittedAt > fortyEightHours) {
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
  };
};
