/**
 * Authentication service using @dfinity/auth-client v2
 * Supports: Internet Identity v2, NFID, Plug Wallet, OISY Wallet
 */

import { AuthClient } from '@dfinity/auth-client';
import type { Identity } from '@dfinity/agent';

// Plug wallet global interface
declare global {
  interface Window {
    ic?: {
      plug?: {
        requestConnect: (options?: { whitelist?: string[]; host?: string }) => Promise<boolean>;
        isConnected: (options?: { host?: string }) => Promise<boolean>;
        createAgent: (options?: { whitelist?: string[]; host?: string }) => Promise<any>;
        agent: any;
        getPrincipal: () => Promise<any>;
        disconnect: () => Promise<void>;
      };
    };
  }
}

export type WalletProvider = 'identity' | 'nfid' | 'plug';

const STORAGE_KEY = 'pokedbots_auth';

interface StoredAuth {
  provider: WalletProvider;
  principal: string;
  timestamp: number;
}

export interface UserObject {
  principal: string;
  agent: Identity;
  provider: string;
}

export class AuthService {
  private currentUser: UserObject | null = null;
  private authClient: AuthClient | null = null;
  private host: string;
  private initPromise: Promise<void> | null = null;
  private hasInitialized: boolean = false;

  constructor(host?: string) {
    // Use mainnet by default, or localhost for development
    this.host = host || 
      (window.location.hostname === 'localhost' ? 'http://localhost:4943' : 'https://icp0.io');
  }

  /**
   * Initialize the auth service (call this before using)
   */
  async init(): Promise<void> {
    if (this.initPromise) {
      return this.initPromise;
    }

    this.initPromise = this.initAuthClient();
    return this.initPromise;
  }

  private async initAuthClient() {
    this.authClient = await AuthClient.create();
    
    // Only load from storage once during initialization
    if (!this.hasInitialized) {
      await this.loadFromAuthClient();
      this.hasInitialized = true;
    }
  }

  /**
   * Load authentication state from AuthClient or Plug (only called once on init)
   */
  private async loadFromAuthClient() {
    // Check localStorage for stored provider
    const stored = localStorage.getItem(STORAGE_KEY);
    let storedProvider: WalletProvider | null = null;
    
    if (stored) {
      try {
        const authData: StoredAuth = JSON.parse(stored);
        storedProvider = authData.provider;
      } catch {}
    }

    // If last provider was Plug, try to restore Plug session
    if (storedProvider === 'plug' && window.ic?.plug) {
      try {
        const whitelist = [
          'bzsui-sqaaa-aaaah-qce2a-cai', // NFT canister
          'p6nop-vyaaa-aaaai-q4djq-cai', // Racing canister
          'ryjl3-tyaaa-aaaaa-aaaba-cai' // ICP Ledger canister
        ];
        
        // Only check connection status during initialization
        // Note: isConnected should not trigger popup, but if disconnected we silently clear storage
        let isConnected = false;
        try {
          isConnected = await window.ic.plug.isConnected({ host: this.host });
        } catch (error) {
          // If isConnected fails (e.g., Plug locked/disconnected), silently clear storage
          console.log('[Auth] Plug isConnected check failed, clearing storage:', error);
          this.clearStorage();
          return;
        }
        
        if (isConnected) {
          // Use existing agent without recreating (createAgent can trigger popup)
          const agent = window.ic.plug.agent;
          if (!agent) {
            console.log('[Auth] Plug connected but no agent available, clearing storage');
            this.clearStorage();
            return;
          }
          
          try {
            const principal = await agent.getPrincipal();
            this.currentUser = {
              principal: principal.toText(),
              agent: agent,
              provider: 'plug',
            };
            console.log('[Auth] Restored Plug session:', this.currentUser.principal);
            return;
          } catch (error) {
            console.log('[Auth] Failed to get principal from Plug agent:', error);
            this.clearStorage();
            return;
          }
        } else {
          // Plug says not connected, clear storage
          console.log('[Auth] Plug not connected, clearing storage');
          this.clearStorage();
        }
      } catch (error) {
        console.log('[Auth] Failed to restore Plug session:', error);
        this.clearStorage();
      }
    }

    // Otherwise check AuthClient (for II/NFID)
    if (!this.authClient) return;

    const isAuthenticated = await this.authClient.isAuthenticated();
    if (isAuthenticated) {
      const identity = this.authClient.getIdentity();
      const principal = identity.getPrincipal().toString();
      
      const provider = storedProvider || 'identity';

      this.currentUser = {
        principal,
        agent: identity,
        provider,
      };
      console.log('[Auth] Restored AuthClient session:', this.currentUser.principal);
    }
  }

