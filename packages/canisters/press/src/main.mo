import Result "mo:base/Result";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";

import HttpTypes "mo:http-types";
import Map "mo:map/Map";

import AuthCleanup "mo:mcp-motoko-sdk/auth/Cleanup";
import AuthState "mo:mcp-motoko-sdk/auth/State";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";

import IC "mo:ic";

import Mcp "mo:mcp-motoko-sdk/mcp/Mcp";
import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import HttpHandler "mo:mcp-motoko-sdk/mcp/HttpHandler";
import Cleanup "mo:mcp-motoko-sdk/mcp/Cleanup";
import State "mo:mcp-motoko-sdk/mcp/State";
import Payments "mo:mcp-motoko-sdk/mcp/Payments";
import HttpAssets "mo:mcp-motoko-sdk/mcp/HttpAssets";
import Beacon "mo:mcp-motoko-sdk/mcp/Beacon";
import ApiKey "mo:mcp-motoko-sdk/auth/ApiKey";

import SrvTypes "mo:mcp-motoko-sdk/server/Types";

import ClassPlus "mo:class-plus";
import TT "mo:timer-tool";

// Import Press modules
import PressTypes "./PressTypes";
import BriefManager "./BriefManager";
import ArticleManager "./ArticleManager";
import ToolContext "./ToolContext";
import IcpLedger "./IcpLedger";

// Import tool modules
import ListBriefs "tools/list_briefs";
import FindBriefs "tools/find_briefs";
import SubmitArticle "tools/submit_article";
import ViewPendingSubmissions "tools/view_pending_submissions";
import EditDraft "tools/edit_draft";
import SubmitRevision "tools/submit_revision";

// Migration function to add platformConfig field to Brief type
// (
//   with migration = func(
//     old_state : {
//       var stable_briefs : Map.Map<Text, {
//         briefId : Text;
//         curator : Principal;
//         title : Text;
//         description : Text;
//         topic : Text;
//         requirements : PressTypes.BriefRequirements;
//         bountyPerArticle : Nat;
//         maxArticles : Nat;
//         submittedCount : Nat;
//         approvedCount : Nat;
//         status : PressTypes.BriefStatus;
//         createdAt : Time.Time;
//         expiresAt : ?Time.Time;
//         escrowSubaccount : Blob;
//         escrowBalance : Nat;
//         isRecurring : Bool;
//         recurrenceIntervalNanos : ?Nat;
//       }>;
//     }
//   ) : {
//     var stable_briefs : Map.Map<Text, PressTypes.Brief>;
//   } {
//     let new_briefs = Map.new<Text, PressTypes.Brief>();

//     for ((briefId, oldBrief) in Map.entries(old_state.stable_briefs)) {
//       // Create default platform config based on description/topic hints
//       let defaultPlatformConfig : PressTypes.PlatformConfig = {
//         platform = #other;
//         includeHashtags = null;
//         threadCount = null;
//         isArticle = null;
//         tags = [];
//         includeTimestamps = null;
//         targetDuration = null;
//         subjectLine = null;
//         citationStyle = null;
//         includeAbstract = null;
//         customInstructions = ?oldBrief.description; // Preserve old description as custom instructions
//       };

//       let newBrief : PressTypes.Brief = {
//         briefId = oldBrief.briefId;
//         curator = oldBrief.curator;
//         title = oldBrief.title;
//         description = oldBrief.description;
//         topic = oldBrief.topic;
//         platformConfig = defaultPlatformConfig;
//         requirements = oldBrief.requirements;
//         bountyPerArticle = oldBrief.bountyPerArticle;
//         maxArticles = oldBrief.maxArticles;
//         submittedCount = oldBrief.submittedCount;
//         approvedCount = oldBrief.approvedCount;
//         status = oldBrief.status;
//         createdAt = oldBrief.createdAt;
//         expiresAt = oldBrief.expiresAt;
//         escrowSubaccount = oldBrief.escrowSubaccount;
//         escrowBalance = oldBrief.escrowBalance;
//         isRecurring = oldBrief.isRecurring;
//         recurrenceIntervalNanos = oldBrief.recurrenceIntervalNanos;
//       };
//       ignore Map.put(new_briefs, Map.thash, briefId, newBrief);
//     };

//     {
//       var stable_briefs = new_briefs;
//     };
//   }
// )

