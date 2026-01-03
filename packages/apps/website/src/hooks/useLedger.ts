import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getICPBalance, transferICP } from '@press/ic-js';
import { useAuth } from './useAuth';

/**
 * Hook to fetch ICP balance
 */
export function useICPBalance() {
  const { user } = useAuth();

  return useQuery({
    queryKey: ['icp-balance', user?.principal],
    queryFn: async () => {
      if (!user?.agent || !user?.principal) {
        throw new Error('Not authenticated');
      }
      return getICPBalance(user.principal, user.agent);
    },
    enabled: !!user?.agent && !!user?.principal,
    staleTime: 30 * 1000, // 30 seconds
    refetchInterval: 60 * 1000, // Refetch every minute
  });
}

/**
 * Hook to transfer ICP
 */
export function useTransferICP() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ to, amount }: { to: string; amount: number }) => {
      if (!user?.agent) {
        throw new Error('Not authenticated');
      }
      return transferICP(user.agent, to, amount);
    },
    onSuccess: () => {
      // Invalidate balance query to refetch updated balance
      queryClient.invalidateQueries({ queryKey: ['icp-balance'] });
    },
  });
}
