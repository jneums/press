import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface AgentStats {
  'firstSubmission' : Time,
  'agent' : Principal,
  'totalEarned' : bigint,
  'lastSubmission' : Time,
  'totalApproved' : bigint,
  'totalExpired' : bigint,
  'totalRejected' : bigint,
  'averageReviewTime' : bigint,
  'totalSubmitted' : bigint,
}
export interface ApiKeyInfo {
  'created' : Time,
  'principal' : Principal,
  'scopes' : Array<string>,
  'name' : string,
}
export interface ApiKeyMetadata {
  'info' : ApiKeyInfo,
  'hashed_key' : HashedApiKey,
}
export interface Article {
  'status' : ArticleStatus,
  'title' : string,
  'content' : string,
  'agent' : Principal,
  'briefId' : string,
  'rejectionReason' : [] | [string],
  'bountyPaid' : bigint,
  'submittedAt' : Time,
  'reviewedAt' : [] | [Time],
  'articleId' : bigint,
  'reviewer' : [] | [Principal],
  'mediaAssets' : Array<bigint>,
}
export type ArticleStatus = { 'expired' : null } |
  { 'pending' : null } |
  { 'approved' : null } |
  { 'rejected' : null };
export interface Brief {
  'status' : BriefStatus,
  'title' : string,
  'topic' : string,
  'expiresAt' : [] | [Time],
  'isRecurring' : boolean,
  'briefId' : string,
  'approvedCount' : bigint,
  'createdAt' : Time,
  'description' : string,
  'bountyPerArticle' : bigint,
  'escrowBalance' : bigint,
  'escrowSubaccount' : Uint8Array | number[],
  'maxArticles' : bigint,
  'curator' : Principal,
  'requirements' : BriefRequirements,
  'recurrenceIntervalNanos' : [] | [bigint],
  'submittedCount' : bigint,
}
export interface BriefRequirements {
  'maxWords' : [] | [bigint],
  'requiredTopics' : Array<string>,
  'minWords' : [] | [bigint],
  'format' : [] | [string],
}
export type BriefStatus = { 'closed' : null } |
  { 'cancelled' : null } |
  { 'open' : null };
