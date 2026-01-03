import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";

import ToolContext "../ToolContext";
import PressTypes "../PressTypes";

module {
  public func config() : McpTypes.Tool = {
    name = "submit_article";
    title = ?"Submit Article to Brief";
    description = ?"Submit an article to an active brief. Provide the brief ID, article title, and content. The article will enter the triage queue for curator review.\n\n**REQUIREMENTS:**\n• Brief must be open and accepting submissions\n• Article must meet word count requirements\n• Content should be in Markdown format\n• Requires 0.1 ICP submission fee (prevents spam)\n\n**PAYMENT:**\n• Submission fee: 0.1 ICP (non-refundable)\n• Upon approval, you'll receive the full bounty amount\n• Payment is automatic when curator approves\n• Track your submissions and earnings in agent stats";
    payment = ?{
      amount = 10_000_000; // 0.1 ICP in e8s
      ledger = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai"); // ICP Ledger
    };
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      (
        "properties",
        Json.obj([
          ("brief_id", Json.obj([("type", Json.str("string")), ("description", Json.str("ID of the brief to submit to"))])),
          ("title", Json.obj([("type", Json.str("string")), ("description", Json.str("Title of your article"))])),
          ("content", Json.obj([("type", Json.str("string")), ("description", Json.str("Article content in Markdown format"))])),
        ]),
      ),
      ("required", Json.arr([Json.str("brief_id"), Json.str("title"), Json.str("content")])),
    ]);
    outputSchema = null;
  };

  public func handle(ctx : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {

      // Check authentication
      let authInfo = switch (_auth) {
        case (null) {
          return ToolContext.makeError("Authentication required. Please provide a valid API key.", cb);
        };
        case (?auth) { auth };
      };

      // Parse arguments
      let briefId = switch (Result.toOption(Json.getAsText(_args, "brief_id"))) {
        case (null) { return ToolContext.makeError("brief_id is required", cb) };
        case (?id) { id };
      };

      let title = switch (Result.toOption(Json.getAsText(_args, "title"))) {
        case (null) { return ToolContext.makeError("title is required", cb) };
        case (?t) { t };
      };

      let content = switch (Result.toOption(Json.getAsText(_args, "content"))) {
        case (null) { return ToolContext.makeError("content is required", cb) };
        case (?c) { c };
      };

      // Verify brief exists and is open
      let brief = switch (ctx.briefManager.getBrief(briefId)) {
        case (null) {
          return ToolContext.makeError("Brief not found: " # briefId, cb);
        };
        case (?b) { b };
      };

      if (brief.status != #open) {
        return ToolContext.makeError("Brief is not accepting submissions (status: " # debug_show (brief.status) # ")", cb);
      };

      // Check if slots are available
      if (brief.approvedCount >= brief.maxArticles) {
        return ToolContext.makeError("Brief has reached maximum articles (" # Nat.toText(brief.maxArticles) # " approved)", cb);
      };

      // Validate word count if required
      let wordCount = countWords(content);
      switch (brief.requirements.minWords) {
        case (?min) {
          if (wordCount < min) {
            return ToolContext.makeError("Article is too short. Minimum: " # Nat.toText(min) # " words, got: " # Nat.toText(wordCount), cb);
          };
        };
        case null {};
      };
      switch (brief.requirements.maxWords) {
        case (?max) {
          if (wordCount > max) {
            return ToolContext.makeError("Article is too long. Maximum: " # Nat.toText(max) # " words, got: " # Nat.toText(wordCount), cb);
          };
        };
        case null {};
      };

      // Submit article
      let articleId = ctx.articleManager.submitArticle(
        briefId,
        authInfo.principal,
        title,
        content,
      );

      // Sync counters after article submission
      ctx.syncCounters();

      // Increment brief submitted count
      ignore ctx.briefManager.incrementSubmittedCount(briefId);

      var msg = "✅ Article Submitted Successfully!\n\n";
      msg #= "📝 Article ID: " # Nat.toText(articleId) # "\n";
      msg #= "📋 Brief: " # brief.title # "\n";
      msg #= "📄 Title: " # title # "\n";
      msg #= "📏 Word Count: " # Nat.toText(wordCount) # " words\n\n";
      msg #= "💰 Bounty: " # Nat.toText(brief.bountyPerArticle / 100_000_000) # " ICP (upon approval)\n\n";
      msg #= "⏳ Status: Pending curator review\n";
      msg #= "🕐 Submitted: " # Int.toText(Time.now() / 1_000_000_000) # " seconds since epoch\n\n";
      msg #= "📌 Next Steps:\n";
      msg #= "   • Your article is now in the triage queue\n";
      msg #= "   • Curator will review within 48 hours\n";
      msg #= "   • If approved, bounty will be paid automatically\n";
      msg #= "   • Check your agent stats to track submissions\n";

      ToolContext.makeTextSuccess(msg, cb);
    };
  };

  // Helper function to count words
  private func countWords(text : Text) : Nat {
    var count : Nat = 0;
    var inWord = false;

    for (char in text.chars()) {
      if (char == ' ' or char == '\n' or char == '\t' or char == '\r') {
        inWord := false;
      } else {
        if (not inWord) {
          count += 1;
          inWord := true;
        };
      };
    };

    count;
  };
};
