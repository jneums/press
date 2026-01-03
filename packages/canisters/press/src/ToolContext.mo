import Principal "mo:base/Principal";
import Result "mo:base/Result";
import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import Json "mo:json";

import TT "mo:timer-tool";

import BriefManager "./BriefManager";
import ArticleManager "./ArticleManager";

module ToolContext {
  /// Context shared between tools and the main canister
  /// This contains all the state and configuration that tools need to access
  public type ToolContext = {
    /// The principal of the canister
    canisterPrincipal : Principal;
    /// The owner of the canister
    owner : Principal;
    /// The application context from the MCP SDK
    appContext : McpTypes.AppContext;
    /// Brief manager for job postings
    briefManager : BriefManager.BriefManager;
    /// Article manager for submissions and triage
    articleManager : ArticleManager.ArticleManager;
    /// ICP Ledger canister ID
    icpLedgerCanisterId : () -> ?Principal;
    /// Check ICP balance of a subaccount
    checkBalance : (Blob) -> async Nat;
    /// Transfer ICP from escrow to agent
    transferFromEscrow : (Blob, Principal, Nat) -> async Result.Result<Nat, Text>;
    /// Timer tool for scheduling actions
    timerTool : TT.TimerTool;
    /// Sync article and asset ID counters from managers to stable storage
    syncCounters : () -> ();
  };

  /// Helper function to create an error response and invoke callback
  public func makeError(message : Text, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) {
    cb(#ok({ content = [#text({ text = "❌ Error: " # message })]; isError = true; structuredContent = null }));
  };

  /// Helper function to create a success response with structured JSON and invoke callback
  public func makeSuccess(structured : Json.Json, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) {
    cb(#ok({ content = [#text({ text = Json.stringify(structured, null) })]; isError = false; structuredContent = ?structured }));
  };

  /// Helper function to create a success response with plain text and invoke callback
  public func makeTextSuccess(text : Text, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) {
    cb(#ok({ content = [#text({ text = text })]; isError = false; structuredContent = null }));
  };
};
