import { useQuery } from '@tanstack/react-query';

type BackgroundData = { backgrounds: Record<string, string> };

/**
 * Hook to fetch bot background colors from precomputed JSON
 */
export function useBackgrounds() {
  return useQuery({
    queryKey: ['backgrounds'],
    queryFn: async () => {
      const response = await fetch('/backgrounds.json');
      return response.json() as Promise<BackgroundData>;
    },
    staleTime: Infinity, // Never refetch - backgrounds don't change
  });
}
