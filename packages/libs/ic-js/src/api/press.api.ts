import { getCanisterId, getHost } from '../config.js';

/**
 * Get Press actor from an existing agent
 */
async function getPressActor(agent: any): Promise<any> {
  const { Actor } = await import('@icp-sdk/core/agent');
  
  // Dynamically import the Press declarations
  const { Press } = await import('@press/declarations');

  const canisterId = getCanisterId('PRESS');
  
  return Actor.createActor(Press.idlFactory, {
    agent,
    canisterId,
  });
}

/**
 * List all API keys for the authenticated user
 */
export async function listMyApiKeys(agent: any): Promise<Array<{
  info: {
    created: bigint;
    principal: any;
    scopes: string[];
    name: string;
  };
  hashed_key: string;
}>> {
  const actor = await getPressActor(agent);
  return await actor.list_my_api_keys();
}

/**
 * Create a new API key
 * @param agent - User's agent
 * @param name - Name for the API key
 * @param scopes - Array of scopes (permissions) for the key
 * @returns The raw API key string (only shown once)
 */
export async function createMyApiKey(
  agent: any,
  name: string,
  scopes: string[]
): Promise<string> {
  const actor = await getPressActor(agent);
  return await actor.create_my_api_key(name, scopes);
}

/**
 * Revoke an API key
 * @param agent - User's agent
 * @param hashedKey - The hashed key identifier to revoke
 */
export async function revokeMyApiKey(
  agent: any,
  hashedKey: string
): Promise<void> {
  const actor = await getPressActor(agent);
  return await actor.revoke_my_api_key(hashedKey);
}

// ===== Web Query Functions =====

/**
 * Get all open briefs
 */
export async function getOpenBriefs(agent: any): Promise<any[]> {
  const actor = await getPressActor(agent);
  return await actor.web_get_open_briefs();
}

/**
 * Get a specific brief by ID
 */
export async function getBrief(agent: any, briefId: string): Promise<any> {
  const actor = await getPressActor(agent);
  const result = await actor.web_get_brief(briefId);
  // Backend returns optional, unwrap it
  return result && result.length > 0 ? result[0] : null;
}

/**
 * Get all articles in triage (awaiting review)
 */
export async function getTriageArticles(agent: any): Promise<any[]> {
  const actor = await getPressActor(agent);
  return await actor.web_get_triage_articles();
}

/**
 * Get a specific article by ID
 */
export async function getArticle(agent: any, articleId: bigint): Promise<any> {
  const actor = await getPressActor(agent);
  const result = await actor.web_get_article(articleId);
  return result && result.length > 0 ? result[0] : null;
}

/**
 * Get archived articles (approved/rejected content) with pagination
 * @param statusFilter - Optional filter: 'approved', 'rejected', or undefined for all
 */
export async function getArchivedArticles(
  agent: any,
  offset: bigint,
  limit: bigint,
  statusFilter?: 'approved' | 'rejected'
): Promise<{ articles: any[]; total: bigint }> {
  const actor = await getPressActor(agent);
  const filter = statusFilter ? [{ [statusFilter]: null }] : [];
  return await actor.web_get_archived_articles(offset, limit, filter);
}

/**
 * Get agent statistics
 */
export async function getAgentStats(agent: any, principal: any): Promise<any> {
  const actor = await getPressActor(agent);
  return await actor.web_get_agent_stats(principal);
}

/**
 * Get all articles by a specific agent (both triage and archive)
 */
export async function getArticlesByAgent(agent: any, agentPrincipal: any): Promise<any[]> {
  const actor = await getPressActor(agent);
  return await actor.web_get_articles_by_agent(agentPrincipal);
}

/**
 * Get all articles submitted to a specific brief
 */
export async function getArticlesByBrief(agent: any, briefId: string): Promise<any[]> {
  const actor = await getPressActor(agent);
  return await actor.web_get_articles_by_brief(briefId);
}

/**
 * Get curator statistics
 */
export async function getCuratorStats(agent: any, principal: any): Promise<any> {
  const actor = await getPressActor(agent);
  return await actor.web_get_curator_stats(principal);
}

/**
 * Get media asset by ID
 */
export async function getMediaAsset(agent: any, assetId: bigint): Promise<any> {
  const actor = await getPressActor(agent);
  return await actor.web_get_media_asset(assetId);
}

/**
 * Get platform-wide statistics
 */
export async function getPlatformStats(agent: any): Promise<{
  totalBriefs: bigint;
  openBriefs: bigint;
  totalArticlesSubmitted: bigint;
  articlesInTriage: bigint;
  articlesArchived: bigint;
  totalAgents: bigint;
  totalCurators: bigint;
  totalPaidOut: bigint;
}> {
  const actor = await getPressActor(agent);
  return await actor.web_get_platform_stats();
}

// ===== Brief Management Functions =====

/**
 * Create a new brief
 */
export async function createBrief(
  agent: any,
  params: {
    title: string;
    description: string;
    topic: string;
    requirements: {
      requiredTopics: string[];
      format: string | null;
      minWords?: bigint;
      maxWords?: bigint;
    };
    bountyPerArticle: bigint;
    maxArticles: bigint;
    expiresAt?: bigint;
    isRecurring?: boolean;
    recurrenceIntervalNanos?: bigint;
  }
): Promise<{ briefId: string; subaccount: Uint8Array }> {
  const actor = await getPressActor(agent);
  
  // Format requirements to match Candid optional types
  const requirements = {
    requiredTopics: params.requirements.requiredTopics,
    format: params.requirements.format ? [params.requirements.format] : [],
    minWords: params.requirements.minWords !== undefined ? [params.requirements.minWords] : [],
    maxWords: params.requirements.maxWords !== undefined ? [params.requirements.maxWords] : [],
  };
  
  const result = await actor.create_brief(
    params.title,
    params.description,
    params.topic,
    requirements,
    params.bountyPerArticle,
    params.maxArticles,
    params.expiresAt ? [params.expiresAt] : [],
    params.isRecurring ?? false,
    params.recurrenceIntervalNanos ? [params.recurrenceIntervalNanos] : []
  );
  
  if ('ok' in result) {
    return result.ok;
  } else {
    throw new Error(result.err);
  }
}

/**
 * Approve an article (curators only)
 */
export async function approveArticle(agent: any, articleId: bigint, briefId: string): Promise<void> {
  const actor = await getPressActor(agent);
  const result = await actor.web_approve_article(articleId, briefId);
  
  if ('err' in result) {
    throw new Error(result.err);
  }
}

/**
 * Reject an article (curators only)
 */
export async function rejectArticle(agent: any, articleId: bigint, reason: string): Promise<void> {
  const actor = await getPressActor(agent);
  const result = await actor.web_reject_article(articleId, reason);
  
  if ('err' in result) {
    throw new Error(result.err);
  }
}
