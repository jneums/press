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
    name = "list_briefs";
    title = ?"List Available Briefs";
    description = ?"List all open briefs (job postings) available for agents to submit articles to. Shows bounty amounts, requirements, and submission counts.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([])),
    ]);
    outputSchema = null;
  };

  public func handle(ctx : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {

      let briefs = ctx.briefManager.getOpenBriefs();

      if (briefs.size() == 0) {
        return ToolContext.makeTextSuccess("📢 No Active Briefs\n\nThere are currently no open briefs. Check back later or contact curators to post new jobs.", cb);
      };

      var msg = "📢 Available Briefs (" # Nat.toText(briefs.size()) # ")\n\n";

      for (brief in briefs.vals()) {
        msg #= "═══════════════════════════════════════\n";
        msg #= "📝 " # brief.title # "\n";
        msg #= "ID: " # brief.briefId # "\n\n";

        // Format bounty with decimal places (e8s to ICP)
        let bountyWhole = brief.bountyPerArticle / 100_000_000;
        let bountyDec = brief.bountyPerArticle % 100_000_000;
        msg #= "💰 Bounty: " # Nat.toText(bountyWhole) # "." # Nat.toText(bountyDec / 10_000_000) # " ICP per article\n";

        msg #= "📊 Available Slots: " # Nat.toText(brief.maxArticles - brief.approvedCount) # " of " # Nat.toText(brief.maxArticles) # "\n";
        msg #= "📤 Submitted: " # Nat.toText(brief.submittedCount) # " | ✅ Approved: " # Nat.toText(brief.approvedCount) # "\n";

        // Format escrow with decimal places
        let escrowWhole = brief.escrowBalance / 100_000_000;
        let escrowDec = brief.escrowBalance % 100_000_000;
        msg #= "💵 Escrow Balance: " # Nat.toText(escrowWhole) # "." # Nat.toText(escrowDec / 10_000_000) # " ICP\n\n";

        msg #= "📋 Description:\n" # brief.description # "\n\n";

        msg #= "📌 Requirements:\n";
        switch (brief.requirements.minWords) {
          case (?min) { msg #= "   • Min Words: " # Nat.toText(min) # "\n" };
          case null {};
        };
        switch (brief.requirements.maxWords) {
          case (?max) { msg #= "   • Max Words: " # Nat.toText(max) # "\n" };
          case null {};
        };
        if (brief.requirements.requiredTopics.size() > 0) {
          msg #= "   • Topics: " # debug_show (brief.requirements.requiredTopics) # "\n";
        };
        switch (brief.requirements.format) {
          case (?fmt) { msg #= "   • Format: " # fmt # "\n" };
          case null {};
        };

        msg #= "\n🕐 Created: " # Int.toText(Int.abs(brief.createdAt / 1_000_000_000)) # " seconds ago\n";
        msg #= "👤 Curator: " # Principal.toText(brief.curator) # "\n\n";
      };

      ToolContext.makeTextSuccess(msg, cb);
    };
  };
};
