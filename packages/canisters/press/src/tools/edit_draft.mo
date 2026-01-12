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
    name = "edit_draft";
    title = ?"Edit Draft Article";
    description = ?"Edit a draft article that you have previously submitted. You can update the title and/or content. Only draft articles (not yet sent to curator) can be edited.\n\n**REQUIREMENTS:**\n• You must be the author of the article\n• Article must be in 'draft' status\n• Provide at least a new title or new content\n\n**WORKFLOW:**\n• Use view_pending_submissions to find your draft article IDs\n• Edit the draft with this tool\n• Approve the draft when ready to send to curator";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      (
        "properties",
        Json.obj([
          ("article_id", Json.obj([("type", Json.str("string")), ("description", Json.str("The ID of the draft article to edit"))])),
          ("title", Json.obj([("type", Json.str("string")), ("description", Json.str("New title for the article (optional if content is provided)"))])),
          ("content", Json.obj([("type", Json.str("string")), ("description", Json.str("New content for the article in Markdown format (optional if title is provided)"))])),
        ]),
      ),
      ("required", Json.arr([Json.str("article_id")])),
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

      // Get new title and content (both optional)
      let newTitle = Result.toOption(Json.getAsText(_args, "title"));
      let newContent = Result.toOption(Json.getAsText(_args, "content"));

      // At least one must be provided
      if (newTitle == null and newContent == null) {
        return ToolContext.makeError("At least one of 'title' or 'content' must be provided", cb);
      };

      // Get the existing article to fill in missing fields
      let existingArticle = switch (ctx.articleManager.getArticle(articleId)) {
        case (null) {
          return ToolContext.makeError("Article not found: " # articleIdText, cb);
        };
        case (?article) { article };
      };

      // Verify status is draft
      if (existingArticle.status != #draft) {
        return ToolContext.makeError("Only draft articles can be edited. This article has status: " # statusToText(existingArticle.status), cb);
      };

      // Use existing values if not provided
      let finalTitle = switch (newTitle) {
        case (?t) { t };
        case null { existingArticle.title };
      };

      let finalContent = switch (newContent) {
        case (?c) { c };
        case null { existingArticle.content };
      };

      // Update the draft
      switch (ctx.articleManager.updateDraftArticle(articleId, authInfo.principal, finalTitle, finalContent)) {
        case (#ok()) {
          let wordCount = countWords(finalContent);

          var msg = "✅ Draft Updated Successfully!\n\n";
          msg #= "📝 Article ID: " # Nat.toText(articleId) # "\n";
          msg #= "📄 Title: " # finalTitle # "\n";
          msg #= "📏 Word Count: " # Nat.toText(wordCount) # " words\n\n";
          msg #= "⏳ Status: Draft - awaiting your approval\n\n";
          msg #= "📌 Next Steps:\n";
          msg #= "   • Review your changes in the Press Dashboard at: https://apk5r-uaaaa-aaaai-q4oaa-cai.icp0.io/agent\n";
          msg #= "   • Make further edits if needed\n";
          msg #= "   • Approve it to send to the curator's queue\n";

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
