import { getCanisterId, getHost } from '../config.js';
import type { Identity } from '@dfinity/agent';

// Accept either Identity or Plug agent
type IdentityOrAgent = Identity | any;

// Helper function to detect if this is a Plug agent
// Plug agents have 'agent' property and are not standard Identity objects
function isPlugAgent(identityOrAgent: any): boolean {
  return identityOrAgent && 
         typeof identityOrAgent === 'object' && 
         'agent' in identityOrAgent &&
         'getPrincipal' in identityOrAgent &&
         typeof identityOrAgent.getPrincipal === 'function';
}

/**
 * Get Press actor from an existing agent or identity
 * If no agent provided, creates an anonymous agent
 */
async function getPressActor(identityOrAgent?: IdentityOrAgent): Promise<any> {
  const { Press } = await import('@press/declarations');

  // Check if it's a Plug agent - use window.ic.plug.createActor
  if (isPlugAgent(identityOrAgent) && typeof globalThis !== 'undefined' && (globalThis as any).window?.ic?.plug?.createActor) {
    // Check if Plug is still connected before calling createActor
    const isConnected = await (globalThis as any).window.ic.plug.isConnected();
    if (!isConnected) {
      throw new Error('Plug session expired. Please reconnect.');
    }
    const canisterId = getCanisterId('PRESS');
    return await (globalThis as any).window.ic.plug.createActor({
      canisterId,
      interfaceFactory: Press.idlFactory,
    });
  }

  // For non-Plug or anonymous, use standard actor creation
  const { Actor, HttpAgent, AnonymousIdentity } = await import('@dfinity/agent');
  const canisterId = getCanisterId('PRESS');
  const host = getHost();
  const isLocal = host.includes('localhost') || host.includes('127.0.0.1');

  // If no identity provided, create anonymous agent
  if (!identityOrAgent) {
    const agent = await HttpAgent.create({
      host,
      identity: new AnonymousIdentity(),
    });
    
    if (isLocal) {
      await agent.fetchRootKey();
    }
    
    return Actor.createActor(Press.idlFactory, {
      agent,
      canisterId,
    });
  }

  // It's a standard Identity - wrap it in HttpAgent
  const agent = await HttpAgent.create({
    host,
    identity: identityOrAgent as Identity,
  });
  
  if (isLocal) {
    await agent.fetchRootKey();
  }
  
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

// Platform config type
interface PlatformConfig {
  platform: { [key: string]: null };
  includeHashtags: boolean[];
  threadCount: bigint[];
  isArticle: boolean[];
  tags: string[];
  includeTimestamps: boolean[];
  targetDuration: bigint[];
  subjectLine: string[];
  citationStyle: string[];
  includeAbstract: boolean[];
  customInstructions: string[];
}

/**
 * Create a new brief
 */
export async function createBrief(
  agent: any,
  params: {
    title: string;
    description: string;
    topic: string;
    platformConfig: PlatformConfig;
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
    params.platformConfig,
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

/**
 * Request revisions for an article (curators only)
 * This signals the curator is interested in the article but needs changes
 * Funds remain in escrow until final approval
 */
export async function requestRevision(agent: any, articleId: bigint, briefId: string, feedback: string): Promise<void> {
  const actor = await getPressActor(agent);
  const result = await actor.web_request_revision(articleId, briefId, feedback);
  
  if ('err' in result) {
    throw new Error(result.err);
  }
}

/**
 * Submit a revision for an article (agents only)
 * This allows the agent to respond to revision requests
 */
export async function submitRevision(agent: any, articleId: bigint, revisedContent: string): Promise<void> {
  const actor = await getPressActor(agent);
  const result = await actor.web_submit_revision(articleId, revisedContent);
  
  if ('err' in result) {
    throw new Error(result.err);
  }
}

/**
 * Agent approves their draft article to send to curator queue
 */
export async function approveDraft(agent: any, articleId: bigint): Promise<void> {
  const actor = await getPressActor(agent);
  const result = await actor.web_approve_draft(articleId);
  
  if ('err' in result) {
    throw new Error(result.err);
  }
}

/**
 * Agent updates their draft article content
 */
export async function updateDraft(agent: any, articleId: bigint, newTitle: string, newContent: string): Promise<void> {
  const actor = await getPressActor(agent);
  const result = await actor.web_update_draft(articleId, newTitle, newContent);
  
  if ('err' in result) {
    throw new Error(result.err);
  }
}

/**
 * Agent deletes their draft article
 */
export async function deleteDraft(agent: any, articleId: bigint): Promise<void> {
  const actor = await getPressActor(agent);
  const result = await actor.web_delete_draft(articleId);
  
  if ('err' in result) {
    throw new Error(result.err);
  }
}

/**
 * Update brief request - all fields are optional
 * Constraints enforced by the backend:
 * - bountyPerArticle can only INCREASE
 * - maxArticles can only INCREASE
 * - expiresAt can only be extended, not shortened
 */
export interface UpdateBriefParams {
  title?: string;
  description?: string;
  topic?: string;
  platformConfig?: PlatformConfig;
  requirements?: {
    requiredTopics: string[];
    format: string | null;
    minWords?: bigint;
    maxWords?: bigint;
  };
  bountyPerArticle?: bigint;
  maxArticles?: bigint;
  expiresAt?: bigint | null; // null = remove expiry, undefined = no change
}

/**
 * Update an existing brief (curator only)
 * Only the curator who created the brief can update it.
 * The brief must be open (not closed or cancelled).
 * Fairness constraints are enforced by the backend.
 */
export async function updateBrief(agent: any, briefId: string, params: UpdateBriefParams): Promise<void> {
  const actor = await getPressActor(agent);
  
  // Build the update request with proper Candid optional types
  const updateRequest = {
    title: params.title !== undefined ? [params.title] : [],
    description: params.description !== undefined ? [params.description] : [],
    topic: params.topic !== undefined ? [params.topic] : [],
    platformConfig: params.platformConfig !== undefined ? [params.platformConfig] : [],
    requirements: params.requirements !== undefined ? [{
      requiredTopics: params.requirements.requiredTopics,
      format: params.requirements.format ? [params.requirements.format] : [],
      minWords: params.requirements.minWords !== undefined ? [params.requirements.minWords] : [],
      maxWords: params.requirements.maxWords !== undefined ? [params.requirements.maxWords] : [],
    }] : [],
    bountyPerArticle: params.bountyPerArticle !== undefined ? [params.bountyPerArticle] : [],
    maxArticles: params.maxArticles !== undefined ? [params.maxArticles] : [],
    // For expiresAt: null means remove expiry (wrap null in array), undefined means no change (empty array)
    expiresAt: params.expiresAt === null ? [[]] : params.expiresAt !== undefined ? [[params.expiresAt]] : [],
  };
  
  const result = await actor.update_brief(briefId, updateRequest);
  
  if ('err' in result) {
    throw new Error(result.err);
  }
}

/**
 * Add additional escrow to a brief
 */
export async function addEscrowToBrief(agent: any, briefId: string, amount: bigint): Promise<void> {
  const actor = await getPressActor(agent);
  const result = await actor.add_escrow_to_brief(briefId, amount);
  
  if ('err' in result) {
    throw new Error(result.err);
  }
}
