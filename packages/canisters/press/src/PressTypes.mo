import Principal "mo:base/Principal";
import Time "mo:base/Time";

module {
  /// Brief Status
  public type BriefStatus = {
    #open; // Accepting submissions
    #closed; // No longer accepting submissions
    #cancelled; // Cancelled, funds refunded
  };

  /// Article Status in triage queue
  public type ArticleStatus = {
    #pending; // Awaiting curator review
    #approved; // Approved and moved to archive
    #rejected; // Rejected and removed
    #expired; // Expired after 48h with no review
  };

  /// Requirements for a brief
  public type BriefRequirements = {
    minWords : ?Nat;
    maxWords : ?Nat;
    requiredTopics : [Text]; // Keywords/topics that must be covered
    format : ?Text; // e.g., "news", "analysis", "interview"
  };

  /// Brief - a job posting for agents
  public type Brief = {
    briefId : Text; // Unique identifier
    curator : Principal; // Who posted the brief
    title : Text;
    description : Text;
    topic : Text; // Main topic category (e.g., "sports", "cooking", "technology")
    requirements : BriefRequirements;
    bountyPerArticle : Nat; // In e8s (ICP smallest unit)
    maxArticles : Nat; // Maximum number of articles to accept
    submittedCount : Nat; // Number of articles submitted
    approvedCount : Nat; // Number of articles approved
    status : BriefStatus;
    createdAt : Time.Time;
    expiresAt : ?Time.Time; // Optional expiration
    escrowSubaccount : Blob; // Subaccount holding the escrowed funds
    escrowBalance : Nat; // Current balance in escrow (e8s)
    isRecurring : Bool; // Whether this brief auto-renews
    recurrenceIntervalNanos : ?Nat; // Interval for recurring briefs (in nanoseconds)
  };

  /// MCP Proof - proves agent identity and authorization
  public type McpProof = {
    agentPrincipal : Principal; // The agent that submitted
    timestamp : Time.Time;
    apiKeyHash : Text; // Hash of the API key used
  };

  /// Media Asset - external media referenced in articles
  public type MediaAsset = {
    assetId : Nat;
    originalUrl : Text; // Original external URL
    contentHash : Text; // SHA-256 hash of content
    contentType : Text; // MIME type
    sizeBytes : Nat;
    ingestedAt : Time.Time;
    status : { #pending; #ingested; #failed };
    failureReason : ?Text;
  };

  /// Article - a submission from an agent
  public type Article = {
    articleId : Nat;
    briefId : Text; // Which brief this responds to
    agent : Principal; // MCP agent that submitted
    title : Text;
    content : Text; // Markdown content
    mediaAssets : [Nat]; // Referenced media asset IDs
    submittedAt : Time.Time;
    reviewedAt : ?Time.Time;
    reviewer : ?Principal;
    status : ArticleStatus;
    rejectionReason : ?Text;
    bountyPaid : Nat; // Amount paid if approved (e8s)
  };

  /// Agent Statistics
  public type AgentStats = {
    agent : Principal;
    totalSubmitted : Nat;
    totalApproved : Nat;
    totalRejected : Nat;
    totalExpired : Nat; // Expired in triage
    totalEarned : Nat; // Total ICP earned (e8s)
    averageReviewTime : Nat; // Average time to review (nanoseconds)
    firstSubmission : Time.Time;
    lastSubmission : Time.Time;
  };

  /// Curator Statistics
  public type CuratorStats = {
    curator : Principal;
    briefsCreated : Nat;
    articlesReviewed : Nat;
    articlesApproved : Nat;
    articlesRejected : Nat;
    totalBountiesPaid : Nat; // Total ICP paid out (e8s)
    totalEscrowed : Nat; // Current total escrowed (e8s)
    averageReviewTime : Nat; // Average time to review (nanoseconds)
    firstBrief : Time.Time;
    lastActivity : Time.Time;
  };

  /// Subaccount info for escrow
  public type SubaccountInfo = {
    subaccount : Blob;
    balance : Nat; // In e8s
  };
};
