import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Map "mo:map/Map";
import { nhash } "mo:map/Map";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";

import ToolContext "../ToolContext";
import PressTypes "../PressTypes";

module {
  public func config() : McpTypes.Tool = {
    name = "view_pending_submissions";
    title = ?"View Pending Submissions";
    description = ?"View your own articles awaiting review or revision. Shows drafts you haven't approved yet, articles pending curator review, revision requests, and rejected articles with rejection reasons.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("status_filter", Json.obj([("type", Json.str("string")), ("description", Json.str("Optional: Filter by status. Values: 'draft', 'pending', 'revisionRequested', 'revisionSubmitted', 'rejected', 'all'. Default is 'all'.")), ("enum", Json.arr([Json.str("draft"), Json.str("pending"), Json.str("revisionRequested"), Json.str("revisionSubmitted"), Json.str("rejected"), Json.str("all")]))]))])),
    ]);
    outputSchema = null;
  };

  public func handle(ctx : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {

      // Check authentication - required to scope results to the caller
      let authInfo = switch (_auth) {
        case (null) {
          return ToolContext.makeError("Authentication required. Please provide a valid API key.", cb);
        };
        case (?auth) { auth };
      };

      // The caller can only see their own submissions
      let callerPrincipal = authInfo.principal;

      // Parse status filter (default: all)
      let statusFilter = switch (Result.toOption(Json.getAsText(_args, "status_filter"))) {
        case (null) { "all" };
        case (?s) { s };
      };

      // Get all articles by this agent (from both triage and archive)
      let allArticles = ctx.articleManager.getArticlesByAgent(callerPrincipal);

      // Filter to only show relevant statuses (exclude approved and expired by default)
      var filteredArticles : [PressTypes.Article] = Array.filter<PressTypes.Article>(
        allArticles,
        func(a) {
          // Show: draft, pending, revisionRequested, revisionSubmitted, rejected
          // Hide: approved, expired (unless explicitly filtered)
          switch (a.status) {
            case (#approved) { false };
            case (#expired) { false };
            case _ { true };
          };
        },
      );

      if (filteredArticles.size() == 0) {
        return ToolContext.makeTextSuccess("📭 No Pending Submissions\n\nYou have no articles pending review, awaiting revision, or recently rejected.", cb);
      };

      // Filter by status if specified
      if (statusFilter != "all") {
        filteredArticles := Array.filter<PressTypes.Article>(
          filteredArticles,
          func(a) {
            switch (statusFilter) {
              case ("draft") { a.status == #draft };
              case ("pending") { a.status == #pending };
              case ("revisionRequested") { a.status == #revisionRequested };
              case ("revisionSubmitted") { a.status == #revisionSubmitted };
              case ("rejected") { a.status == #rejected };
              case _ { true };
            };
          },
        );
      };

      if (filteredArticles.size() == 0) {
        let statusMsg = if (statusFilter != "all") {
          " with status '" # statusFilter # "'";
        } else { "" };
        return ToolContext.makeTextSuccess("📭 No Matching Submissions\n\nNo articles found" # statusMsg # ".", cb);
      };

      var msg = "📋 Your Submissions (" # Nat.toText(filteredArticles.size()) # ")\n\n";

      for (article in filteredArticles.vals()) {
        msg #= "═══════════════════════════════════════\n";
        msg #= "📝 " # article.title # "\n";
        msg #= "ID: " # Nat.toText(article.articleId) # " | Brief: " # article.briefId # "\n";

        // Status with emoji
        let statusEmoji = switch (article.status) {
          case (#draft) { "✏️ Draft" };
          case (#pending) { "⏳ Pending Review" };
          case (#revisionRequested) { "🔄 Revision Requested" };
          case (#revisionSubmitted) { "✅ Revision Submitted" };
          case (#approved) { "✅ Approved" };
          case (#rejected) { "❌ Rejected" };
          case (#expired) { "⏰ Expired" };
        };
        msg #= "Status: " # statusEmoji # "\n";

        // Show rejection reason if rejected
        switch (article.rejectionReason) {
          case (?reason) {
            msg #= "❌ Rejection Reason: " # reason # "\n";
          };
          case (null) {};
        };

        msg #= "👤 Agent: " # Principal.toText(article.agent) # "\n";

        // Show revision info if applicable
        if (article.revisionsRequested > 0) {
          msg #= "🔄 Revisions: " # Nat.toText(article.revisionsRequested) # " of 3\n";
          msg #= "📊 Current Revision: " # Nat.toText(article.currentRevision) # "\n";
        };

        // Show submission time
        let now = Time.now();
        let ageSeconds = Int.abs((now - article.submittedAt) / 1_000_000_000);
        let ageHours = ageSeconds / 3600;
        let ageMinutes = (ageSeconds % 3600) / 60;

        if (ageHours > 0) {
          msg #= "🕐 Submitted: " # Nat.toText(ageHours) # "h " # Nat.toText(ageMinutes) # "m ago\n";
        } else {
          msg #= "🕐 Submitted: " # Nat.toText(ageMinutes) # " minutes ago\n";
        };

        // Show latest revision request if exists
        if (article.revisionHistory.size() > 0) {
          let latestRevision = article.revisionHistory[article.revisionHistory.size() - 1];
          msg #= "\n💬 Latest Feedback:\n";
          msg #= "   " # latestRevision.feedback # "\n";
          msg #= "   Requested by: " # Principal.toText(latestRevision.requestedBy) # "\n";

          let revAgeSeconds = Int.abs((now - latestRevision.requestedAt) / 1_000_000_000);
          let revAgeHours = revAgeSeconds / 3600;
          let revAgeMinutes = (revAgeSeconds % 3600) / 60;

          if (revAgeHours > 0) {
            msg #= "   " # Nat.toText(revAgeHours) # "h " # Nat.toText(revAgeMinutes) # "m ago\n";
          } else {
            msg #= "   " # Nat.toText(revAgeMinutes) # " minutes ago\n";
          };
        };

        // Show content preview
        let contentPreview = if (Text.size(article.content) > 200) {
          let chars = Text.toIter(article.content);
          var preview = "";
          var count = 0;
          label l for (char in chars) {
            if (count >= 200) break l;
            preview #= Text.fromChar(char);
            count += 1;
          };
          preview # "...";
        } else {
          article.content;
        };
        msg #= "\n📄 Content Preview:\n" # contentPreview # "\n\n";
      };

      // Add helpful instructions based on what's shown
      if (filteredArticles.size() > 0) {
        msg #= "═══════════════════════════════════════\n";
        msg #= "ℹ️  Instructions:\n";

        let hasDrafts = Array.filter<PressTypes.Article>(filteredArticles, func(a) { a.status == #draft }).size() > 0;
        let hasRevisionRequests = Array.filter<PressTypes.Article>(filteredArticles, func(a) { a.status == #revisionRequested }).size() > 0;

        if (hasDrafts) {
          msg #= "• Draft articles need to be approved before curators can review them\n";
        };
        if (hasRevisionRequests) {
          msg #= "• Revision-requested articles need updated content submitted by the agent\n";
        };
      };

      ToolContext.makeTextSuccess(msg, cb);
    };
  };
};
