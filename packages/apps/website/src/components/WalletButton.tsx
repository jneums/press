import { useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { useWalletDrawer } from '../contexts/WalletDrawerContext';
import { Button } from './ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from './ui/dialog';
import { Wallet } from 'lucide-react';
import type { WalletProvider } from '../lib/auth';

const WALLET_OPTIONS: { id: WalletProvider; name: string; description: string }[] = [
  {
    id: 'identity',
    name: 'Internet Identity',
    description: 'IC native authentication',
  },
  {
    id: 'nfid',
    name: 'NFID',
    description: 'Modern wallet with email',
  },
  {
    id: 'plug',
    name: 'Plug Wallet',
    description: 'Browser extension',
  },
];

export default function WalletButton() {
  const { user, isAuthenticated, isLoading, error, login } = useAuth();
  const { openDrawer } = useWalletDrawer();
  const [isOpen, setIsOpen] = useState(false);
  const [connectingProvider, setConnectingProvider] = useState<WalletProvider | null>(null);

  const handleLogin = async (provider: WalletProvider) => {
    setConnectingProvider(provider);
    try {
      await login(provider);
      setIsOpen(false);
    } catch (err) {
      console.error('Login failed:', err);
    } finally {
      setConnectingProvider(null);
    }
  };

  const truncatePrincipal = (principal: string) => {
    if (principal.length <= 12) return principal;
    return `${principal.slice(0, 6)}...${principal.slice(-4)}`;
  };

  if (isAuthenticated && user) {
    return (
      <Button variant="outline" className="gap-2" onClick={openDrawer}>
        <Wallet className="h-4 w-4" />
        <span className="hidden sm:inline">{truncatePrincipal(user.principal)}</span>
        <span className="sm:hidden">Wallet</span>
      </Button>
    );
  }

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" className="gap-2">
          <Wallet className="h-4 w-4" />
          Connect Wallet
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Connect Your Wallet</DialogTitle>
          <DialogDescription>
            Choose a wallet provider to connect to PokedBots Racing
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-2 mt-4">
          {WALLET_OPTIONS.map((wallet) => (
            <button
              key={wallet.id}
              onClick={() => handleLogin(wallet.id)}
              disabled={isLoading || connectingProvider !== null}
              className="w-full flex items-start gap-3 p-4 rounded-lg border border-border hover:bg-secondary transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-left"
            >
              <Wallet className="h-5 w-5 mt-0.5 flex-shrink-0" />
              <div className="flex-1 min-w-0">
                <div className="font-medium">{wallet.name}</div>
                <div className="text-sm text-muted-foreground">
                  {wallet.description}
                </div>
                {connectingProvider === wallet.id && (
                  <div className="text-sm text-primary mt-1">
                    Connecting...
                  </div>
                )}
              </div>
            </button>
          ))}
        </div>

        {error && (
          <div className="mt-4 p-3 bg-destructive/10 border border-destructive/20 rounded-md">
            <p className="text-sm text-destructive">
              {error}
            </p>
          </div>
        )}

        <div className="mt-4 text-xs text-muted-foreground text-center">
          By connecting, you agree to keep your NFTs in your wallet. This is a non-custodial platform.
        </div>
      </DialogContent>
    </Dialog>
  );
}
