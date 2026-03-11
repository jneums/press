import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  getOpenBriefs,
  getMyBriefs,
  getBrief,
  getTriageArticles,
  getArticle,
  getArchivedArticles,
  getAgentStats,
  getArticlesByAgent,
  getArticlesByBrief,
  getCuratorStats,
  getTopCurators,
  getTopAuthors,
  getMediaAsset,
  getPlatformStats,
  createBrief,
  updateBrief,
  addEscrowToBrief,
  approveArticle,
  rejectArticle,
  requestRevision,
} from '@press/ic-js';
import { useAuth } from './useAuth';
import { Principal } from '@dfinity/principal';

/**
 * Hook to fetch all open briefs (public - works without authentication)
 */
export function useOpenBriefs() {
  const { getAgent } = useAuth();

  return useQuery({
    queryKey: ['press', 'briefs', 'open'],
    queryFn: async () => {
      return await getOpenBriefs(getAgent());
    },
    refetchInterval: 30000, // Refetch every 30 seconds
  });
}

/**
 * Hook to fetch briefs created by the current user
 */
export function useMyBriefs() {
  const { getAgent, isAuthenticated } = useAuth();

  return useQuery({
    queryKey: ['press', 'briefs', 'my'],
    queryFn: async () => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      return await getMyBriefs(agent);
    },
    enabled: isAuthenticated,
    refetchInterval: 30000, // Refetch every 30 seconds
  });
}

/**
 * Hook to fetch a specific brief by ID (public - works without authentication)
 */
export function useBrief(briefId: string | undefined) {
  const { getAgent } = useAuth();

  return useQuery({
    queryKey: ['press', 'brief', briefId],
    queryFn: async () => {
      if (!briefId) throw new Error('No brief ID');
      return await getBrief(getAgent(), briefId);
    },
    enabled: !!briefId,
  });
}

/**
 * Hook to fetch multiple briefs by IDs (for bulk lookups)
 */
export function useBriefsByIds(briefIds: string[]) {
  const { getAgent } = useAuth();

  return useQuery({
    queryKey: ['press', 'briefs', 'byIds', briefIds.sort().join(',')],
    queryFn: async () => {
      if (briefIds.length === 0) return [];
      const { getBriefsByIds } = await import('@press/ic-js');
      return await getBriefsByIds(getAgent(), briefIds);
    },
    enabled: briefIds.length > 0,
  });
}

/**
 * Hook to fetch all articles in triage (awaiting review)
 */
export function useTriageArticles() {
  const { getAgent, isAuthenticated } = useAuth();

  return useQuery({
    queryKey: ['press', 'articles', 'triage'],
    queryFn: async () => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      return await getTriageArticles(agent);
    },
    enabled: isAuthenticated,
    refetchInterval: 15000, // Refetch every 15 seconds for curator queue
  });
}

/**
 * Hook to fetch a specific article by ID
 */
export function useArticle(articleId: bigint | undefined) {
  const { getAgent, isAuthenticated } = useAuth();

  return useQuery({
    queryKey: ['press', 'article', articleId?.toString()],
    queryFn: async () => {
      const agent = getAgent();
      if (!agent || articleId === undefined) throw new Error('Not authenticated or no article ID');
      return await getArticle(agent, articleId);
    },
    enabled: isAuthenticated && articleId !== undefined,
  });
}

/**
 * Hook to fetch archived articles with pagination and optional status filter
 * @param statusFilter - 'approved', 'rejected', or undefined for all
 */
export function useArchivedArticles(
  offset: bigint = 0n,
  limit: bigint = 50n,
  statusFilter?: 'approved' | 'rejected'
) {
  const { getAgent, isAuthenticated } = useAuth();

  return useQuery({
    queryKey: ['press', 'articles', 'archived', offset.toString(), limit.toString(), statusFilter],
    queryFn: async () => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      return await getArchivedArticles(agent, offset, limit, statusFilter);
    },
    enabled: isAuthenticated,
  });
}

/**
 * Hook to fetch agent statistics
 */
export function useAgentStats(principal?: Principal) {
  const { getAgent, isAuthenticated } = useAuth();

  return useQuery({
    queryKey: ['press', 'stats', 'agent', principal?.toText()],
    queryFn: async () => {
      const agent = getAgent();
      if (!agent || !principal) throw new Error('Not authenticated or no principal');
      const result = await getAgentStats(agent, principal);
      // Backend returns opt record which gets wrapped in array
      return Array.isArray(result) ? result[0] : result;
    },
    enabled: isAuthenticated && !!principal,
  });
}

/**
 * Hook to fetch all articles by a specific agent
 */
export function useArticlesByAgent(agentPrincipal?: Principal) {
  const { getAgent, isAuthenticated } = useAuth();

  return useQuery({
    queryKey: ['press', 'articles', 'by-agent', agentPrincipal?.toText()],
    queryFn: async () => {
      const agent = getAgent();
      if (!agent || !agentPrincipal) throw new Error('Not authenticated or no principal');
      return await getArticlesByAgent(agent, agentPrincipal);
    },
    enabled: isAuthenticated && !!agentPrincipal,
  });
}

/**
 * Hook to fetch articles for a specific brief
 */
export function useArticlesByBrief(briefId?: string) {
  const { getAgent } = useAuth();

  return useQuery({
    queryKey: ['press', 'articles', 'by-brief', briefId],
    queryFn: async () => {
      const agent = getAgent();
      if (!agent || !briefId) throw new Error('No agent or no brief');
      return await getArticlesByBrief(agent, briefId);
    },
    enabled: !!briefId,
  });
}

/**
 * Hook to fetch curator statistics
 */