export interface CuratorStats {
  'lastActivity' : Time,
  'briefsCreated' : bigint,
  'articlesApproved' : bigint,
  'totalBountiesPaid' : bigint,
  'articlesRejected' : bigint,
  'articlesReviewed' : bigint,
  'curator' : Principal,
  'firstBrief' : Time,
  'totalEscrowed' : bigint,
  'averageReviewTime' : bigint,
}
export interface Destination {
  'owner' : Principal,
  'subaccount' : [] | [Subaccount],
}
export type HashedApiKey = string;
export type Header = [string, string];
export interface HttpHeader { 'value' : string, 'name' : string }
export interface HttpRequest {
  'url' : string,
  'method' : string,
  'body' : Uint8Array | number[],
  'headers' : Array<Header>,
  'certificate_version' : [] | [number],
}
export interface HttpRequestResult {
  'status' : bigint,
  'body' : Uint8Array | number[],
  'headers' : Array<HttpHeader>,
}
export interface HttpResponse {
  'body' : Uint8Array | number[],
  'headers' : Array<Header>,
  'upgrade' : [] | [boolean],
  'streaming_strategy' : [] | [StreamingStrategy],
  'status_code' : number,
}
export interface McpServer {
  'create_brief' : ActorMethod<
    [
      string,
      string,
      string,
      BriefRequirements,
      bigint,
      bigint,
      [] | [Time],
      boolean,
      [] | [bigint],
    ],
    Result_3
  >,
  'create_my_api_key' : ActorMethod<[string, Array<string>], string>,
  'get_icp_ledger' : ActorMethod<[], [] | [Principal]>,
  'get_owner' : ActorMethod<[], Principal>,
  'get_treasury_balance' : ActorMethod<[Principal], bigint>,
  'http_request' : ActorMethod<[HttpRequest], HttpResponse>,
  'http_request_streaming_callback' : ActorMethod<
    [StreamingToken],
    [] | [StreamingCallbackResponse]
  >,
  'http_request_update' : ActorMethod<[HttpRequest], HttpResponse>,
  'icrc120_upgrade_finished' : ActorMethod<[], UpgradeFinishedResult>,
  'list_my_api_keys' : ActorMethod<[], Array<ApiKeyMetadata>>,
  'revoke_my_api_key' : ActorMethod<[string], undefined>,
  'run_janitor_now' : ActorMethod<[], string>,
  'set_icp_ledger' : ActorMethod<[Principal], Result_1>,
  'set_owner' : ActorMethod<[Principal], Result_2>,
  'start_janitor_timer' : ActorMethod<[], string>,
  'transformJwksResponse' : ActorMethod<
    [{ 'context' : Uint8Array | number[], 'response' : HttpRequestResult }],
    HttpRequestResult
  >,
  'web_approve_article' : ActorMethod<[bigint, string], Result_1>,
  'web_get_agent_stats' : ActorMethod<[Principal], [] | [AgentStats]>,
  'web_get_archived_articles' : ActorMethod<
    [bigint, bigint, [] | [ArticleStatus]],
    { 'total' : bigint, 'articles' : Array<Article> }
  >,
  'web_get_article' : ActorMethod<[bigint], [] | [Article]>,
  'web_get_brief' : ActorMethod<[string], [] | [Brief]>,
  'web_get_briefs_filtered' : ActorMethod<
    [[] | [BriefStatus], [] | [string], bigint, bigint],
    { 'total' : bigint, 'briefs' : Array<Brief> }
  >,
  'web_get_curator_stats' : ActorMethod<[Principal], [] | [CuratorStats]>,
  'web_get_media_asset' : ActorMethod<[bigint], [] | [MediaAsset]>,
  'web_get_open_briefs' : ActorMethod<[], Array<Brief>>,
  'web_get_platform_stats' : ActorMethod<
    [],
    {
      'totalCurators' : bigint,
      'totalAgents' : bigint,
      'openBriefs' : bigint,
      'totalArticlesSubmitted' : bigint,
      'articlesInTriage' : bigint,
      'articlesArchived' : bigint,
      'totalBriefs' : bigint,
    }
  >,
  'web_get_triage_articles' : ActorMethod<[], Array<Article>>,
  'web_reject_article' : ActorMethod<[bigint, string], Result_1>,
  'withdraw' : ActorMethod<[Principal, bigint, Destination], Result>,
}
export interface MediaAsset {
  'status' : { 'pending' : null } |
    { 'failed' : null } |
    { 'ingested' : null },
  'contentHash' : string,
  'failureReason' : [] | [string],
  'contentType' : string,
  'originalUrl' : string,
  'assetId' : bigint,
  'sizeBytes' : bigint,
  'ingestedAt' : Time,
}
export type Result = { 'ok' : bigint } |
  { 'err' : TreasuryError };
export type Result_1 = { 'ok' : null } |
  { 'err' : string };
export type Result_2 = { 'ok' : null } |
  { 'err' : TreasuryError };
export type Result_3 = {
    'ok' : { 'briefId' : string, 'subaccount' : Uint8Array | number[] }
  } |
  { 'err' : string };
export type StreamingCallback = ActorMethod<
  [StreamingToken],
  [] | [StreamingCallbackResponse]
>;
export interface StreamingCallbackResponse {
  'token' : [] | [StreamingToken],
  'body' : Uint8Array | number[],
}
export type StreamingStrategy = {
    'Callback' : { 'token' : StreamingToken, 'callback' : StreamingCallback }
  };
export type StreamingToken = Uint8Array | number[];
export type Subaccount = Uint8Array | number[];
export type Time = bigint;
export type Timestamp = bigint;
export type TransferError = {
    'GenericError' : { 'message' : string, 'error_code' : bigint }
  } |
  { 'TemporarilyUnavailable' : null } |
  { 'BadBurn' : { 'min_burn_amount' : bigint } } |
  { 'Duplicate' : { 'duplicate_of' : bigint } } |
  { 'BadFee' : { 'expected_fee' : bigint } } |
  { 'CreatedInFuture' : { 'ledger_time' : Timestamp } } |
  { 'TooOld' : null } |
  { 'InsufficientFunds' : { 'balance' : bigint } };
export type TreasuryError = { 'LedgerTrap' : string } |
  { 'NotOwner' : null } |
  { 'TransferFailed' : TransferError };
export type UpgradeFinishedResult = { 'Failed' : [bigint, string] } |
  { 'Success' : bigint } |
  { 'InProgress' : bigint };
export interface _SERVICE extends McpServer {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
