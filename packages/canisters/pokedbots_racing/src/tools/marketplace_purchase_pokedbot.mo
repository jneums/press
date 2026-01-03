import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Time "mo:base/Time";
import Debug "mo:base/Debug";

import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Json "mo:json";
import ICRC2 "mo:icrc2-types";
import Base16 "mo:base16/Base16";

import ToolContext "./ToolContext";
import ExtIntegration "../ExtIntegration";
import IcpLedger "../IcpLedger";

module {
  public func config() : McpTypes.Tool = {
    name = "purchase_pokedbot";
    title = ?"Purchase PokedBot";
    description = ?"Purchase a PokedBot NFT from the marketplace. The bot will be sent directly to your wallet for racing.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_index", Json.obj([("type", Json.str("number")), ("description", Json.str("The token index of the PokedBot to purchase"))]))])),
      ("required", Json.arr([Json.str("token_index")])),
    ]);
    outputSchema = null;
  };

  public func handle(context : ToolContext.ToolContext) : (
    _args : McpTypes.JsonValue,
    _auth : ?AuthTypes.AuthInfo,
    cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> (),
  ) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {
      Debug.print("[PURCHASE] Tool called");

      // Get authenticated user
      let userPrincipal = switch (_auth) {
        case (?auth) {
          Debug.print("[PURCHASE] Auth principal: " # Principal.toText(auth.principal));
          auth.principal;
        };
        case (null) {
          Debug.print("[PURCHASE] No auth provided");
          return ToolContext.makeError("Authentication required to purchase PokedBots.", cb);
        };
      };

      // Extract token_index from args
      let tokenIndex = switch (Result.toOption(Json.getAsNat(_args, "token_index"))) {
        case (?n) {
          let idx = Nat32.fromNat(n);
          Debug.print("[PURCHASE] Token index: " # Nat32.toText(idx));
          idx;
        };
        case (null) {
          Debug.print("[PURCHASE] Missing token_index in args");
          return ToolContext.makeError("Missing or invalid token_index parameter", cb);
        };
      };

      // Get listing details
      let tokenId = ExtIntegration.encodeTokenIdentifier(tokenIndex, context.extCanisterId);
      let detailsResult = await context.extCanister.details(tokenId);

      let (accountId, listingOpt) = switch (detailsResult) {
        case (#ok(details)) { details };
        case (#err(#InvalidToken(_))) {
          return ToolContext.makeError("Invalid token index: " # Nat32.toText(tokenIndex), cb);
        };
        case (#err(#Other(msg))) {
          return ToolContext.makeError("Error fetching listing: " # msg, cb);
        };
      };

      let listing = switch (listingOpt) {
        case (?l) { l };
        case (null) {
          return ToolContext.makeError("Token #" # Nat32.toText(tokenIndex) # " is not currently listed for sale", cb);
        };
      };

      // Get user's wallet account identifier (where NFT will be sent - non-custodial!)
      let walletAccountId = ExtIntegration.principalToAccountIdentifier(
        userPrincipal,
        null, // No subaccount - direct to wallet
      );

      try {
        // Lock the NFT for purchase - will go to buyer's wallet
        let lockResult = await context.extCanister.lock(
          tokenId,
          listing.price,
          walletAccountId, // NFT goes directly to user's wallet
          [], // No subaccount needed
        );

        switch (lockResult) {
          case (#err(#InvalidToken(_))) {
            return ToolContext.makeError("Invalid token", cb);
          };
          case (#err(#Other(msg))) {
            return ToolContext.makeError("Failed to lock NFT: " # msg, cb);
          };
          case (#ok(paymentAddress)) {
            // NFT is locked, proceed with two-step payment:
            // 1. ICRC-2 transfer from user to canister
            // 2. Legacy transfer from canister to marketplace payment address

            // Create ICP ledger actor
            let ledgerCanisterId = switch (context.icpLedgerCanisterId()) {
              case (?id) { id };
              case (null) {
                return ToolContext.makeError("ICP Ledger not configured", cb);
              };
            };
            let icpLedger = actor (Principal.toText(ledgerCanisterId)) : actor {
              icrc2_transfer_from : shared IcpLedger.TransferFromArgs -> async IcpLedger.Result_3;
              transfer : shared IcpLedger.TransferArgs -> async IcpLedger.Result_6;
            };

            // Convert payment address (hex AccountIdentifier) to Blob for legacy transfer
            let paymentAddressBlob = switch (Base16.decode(paymentAddress)) {
              case (?blob) { blob };
              case (null) {
                return ToolContext.makeError("Invalid payment address format: " # paymentAddress, cb);
              };
            };

            // Step 1: Transfer from user to canister using ICRC-2 (temporary holding)
            let canisterAccount : IcpLedger.Account = {
              owner = context.canisterPrincipal;
              subaccount = null;
            };

            let transferFromArgs : IcpLedger.TransferFromArgs = {
              spender_subaccount = null;
              from = {
                owner = userPrincipal;
                subaccount = null;
              };
              to = canisterAccount;
              amount = Nat64.toNat(listing.price) + 10_000; // listing price + transfer fee
              fee = null;
              memo = null;
              created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            };

            let transferFromResult = await icpLedger.icrc2_transfer_from(transferFromArgs);

            switch (transferFromResult) {
              case (#Ok(blockIndex1)) {
                // Step 2: Transfer from canister to marketplace payment address using legacy transfer
                let transferArgs : IcpLedger.TransferArgs = {
                  to = paymentAddressBlob;
                  fee = { e8s = 10_000 }; // Standard ICP transfer fee
                  memo = 0;
                  from_subaccount = null;
                  created_at_time = ?{
                    timestamp_nanos = Nat64.fromNat(Int.abs(Time.now()));
                  };
                  amount = { e8s = listing.price }; // Send full listing price
                };

                let transferResult = await icpLedger.transfer(transferArgs);

                switch (transferResult) {
                  case (#Ok(blockIndex2)) {
                    // Payment successful, now settle the NFT
                    let settleResult = await context.extCanister.settle(tokenId);

                    switch (settleResult) {
                      case (#ok(())) {
                        // Update bot stats to mark as not listed (if it was initialized for racing)
                        switch (context.garageManager.getStats(Nat32.toNat(tokenIndex))) {
                          case (?stats) {
                            let updatedStats = {
                              stats with
                              listedForSale = false;
                            };
                            context.garageManager.updateStats(Nat32.toNat(tokenIndex), updatedStats);
                          };
                          case (null) {
                            /* Bot not initialized yet, that's fine */
                          };
                        };

                        let priceIcp = Float.fromInt(Nat64.toNat(listing.price)) / 100_000_000.0;
                        let message = "✅ Purchase Complete!\n\n" #
                        "PokedBot #" # Nat32.toText(tokenIndex) # " is now in your wallet!\n\n" #
                        "Price paid: " # Float.format(#fix 2, priceIcp) # " ICP\n" #
                        "Transaction 1: Block #" # Nat.toText(blockIndex1) # "\n" #
                        "Transaction 2: Block #" # Nat64.toText(blockIndex2) # "\n\n" #
                        "🎮 Next: Use garage_list_my_pokedbots to see your bot\n" #
                        "🏆 Your NFT is in YOUR wallet - fully non-custodial!";

                        ToolContext.makeTextSuccess(message, cb);
                      };
                      case (#err(#InvalidToken(_))) {
                        ToolContext.makeError("Payment sent but settlement failed: Invalid token", cb);
                      };
                      case (#err(#Other(msg))) {
                        ToolContext.makeError("Payment sent but settlement failed: " # msg, cb);
                      };
                    };
                  };
                  case (#Err(error)) {
                    let errorMsg = switch (error) {
                      case (#InsufficientFunds({ balance })) {
                        "Insufficient funds. Balance: " # Nat64.toText(balance.e8s) # " e8s";
                      };
                      case (#BadFee({ expected_fee })) {
                        "Bad fee. Expected: " # Nat64.toText(expected_fee.e8s) # " e8s";
                      };
                      case (#TxTooOld({ allowed_window_nanos })) {
                        "Transaction too old. Allowed window: " # Nat64.toText(allowed_window_nanos) # " nanos";
                      };
                      case (#TxCreatedInFuture) {
                        "Transaction created in future";
                      };
                      case (#TxDuplicate({ duplicate_of })) {
                        "Duplicate transaction: " # Nat64.toText(duplicate_of);
                      };
                    };
                    ToolContext.makeError("Transfer to marketplace failed: " # errorMsg, cb);
                  };
                };
              };
              case (#Err(error)) {
                let errorMsg = switch (error) {
                  case (#InsufficientFunds({ balance })) {
                    "Insufficient ICP balance. Your balance: " # Nat.toText(balance) # " e8s";
                  };
                  case (#InsufficientAllowance({ allowance })) {
                    "Insufficient allowance. Please approve the racing canister to spend ICP on your behalf. Current allowance: " # Nat.toText(allowance) # " e8s";
                  };
                  case (#BadFee({ expected_fee })) {
                    "Bad fee. Expected: " # Nat.toText(expected_fee) # " e8s";
                  };
                  case (#GenericError({ message; error_code = _ })) {
                    "Transfer error: " # message;
                  };
                  case _ {
                    "Transfer failed: " # debug_show (error);
                  };
                };
                ToolContext.makeError(errorMsg, cb);
              };
            };
          };
        };

      } catch (e) {
        ToolContext.makeError("Purchase failed: " # Error.message(e), cb);
      };
    };
  };
};