export function useCuratorStats(principal?: Principal) {
  const { getAgent, isAuthenticated } = useAuth();

  return useQuery({
    queryKey: ['press', 'stats', 'curator', principal?.toText()],
    queryFn: async () => {
      const agent = getAgent();
      if (!agent || !principal) throw new Error('Not authenticated or no principal');
      return await getCuratorStats(agent, principal);
    },
    enabled: isAuthenticated && !!principal,
  });
}

/**
 * Hook to fetch top curators by total bounties paid (public - works without authentication)
 */
export function useTopCurators(limit: number = 5) {
  const { getAgent } = useAuth();

  return useQuery({
    queryKey: ['press', 'stats', 'topCurators', limit],
    queryFn: async () => {
      return await getTopCurators(getAgent(), limit);
    },
    refetchInterval: 60000, // Refetch every minute
  });
}

/**
 * Hook to fetch top authors by total earnings (public - works without authentication)
 */
export function useTopAuthors(limit: number = 5) {
  const { getAgent } = useAuth();

  return useQuery({
    queryKey: ['press', 'stats', 'topAuthors', limit],
    queryFn: async () => {
      return await getTopAuthors(getAgent(), limit);
    },
    refetchInterval: 60000, // Refetch every minute
  });
}

/**
 * Hook to fetch media asset by ID
 */
export function useMediaAsset(assetId: bigint | undefined) {
  const { getAgent, isAuthenticated } = useAuth();

  return useQuery({
    queryKey: ['press', 'media', assetId?.toString()],
    queryFn: async () => {
      const agent = getAgent();
      if (!agent || assetId === undefined) throw new Error('Not authenticated or no asset ID');
      return await getMediaAsset(agent, assetId);
    },
    enabled: isAuthenticated && assetId !== undefined,
  });
}

/**
 * Hook to fetch platform-wide statistics (public - works without authentication)
 */
export function usePlatformStats() {
  const { getAgent } = useAuth();

  return useQuery({
    queryKey: ['press', 'stats', 'platform'],
    queryFn: async () => {
      return await getPlatformStats(getAgent());
    },
    refetchInterval: 60000, // Refetch every minute
  });
}

/**
 * Hook to create a new brief
 */
export function useCreateBrief() {
  const { getAgent } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (params: {
      title: string;
      description: string;
      topic: string;
      platformConfig: {
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
        pinType: string[];
        boardSuggestion: string[];
        customInstructions: string[];
      };
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
    }) => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      return await createBrief(agent, params);
    },
    onSuccess: async () => {
      // Invalidate briefs queries to refetch the list
      await queryClient.invalidateQueries({ queryKey: ['press', 'briefs'] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'stats'] });
    },
  });
}

/**
 * Hook to update an existing brief (curator only)
 * Fairness constraints are enforced by the backend:
 * - bountyPerArticle can only INCREASE
 * - maxArticles can only INCREASE
 * - expiresAt can only be extended, not shortened
 */
export function useUpdateBrief() {
  const { getAgent } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (params: {
      briefId: string;
      title?: string;
      description?: string;
      topic?: string;
      platformConfig?: {
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
        pinType: string[];
        boardSuggestion: string[];
        customInstructions: string[];
      };
      requirements?: {
        requiredTopics: string[];
        format: string | null;
        minWords?: bigint;
        maxWords?: bigint;
      };
      bountyPerArticle?: bigint;
      maxArticles?: bigint;
      expiresAt?: bigint | null;
    }) => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      const { briefId, ...updateParams } = params;
      return await updateBrief(agent, briefId, updateParams);
    },
    onSuccess: async (_data, variables) => {
      // Invalidate specific brief and all briefs queries
      await queryClient.invalidateQueries({ queryKey: ['press', 'brief', variables.briefId] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'briefs'] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'stats'] });
    },
  });
}

/**
 * Hook to add additional escrow to a brief
 */
export function useAddEscrowToBrief() {
  const { getAgent } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (params: { briefId: string; amount: bigint }) => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      return await addEscrowToBrief(agent, params.briefId, params.amount);
    },
    onSuccess: async (_data, variables) => {
      await queryClient.invalidateQueries({ queryKey: ['press', 'brief', variables.briefId] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'briefs'] });
    },
  });
}

/**
 * Hook to approve an article and pay the bounty
 */
export function useApproveArticle() {
  const { getAgent } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (params: { articleId: bigint; briefId: string }) => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      return await approveArticle(agent, params.articleId, params.briefId);
    },
    onSuccess: async (_data, variables) => {
      // Invalidate all related queries to ensure UI updates
      await queryClient.invalidateQueries({ queryKey: ['press', 'article', variables.articleId.toString()] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'articles'] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'brief', variables.briefId] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'briefs'] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'stats'] });
    },
  });
}

/**
 * Hook to reject an article
 */
export function useRejectArticle() {
  const { getAgent } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (params: { articleId: bigint; reason: string }) => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      return await rejectArticle(agent, params.articleId, params.reason);
    },
    onSuccess: async (_data, variables) => {
      // Invalidate all related queries to ensure UI updates
      await queryClient.invalidateQueries({ queryKey: ['press', 'article', variables.articleId.toString()] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'articles'] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'stats'] });
    },
  });
}

/**
 * Hook to request a revision for an article
 */
export function useRequestRevision() {
  const { getAgent } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (params: { articleId: bigint; briefId: string; feedback: string }) => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      return await requestRevision(agent, params.articleId, params.briefId, params.feedback);
    },
    onSuccess: async (_data, variables) => {
      // Invalidate all related queries to ensure UI updates
      await queryClient.invalidateQueries({ queryKey: ['press', 'article', variables.articleId.toString()] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'articles'] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'brief', variables.briefId] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'briefs'] });
    },
  });
}
