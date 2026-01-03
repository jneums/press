import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Char "mo:base/Char";

module {
  // List of prohibited words (case-insensitive)
  private let PROHIBITED_WORDS = [
    "fuck",
    "shit",
    "ass",
    "bitch",
    "cunt",
    "dick",
    "cock",
    "pussy",
    "damn",
    "bastard",
    "whore",
    "slut",
    "piss",
    "fag",
    "nigger",
    "nigga",
    "retard",
    "nazi",
    "rape",
    "sex",
    "porn",
    "xxx",
    "penis",
    "vagina",
    "hitler",
    "kike",
    "kyke",
    "jew",
    "terrorist",
    "drug",
    "cocaine",
    "heroin",
    "meth",
  ];

  // Helper function to convert char to lowercase
  private func toLower(c : Char) : Char {
    let code = Char.toNat32(c);
    if (code >= 65 and code <= 90) {
      // A-Z
      Char.fromNat32(code + 32) // Convert to a-z
    } else {
      c;
    };
  };

  /// Validate username for offensive content
  /// Returns null if valid, error message if invalid
  public func validateUsername(name : Text) : ?Text {
    // Check length
    if (Text.size(name) < 3) {
      return ?"Username must be at least 3 characters";
    };
    if (Text.size(name) > 30) {
      return ?"Username must be 30 characters or less";
    };

    // Convert to lowercase for checking
    let lowerName = Text.map(name, toLower);

    // Check for prohibited words
    for (word in PROHIBITED_WORDS.vals()) {
      if (Text.contains(lowerName, #text word)) {
        return ?"Username contains inappropriate language";
      };
    };

    // Check for valid characters (alphanumeric, spaces, hyphens, underscores)
    for (char in name.chars()) {
      if (not (Char.isAlphabetic(char) or Char.isDigit(char) or char == ' ' or char == '-' or char == '_')) {
        return ?"Username can only contain letters, numbers, spaces, hyphens, and underscores";
      };
    };

    null // Valid
  };
};
