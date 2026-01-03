import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getAllowance, setAllowance } from '@press/ic-js';
import { useAuth } from './useAuth';
import { getCanisterId } from '@press/ic-js';

/**
 * Hook to get current allowance for racing canister
 */
export function useAllowance() {
  const { user } = useAuth();
  const racingCanisterId = getCanisterId('press');

  return useQuery({
    queryKey: ['allowance', user?.principal, racingCanisterId],
    queryFn: async () => {
      if (!user?.agent) {
        throw new Error('Not authenticated');
      }
      const allowanceE8s = await getAllowance(user.agent, racingCanisterId);
      // Convert to ICP
      return Number(allowanceE8s) / 100_000_000;
    },
    enabled: !!user?.agent,
    staleTime: 30 * 1000, // 30 seconds
    refetchInterval: 60 * 1000, // Refetch every minute
    gcTime: 60 * 1000, // 1 minute
  });
}

/**
 * Hook to set allowance
 */
export function useSetAllowance() {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const racingCanisterId = getCanisterId('press');

  return useMutation({
    mutationFn: async (amountICP: number) => {
      if (!user?.agent) {
        throw new Error('Not authenticated');
      }
      await setAllowance(user.agent, racingCanisterId, amountICP);
    },
    onSuccess: () => {
      // Invalidate allowance query to refetch
      queryClient.invalidateQueries({ queryKey: ['allowance', user?.principal, racingCanisterId] });
    },
  });
}
