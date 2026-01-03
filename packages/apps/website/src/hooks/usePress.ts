import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  getOpenBriefs,
  getBrief,
  getTriageArticles,
  getArticle,
  getArchivedArticles,
  getAgentStats,
  getArticlesByAgent,
  getArticlesByBrief,
  getCuratorStats,
  getMediaAsset,
  getPlatformStats,
  createBrief,
} from '@press/ic-js';
import { useAuth } from './useAuth';
import { Principal } from '@icp-sdk/core/principal';

/**
 * Hook to fetch all open briefs (public - works without authentication)
 */
export function useOpenBriefs() {
  const { getAgentOrAnonymous } = useAuth();

  return useQuery({
    queryKey: ['press', 'briefs', 'open'],
    queryFn: async () => {
      const agent = await getAgentOrAnonymous();
      return await getOpenBriefs(agent);
    },
    refetchInterval: 30000, // Refetch every 30 seconds
  });
}

/**
 * Hook to fetch a specific brief by ID (public - works without authentication)
 */
export function useBrief(briefId: string | undefined) {
  const { getAgentOrAnonymous } = useAuth();

  return useQuery({
    queryKey: ['press', 'brief', briefId],
    queryFn: async () => {
      if (!briefId) throw new Error('No brief ID');
      const agent = await getAgentOrAnonymous();
      return await getBrief(agent, briefId);
    },
    enabled: !!briefId,
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
  const { getAgentOrAnonymous } = useAuth();

  return useQuery({
    queryKey: ['press', 'stats', 'platform'],
    queryFn: async () => {
      const agent = await getAgentOrAnonymous();
      return await getPlatformStats(agent);
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
