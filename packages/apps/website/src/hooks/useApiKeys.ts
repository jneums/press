import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { listMyApiKeys, createMyApiKey, revokeMyApiKey } from '@press/ic-js';
import { useAuth } from './useAuth';
import { Principal } from '@icp-sdk/core/principal';

export interface ApiKeyInfo {
  created: bigint;
  principal: Principal;
  scopes: string[];
  name: string;
}

export interface ApiKeyMetadata {
  info: ApiKeyInfo;
  hashed_key: string;
}

/**
 * Hook to fetch all API keys for the current user
 */
export function useMyApiKeys() {
  const { getAgent, isAuthenticated } = useAuth();

  return useQuery<ApiKeyMetadata[], Error>({
    queryKey: ['apiKeys'],
    queryFn: async () => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      return await listMyApiKeys(agent);
    },
    enabled: isAuthenticated,
  });
}

/**
 * Hook to create a new API key
 */
export function useCreateApiKey() {
  const { getAgent } = useAuth();
  const queryClient = useQueryClient();

  return useMutation<string, Error, { name: string; scopes: string[] }>({
    mutationFn: async ({ name, scopes }) => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      return await createMyApiKey(agent, name, scopes);
    },
    onSuccess: () => {
      // Invalidate the API keys query to refetch the list
      queryClient.invalidateQueries({ queryKey: ['apiKeys'] });
    },
  });
}

/**
 * Hook to revoke an API key
 */
export function useRevokeApiKey() {
  const { getAgent } = useAuth();
  const queryClient = useQueryClient();

  return useMutation<void, Error, string>({
    mutationFn: async (hashedKey: string) => {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      return await revokeMyApiKey(agent, hashedKey);
    },
    onSuccess: () => {
      // Invalidate the API keys query to refetch the list
      queryClient.invalidateQueries({ queryKey: ['apiKeys'] });
    },
  });
}
