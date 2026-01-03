import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ToolContext "ToolContext";
import PokedBotsGarage "../PokedBotsGarage";

module {
  public func config() : McpTypes.Tool = {
    name = "garage_convert_parts";
    title = ?"Convert Parts";
    description = ?"Convert parts from one type to another with a 25% conversion cost (you receive 75% of input amount).\n\n**Conversion Rules:**\n• Cannot convert Universal Parts (they already work for any upgrade)\n• Cannot convert to the same type\n• 25% conversion cost: converting 100 parts yields 75 parts of the target type\n• Minimum conversion: 2 parts input → 1 part output\n\n**Part Types:**\n• SpeedChip → For Speed upgrades\n• PowerCoreFragment → For Power Core upgrades\n• ThrusterKit → For Acceleration upgrades\n• GyroModule → For Stability upgrades\n• UniversalPart → Works for any upgrade (cannot convert from this)\n\n**Strategy:**\n• Use conversion when you have excess parts of one type and need another\n• Universal Parts are more valuable - save them rather than converting to them\n• Consider scavenging in zone-specific areas if you need lots of one part type";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("from_type", Json.obj([("type", Json.str("string")), ("enum", Json.arr([Json.str("SpeedChip"), Json.str("PowerCoreFragment"), Json.str("ThrusterKit"), Json.str("GyroModule")])), ("description", Json.str("Part type to convert FROM (cannot be UniversalPart)"))])), ("to_type", Json.obj([("type", Json.str("string")), ("enum", Json.arr([Json.str("SpeedChip"), Json.str("PowerCoreFragment"), Json.str("ThrusterKit"), Json.str("GyroModule"), Json.str("UniversalPart")])), ("description", Json.str("Part type to convert TO"))])), ("amount", Json.obj([("type", Json.str("number")), ("description", Json.str("Amount of parts to convert (you will receive 75% of this amount in the target type)"))]))])),
      ("required", Json.arr([Json.str("from_type"), Json.str("to_type"), Json.str("amount")])),
    ]);
    outputSchema = null;
  };

  public func handle(ctx : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {
      // Authentication required
      let user = switch (_auth) {
        case (null) {
          return ToolContext.makeError("Authentication required", cb);
        };
        case (?auth) { auth.principal };
      };

      // Parse arguments
      let fromTypeStr = switch (Result.toOption(Json.getAsText(_args, "from_type"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: from_type", cb);
        };
        case (?val) { val };
      };

      let toTypeStr = switch (Result.toOption(Json.getAsText(_args, "to_type"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: to_type", cb);
        };
        case (?val) { val };
      };

      let amount = switch (Result.toOption(Json.getAsNat(_args, "amount"))) {
        case (null) {
          return ToolContext.makeError("Missing required argument: amount", cb);
        };
        case (?val) { val };
      };

      // Parse part types
      let fromType : PokedBotsGarage.PartType = switch (fromTypeStr) {
        case ("SpeedChip") { #SpeedChip };
        case ("PowerCoreFragment") { #PowerCoreFragment };
        case ("ThrusterKit") { #ThrusterKit };
        case ("GyroModule") { #GyroModule };
        case (_) {
          return ToolContext.makeError("Invalid from_type. Must be SpeedChip, PowerCoreFragment, ThrusterKit, or GyroModule", cb);
        };
      };

      let toType : PokedBotsGarage.PartType = switch (toTypeStr) {
        case ("SpeedChip") { #SpeedChip };
        case ("PowerCoreFragment") { #PowerCoreFragment };
        case ("ThrusterKit") { #ThrusterKit };
        case ("GyroModule") { #GyroModule };
        case ("UniversalPart") { #UniversalPart };
        case (_) {
          return ToolContext.makeError("Invalid to_type. Must be SpeedChip, PowerCoreFragment, ThrusterKit, GyroModule, or UniversalPart", cb);
        };
      };

      // Perform conversion
      switch (ctx.garageManager.convertParts(user, fromType, toType, amount)) {
        case (#err(msg)) {
          return ToolContext.makeError(msg, cb);
        };
        case (#ok()) {
          let convertedAmount = (amount * 3) / 4;
          let fromName = switch (fromType) {
            case (#SpeedChip) { "Speed Chips" };
            case (#PowerCoreFragment) { "Power Core Fragments" };
            case (#ThrusterKit) { "Thruster Kits" };
            case (#GyroModule) { "Gyro Modules" };
            case (#UniversalPart) { "Universal Parts" };
          };
          let toName = switch (toType) {
            case (#SpeedChip) { "Speed Chips" };
            case (#PowerCoreFragment) { "Power Core Fragments" };
            case (#ThrusterKit) { "Thruster Kits" };
            case (#GyroModule) { "Gyro Modules" };
            case (#UniversalPart) { "Universal Parts" };
          };

          let fromTypeStr = switch (fromType) {
            case (#SpeedChip) { "SpeedChip" };
            case (#PowerCoreFragment) { "PowerCoreFragment" };
            case (#ThrusterKit) { "ThrusterKit" };
            case (#GyroModule) { "GyroModule" };
            case (#UniversalPart) { "UniversalPart" };
          };

          let toTypeStr = switch (toType) {
            case (#SpeedChip) { "SpeedChip" };
            case (#PowerCoreFragment) { "PowerCoreFragment" };
            case (#ThrusterKit) { "ThrusterKit" };
            case (#GyroModule) { "GyroModule" };
            case (#UniversalPart) { "UniversalPart" };
          };

          // Get updated inventory
          let inv = ctx.garageManager.getUserInventory(user);

          let response = Json.obj([
            ("from_type", Json.str(fromTypeStr)),
            ("to_type", Json.str(toTypeStr)),
            ("amount_converted", Json.int(amount)),
            ("amount_received", Json.int(convertedAmount)),
            ("conversion_cost", Json.int(amount - convertedAmount)),
            ("updated_inventory", Json.obj([("speed_chips", Json.int(inv.speedChips)), ("power_core_fragments", Json.int(inv.powerCoreFragments)), ("thruster_kits", Json.int(inv.thrusterKits)), ("gyro_modules", Json.int(inv.gyroModules)), ("universal_parts", Json.int(inv.universalParts))])),
            ("message", Json.str("✅ Conversion complete! Converted " # Nat.toText(amount) # " " # fromName # " → " # Nat.toText(convertedAmount) # " " # toName # " (25% cost)")),
          ]);

          ToolContext.makeSuccess(response, cb);
        };
      };
    };
  };
};
