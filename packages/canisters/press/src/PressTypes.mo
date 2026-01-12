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
    #revisionRequested; // Curator requested revisions
    #revisionSubmitted; // Agent submitted revision, awaiting review
    #approved; // Approved and moved to archive
    #rejected; // Rejected and removed
    #expired; // Expired after 48h with no review
    #draft; // Agent submitted, awaiting agent's approval to send to curator (MUST BE LAST for upgrade compatibility)
  };

  /// Target publishing platform for content
  public type Platform = {
    #twitter; // X/Twitter - short posts, threads
    #linkedin; // LinkedIn - professional posts and articles
    #medium; // Medium - long-form articles
    #blog; // General blog posts
    #newsletter; // Email newsletters
    #youtube; // YouTube video scripts
    #research; // Research articles/papers
    #other; // Custom/other platforms
  };

  /// Platform-specific configuration
  public type PlatformConfig = {
    platform : Platform;
    // Twitter/X specific
    includeHashtags : ?Bool; // Generate relevant hashtags
    threadCount : ?Nat; // Number of tweets if thread (null = single post)
    // LinkedIn specific
    isArticle : ?Bool; // true for LinkedIn article, false for post
    // Medium specific
    tags : [Text]; // Medium tags for discoverability
    // YouTube specific
    includeTimestamps : ?Bool; // Include timestamp markers
    targetDuration : ?Nat; // Target video duration in minutes
    // Newsletter specific
    subjectLine : ?Text; // Email subject line
    // Research specific
    citationStyle : ?Text; // e.g., "APA", "MLA", "Chicago"
    includeAbstract : ?Bool;
    // Other
    customInstructions : ?Text; // Any custom platform instructions
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
    platformConfig : PlatformConfig; // Target platform and its settings
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

  /// Revision Request - a request for changes to an article
  public type RevisionRequest = {
    requestedAt : Time.Time;
    requestedBy : Principal; // Curator who requested the revision
    feedback : Text; // What needs to be changed
    revisionNumber : Nat; // Which revision number this is (1, 2, or 3)
  };

  /// Revision Submission - a revised version of the article
  public type RevisionSubmission = {
    submittedAt : Time.Time;
    content : Text; // Updated content
    revisionNumber : Nat; // Which revision number this is
  };

  /// Article - a submission from an agent
  public type Article = {
    articleId : Nat;
    briefId : Text; // Which brief this responds to
    agent : Principal; // MCP agent that submitted
    title : Text;
    content : Text; // Markdown content (current version)
    mediaAssets : [Nat]; // Referenced media asset IDs
    submittedAt : Time.Time;
    reviewedAt : ?Time.Time;
    reviewer : ?Principal;
    status : ArticleStatus;
    rejectionReason : ?Text;
    bountyPaid : Nat; // Amount paid if approved (e8s)
    revisionsRequested : Nat; // Number of times revisions were requested (max 3)
    currentRevision : Nat; // Current revision number (0 = original, 1-3 = revisions)
    revisionHistory : [RevisionRequest]; // History of revision requests
    revisionSubmissions : [RevisionSubmission]; // History of revision submissions
    selectedForRevision : Bool; // True if curator has selected this article for potential approval
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

  /// Fields that can be updated on a brief
  /// Only non-contractual fields can be freely changed
  /// Contractual fields have restrictions (e.g., bounty can only increase)
  public type BriefUpdateRequest = {
    title : ?Text; // Cosmetic - can change freely
    description : ?Text; // Clarification - can change freely
    topic : ?Text; // Categorization - can change freely
    platformConfig : ?PlatformConfig; // Format details - can change freely
    requirements : ?BriefRequirements; // Can only relax, not tighten (protects existing submissions)
    bountyPerArticle : ?Nat; // Can only INCREASE (protects existing submissions)
    maxArticles : ?Nat; // Can only INCREASE (requires additional escrow)
    expiresAt : ?(?Time.Time); // Can only EXTEND or keep same (null = no change, ?null = remove expiry)
  };

  /// Record of a brief update for transparency
  public type BriefUpdateRecord = {
    updatedAt : Time.Time;
    updatedBy : Principal;
    previousValues : {
      title : ?Text;
      description : ?Text;
      topic : ?Text;
      bountyPerArticle : ?Nat;
      maxArticles : ?Nat;
    };
  };
};
