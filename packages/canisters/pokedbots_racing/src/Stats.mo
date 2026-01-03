import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Map "mo:map/Map";
import { nhash } "mo:map/Map";

module {
  // EXT Token Identifier types
  public type TokenIndex = Nat32;
  public type TokenIdentifier = Text;

  type TokenObj = {
    index : TokenIndex;
    canister : [Nat8];
  };
  // Type definitions for NFT metadata structure
  // Store raw trait value IDs as integers for efficiency
  public type NFTStats = [Nat]; // Array of trait value IDs [type_id, body_id, driver_id, ...]

  // Trait schema types
  public type TraitValue = {
    id : Nat;
    name : Text;
  };

  public type Trait = {
    id : Nat;
    name : Text;
    values : [TraitValue];
  };

  public type TraitSchema = [Trait];

  // Decoded metadata for display
  public type NFTMetadata = [(Text, Text)]; // Array of (trait_name, trait_value) pairs

  // EXT Token Identifier utilities
  private let tds : [Nat8] = [10, 116, 105, 100]; //b"\x0Atid"

  private func bytestonat32(b : [Nat8]) : Nat32 {
    var index : Nat32 = 0;
    Array.foldRight<Nat8, Nat32>(
      b,
      0,
      func(u8, accum) {
        index += 1;
        accum + Nat32.fromNat(Nat8.toNat(u8)) << ((index - 1) * 8);
      },
    );
  };

  public func decodeTokenIdentifier(tid : TokenIdentifier) : TokenObj {
    let bytes = Blob.toArray(Principal.toBlob(Principal.fromText(tid)));
    var index : Nat8 = 0;
    var _canister : [Nat8] = [];
    var _token_index : [Nat8] = [];
    var _tdscheck : [Nat8] = [];
    var length : Nat8 = 0;
    for (b in bytes.vals()) {
      length += 1;
      if (length <= 4) {
        _tdscheck := Array.append(_tdscheck, [b]);
      };
      if (length == 4) {
        if (Array.equal(_tdscheck, tds, Nat8.equal) == false) {
          return {
            index = 0;
            canister = bytes;
          };
        };
      };
    };
    for (b in bytes.vals()) {
      index += 1;
      if (index >= 5) {
        if (index <= (length - 4)) {
          _canister := Array.append(_canister, [b]);
        } else {
          _token_index := Array.append(_token_index, [b]);
        };
      };
    };
    let v : TokenObj = {
      index = bytestonat32(_token_index);
      canister = _canister;
    };
    return v;
  };

  public func getTokenIndex(tid : TokenIdentifier) : TokenIndex {
    let tobj = decodeTokenIdentifier(tid);
    tobj.index;
  };

  public class StatsManager(initStats : Map.Map<Nat, NFTStats>, initSchema : TraitSchema) {
    // Map.Map to store NFT stats by token ID (raw integer values) - stable across upgrades
    private let stats = initStats;

    // Trait schema for decoding
    private var schema : TraitSchema = initSchema;

    // Get the stats map (for stable storage)
    public func getStatsMap() : Map.Map<Nat, NFTStats> {
      stats;
    };

    // Get the schema (for stable storage)
    public func getSchemaValue() : TraitSchema {
      schema;
    };

    // Set the trait schema
    public func setSchema(newSchema : TraitSchema) {
      schema := newSchema;
    };

    // Get the trait schema
    public func getSchema() : TraitSchema {
      schema;
    };

    // Add stats for a single NFT (raw values)
    public func addNFTStats(tokenId : Nat, nftStats : NFTStats) {
      ignore Map.put(stats, nhash, tokenId, nftStats);
    };

    // Add stats for multiple NFTs in batch (raw values)
    public func addBatchStats(batch : [(Nat, NFTStats)]) {
      for ((tokenId, nftStats) in batch.vals()) {
        ignore Map.put(stats, nhash, tokenId, nftStats);
      };
    };

    // Get raw stats for a specific NFT
    public func getNFTStats(tokenId : Nat) : ?NFTStats {
      Map.get(stats, nhash, tokenId);
    };

    // Get decoded metadata for a specific NFT
    public func getNFTMetadata(tokenId : Nat) : ?NFTMetadata {
      switch (Map.get(stats, nhash, tokenId)) {
        case null { null };
        case (?rawStats) {
          ?decodeStats(rawStats);
        };
      };
    };

    // Get metadata by EXT token identifier
    public func getNFTMetadataByIdentifier(tid : TokenIdentifier) : ?NFTMetadata {
      let index = Nat32.toNat(getTokenIndex(tid));
      getNFTMetadata(index);
    };

    // Get raw stats by EXT token identifier
    public func getNFTStatsByIdentifier(tid : TokenIdentifier) : ?NFTStats {
      let index = Nat32.toNat(getTokenIndex(tid));
      getNFTStats(index);
    };

    // Decode raw stats to human-readable metadata
    private func decodeStats(rawStats : NFTStats) : NFTMetadata {
      let buffer = Buffer.Buffer<(Text, Text)>(rawStats.size());

      for (i in Iter.range(0, rawStats.size() - 1)) {
        if (i < schema.size()) {
          let trait = schema[i];
          let valueId = rawStats[i];

          // Find the value name
          let valueName = switch (
            Array.find<TraitValue>(
              trait.values,
              func(v) { v.id == valueId },
            )
          ) {
            case null { Nat.toText(valueId) }; // Fallback to ID if not found
            case (?v) { v.name };
          };

          buffer.add((trait.name, valueName));
        };
      };

      Buffer.toArray(buffer);
    };

    // Get metadata for multiple NFTs (decoded)
    public func getBatchMetadata(tokenIds : [Nat]) : [(Nat, ?NFTMetadata)] {
      Array.map<Nat, (Nat, ?NFTMetadata)>(
        tokenIds,
        func(id) {
          (id, getNFTMetadata(id));
        },
      );
    };

    // Get all stored token IDs
    public func getAllTokenIds() : [Nat] {
      Iter.toArray(Map.keys(stats));
    };

    // Get total number of NFTs stored
    public func getTotalCount() : Nat {
      Map.size(stats);
    };

    // Get stats in a paginated manner (decoded)
    public func getStatsPage(offset : Nat, limit : Nat) : [(Nat, NFTMetadata)] {
      let entries = Iter.toArray(Map.entries(stats));
      let start = Nat.min(offset, entries.size());
      let end = Nat.min(offset + limit, entries.size());

      if (start >= entries.size()) {
        return [];
      };

      let buffer = Buffer.Buffer<(Nat, NFTMetadata)>(end - start);
      var i = start;
      while (i < end) {
        let (tokenId, rawStats) = entries[i];
        buffer.add((tokenId, decodeStats(rawStats)));
        i += 1;
      };
      Buffer.toArray(buffer);
    };

    // Clear all stats (use with caution!)
    public func clearAll() {
      Map.clear(stats);
    };

    // Get specific trait value by trait index
    public func getTraitValue(tokenId : Nat, traitIndex : Nat) : ?Nat {
      switch (Map.get(stats, nhash, tokenId)) {
        case null { null };
        case (?rawStats) {
          if (traitIndex < rawStats.size()) {
            ?rawStats[traitIndex];
          } else {
            null;
          };
        };
      };
    };

    // Get decoded trait value by trait name
    public func getTraitValueByName(tokenId : Nat, traitName : Text) : ?Text {
      switch (getNFTMetadata(tokenId)) {
        case null { null };
        case (?metadata) {
          let trait = Array.find<(Text, Text)>(
            metadata,
            func(t : (Text, Text)) : Bool { t.0 == traitName },
          );
          switch (trait) {
            case null { null };
            case (?(_, value)) { ?value };
          };
        };
      };
    };
  };
};
