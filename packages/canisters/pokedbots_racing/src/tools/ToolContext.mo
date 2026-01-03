import Principal "mo:base/Principal";
import Result "mo:base/Result";
import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import Json "mo:json";

import PokedBotsGarage "../PokedBotsGarage";
import RacingSimulator "../RacingSimulator";
import ExtIntegration "../ExtIntegration";
import BettingManager "../BettingManager";
import TimerTool "mo:timer-tool";

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
    /// Garage manager for PokedBots (collection-specific logic)
    garageManager : PokedBotsGarage.PokedBotsGarageManager;
    /// Race manager (generic racing simulator)
    raceManager : RacingSimulator.RaceManager;
    /// Betting manager (integrated betting system)
    bettingManager : BettingManager.BettingManager;
    /// EXT canister interface for ownership verification
    extCanister : ExtIntegration.ExtCanisterInterface;
    /// EXT canister ID (needed for encoding token identifiers)
    extCanisterId : Principal;
    /// ICP Ledger canister ID (for payments)
    icpLedgerCanisterId : () -> ?Principal;
    /// Get cached marketplace listings
    getMarketplaceListings : () -> async [(Nat32, ExtIntegration.Listing, ExtIntegration.Metadata)];
    /// Timer tool for scheduling actions
    timerTool : TimerTool.TimerTool;
    /// Get NFT metadata for faction/stats derivation
    getNFTMetadata : (Nat) -> ?[(Text, Text)];
    /// Get robot racing stats (initialized bots only)
    getStats : (Nat) -> ?PokedBotsGarage.PokedBotRacingStats;
    /// Get current stats (base + bonuses) for an initialized bot
    getCurrentStats : (PokedBotsGarage.PokedBotRacingStats) -> {
      speed : Nat;
      powerCore : Nat;
      acceleration : Nat;
      stability : Nat;
    };
    /// Check if a bot is in any active race
    isInActiveRace : (Nat) -> Bool;
    /// Add a sponsor to a race
    addSponsor : (raceId : Nat, sponsor : Principal, amount : Nat, message : ?Text) -> ?RacingSimulator.Race;
    /// Check if registration is open for a race's event
    checkRegistrationWindow : (raceId : Nat, now : Int) -> Result.Result<(), Text>;
    /// Check if a bot is already entered in any race within the same event
    checkBotInEvent : (raceId : Nat, nftId : Text) -> Result.Result<(), Text>;
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
