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
        msg #= "Article ID: " # Nat.toText(article.articleId) # "\n";

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

        // Show bounty paid if approved
        if (article.bountyPaid > 0) {
          let paidWhole = article.bountyPaid / 100_000_000;
          let paidDec = article.bountyPaid % 100_000_000;
          msg #= "💰 Bounty Paid: " # Nat.toText(paidWhole) # "." # Nat.toText(paidDec / 10_000_000) # " ICP\n";
        };

        // Show revision info if applicable
        if (article.revisionsRequested > 0) {
          msg #= "🔄 Revisions: " # Nat.toText(article.revisionsRequested) # " of 3\n";
        };

        // Show submission time
        let now = Time.now();
        let submittedDate = article.submittedAt / 1_000_000_000;
        let ageSeconds = Int.abs((now - article.submittedAt) / 1_000_000_000);
        let ageHours = ageSeconds / 3600;
        let ageMinutes = (ageSeconds % 3600) / 60;

        if (ageHours > 0) {
          msg #= "🕐 Submitted: " # Nat.toText(ageHours) # "h " # Nat.toText(ageMinutes) # "m ago\n";
        } else {
          msg #= "🕐 Submitted: " # Nat.toText(ageMinutes) # " minutes ago\n";
        };

        // Show expiry warning for drafts and pending articles
        switch (ctx.articleManager.getArticleExpiryInfo(article.articleId)) {
          case (?(hoursRemaining, shouldRemind)) {
            let remainingHours = Int.abs(hoursRemaining);
            if (shouldRemind) {
              // Urgent warning
              msg #= "⚠️ EXPIRES IN " # Nat.toText(remainingHours) # "h - Please take action soon!\n";
            } else if (article.status == #draft) {
              // Draft with time remaining
              msg #= "⏱️ Draft expires in " # Nat.toText(remainingHours) # "h (72h limit)\n";
            } else if (article.status == #pending or article.status == #revisionSubmitted) {
              // Pending with time remaining
              msg #= "⏱️ Review window: " # Nat.toText(remainingHours) # "h remaining (48h limit)\n";
            };
          };
          case (null) {};
        };

        // Show reviewed time if available
        switch (article.reviewedAt) {
          case (?reviewedAt) {
            let reviewedAgeSeconds = Int.abs((now - reviewedAt) / 1_000_000_000);
            let reviewedAgeHours = reviewedAgeSeconds / 3600;
            let reviewedAgeMinutes = (reviewedAgeSeconds % 3600) / 60;

            if (reviewedAgeHours > 0) {
              msg #= "✓ Reviewed: " # Nat.toText(reviewedAgeHours) # "h " # Nat.toText(reviewedAgeMinutes) # "m ago\n";
            } else {
              msg #= "✓ Reviewed: " # Nat.toText(reviewedAgeMinutes) # " minutes ago\n";
            };
          };
          case (null) {};
        };

        // Show latest revision feedback if exists (but not who requested it for privacy)
        if (article.revisionHistory.size() > 0 and (article.status == #revisionRequested or article.status == #revisionSubmitted)) {
          let latestRevision = article.revisionHistory[article.revisionHistory.size() - 1];
          msg #= "\n💬 Latest Feedback:\n";
          msg #= "   " # latestRevision.feedback # "\n";
        };

        msg #= "\n";
      };

      // Add helpful instructions based on what's shown
      if (filteredArticles.size() > 0) {
        msg #= "═══════════════════════════════════════\n";
        msg #= "ℹ️  Next Steps:\n";

        let hasDrafts = Array.filter<PressTypes.Article>(filteredArticles, func(a) { a.status == #draft }).size() > 0;
        let hasRevisionRequests = Array.filter<PressTypes.Article>(filteredArticles, func(a) { a.status == #revisionRequested }).size() > 0;

        if (hasDrafts) {
          msg #= "• Use edit_draft to modify your draft, then the system will auto-submit\n";
        };
        if (hasRevisionRequests) {
          msg #= "• Use submit_revision with article ID to submit updated content\n";
        };
      };

      ToolContext.makeTextSuccess(msg, cb);
    };
  };
};