  /**
   * Check if user is authenticated
   */
  isAuthenticated(): boolean {
    return this.currentUser !== null && this.currentUser.principal !== '2vxsx-fae';
  }

  /**
   * Get the current user's principal as a string
   */
  getPrincipal(): string | null {
    return this.isAuthenticated() ? this.currentUser!.principal : null;
  }

  /**
   * Get the current agent for making canister calls
   */
  getAgent(): Identity | null {
    return this.currentUser?.agent || null;
  }

  /**
   * Get the current provider name
   */
  getProvider(): string | null {
    return this.currentUser?.provider || null;
  }

  /**
   * Login with the specified wallet provider
   */
  async login(provider: WalletProvider): Promise<UserObject> {
    console.log(`[AuthService] Logging in with ${provider}, host: ${this.host}`);

    // Ensure initialization is complete
    await this.init();

    // Handle Plug wallet separately
    if (provider === 'plug') {
      return this.loginWithPlug();
    }

    // Handle AuthClient-based providers (II, NFID)
    if (!this.authClient) {
      throw new Error('AuthClient not initialized');
    }

    const identityProvider = provider === 'nfid' 
      ? 'https://nfid.one/authenticate'
      : 'https://id.ai';

    return new Promise((resolve, reject) => {
      this.authClient!.login({
        identityProvider,
        onSuccess: () => {
          const identity = this.authClient!.getIdentity();
          const principal = identity.getPrincipal().toString();

          this.currentUser = {
            principal,
            agent: identity,
            provider,
          };

          // Save to localStorage
          this.saveToStorage(provider, principal);
          resolve(this.currentUser);
        },
        onError: (error) => {
          console.error('Authentication error:', error);
          reject(new Error(`Authentication failed: ${error}`));
        },
      });
    });
  }

  /**
   * Login with Plug wallet
   */
  private async loginWithPlug(): Promise<UserObject> {
    if (!window.ic?.plug) {
      throw new Error('Plug wallet is not installed. Please install it from https://plugwallet.ooo/');
    }

    console.log('host', this.host);

    const whitelist = [
      'bzsui-sqaaa-aaaah-qce2a-cai', // NFT canister
      'p6nop-vyaaa-aaaai-q4djq-cai', // Racing canister
      'ryjl3-tyaaa-aaaaa-aaaba-cai' // ICP Ledger canister
    ];

    if (!window.ic?.plug?.requestConnect) {
      throw new Error('Plug wallet not available');
    }

    // Check if already connected (e.g., user just unlocked Plug)
    let isConnected = false;
    try {
      isConnected = await window.ic.plug.isConnected({ host: this.host });
    } catch (error) {
      console.log('Error checking Plug connection:', error);
    }

    // Only request connection if not already connected
    if (!isConnected) {
      const connected = await window.ic.plug.requestConnect({ whitelist, host: this.host });
      if (!connected) {
        throw new Error('User denied Plug wallet connection');
      }
    } else {
      console.log('Plug already connected, creating agent...');
      // Ensure agent is created even if already connected
      await window.ic.plug.createAgent({ whitelist, host: this.host });
    }
  

    const agent = window.ic.plug.agent;
    const principal = await agent.getPrincipal();

    this.currentUser = {
      principal: principal.toText(),
      agent: agent,
      provider: 'plug',
    };

    console.log('Plug connected!', this.currentUser);
    this.saveToStorage('plug', principal.toText());
    return this.currentUser;
  }

  /**
   * Logout the current user
   */
  async logout(): Promise<void> {
    // Handle Plug logout separately
    if (this.currentUser?.provider === 'plug' && window.ic?.plug?.disconnect) {
      await window.ic.plug.disconnect();
    } else if (this.authClient) {
      await this.authClient.logout();
    }
    this.currentUser = null;
    this.clearStorage();
  }

  /**
   * Save authentication state to localStorage
   */
  private saveToStorage(provider: WalletProvider, principal: string): void {
    const authData: StoredAuth = {
      provider,
      principal,
      timestamp: Date.now(),
    };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(authData));
  }

  /**
   * Clear authentication storage
   */
  private clearStorage(): void {
    localStorage.removeItem(STORAGE_KEY);
    // Clear cached Plug ledger actor
    // clearPlugLedgerCache();
  }

  /**
   * Get the last used provider
   */
  getLastProvider(): WalletProvider | null {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) return null;

    try {
      const authData: StoredAuth = JSON.parse(stored);
      return authData.provider;
    } catch {
      return null;
    }
  }
}

// Singleton instance
let authService: AuthService | null = null;

/**
 * Initialize and get the auth service instance
 * @param host Optional host URL (defaults to mainnet or localhost based on environment)
 */
export const getAuthService = (host?: string): AuthService => {
  if (!authService) {
    authService = new AuthService(host);
  }
  return authService;
};