shared ({ caller = deployer }) persistent actor class McpServer(
  args : ?{
    owner : ?Principal;
    icpLedgerCanisterId : ?Principal;
  }
) = self {

  // The canister owner, who can manage treasury funds.
  // Defaults to the deployer if not specified.
  var owner : Principal = Option.get(do ? { args!.owner! }, deployer);
  let thisPrincipal = Principal.fromActor(self);

  // ICP Ledger canister ID
  var icpLedger : ?Principal = do ? { args!.icpLedgerCanisterId! };

  // ===== PRESS PLATFORM STABLE STATE =====

  // Brief management
  let stable_briefs = Map.new<Text, PressTypes.Brief>();
  var stable_next_brief_id : Nat = 1;

  // Article triage (temporary storage, auto-purged after 48h)
  let stable_articles_triage = Map.new<Nat, PressTypes.Article>();

  // Article archive (permanent storage for approved content)
  let stable_articles_archive = Map.new<Nat, PressTypes.Article>();
  var stable_next_article_id : Nat = 1;

  // Media assets (ingested images/files)
  let stable_media_assets = Map.new<Nat, PressTypes.MediaAsset>();
  var stable_next_asset_id : Nat = 1;

  // Agent statistics
  let stable_agent_stats = Map.new<Principal, PressTypes.AgentStats>();

  // Curator statistics
  let stable_curator_stats = Map.new<Principal, PressTypes.CuratorStats>();

  // State for certified HTTP assets (like /.well-known/...)
  var stable_http_assets : HttpAssets.StableEntries = [];
  transient let http_assets = HttpAssets.init(stable_http_assets);

  // Create managers for Press platform
  transient let briefManager = BriefManager.BriefManager(
    stable_briefs,
    stable_curator_stats,
    Option.get(icpLedger, Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai")), // ICP ledger
    thisPrincipal,
    stable_next_brief_id,
  );

  transient let articleManager = ArticleManager.ArticleManager(
    stable_articles_triage,
    stable_articles_archive,
    stable_agent_stats,
    stable_media_assets,
    stable_next_article_id,
    stable_next_asset_id,
  );

  // --- TimerTool Setup ---
  transient let initManager = ClassPlus.ClassPlusInitializationManager(owner, thisPrincipal, true);

  private func reportTTExecution(execInfo : TT.ExecutionReport) : Bool {
    Debug.print("CANISTER: TimerTool Execution: " # debug_show (execInfo));
    false;
  };

  private func reportTTError(errInfo : TT.ErrorReport) : ?Nat {
    Debug.print("CANISTER: TimerTool Error: " # debug_show (errInfo));
    null;
  };

  var tt_migration_state : TT.State = TT.Migration.migration.initialState;
  transient let tt = TT.Init<system>({
    manager = initManager;
    initialState = tt_migration_state;
    args = null;
    pullEnvironment = ?(
      func() : TT.Environment {
        {
          advanced = null;
          reportExecution = ?reportTTExecution;
          reportError = ?reportTTError;
          syncUnsafe = null;
          reportBatch = null;
        };
      }
    );
    onInitialize = ?(
      func(newClass : TT.TimerTool) : async* () {
        Debug.print("Initializing TimerTool");
        newClass.initialize<system>();
      }
    );
    onStorageChange = func(state : TT.State) { tt_migration_state := state };
  });

  // Constants
  let JANITOR_INTERVAL_HOURS : Nat = 6; // Run janitor every 6 hours
  let ARTICLE_TTL_HOURS : Nat = 48; // Articles expire after 48 hours in triage
  let SUBMISSION_FEE_E8S : Nat = 10_000_000; // 0.1 ICP submission fee to prevent spam

  // --- Janitor Timer Handler ---
  // Purges expired articles from triage (>48h old) and renews recurring briefs
  func handleJanitorCleanup<system>(_actionId : TT.ActionId, _action : TT.Action) : TT.ActionId {
    Debug.print("[Janitor] Running triage cleanup...");
    let purgedCount = articleManager.purgeExpiredArticles();
    Debug.print("[Janitor] Purged " # Nat.toText(purgedCount) # " expired articles");

    // Check and renew expired recurring briefs
    Debug.print("[Janitor] Checking for recurring briefs to renew...");
    let renewedCount = renewExpiredRecurringBriefs();
    Debug.print("[Janitor] Renewed " # Nat.toText(renewedCount) # " recurring briefs");

    // Schedule next cleanup in 6 hours
    let now = Time.now();
    let nextCleanupTime = now + (JANITOR_INTERVAL_HOURS * 60 * 60 * 1_000_000_000); // 6 hours in nanoseconds
    let nextActionId = tt().setActionSync<system>(
      Int.abs(nextCleanupTime),
      {
        actionType = "janitor_cleanup";
        params = to_candid (());
      },
    );
    Debug.print("[Janitor] Scheduled next cleanup for " # debug_show (nextCleanupTime));

    nextActionId;
  };

  // Helper function to renew expired recurring briefs
  func renewExpiredRecurringBriefs() : Nat {
    let now = Time.now();
    let expiredBriefIds = briefManager.getExpiredRecurringBriefs(now);
    var renewedCount = 0;

    for (briefId in expiredBriefIds.vals()) {
      switch (briefManager.renewRecurringBrief(briefId)) {
        case (#ok()) {
          renewedCount += 1;
        };
        case (#err(msg)) {
          Debug.print("[Janitor] Failed to renew brief " # briefId # ": " # msg);
        };
      };
    };

    renewedCount;
  };

  // Resource contents stored in memory for simplicity.
  // In a real application these would probably be uploaded or user generated.
  var resourceContents = [
    ("file:///main.py", "print('Hello from main.py!')"),
    ("file:///README.md", "# MCP Motoko Server"),
  ];

  // The application context that holds our state.
  var appContext : McpTypes.AppContext = State.init(resourceContents);

  // =================================================================================
  // --- OPT-IN: MONETIZATION & AUTHENTICATION ---
  // To enable paid tools, uncomment the following `authContext` initialization.
  // By default, it is `null`, and all tools are public.
  // Set the payment details in each tool definition to require payment.
  // See the README for more details.
  // =================================================================================

  // transient let authContext : ?AuthTypes.AuthContext = null;

  // --- UNCOMMENT THIS BLOCK TO ENABLE AUTHENTICATION ---

  let issuerUrl = "https://bfggx-7yaaa-aaaai-q32gq-cai.icp0.io";
  let allowanceUrl = "https://prometheusprotocol.org/connections";
  let requiredScopes = ["openid"];

  //function to transform the response for jwks client
  public query func transformJwksResponse({
    context : Blob;
    response : IC.HttpRequestResult;
  }) : async IC.HttpRequestResult {
    {
      response with headers = []; // not intersted in the headers
    };
  };

  // Initialize the auth context with the issuer URL and required scopes.
  let authContext : ?AuthTypes.AuthContext = ?AuthState.init(
    Principal.fromActor(self),
    owner,
    issuerUrl,
    requiredScopes,
    transformJwksResponse,
  );

  // --- END OF AUTHENTICATION BLOCK ---

  // =================================================================================
  // --- OPT-IN: USAGE ANALYTICS (BEACON) ---
  // To enable anonymous usage analytics, uncomment the `beaconContext` initialization.
  // This helps the Prometheus Protocol DAO understand ecosystem growth.
  // =================================================================================

  // transient let beaconContext : ?Beacon.BeaconContext = null;

  // --- UNCOMMENT THIS BLOCK TO ENABLE THE BEACON ---

  let beaconCanisterId = Principal.fromText("m63pw-fqaaa-aaaai-q33pa-cai");
  transient let beaconContext : ?Beacon.BeaconContext = ?Beacon.init(
    beaconCanisterId, // Public beacon canister ID
    ?(15 * 60), // Send a beacon every 15 minutes
  );

  // --- END OF BEACON BLOCK ---

  // --- Timers ---
  Cleanup.startCleanupTimer<system>(appContext);

  // The AuthCleanup timer only needs to run if authentication is enabled.
  switch (authContext) {
    case (?ctx) { AuthCleanup.startCleanupTimer<system>(ctx) };
    case (null) { Debug.print("Authentication is disabled.") };
  };

  // The Beacon timer only needs to run if the beacon is enabled.
  switch (beaconContext) {
    case (?ctx) { Beacon.startTimer<system>(ctx) };
    case (null) { Debug.print("Beacon is disabled.") };
  };

  // --- Register TimerTool Handlers ---
  tt().registerExecutionListenerSync(?"janitor_cleanup", handleJanitorCleanup);

  // --- 1. DEFINE YOUR RESOURCES & TOOLS ---
  transient let resources : [McpTypes.Resource] = [
    {
      uri = "file:///main.py";
      name = "main.py";
      title = ?"Main Python Script";
      description = ?"Contains the main logic of the application.";
      mimeType = ?"text/x-python";
    },
    {
      uri = "file:///README.md";
      name = "README.md";
      title = ?"Project Documentation";
      description = null;
      mimeType = ?"text/markdown";
    },
  ];

  // Helper functions for ICP ledger operations
  private func checkBalance(subaccount : Blob) : async Nat {
    // TODO: Implement ICP ledger balance check
    0;
  };

  private func transferFromEscrow(subaccount : Blob, to : Principal, amount : Nat) : async Result.Result<Nat, Text> {
    // TODO: Implement ICP ledger transfer
    #ok(0);
  };

  // Helper function to sync counters from transient managers to stable storage
  private func syncCounters() {
    stable_next_article_id := articleManager.getNextArticleId();
    stable_next_asset_id := articleManager.getNextAssetId();
  };

  // Create the tool context that will be passed to all tools
  transient let toolContext : ToolContext.ToolContext = {
    canisterPrincipal = thisPrincipal;
    owner = owner;
    appContext = appContext;
    briefManager = briefManager;
    articleManager = articleManager;
    icpLedgerCanisterId = func() { icpLedger };
    checkBalance = checkBalance;
    transferFromEscrow = transferFromEscrow;
    timerTool = tt();
    syncCounters = syncCounters;
  };

  // Import tool configurations from separate modules
  transient let tools : [McpTypes.Tool] = [
    ListBriefs.config(),
    FindBriefs.config(),
    SubmitArticle.config(),
    ViewPendingSubmissions.config(),
    EditDraft.config(),
    SubmitRevision.config(),
    // Add more tools here as you create them
  ];

  // --- 2. CONFIGURE THE SDK ---
  transient let mcpConfig : McpTypes.McpConfig = {
    self = Principal.fromActor(self);
    // allowanceUrl = null; // No allowance URL needed for free tools.
    allowanceUrl = ?allowanceUrl; // Uncomment this line if using paid tools.
    serverInfo = {
      name = "io.github.jneums.press";
      title = "Press";
      version = "0.1.4";
    };
    resources = resources;
    resourceReader = func(uri) {
      Map.get(appContext.resourceContents, Map.thash, uri);
    };
    tools = tools;
    toolImplementations = [
      ("list_briefs", ListBriefs.handle(toolContext)),
      ("find_briefs", FindBriefs.handle(toolContext)),
      ("submit_article", SubmitArticle.handle(toolContext)),
      ("view_pending_submissions", ViewPendingSubmissions.handle(toolContext)),
      ("edit_draft", EditDraft.handle(toolContext)),
      ("submit_revision", SubmitRevision.handle(toolContext)),
      // Add more tool implementations here as you create them
    ];
    beacon = beaconContext;
  };

  // --- 3. CREATE THE SERVER LOGIC ---
  transient let mcpServer = Mcp.createServer(mcpConfig);

  // --- PUBLIC ENTRY POINTS ---

  // Do not remove these public methods below. They are required for the MCP Registry and MCP Orchestrator
  // to manage the canister upgrades and installs, handle payments, and allow owner only methods.

  /// Get the current owner of the canister.
  public query func get_owner() : async Principal { return owner };

  /// Set a new owner for the canister. Only the current owner can call this.
  public shared ({ caller }) func set_owner(new_owner : Principal) : async Result.Result<(), Payments.TreasuryError> {
    if (caller != owner) { return #err(#NotOwner) };
    owner := new_owner;
    return #ok(());
  };

  /// Set the ICP Ledger canister ID. Only the current owner can call this.
  public shared ({ caller }) func set_icp_ledger(ledger_id : Principal) : async Result.Result<(), Text> {
    if (caller != owner) {
      return #err("Only the owner can set the ICP Ledger");
    };
    icpLedger := ?ledger_id;
    return #ok(());
  };

  /// Get the current ICP Ledger canister ID.
  public query func get_icp_ledger() : async ?Principal {
    return icpLedger;
  };

  /// Get the canister's balance of a specific ICRC-1 token.
  public shared func get_treasury_balance(ledger_id : Principal) : async Nat {
    return await Payments.get_treasury_balance(Principal.fromActor(self), ledger_id);
  };

  /// Withdraw tokens from the canister's treasury to a specified destination.
  public shared ({ caller }) func withdraw(
    ledger_id : Principal,
    amount : Nat,
    destination : Payments.Destination,
  ) : async Result.Result<Nat, Payments.TreasuryError> {
    return await Payments.withdraw(
      caller,
      owner,
      ledger_id,
      amount,
      destination,
    );
  };

  // Helper to create the HTTP context for each request.
  private func _create_http_context() : HttpHandler.Context {
    return {
      self = Principal.fromActor(self);
      active_streams = appContext.activeStreams;
      mcp_server = mcpServer;
      streaming_callback = http_request_streaming_callback;
      // This passes the optional auth context to the handler.
      // If it's `null`, the handler will skip all auth checks.
      auth = authContext;
      http_asset_cache = ?http_assets.cache;
      mcp_path = ?"/mcp";
    };
  };

  /// Handle incoming HTTP requests.
  public query func http_request(req : SrvTypes.HttpRequest) : async SrvTypes.HttpResponse {
    let ctx : HttpHandler.Context = _create_http_context();
    // Ask the SDK to handle the request
    switch (HttpHandler.http_request(ctx, req)) {
      case (?mcpResponse) {
        // The SDK handled it, so we return its response.
        return mcpResponse;
      };
      case (null) {
        // The SDK ignored it. Now we can handle our own custom routes.
        if (req.url == "/") {
          // e.g., Serve a frontend asset
          return {
            status_code = 200;
            headers = [("Content-Type", "text/html")];
            body = Text.encodeUtf8("<h1>My Canister Frontend</h1>");
            upgrade = null;
            streaming_strategy = null;
          };
        } else {
          // Return a 404 for any other unhandled routes.
          return {
            status_code = 404;
            headers = [];
            body = Blob.fromArray([]);
            upgrade = null;
            streaming_strategy = null;
          };
        };
      };
    };
  };

  /// Handle incoming HTTP requests that modify state (e.g., POST).
  public shared func http_request_update(req : SrvTypes.HttpRequest) : async SrvTypes.HttpResponse {
    let ctx : HttpHandler.Context = _create_http_context();

    // Ask the SDK to handle the request
    let mcpResponse = await HttpHandler.http_request_update(ctx, req);

    switch (mcpResponse) {
      case (?res) {
        // The SDK handled it.
        return res;
      };
      case (null) {
        // The SDK ignored it. Handle custom update calls here.
        return {
          status_code = 404;
          headers = [];
          body = Blob.fromArray([]);
          upgrade = null;
          streaming_strategy = null;
        };
      };
    };
  };

  /// Handle streaming callbacks for large HTTP responses.
  public query func http_request_streaming_callback(token : HttpTypes.StreamingToken) : async ?HttpTypes.StreamingCallbackResponse {
    let ctx : HttpHandler.Context = _create_http_context();
    return HttpHandler.http_request_streaming_callback(ctx, token);
  };

  // --- CANISTER LIFECYCLE MANAGEMENT ---

  system func preupgrade() {
    stable_http_assets := HttpAssets.preupgrade(http_assets);

    // Save counters before upgrade
    stable_next_brief_id := briefManager.getNextBriefId();
    stable_next_article_id := articleManager.getNextArticleId();
    stable_next_asset_id := articleManager.getNextAssetId();
  };

  system func postupgrade() {
    HttpAssets.postupgrade(http_assets);
  };

  /**
   * Creates a new API key. This API key is linked to the caller's principal.
   * @param name A human-readable name for the key.
   * @returns The raw, unhashed API key. THIS IS THE ONLY TIME IT WILL BE VISIBLE.
   */
  public shared (msg) func create_my_api_key(name : Text, scopes : [Text]) : async Text {
    switch (authContext) {
      case (null) {
        Debug.trap("Authentication is not enabled on this canister.");
      };
      case (?ctx) {
        return await ApiKey.create_my_api_key(
          ctx,
          msg.caller,
          name,
          scopes,
        );
      };
    };
  };

  /** Revoke (delete) an API key owned by the caller.
   * @param key_id The ID of the key to revoke.
   * @returns True if the key was found and revoked, false otherwise.
   */
  public shared (msg) func revoke_my_api_key(key_id : Text) : async () {
    switch (authContext) {
      case (null) {
        Debug.trap("Authentication is not enabled on this canister.");
      };
      case (?ctx) {
        return ApiKey.revoke_my_api_key(ctx, msg.caller, key_id);
      };
    };
  };

  /** List all API keys owned by the caller.
   * @returns A list of API key metadata (but not the raw keys).
   */
  public query (msg) func list_my_api_keys() : async [AuthTypes.ApiKeyMetadata] {
    switch (authContext) {
      case (null) {
        Debug.trap("Authentication is not enabled on this canister.");
      };
      case (?ctx) {
        return ApiKey.list_my_api_keys(ctx, msg.caller);
      };
    };
  };

  // --- Press Platform Management Functions ---

  /// Start the janitor timer for automatic triage cleanup
  /// Owner-only function to initialize the cleanup process
  public shared ({ caller }) func start_janitor_timer() : async Text {
    if (caller != owner) {
      return "Unauthorized: only owner can start janitor timer";
    };

    let now = Time.now();
    let firstCleanupTime = now + (JANITOR_INTERVAL_HOURS * 60 * 60 * 1_000_000_000);

    ignore tt().setActionSync<system>(
      Int.abs(firstCleanupTime),
      {
        actionType = "janitor_cleanup";
        params = to_candid (());
      },
    );

    "Janitor timer started. First cleanup scheduled in " # Nat.toText(JANITOR_INTERVAL_HOURS) # " hours.";
  };

  /// Manually run the janitor cleanup (owner-only)
  public shared ({ caller }) func run_janitor_now() : async Text {
    if (caller != owner) {
      return "Unauthorized: only owner can run janitor";
    };

    Debug.print("[Janitor] Manual cleanup triggered");
    let purgedCount = articleManager.purgeExpiredArticles();
    "Purged " # Nat.toText(purgedCount) # " expired articles from triage.";
  };

  // --- Web Query Endpoints for Frontend ---

  /// Get all open briefs for agents to browse
  public query func web_get_open_briefs() : async [PressTypes.Brief] {
    briefManager.getOpenBriefs();
  };

  /// Get briefs with filters and pagination (for MCP agents)
  public query func web_get_briefs_filtered(
    statusFilter : ?PressTypes.BriefStatus,
    topicFilter : ?Text,
    limit : Nat,
    offset : Nat,
  ) : async {
    briefs : [PressTypes.Brief];
    total : Nat;
  } {
    briefManager.getBriefsFiltered(statusFilter, topicFilter, limit, offset);
  };

  /// Get a specific brief by ID
  public query func web_get_brief(briefId : Text) : async ?PressTypes.Brief {
    briefManager.getBrief(briefId);
  };

  /// Get all articles in triage for the curator's briefs
  public shared query ({ caller }) func web_get_triage_articles() : async [PressTypes.Article] {
    // Get all briefs owned by the caller
    let curatorBriefIds = Buffer.Buffer<Text>(0);
    for ((briefId, brief) in Map.entries(stable_briefs)) {
      if (brief.curator == caller) {
        curatorBriefIds.add(briefId);
      };
    };

    // Filter triage articles to only include those for the curator's briefs
    // AND exclude #draft articles (only show #pending or later)
    let filteredArticles = Buffer.Buffer<PressTypes.Article>(0);
    for (article in articleManager.getTriageArticles().vals()) {
      // Skip draft articles - they should only be visible to the author
      switch (article.status) {
        case (#draft) { /* skip */ };
        case (_) {
          // Check if this article's brief belongs to the caller
          for (briefId in curatorBriefIds.vals()) {
            if (article.briefId == briefId) {
              filteredArticles.add(article);
            };
          };
        };
      };
    };

    Buffer.toArray(filteredArticles);
  };

  /// Get a specific article by ID
  public query func web_get_article(articleId : Nat) : async ?PressTypes.Article {
    articleManager.getArticle(articleId);
  };

  /// Get agent statistics
  public query func web_get_agent_stats(agent : Principal) : async ?PressTypes.AgentStats {
    articleManager.getAgentStats(agent);
  };

  /// Get all articles by a specific agent
  public query func web_get_articles_by_agent(agent : Principal) : async [PressTypes.Article] {
    articleManager.getArticlesByAgent(agent);
  };

  /// Get all articles submitted to a specific brief
  public query func web_get_articles_by_brief(briefId : Text) : async [PressTypes.Article] {
    articleManager.getArticlesByBrief(briefId);
  };

  /// Get curator statistics
  public query func web_get_curator_stats(curator : Principal) : async ?PressTypes.CuratorStats {
    briefManager.getCuratorStats(curator);
  };

  /// Get a media asset by ID
  public query func web_get_media_asset(assetId : Nat) : async ?PressTypes.MediaAsset {
    articleManager.getMediaAsset(assetId);
  };

  /// Get all articles in archive (approved/rejected content) for the curator's briefs
  /// Paginated to avoid large responses
  /// Optional status filter: null = all, ?#approved = approved only, ?#rejected = rejected only
  public shared query ({ caller }) func web_get_archived_articles(offset : Nat, limit : Nat, statusFilter : ?PressTypes.ArticleStatus) : async {
    articles : [PressTypes.Article];
    total : Nat;
  } {
    // Get all briefs owned by the caller
    let curatorBriefIds = Buffer.Buffer<Text>(0);
    for ((briefId, brief) in Map.entries(stable_briefs)) {
      if (brief.curator == caller) {
        curatorBriefIds.add(briefId);
      };
    };

    let allArticles = Buffer.Buffer<PressTypes.Article>(0);
    for ((id, article) in Map.entries(stable_articles_archive)) {
      // Check if this article's brief belongs to the caller
      var belongsToCurator = false;
      for (briefId in curatorBriefIds.vals()) {
        if (article.briefId == briefId) {
          belongsToCurator := true;
        };
      };

      if (belongsToCurator) {
        // Apply status filter if provided
        let shouldInclude = switch (statusFilter) {
          case (null) true;
          case (?filter) article.status == filter;
        };
        if (shouldInclude) {
          allArticles.add(article);
        };
      };
    };

    let total = allArticles.size();
    let articles = Buffer.Buffer<PressTypes.Article>(0);

    var i = offset;
    let endIndex = Nat.min(offset + limit, total);
    while (i < endIndex) {
      articles.add(allArticles.get(i));
      i += 1;
    };

    {
      articles = Buffer.toArray(articles);
      total = total;
    };
  };

  /// Get stats summary for the platform
  public query func web_get_platform_stats() : async {
    totalBriefs : Nat;
    openBriefs : Nat;
    totalArticlesSubmitted : Nat;
    articlesInTriage : Nat;
    articlesArchived : Nat;
    totalAgents : Nat;
    totalCurators : Nat;
    totalPaidOut : Nat;
  } {
    var openCount = 0;
    for ((id, brief) in Map.entries(stable_briefs)) {
      if (brief.status == #open) {
        openCount += 1;
      };
    };

    // Calculate total paid out across all agents
    var totalPaid : Nat = 0;
    for ((agent, stats) in Map.entries(stable_agent_stats)) {
      totalPaid += stats.totalEarned;
    };

    {
      totalBriefs = Map.size(stable_briefs);
      openBriefs = openCount;
      totalArticlesSubmitted = stable_next_article_id - 1;
      articlesInTriage = Map.size(stable_articles_triage);
      articlesArchived = Map.size(stable_articles_archive);
      totalAgents = Map.size(stable_agent_stats);
      totalCurators = Map.size(stable_curator_stats);
      totalPaidOut = totalPaid;
    };
  };

  // --- Article Curation Functions ---

  /// Approve an article and pay bounty to agent (curators only)
  public shared ({ caller }) func web_approve_article(
    articleId : Nat,
    briefId : Text,
  ) : async Result.Result<(), Text> {
    // Get article to find agent
    switch (articleManager.getArticle(articleId)) {
      case (?article) {
        // Get brief to determine bounty amount
        switch (briefManager.getBrief(briefId)) {
          case (?brief) {
            // Check that caller is the brief curator
            if (caller != brief.curator) {
              return #err("Only the brief curator can approve articles");
            };

            Debug.print("web_approve_article - Starting approval process");
            Debug.print("web_approve_article - briefId: " # briefId);
            Debug.print("web_approve_article - brief.bountyPerArticle: " # debug_show (brief.bountyPerArticle));
            Debug.print("web_approve_article - brief.escrowBalance: " # debug_show (brief.escrowBalance));
            Debug.print("web_approve_article - brief.approvedCount: " # debug_show (brief.approvedCount));
            Debug.print("web_approve_article - brief.maxArticles: " # debug_show (brief.maxArticles));

            // Check and deduct from escrow BEFORE making the transfer
            // This ensures our tracking stays in sync even if transfer fails
            let totalCost = brief.bountyPerArticle; // Full bounty covers paymentAmount + fee
            Debug.print("web_approve_article - totalCost: " # debug_show (totalCost));

            if (brief.escrowBalance < totalCost) {
              Debug.print("web_approve_article - INSUFFICIENT ESCROW (before recordApproval)");
              return #err("Insufficient escrow balance");
            };

            // Record the approval and deduct from escrow tracking FIRST
            Debug.print("web_approve_article - Calling recordApproval...");
            switch (briefManager.recordApproval(briefId, totalCost)) {
              case (#err(msg)) {
                Debug.print("web_approve_article - recordApproval FAILED: " # msg);
                return #err(msg);
              };
              case (#ok()) {
                Debug.print("web_approve_article - recordApproval SUCCESS");
              };
            };

            // Get ICP Ledger principal
            let ledgerPrincipal = Option.get(icpLedger, Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai"));

            // Transfer ICP bounty to agent from brief's escrow using ICRC-1
            let ledger = actor (Principal.toText(ledgerPrincipal)) : actor {
              icrc1_transfer : shared IcpLedger.TransferArg -> async IcpLedger.Result;
            };

            // ICP transfer fee is 10,000 e8s (0.0001 ICP)
            let fee = 10_000;

            // Calculate payment amount (bounty minus fee, so agent receives exactly bountyPerArticle - fee)
            if (brief.bountyPerArticle <= fee) {
              return #err("Bounty is too small to cover transfer fee");
            };
            let paymentAmount = brief.bountyPerArticle - fee;

            let transferArgs : IcpLedger.TransferArg = {
              from_subaccount = ?brief.escrowSubaccount;
              to = { owner = article.agent; subaccount = null };
              amount = paymentAmount;
              fee = ?fee;
              memo = null;
              created_at_time = null;
            };

            let transferResult = await ledger.icrc1_transfer(transferArgs);

            switch (transferResult) {
              case (#Ok(blockHeight)) {
                // Payment successful, approve the article
                let result = articleManager.approveArticle(articleId, caller, paymentAmount);

                // Check if the brief is now full and reject remaining pending articles
                if (brief.approvedCount + 1 >= brief.maxArticles) {
                  let rejectedCount = articleManager.rejectPendingArticlesForBrief(
                    briefId,
                    ?articleId,
                    caller,
                    "Brief has been filled - all available slots have been approved",
                  );
                  Debug.print("web_approve_article - Brief filled, auto-rejected " # debug_show (rejectedCount) # " pending articles");
                };

                result;
              };
              case (#Err(error)) {
                // Transfer failed - we need to refund the escrow tracking
                // Add the bounty back to escrow since payment didn't happen
                ignore briefManager.addToEscrow(briefId, totalCost);
                #err("Failed to transfer bounty: " # debug_show (error));
              };
            };
          };
          case null {
            #err("Brief not found");
          };
        };
      };
      case null {
        #err("Article not found");
      };
    };
  };

  /// Reject an article (curators only)
  public shared ({ caller }) func web_reject_article(
    articleId : Nat,
    reason : Text,
  ) : async Result.Result<(), Text> {
    // TODO: Add curator permission check
    articleManager.rejectArticle(articleId, caller, reason);
  };

  /// Request revisions for an article (curators only)
  /// This signals the curator is interested in the article but needs changes
  /// On first revision request, reserves the slot (counts as acceptance)
  /// Funds remain in escrow until final approval
  public shared ({ caller }) func web_request_revision(
    articleId : Nat,
    briefId : Text,
    feedback : Text,
  ) : async Result.Result<(), Text> {
    // Get article to verify it exists and get brief
    switch (articleManager.getArticle(articleId)) {
      case (?article) {
        // Get brief to verify curator owns it
        switch (briefManager.getBrief(briefId)) {
          case (?brief) {
            // Check that caller is the brief curator
            if (caller != brief.curator) {
              return #err("Only the brief curator can request revisions");
            };

            // If this is the first revision request (not already selected), reserve the slot
            // This treats the revision request as an acceptance and closes the brief to other submissions
            if (not article.selectedForRevision) {
              switch (briefManager.reserveSlot(briefId)) {
                case (#err(e)) { return #err(e) };
                case (#ok()) {
                  // If this is a single-slot brief, reject other pending articles
                  if (brief.maxArticles == 1) {
                    let rejectedCount = articleManager.rejectPendingArticlesForBrief(
                      briefId,
                      ?articleId,
                      caller,
                      "Brief has been filled - article selected for revision",
                    );
                    Debug.print("web_request_revision - Single-slot brief, auto-rejected " # debug_show (rejectedCount) # " pending articles");
                  };
                };
              };
            };

            // Request the revision
            articleManager.requestRevision(articleId, caller, feedback);
          };
          case null {
            #err("Brief not found");
          };
        };
      };
      case null {
        #err("Article not found");
      };
    };
  };

  /// Submit a revision for an article (agents only)
  /// This allows the agent to respond to revision requests
  public shared ({ caller }) func web_submit_revision(
    articleId : Nat,
    revisedContent : Text,
  ) : async Result.Result<(), Text> {
    articleManager.submitRevision(articleId, caller, revisedContent);
  };

  /// Agent approves their draft article to send to curator queue
  public shared ({ caller }) func web_approve_draft(
    articleId : Nat
  ) : async Result.Result<(), Text> {
    switch (articleManager.approveDraftToPending(articleId, caller)) {
      case (#ok(briefId)) {
        // Now increment the submitted count since article is moving from draft to pending
        ignore briefManager.incrementSubmittedCount(briefId);
        #ok();
      };
      case (#err(e)) {
        #err(e);
      };
    };
  };

  /// Agent updates their draft article content
  public shared ({ caller }) func web_update_draft(
    articleId : Nat,
    newTitle : Text,
    newContent : Text,
  ) : async Result.Result<(), Text> {
    articleManager.updateDraftArticle(articleId, caller, newTitle, newContent);
  };

  /// Agent deletes their draft article
  public shared ({ caller }) func web_delete_draft(
    articleId : Nat
  ) : async Result.Result<(), Text> {
    articleManager.deleteDraftArticle(articleId, caller);
  };

  // --- Brief Management Functions ---

  /// Create a new brief (curators only)
  public shared ({ caller }) func create_brief(
    title : Text,
    description : Text,
    topic : Text,
    platformConfig : PressTypes.PlatformConfig,
    requirements : PressTypes.BriefRequirements,
    bountyPerArticle : Nat,
    maxArticles : Nat,
    expiresAt : ?Time.Time,
    isRecurring : Bool,
    recurrenceIntervalNanos : ?Nat,
  ) : async Result.Result<{ briefId : Text; subaccount : Blob }, Text> {

    // Calculate total escrow amount needed
    let totalEscrow = bountyPerArticle * maxArticles;

    // Get ICP Ledger canister ID
    let ledgerCanisterId = switch (icpLedger) {
      case (?id) { id };
      case (null) {
        return #err("ICP Ledger not configured");
      };
    };

    // Create actor reference to ICP Ledger for ICRC-2 transfer_from
    let ledger = actor (Principal.toText(ledgerCanisterId)) : actor {
      icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
    };

    // First create the brief to get the subaccount (with 0 balance temporarily)
    let briefResult = briefManager.createBrief(
      caller,
      title,
      description,
      topic,
      platformConfig,
      requirements,
      bountyPerArticle,
      maxArticles,
      expiresAt,
      0, // Temporary, will update after transfer
      isRecurring,
      recurrenceIntervalNanos,
    );

    let (briefId, subaccount) = switch (briefResult) {
      case (#ok(result)) { (result.briefId, result.subaccount) };
      case (#err(msg)) { return #err(msg) };
    };

    // Now transfer funds from curator to escrow subaccount using ICRC-2 transfer_from
    try {
      let transferResult = await ledger.icrc2_transfer_from({
        from = { owner = caller; subaccount = null };
        to = { owner = thisPrincipal; subaccount = ?subaccount };
        amount = totalEscrow;
        fee = null;
        memo = null;
        created_at_time = null;
        spender_subaccount = null;
      });

      switch (transferResult) {
        case (#Err(error)) {
          // Transfer failed - close the brief
          ignore briefManager.closeBrief(briefId);

          let errorMsg = switch (error) {
            case (#InsufficientAllowance { allowance }) {
              "Insufficient ICRC-2 allowance. Please approve " # Nat.toText(totalEscrow + 10_000) # " e8s (including fee) before creating the brief";
            };
            case (#InsufficientFunds { balance }) {
              "Insufficient ICP balance: " # Nat.toText(balance) # " e8s. Need " # Nat.toText(totalEscrow) # " e8s";
            };
            case (#BadFee { expected_fee }) {
              "Incorrect fee. Expected: " # Nat.toText(expected_fee) # " e8s";
            };
            case _ {
              "Transfer failed. Please ensure you have approved the canister to spend ICP on your behalf";
            };
          };
          return #err(errorMsg);
        };
        case (#Ok(_blockIndex)) {
          // Transfer successful - update the escrow balance
          ignore briefManager.updateEscrowBalance(briefId, totalEscrow);
          return #ok({ briefId = briefId; subaccount = subaccount });
        };
      };
    } catch (e) {
      // Exception during transfer - close the brief
      ignore briefManager.closeBrief(briefId);
      return #err("Failed to transfer funds: " # Error.message(e));
    };
  };

  /// Update an existing brief (curators only)
  /// Fairness constraints:
  /// - Only the curator who created the brief can update it
  /// - Brief must be open (can't update closed/cancelled briefs)
  /// - Bounty can only INCREASE (protects authors who submitted based on original terms)
  /// - MaxArticles can only INCREASE (requires additional escrow)
  /// - ExpiresAt can only be extended, not shortened
  /// - Requirements can be changed but should be done fairly
  /// If bounty or maxArticles increase, additional escrow is required
  public shared ({ caller }) func update_brief(
    briefId : Text,
    updates : PressTypes.BriefUpdateRequest,
  ) : async Result.Result<(), Text> {
    // First validate the update and calculate additional escrow needed
    let updateResult = briefManager.updateBrief(briefId, caller, updates);

    switch (updateResult) {
      case (#err(msg)) {
        return #err(msg);
      };
      case (#ok({ additionalEscrowNeeded })) {
        // If additional escrow is needed, transfer it
        if (additionalEscrowNeeded > 0) {
          // Get ICP Ledger canister ID
          let ledgerCanisterId = switch (icpLedger) {
            case (?id) { id };
            case (null) {
              return #err("ICP Ledger not configured");
            };
          };

          // Get the brief to get its subaccount
          let brief = switch (briefManager.getBrief(briefId)) {
            case (?b) { b };
            case (null) {
              return #err("Brief not found after update");
            };
          };

          // Create actor reference to ICP Ledger for ICRC-2 transfer_from
          let ledger = actor (Principal.toText(ledgerCanisterId)) : actor {
            icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
          };

          try {
            let transferResult = await ledger.icrc2_transfer_from({
              from = { owner = caller; subaccount = null };
              to = {
                owner = thisPrincipal;
                subaccount = ?brief.escrowSubaccount;
              };
              amount = additionalEscrowNeeded;
              fee = null;
              memo = null;
              created_at_time = null;
              spender_subaccount = null;
            });

            switch (transferResult) {
              case (#Err(error)) {
                // Transfer failed - but update already applied
                // We should note this in the error message
                let errorMsg = switch (error) {
                  case (#InsufficientAllowance { allowance }) {
                    "Brief updated but additional escrow transfer failed: Insufficient ICRC-2 allowance. Please approve " # Nat.toText(additionalEscrowNeeded + 10_000) # " e8s and call add_escrow_to_brief";
                  };
                  case (#InsufficientFunds { balance }) {
                    "Brief updated but additional escrow transfer failed: Insufficient ICP balance. Need " # Nat.toText(additionalEscrowNeeded) # " e8s. Call add_escrow_to_brief when ready";
                  };
                  case _ {
                    "Brief updated but additional escrow transfer failed. Call add_escrow_to_brief with " # Nat.toText(additionalEscrowNeeded) # " e8s";
                  };
                };
                return #err(errorMsg);
              };
              case (#Ok(_blockIndex)) {
                // Transfer successful - update the escrow balance
                let newBalance = brief.escrowBalance + additionalEscrowNeeded;
                ignore briefManager.updateEscrowBalance(briefId, newBalance);
                return #ok();
              };
            };
          } catch (e) {
            return #err("Brief updated but escrow transfer failed: " # Error.message(e) # ". Call add_escrow_to_brief when ready");
          };
        } else {
          // No additional escrow needed
          return #ok();
        };
      };
    };
  };

  /// Add additional escrow to a brief (useful after failed transfer during update)
  public shared ({ caller }) func add_escrow_to_brief(
    briefId : Text,
    amount : Nat,
  ) : async Result.Result<(), Text> {
    // Get the brief
    let brief = switch (briefManager.getBrief(briefId)) {
      case (?b) { b };
      case (null) {
        return #err("Brief not found");
      };
    };

    // Only curator can add escrow
    if (brief.curator != caller) {
      return #err("Only the brief curator can add escrow");
    };

    // Get ICP Ledger canister ID
    let ledgerCanisterId = switch (icpLedger) {
      case (?id) { id };
      case (null) {
        return #err("ICP Ledger not configured");
      };
    };

    // Create actor reference to ICP Ledger
    let ledger = actor (Principal.toText(ledgerCanisterId)) : actor {
      icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
    };

    try {
      let transferResult = await ledger.icrc2_transfer_from({
        from = { owner = caller; subaccount = null };
        to = { owner = thisPrincipal; subaccount = ?brief.escrowSubaccount };
        amount = amount;
        fee = null;
        memo = null;
        created_at_time = null;
        spender_subaccount = null;
      });

      switch (transferResult) {
        case (#Err(error)) {
          let errorMsg = switch (error) {
            case (#InsufficientAllowance { allowance }) {
              "Insufficient ICRC-2 allowance. Please approve " # Nat.toText(amount + 10_000) # " e8s";
            };
            case (#InsufficientFunds { balance }) {
              "Insufficient ICP balance: " # Nat.toText(balance) # " e8s";
            };
            case _ {
              "Transfer failed";
            };
          };
          return #err(errorMsg);
        };
        case (#Ok(_blockIndex)) {
          // Transfer successful - update the escrow balance
          let newBalance = brief.escrowBalance + amount;
          ignore briefManager.updateEscrowBalance(briefId, newBalance);
          return #ok();
        };
      };
    } catch (e) {
      return #err("Failed to transfer funds: " # Error.message(e));
    };
  };

  public type UpgradeFinishedResult = {
    #InProgress : Nat;
    #Failed : (Nat, Text);
    #Success : Nat;
  };
  private func natNow() : Nat {
    return Int.abs(Time.now());
  };
  /* Return success after post-install/upgrade operations complete.
   * The Nat value is a timestamp (in nanoseconds) of when the upgrade finished.
   * If the upgrade is still in progress, return #InProgress with a timestamp of when it started.
   * If the upgrade failed, return #Failed with a timestamp and an error message.
   */
  public func icrc120_upgrade_finished() : async UpgradeFinishedResult {
    #Success(natNow());
  };
};
