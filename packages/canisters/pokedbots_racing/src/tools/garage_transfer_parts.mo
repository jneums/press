import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";

module {
  public func config() : McpTypes.Tool = {
    name = "garage_transfer_parts";
    title = ?"Transfer Parts to Another User";
    description = ?"Transfer parts from your inventory to another user's garage inventory. Useful for gifting parts or helping other players.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("recipient_principal", Json.obj([("type", Json.str("string")), ("description", Json.str("The principal ID of the recipient"))])), ("speed_chips", Json.obj([("type", Json.str("number")), ("description", Json.str("Number of Speed Chips to transfer (default: 0)"))])), ("power_core_fragments", Json.obj([("type", Json.str("number")), ("description", Json.str("Number of Power Core Fragments to transfer (default: 0)"))])), ("thruster_kits", Json.obj([("type", Json.str("number")), ("description", Json.str("Number of Thruster Kits to transfer (default: 0)"))])), ("gyro_modules", Json.obj([("type", Json.str("number")), ("description", Json.str("Number of Gyro Modules to transfer (default: 0)"))])), ("universal_parts", Json.obj([("type", Json.str("number")), ("description", Json.str("Number of Universal Parts to transfer (default: 0)"))]))])),
      ("required", Json.arr([Json.str("recipient_principal")])),
    ]);
    outputSchema = null;
  };

  public func handle(ctx : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {
      let sender = switch (_auth) {
        case (null) {
          return ToolContext.makeError("Authentication required", cb);
        };
        case (?auth) { auth.principal };
      };

      // Parse recipient principal
      let recipientText = switch (Result.toOption(Json.getAsText(_args, "recipient_principal"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: recipient_principal", cb);
        };
        case (?text) { text };
      };

      let recipient = try {
        Principal.fromText(recipientText);
      } catch (_) {
        return ToolContext.makeError("Invalid principal ID format", cb);
      };

      // Can't transfer to yourself
      if (sender == recipient) {
        return ToolContext.makeError("Cannot transfer parts to yourself", cb);
      };

      // Parse amounts (default to 0)
      let speedChips = switch (Result.toOption(Json.getAsNat(_args, "speed_chips"))) {
        case (null) { 0 };
        case (?n) { n };
      };
      let powerCoreFragments = switch (Result.toOption(Json.getAsNat(_args, "power_core_fragments"))) {
        case (null) { 0 };
        case (?n) { n };
      };
      let thrusterKits = switch (Result.toOption(Json.getAsNat(_args, "thruster_kits"))) {
        case (null) { 0 };
        case (?n) { n };
      };
      let gyroModules = switch (Result.toOption(Json.getAsNat(_args, "gyro_modules"))) {
        case (null) { 0 };
        case (?n) { n };
      };
      let universalParts = switch (Result.toOption(Json.getAsNat(_args, "universal_parts"))) {
        case (null) { 0 };
        case (?n) { n };
      };

      // Must transfer at least something
      let total = speedChips + powerCoreFragments + thrusterKits + gyroModules + universalParts;
      if (total == 0) {
        return ToolContext.makeError("Must transfer at least 1 part", cb);
      };

      // Get sender's inventory
      let senderInventory = ctx.garageManager.getUserInventory(sender);

      // Check sender has enough parts
      if (speedChips > senderInventory.speedChips) {
        return ToolContext.makeError("Insufficient Speed Chips. You have: " # Nat.toText(senderInventory.speedChips), cb);
      };
      if (powerCoreFragments > senderInventory.powerCoreFragments) {
        return ToolContext.makeError("Insufficient Power Core Fragments. You have: " # Nat.toText(senderInventory.powerCoreFragments), cb);
      };
      if (thrusterKits > senderInventory.thrusterKits) {
        return ToolContext.makeError("Insufficient Thruster Kits. You have: " # Nat.toText(senderInventory.thrusterKits), cb);
      };
      if (gyroModules > senderInventory.gyroModules) {
        return ToolContext.makeError("Insufficient Gyro Modules. You have: " # Nat.toText(senderInventory.gyroModules), cb);
      };
      if (universalParts > senderInventory.universalParts) {
        return ToolContext.makeError("Insufficient Universal Parts. You have: " # Nat.toText(senderInventory.universalParts), cb);
      };

      // Update sender's inventory (manually create new inventory with reduced amounts)
      let newSenderInventory = {
        owner = senderInventory.owner;
        speedChips = senderInventory.speedChips - speedChips;
        powerCoreFragments = senderInventory.powerCoreFragments - powerCoreFragments;
        thrusterKits = senderInventory.thrusterKits - thrusterKits;
        gyroModules = senderInventory.gyroModules - gyroModules;
        universalParts = senderInventory.universalParts - universalParts;
      };
      ctx.garageManager.setUserInventory(sender, newSenderInventory);

      // Add to recipient using addParts
      if (speedChips > 0) {
        ctx.garageManager.addParts(recipient, #SpeedChip, speedChips);
      };
      if (powerCoreFragments > 0) {
        ctx.garageManager.addParts(recipient, #PowerCoreFragment, powerCoreFragments);
      };
      if (thrusterKits > 0) {
        ctx.garageManager.addParts(recipient, #ThrusterKit, thrusterKits);
      };
      if (gyroModules > 0) {
        ctx.garageManager.addParts(recipient, #GyroModule, gyroModules);
      };
      if (universalParts > 0) {
        ctx.garageManager.addParts(recipient, #UniversalPart, universalParts);
      };

      // Build success message
      var message = "✅ Parts transferred successfully to " # recipientText # ":\n";
      if (speedChips > 0) {
        message #= "\n• " # Nat.toText(speedChips) # " Speed Chips";
      };
      if (powerCoreFragments > 0) {
        message #= "\n• " # Nat.toText(powerCoreFragments) # " Power Core Fragments";
      };
      if (thrusterKits > 0) {
        message #= "\n• " # Nat.toText(thrusterKits) # " Thruster Kits";
      };
      if (gyroModules > 0) {
        message #= "\n• " # Nat.toText(gyroModules) # " Gyro Modules";
      };
      if (universalParts > 0) {
        message #= "\n• " # Nat.toText(universalParts) # " Universal Parts";
      };
      message #= "\n\nTotal: " # Nat.toText(total) # " parts";

      cb(#ok({ content = [#text({ text = message })]; isError = false; structuredContent = null }));
    };
  };
};
