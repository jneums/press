/**
 * React hook for authentication
 */

import { create } from 'zustand';
import { getAuthService, type WalletProvider, type UserObject } from '../lib/auth';
import { useQueryClient } from '@tanstack/react-query';

interface AuthStore {
  user: UserObject | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  login: (provider: WalletProvider) => Promise<void>;
  logout: () => Promise<void>;
  getAgent: () => any;
  getAgentOrAnonymous: () => Promise<any>;
  getPrincipal: () => string | null;
  invalidateQueries?: () => void;
  handleSessionExpired?: () => void;
}

const network = process.env.DFX_NETWORK || 'local'; // 'ic' for mainnet, 'local' for local dev
const host = network === 'ic' ? 'https://icp0.io' : 'http://127.0.0.1:4943';

// Initialize auth service with proper host
const authService = getAuthService(host);

/**
 * Zustand store for authentication state
 * Using Zustand for simple global state management
 */
export const useAuthStore = create<AuthStore>((set: any, get: any) => ({
  user: null,
  isAuthenticated: false,
  isLoading: true, // Start as loading to prevent flash of logged-out state
  error: null,

  login: async (provider: WalletProvider) => {
    set({ isLoading: true, error: null });
    
    try {
      const user = await authService.login(provider);
      set({ 
        user, 
        isAuthenticated: true, 
        isLoading: false,
        error: null
      });
      
      // Invalidate all React Query caches after login to force re-fetch with new agent
      const invalidate = get().invalidateQueries;
      if (invalidate) {
        invalidate();
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Login failed';
      set({ 
        user: null, 
        isAuthenticated: false, 
        isLoading: false,
        error: message
      });
      throw error;
    }
  },

  logout: async () => {
    await authService.logout();
    set({ 
      user: null, 
      isAuthenticated: false, 
      error: null 
    });
    
    // Invalidate all React Query caches after logout
    const invalidate = get().invalidateQueries;
    if (invalidate) {
      invalidate();
    }
  },

  getAgent: () => {
    return authService.getAgent();
  },

  getAgentOrAnonymous: async () => {
    const agent = authService.getAgent();
    if (agent) return agent;
    
    // Create anonymous agent for public queries
    const { HttpAgent, AnonymousIdentity } = await import('@dfinity/agent');
    const network = process.env.DFX_NETWORK || 'local';
    const host = network === 'ic' ? 'https://icp0.io' : 'http://127.0.0.1:4943';
    return await HttpAgent.create({
      identity: new AnonymousIdentity(),
      host,
    });
  },

  getPrincipal: () => {
    return authService.getPrincipal();
  },
  
  // Handle session expiry (called when API detects expired session)
  handleSessionExpired: () => {
    console.log('[Auth] Session expired, logging out');
    const currentUser = get().user;
    if (currentUser?.provider === 'plug') {
      // Don't call Plug disconnect as it may trigger popup
      set({ 
        user: null, 
        isAuthenticated: false, 
        error: 'Session expired. Please reconnect.' 
      });
      authService.logout().catch(() => {}); // Logout in background
    }
  },
}));

// Initialize authentication state on app load
(async () => {
  try {
    await authService.init();
    const isAuth = authService.isAuthenticated();
    const agent = authService.getAgent();
    const principal = authService.getPrincipal();
    
    if (isAuth && agent && principal) {
      useAuthStore.setState({
        user: {
          principal,
          agent,
          provider: authService.getProvider() || 'identity',
        },
        isAuthenticated: true,
        isLoading: false,
      });
    } else {
      useAuthStore.setState({
        isLoading: false,
      });
    }
  } catch (error) {
    console.error('[Auth] Failed to restore session:', error);
    useAuthStore.setState({
      isLoading: false,
    });
  }
})();

/**
 * Hook to access authentication state and methods
 */
export const useAuth = () => {
  const store = useAuthStore();
  const queryClient = useQueryClient();
  
  // Set up the invalidateQueries function in the store if not already set
  if (!store.invalidateQueries) {
    useAuthStore.setState({
      invalidateQueries: () => {
        console.log('[Auth] Invalidating all React Query caches after auth change');
        queryClient.invalidateQueries();
      }
    });
  }
  
  return {
    user: store.user,
    isAuthenticated: store.isAuthenticated,
    isLoading: store.isLoading,
    error: store.error,
    login: store.login,
    logout: store.logout,
    getAgent: store.getAgent,
    getAgentOrAnonymous: store.getAgentOrAnonymous,
    getPrincipal: store.getPrincipal,
    provider: authService.getProvider(),
    lastProvider: authService.getLastProvider(),
  };
};
