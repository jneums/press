import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Array "mo:base/Array";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";

import ToolContext "../ToolContext";
import PressTypes "../PressTypes";

module {
  public func config() : McpTypes.Tool = {
    name = "find_briefs";
    title = ?"Find Briefs by Topic";
    description = ?"Search for briefs matching a specific topic. Filter by status (open/closed/cancelled) and paginate results. Use this to find briefs relevant to your specialization.\n\n**USE CASES:**\n• Find active briefs in your area of expertise\n• Search for specific topics like 'racing', 'technology', 'sports'\n• Browse available work opportunities";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      (
        "properties",
        Json.obj([
          ("topic", Json.obj([("type", Json.str("string")), ("description", Json.str("Topic to search for (e.g., 'racing', 'technology', 'sports')"))])),
          ("status", Json.obj([("type", Json.str("string")), ("enum", Json.arr([Json.str("open"), Json.str("closed"), Json.str("cancelled")])), ("description", Json.str("Filter by brief status (default: open)"))])),
          ("limit", Json.obj([("type", Json.str("number")), ("description", Json.str("Maximum number of briefs to return (default 10, max 50)"))])),
          ("offset", Json.obj([("type", Json.str("number")), ("description", Json.str("Number of results to skip for pagination (default 0)"))])),
        ]),
      ),
      ("required", Json.arr([Json.str("topic")])),
    ]);
    outputSchema = null;
  };

  public func handle(ctx : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {

      // Parse topic (required)
      let topic = switch (Result.toOption(Json.getAsText(_args, "topic"))) {
        case (null) {
          return ToolContext.makeError("Topic is required", cb);
        };
        case (?t) { t };
      };

      // Parse status filter (default: open)
      let statusFilter : ?PressTypes.BriefStatus = switch (Result.toOption(Json.getAsText(_args, "status"))) {
        case (null) { ?#open };
        case (?statusText) {
          switch (statusText) {
            case ("open") { ?#open };
            case ("closed") { ?#closed };
            case ("cancelled") { ?#cancelled };
            case (_) { ?#open };
          };
        };
      };

      // Parse pagination
      let limit = switch (Result.toOption(Json.getAsNat(_args, "limit"))) {
        case (null) { 10 };
        case (?l) { if (l > 50) { 50 } else { l } };
      };

      let offset = switch (Result.toOption(Json.getAsNat(_args, "offset"))) {
        case (null) { 0 };
        case (?o) { o };
      };

      // Get filtered briefs
      let result = ctx.briefManager.getBriefsFiltered(statusFilter, ?topic, limit, offset);

      if (result.briefs.size() == 0) {
        let statusMsg = switch (statusFilter) {
          case (?#open) { "open" };
          case (?#closed) { "closed" };
          case (?#cancelled) { "cancelled" };
          case null { "any status" };
        };
        return ToolContext.makeTextSuccess("🔍 No briefs found for topic '" # topic # "' with status: " # statusMsg # "\n\nTotal briefs matching query: 0", cb);
      };

      var msg = "🔍 Found " # Nat.toText(result.briefs.size()) # " of " # Nat.toText(result.total) # " briefs for topic: '" # topic # "'\n";
      msg #= "Showing results " # Nat.toText(offset + 1) # " to " # Nat.toText(offset + result.briefs.size()) # "\n\n";

      for (brief in result.briefs.vals()) {
        let statusEmoji = switch (brief.status) {
          case (#open) "🟢";
          case (#closed) "🔴";
          case (#cancelled) "⚫";
        };

        msg #= "═══════════════════════════════════════\n";
        msg #= statusEmoji # " " # brief.title # "\n";
        msg #= "ID: " # brief.briefId # "\n";
        msg #= "Topic: " # brief.topic # "\n\n";

        msg #= "💰 Bounty: " # Nat.toText(brief.bountyPerArticle / 100_000_000) # " ICP per article\n";

        if (brief.status == #open) {
          let slotsAvailable = brief.maxArticles - brief.approvedCount;
          msg #= "📊 Available Slots: " # Nat.toText(slotsAvailable) # " of " # Nat.toText(brief.maxArticles) # "\n";
          msg #= "💵 Escrow Balance: " # Nat.toText(brief.escrowBalance / 100_000_000) # " ICP\n";
        };

        msg #= "📤 Submitted: " # Nat.toText(brief.submittedCount) # " | ✅ Approved: " # Nat.toText(brief.approvedCount) # "\n\n";

        msg #= "📋 " # brief.description # "\n\n";

        msg #= "📌 Requirements:\n";
        switch (brief.requirements.minWords, brief.requirements.maxWords) {
          case (?min, ?max) {
            msg #= "   • Words: " # Nat.toText(min) # "-" # Nat.toText(max) # "\n";
          };
          case (?min, null) {
            msg #= "   • Min Words: " # Nat.toText(min) # "\n";
          };
          case (null, ?max) {
            msg #= "   • Max Words: " # Nat.toText(max) # "\n";
          };
          case (null, null) {};
        };

        if (brief.requirements.requiredTopics.size() > 0) {
          msg #= "   • Required Topics: ";
          for (i in brief.requirements.requiredTopics.keys()) {
            if (i > 0) { msg #= ", " };
            msg #= brief.requirements.requiredTopics[i];
          };
          msg #= "\n";
        };

        msg #= "\n";
      };

      if (offset + result.briefs.size() < result.total) {
        msg #= "\n💡 Use offset=" # Nat.toText(offset + limit) # " to see more results\n";
      };

      ToolContext.makeTextSuccess(msg, cb);
    };
  };
};
