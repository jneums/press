import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Text "mo:base/Text";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";

import ToolContext "../ToolContext";
import PressTypes "../PressTypes";

module {
  public func config() : McpTypes.Tool = {
    name = "submit_revision";
    title = ?"Submit Revision";
    description = ?"Submit a revised article in response to a curator's revision request. Use this tool when a curator has requested changes to your article.\n\n**REQUIREMENTS:**\n• Article must have status 'revisionRequested'\n• You must be the original author\n• Address the curator's feedback in your revision\n\n**NO PAYMENT REQUIRED:**\n• Revisions are free - no additional ICP fee\n• You already paid the submission fee when first submitting\n\n**WORKFLOW:**\n1. Use view_pending_submissions to see revision requests and feedback\n2. Revise your content based on the curator's feedback\n3. Submit the revision with this tool\n4. Curator will review the updated article";
    payment = null; // No payment required for revisions
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      (
        "properties",
        Json.obj([
          ("article_id", Json.obj([("type", Json.str("string")), ("description", Json.str("The ID of the article to revise (from view_pending_submissions)"))])),
          ("content", Json.obj([("type", Json.str("string")), ("description", Json.str("The revised article content in Markdown format. Address the curator's feedback."))])),
        ]),
      ),
      ("required", Json.arr([Json.str("article_id"), Json.str("content")])),
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
      let articleIdText = switch (Result.toOption(Json.getAsText(_args, "article_id"))) {
        case (null) {
          return ToolContext.makeError("article_id is required", cb);
        };
        case (?id) { id };
      };

      // Parse article ID as Nat
      let articleId = switch (Nat.fromText(articleIdText)) {
        case (null) {
          return ToolContext.makeError("Invalid article_id: must be a number", cb);
        };
        case (?id) { id };
      };

      let revisedContent = switch (Result.toOption(Json.getAsText(_args, "content"))) {
        case (null) {
          return ToolContext.makeError("content is required", cb);
        };
        case (?c) { c };
      };

      // Get the existing article to check status and show feedback
      let existingArticle = switch (ctx.articleManager.getArticle(articleId)) {
        case (null) {
          return ToolContext.makeError("Article not found: " # articleIdText, cb);
        };
        case (?article) { article };
      };

      // Verify status is revisionRequested
      if (existingArticle.status != #revisionRequested) {
        return ToolContext.makeError("This article does not have a pending revision request. Current status: " # statusToText(existingArticle.status) # ". Use edit_draft for draft articles.", cb);
      };

      // Get the brief for context
      let brief = ctx.briefManager.getBrief(existingArticle.briefId);

      // Validate word count if brief has requirements
      let wordCount = countWords(revisedContent);
      switch (brief) {
        case (?b) {
          switch (b.requirements.minWords) {
            case (?min) {
              if (wordCount < min) {
                return ToolContext.makeError("Revised article is too short. Minimum: " # Nat.toText(min) # " words, got: " # Nat.toText(wordCount), cb);
              };
            };
            case null {};
          };
          switch (b.requirements.maxWords) {
            case (?max) {
              if (wordCount > max) {
                return ToolContext.makeError("Revised article is too long. Maximum: " # Nat.toText(max) # " words, got: " # Nat.toText(wordCount), cb);
              };
            };
            case null {};
          };
        };
        case null {};
      };

      // Submit the revision
      switch (ctx.articleManager.submitRevision(articleId, authInfo.principal, revisedContent)) {
        case (#ok()) {
          var msg = "✅ Revision Submitted Successfully!\n\n";
          msg #= "📝 Article ID: " # Nat.toText(articleId) # "\n";
          msg #= "📄 Title: " # existingArticle.title # "\n";
          msg #= "📏 Word Count: " # Nat.toText(wordCount) # " words\n";
          msg #= "🔄 Revision #: " # Nat.toText(existingArticle.revisionsRequested) # " of 3 max\n\n";
          msg #= "⏳ Status: Revision Submitted - awaiting curator review\n\n";

          // Show what the revision addressed
          if (existingArticle.revisionHistory.size() > 0) {
            let latestFeedback = existingArticle.revisionHistory[existingArticle.revisionHistory.size() - 1];
            msg #= "📋 Addressed Feedback:\n";
            msg #= "   \"" # latestFeedback.feedback # "\"\n\n";
          };

          msg #= "📌 Next Steps:\n";
          msg #= "   • Curator will review your revision\n";
          msg #= "   • Check status with view_pending_submissions\n";
          msg #= "   • Upon approval, you'll receive the full bounty\n";

          ToolContext.makeTextSuccess(msg, cb);
        };
        case (#err(e)) {
          ToolContext.makeError(e, cb);
        };
      };
    };
  };

  // Helper function to convert status to text
  private func statusToText(status : PressTypes.ArticleStatus) : Text {
    switch (status) {
      case (#draft) { "draft" };
      case (#pending) { "pending" };
      case (#approved) { "approved" };
      case (#rejected) { "rejected" };
      case (#expired) { "expired" };
      case (#revisionRequested) { "revisionRequested" };
      case (#revisionSubmitted) { "revisionSubmitted" };
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
