export const idlFactory = ({ IDL }) => {
  const Result_1 = IDL.Variant({ 'ok' : IDL.Null, 'err' : IDL.Text });
  const Result_5 = IDL.Variant({
    'ok' : IDL.Vec(IDL.Tuple(IDL.Text, IDL.Nat)),
    'err' : IDL.Text,
  });
  const Platform = IDL.Variant({
    'linkedin' : IDL.Null,
    'twitter' : IDL.Null,
    'other' : IDL.Null,
    'blog' : IDL.Null,
    'research' : IDL.Null,
    'pinterest' : IDL.Null,
    'youtube' : IDL.Null,
    'newsletter' : IDL.Null,
    'medium' : IDL.Null,
  });
  const PlatformConfig = IDL.Record({
    'targetDuration' : IDL.Opt(IDL.Nat),
    'subjectLine' : IDL.Opt(IDL.Text),
    'includeAbstract' : IDL.Opt(IDL.Bool),
    'customInstructions' : IDL.Opt(IDL.Text),
    'tags' : IDL.Vec(IDL.Text),
    'citationStyle' : IDL.Opt(IDL.Text),
    'platform' : Platform,
    'isArticle' : IDL.Opt(IDL.Bool),
    'threadCount' : IDL.Opt(IDL.Nat),
    'includeHashtags' : IDL.Opt(IDL.Bool),
    'pinType' : IDL.Opt(IDL.Text),
    'includeTimestamps' : IDL.Opt(IDL.Bool),
    'boardSuggestion' : IDL.Opt(IDL.Text),
  });
  const BriefRequirements = IDL.Record({
    'maxWords' : IDL.Opt(IDL.Nat),
    'requiredTopics' : IDL.Vec(IDL.Text),
    'minWords' : IDL.Opt(IDL.Nat),
    'format' : IDL.Opt(IDL.Text),
  });
  const Time = IDL.Int;
  const Result_4 = IDL.Variant({
    'ok' : IDL.Record({
      'briefId' : IDL.Text,
      'subaccount' : IDL.Vec(IDL.Nat8),
    }),
    'err' : IDL.Text,
  });
  const Header = IDL.Tuple(IDL.Text, IDL.Text);
  const HttpRequest = IDL.Record({
    'url' : IDL.Text,
    'method' : IDL.Text,
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(Header),
    'certificate_version' : IDL.Opt(IDL.Nat16),
  });
  const StreamingToken = IDL.Vec(IDL.Nat8);
  const StreamingCallbackResponse = IDL.Record({
    'token' : IDL.Opt(StreamingToken),
    'body' : IDL.Vec(IDL.Nat8),
  });
  const StreamingCallback = IDL.Func(
      [StreamingToken],
      [IDL.Opt(StreamingCallbackResponse)],
      ['query'],
    );
  const StreamingStrategy = IDL.Variant({
    'Callback' : IDL.Record({
      'token' : StreamingToken,
      'callback' : StreamingCallback,
    }),
  });
  const HttpResponse = IDL.Record({
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(Header),
    'upgrade' : IDL.Opt(IDL.Bool),
    'streaming_strategy' : IDL.Opt(StreamingStrategy),
    'status_code' : IDL.Nat16,
  });
  const UpgradeFinishedResult = IDL.Variant({
    'Failed' : IDL.Tuple(IDL.Nat, IDL.Text),
    'Success' : IDL.Nat,
    'InProgress' : IDL.Nat,
  });
  const ApiKeyInfo = IDL.Record({
    'created' : Time,
    'principal' : IDL.Principal,
    'scopes' : IDL.Vec(IDL.Text),
    'name' : IDL.Text,
  });
  const HashedApiKey = IDL.Text;
  const ApiKeyMetadata = IDL.Record({
    'info' : ApiKeyInfo,
    'hashed_key' : HashedApiKey,
  });
  const Result_3 = IDL.Variant({ 'ok' : IDL.Text, 'err' : IDL.Text });
  const Timestamp = IDL.Nat64;
  const TransferError = IDL.Variant({
    'GenericError' : IDL.Record({
      'message' : IDL.Text,
      'error_code' : IDL.Nat,
    }),
    'TemporarilyUnavailable' : IDL.Null,
    'BadBurn' : IDL.Record({ 'min_burn_amount' : IDL.Nat }),
    'Duplicate' : IDL.Record({ 'duplicate_of' : IDL.Nat }),
    'BadFee' : IDL.Record({ 'expected_fee' : IDL.Nat }),
    'CreatedInFuture' : IDL.Record({ 'ledger_time' : Timestamp }),
    'TooOld' : IDL.Null,
    'InsufficientFunds' : IDL.Record({ 'balance' : IDL.Nat }),
  });
  const TreasuryError = IDL.Variant({
    'LedgerTrap' : IDL.Text,
    'NotOwner' : IDL.Null,
    'TransferFailed' : TransferError,
  });
  const Result_2 = IDL.Variant({ 'ok' : IDL.Null, 'err' : TreasuryError });
  const HttpHeader = IDL.Record({ 'value' : IDL.Text, 'name' : IDL.Text });
  const HttpRequestResult = IDL.Record({
    'status' : IDL.Nat,
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HttpHeader),
  });
  const BriefUpdateRequest = IDL.Record({
    'title' : IDL.Opt(IDL.Text),
    'topic' : IDL.Opt(IDL.Text),
    'expiresAt' : IDL.Opt(IDL.Opt(Time)),
    'platformConfig' : IDL.Opt(PlatformConfig),
    'description' : IDL.Opt(IDL.Text),
    'bountyPerArticle' : IDL.Opt(IDL.Nat),
    'maxArticles' : IDL.Opt(IDL.Nat),
    'requirements' : IDL.Opt(BriefRequirements),
  });
  const AgentStats = IDL.Record({
    'firstSubmission' : Time,
    'agent' : IDL.Principal,
    'totalEarned' : IDL.Nat,
    'lastSubmission' : Time,
    'totalApproved' : IDL.Nat,
    'totalExpired' : IDL.Nat,
    'totalRejected' : IDL.Nat,
    'averageReviewTime' : IDL.Nat,
    'totalSubmitted' : IDL.Nat,
  });
  const ArticleStatus = IDL.Variant({
    'revisionSubmitted' : IDL.Null,
    'expired' : IDL.Null,
    'pending' : IDL.Null,
    'approved' : IDL.Null,
    'rejected' : IDL.Null,
    'draft' : IDL.Null,
    'revisionRequested' : IDL.Null,
  });
  const RevisionSubmission = IDL.Record({
    'content' : IDL.Text,
    'submittedAt' : Time,
    'revisionNumber' : IDL.Nat,
  });
  const RevisionRequest = IDL.Record({
    'feedback' : IDL.Text,
    'revisionNumber' : IDL.Nat,
    'requestedAt' : Time,
    'requestedBy' : IDL.Principal,
  });
  const Article = IDL.Record({
    'status' : ArticleStatus,
    'title' : IDL.Text,
    'content' : IDL.Text,
    'agent' : IDL.Principal,
    'revisionSubmissions' : IDL.Vec(RevisionSubmission),
    'briefId' : IDL.Text,
    'revisionHistory' : IDL.Vec(RevisionRequest),
    'rejectionReason' : IDL.Opt(IDL.Text),
    'bountyPaid' : IDL.Nat,
    'submittedAt' : Time,
    'reviewedAt' : IDL.Opt(Time),
    'articleId' : IDL.Nat,
    'selectedForRevision' : IDL.Bool,
    'currentRevision' : IDL.Nat,
    'reviewer' : IDL.Opt(IDL.Principal),
    'revisionsRequested' : IDL.Nat,
    'mediaAssets' : IDL.Vec(IDL.Nat),
  });
  const BriefStatus = IDL.Variant({
    'closed' : IDL.Null,
    'cancelled' : IDL.Null,
    'open' : IDL.Null,
  });
  const Brief = IDL.Record({
    'status' : BriefStatus,
    'title' : IDL.Text,
    'topic' : IDL.Text,
    'expiresAt' : IDL.Opt(Time),
    'platformConfig' : PlatformConfig,
    'isRecurring' : IDL.Bool,
    'briefId' : IDL.Text,
    'approvedCount' : IDL.Nat,
    'createdAt' : Time,
    'description' : IDL.Text,
    'bountyPerArticle' : IDL.Nat,
    'escrowBalance' : IDL.Nat,
    'escrowSubaccount' : IDL.Vec(IDL.Nat8),
    'maxArticles' : IDL.Nat,
    'curator' : IDL.Principal,
    'requirements' : BriefRequirements,
    'recurrenceIntervalNanos' : IDL.Opt(IDL.Nat),
    'submittedCount' : IDL.Nat,
  });
  const CuratorStats = IDL.Record({
    'lastActivity' : Time,
    'briefsCreated' : IDL.Nat,
    'articlesApproved' : IDL.Nat,
    'totalBountiesPaid' : IDL.Nat,
    'articlesRejected' : IDL.Nat,
    'articlesReviewed' : IDL.Nat,
    'curator' : IDL.Principal,
    'firstBrief' : Time,
    'totalEscrowed' : IDL.Nat,
    'averageReviewTime' : IDL.Nat,
  });
  const MediaAsset = IDL.Record({
    'status' : IDL.Variant({
      'pending' : IDL.Null,
      'failed' : IDL.Null,
      'ingested' : IDL.Null,
    }),
    'contentHash' : IDL.Text,
    'failureReason' : IDL.Opt(IDL.Text),
    'contentType' : IDL.Text,
    'originalUrl' : IDL.Text,
    'assetId' : IDL.Nat,
    'sizeBytes' : IDL.Nat,
    'ingestedAt' : Time,
  });
  const Subaccount = IDL.Vec(IDL.Nat8);
  const Destination = IDL.Record({
    'owner' : IDL.Principal,
    'subaccount' : IDL.Opt(Subaccount),
  });
  const Result = IDL.Variant({ 'ok' : IDL.Nat, 'err' : TreasuryError });
  const McpServer = IDL.Service({
    'add_escrow_to_brief' : IDL.Func([IDL.Text, IDL.Nat], [Result_1], []),
    'cleanup_briefs_no_expiration' : IDL.Func([], [Result_5], []),
    'create_brief' : IDL.Func(
        [
          IDL.Text,
          IDL.Text,
          IDL.Text,
          PlatformConfig,
          BriefRequirements,
          IDL.Nat,
          IDL.Nat,
          IDL.Opt(Time),
          IDL.Bool,
          IDL.Opt(IDL.Nat),
        ],
        [Result_4],
        [],
      ),
    'create_my_api_key' : IDL.Func(
        [IDL.Text, IDL.Vec(IDL.Text)],
        [IDL.Text],
        [],
      ),
    'get_icp_ledger' : IDL.Func([], [IDL.Opt(IDL.Principal)], ['query']),
    'get_owner' : IDL.Func([], [IDL.Principal], ['query']),
    'get_treasury_balance' : IDL.Func([IDL.Principal], [IDL.Nat], []),
    'http_request' : IDL.Func([HttpRequest], [HttpResponse], ['query']),
    'http_request_streaming_callback' : IDL.Func(
        [StreamingToken],
        [IDL.Opt(StreamingCallbackResponse)],
        ['query'],
      ),
    'http_request_update' : IDL.Func([HttpRequest], [HttpResponse], []),
    'icrc120_upgrade_finished' : IDL.Func([], [UpgradeFinishedResult], []),
    'list_my_api_keys' : IDL.Func([], [IDL.Vec(ApiKeyMetadata)], ['query']),
    'process_closed_briefs_escrow' : IDL.Func([], [Result_3], []),
    'revoke_my_api_key' : IDL.Func([IDL.Text], [], []),
    'run_janitor_now' : IDL.Func([], [IDL.Text], []),
    'set_icp_ledger' : IDL.Func([IDL.Principal], [Result_1], []),
    'set_owner' : IDL.Func([IDL.Principal], [Result_2], []),
    'start_janitor_timer' : IDL.Func([], [IDL.Text], []),
    'transformJwksResponse' : IDL.Func(
        [
          IDL.Record({
            'context' : IDL.Vec(IDL.Nat8),
            'response' : HttpRequestResult,
          }),
        ],
        [HttpRequestResult],
        ['query'],
      ),
    'update_brief' : IDL.Func([IDL.Text, BriefUpdateRequest], [Result_1], []),
    'web_approve_article' : IDL.Func([IDL.Nat, IDL.Text], [Result_1], []),
    'web_approve_draft' : IDL.Func([IDL.Nat], [Result_1], []),
    'web_delete_draft' : IDL.Func([IDL.Nat], [Result_1], []),
    'web_get_agent_stats' : IDL.Func(
        [IDL.Principal],
        [IDL.Opt(AgentStats)],
        ['query'],
      ),
    'web_get_archived_articles' : IDL.Func(
        [IDL.Nat, IDL.Nat, IDL.Opt(ArticleStatus)],
        [IDL.Record({ 'total' : IDL.Nat, 'articles' : IDL.Vec(Article) })],
        ['query'],
      ),
    'web_get_article' : IDL.Func([IDL.Nat], [IDL.Opt(Article)], ['query']),
    'web_get_articles_by_agent' : IDL.Func(
        [IDL.Principal],
        [IDL.Vec(Article)],
        ['query'],
      ),
    'web_get_articles_by_brief' : IDL.Func(
        [IDL.Text],
        [IDL.Vec(Article)],
        ['query'],
      ),
    'web_get_brief' : IDL.Func([IDL.Text], [IDL.Opt(Brief)], ['query']),
    'web_get_briefs_by_ids' : IDL.Func(
        [IDL.Vec(IDL.Text)],
        [IDL.Vec(Brief)],
        ['query'],
      ),
    'web_get_briefs_filtered' : IDL.Func(
        [IDL.Opt(BriefStatus), IDL.Opt(IDL.Text), IDL.Nat, IDL.Nat],
        [IDL.Record({ 'total' : IDL.Nat, 'briefs' : IDL.Vec(Brief) })],
        ['query'],
      ),
    'web_get_curator_stats' : IDL.Func(
        [IDL.Principal],
        [IDL.Opt(CuratorStats)],
        ['query'],
      ),
    'web_get_media_asset' : IDL.Func(
        [IDL.Nat],
        [IDL.Opt(MediaAsset)],
        ['query'],
      ),
    'web_get_my_briefs' : IDL.Func([], [IDL.Vec(Brief)], ['query']),
    'web_get_open_briefs' : IDL.Func([], [IDL.Vec(Brief)], ['query']),
    'web_get_platform_stats' : IDL.Func(
        [],
        [
          IDL.Record({
            'totalCurators' : IDL.Nat,
            'totalAgents' : IDL.Nat,
            'totalPaidOut' : IDL.Nat,
            'openBriefs' : IDL.Nat,
            'totalArticlesSubmitted' : IDL.Nat,
            'articlesInTriage' : IDL.Nat,
            'articlesArchived' : IDL.Nat,
            'totalBriefs' : IDL.Nat,
          }),
        ],
        ['query'],
      ),
    'web_get_top_authors' : IDL.Func(
        [IDL.Nat],
        [IDL.Vec(AgentStats)],
        ['query'],
      ),
    'web_get_top_curators' : IDL.Func(
        [IDL.Nat],
        [IDL.Vec(CuratorStats)],
        ['query'],
      ),
    'web_get_triage_articles' : IDL.Func([], [IDL.Vec(Article)], ['query']),
    'web_reject_article' : IDL.Func([IDL.Nat, IDL.Text], [Result_1], []),
    'web_request_revision' : IDL.Func(
        [IDL.Nat, IDL.Text, IDL.Text],
        [Result_1],
        [],
      ),
    'web_submit_revision' : IDL.Func([IDL.Nat, IDL.Text], [Result_1], []),
    'web_update_draft' : IDL.Func(
        [IDL.Nat, IDL.Text, IDL.Text],
        [Result_1],
        [],
      ),
    'withdraw' : IDL.Func([IDL.Principal, IDL.Nat, Destination], [Result], []),
  });
  return McpServer;
};
export const init = ({ IDL }) => {
  return [
    IDL.Opt(
      IDL.Record({
        'owner' : IDL.Opt(IDL.Principal),
        'icpLedgerCanisterId' : IDL.Opt(IDL.Principal),
      })
    ),
  ];
};
