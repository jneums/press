import { useEffect, useState } from 'react';
import { useAuth } from '../../hooks/useAuth';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../../components/ui/card';
import { Button } from '../../components/ui/button';
import { Badge } from '../../components/ui/badge';
import { WalletConnect } from '../../components/WalletConnect';
import { AccountIdentifier } from '@icp-sdk/canisters/ledger/icp';
import { Principal } from '@icp-sdk/core/principal';
import { Copy, RefreshCw } from 'lucide-react';

export default function WalletPage() {
  const { isAuthenticated, user } = useAuth();
  const [balance, setBalance] = useState<bigint | null>(null);
  const [loading, setLoading] = useState(false);

  // TODO: Implement balance fetching from ICP ledger
  const loadBalance = async () => {
    if (!user?.principal) return;
    setLoading(true);
    try {
      // TODO: Call ICP ledger to get balance
      // const balance = await getICPBalance(user.principal);
      // setBalance(balance);
      console.log('Balance loading not yet implemented');
    } catch (err) {
      console.error('Error loading balance:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isAuthenticated && user?.principal) {
      loadBalance();
    }
  }, [isAuthenticated, user]);

  if (!isAuthenticated) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12">
        <Card className="max-w-2xl mx-auto">
          <CardHeader>
            <CardTitle className="text-3xl">Wallet</CardTitle>
            <CardDescription>
              Connect your wallet to view your ICP balance and manage transfers
            </CardDescription>
          </CardHeader>
          <CardContent className="flex justify-center py-8">
            <WalletConnect />
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-4xl font-bold mb-2">Wallet</h1>
          <p className="text-muted-foreground">
            Manage your ICP balance and transfers
          </p>
        </div>
      </div>

      {/* Balance Card */}
      <Card className="mb-6">
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>ICP Balance</CardTitle>
            <Button
              variant="ghost"
              size="sm"
              onClick={loadBalance}
              disabled={loading}
            >
              <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="text-3xl font-bold mb-2">
            {balance !== null ? (Number(balance) / 100_000_000).toFixed(8) : '—'} ICP
          </div>
          <p className="text-sm text-muted-foreground">
            {balance !== null ? `${balance.toString()} e8s` : 'Loading...'}
          </p>
        </CardContent>
      </Card>

      {/* Account Info */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Account Information</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <p className="text-sm font-medium mb-1">Principal ID</p>
            <p className="text-xs text-muted-foreground mb-2">
              Your wallet identity on the Internet Computer
            </p>
            <div className="flex items-center gap-2">
              <code className="text-xs bg-muted px-2 py-1 rounded border font-mono break-all flex-1">
                {user?.principal}
              </code>
              <Button
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                onClick={() => {
                  if (user?.principal) {
                    navigator.clipboard.writeText(user.principal);
                  }
                }}
                title="Copy Principal ID"
              >
                <Copy className="h-3 w-3" />
              </Button>
            </div>
          </div>

          <div>
            <p className="text-sm font-medium mb-1">ICP Account ID</p>
            <p className="text-xs text-muted-foreground mb-2">
              Your account address for receiving ICP and NFTs
            </p>
            <div className="flex items-center gap-2">
              <code className="text-xs bg-muted px-2 py-1 rounded border font-mono break-all flex-1">
                {user?.principal && AccountIdentifier.fromPrincipal({
                  principal: Principal.fromText(user.principal),
                }).toHex()}
              </code>
              <Button
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                onClick={() => {
                  if (user?.principal) {
                    const accountId = AccountIdentifier.fromPrincipal({
                      principal: Principal.fromText(user.principal),
                    }).toHex();
                    navigator.clipboard.writeText(accountId);
                  }
                }}
                title="Copy Account ID"
              >
                <Copy className="h-3 w-3" />
              </Button>
            </div>
          </div>

          <div>
            <p className="text-sm font-medium mb-1">Wallet Provider</p>
            <Badge variant="outline" className="capitalize">
              {user?.provider}
            </Badge>
          </div>
        </CardContent>
      </Card>

      {/* Transfer Card - Placeholder */}
      <Card>
        <CardHeader>
          <CardTitle>Transfer ICP</CardTitle>
          <CardDescription>
            Send ICP to another account
          </CardDescription>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground text-sm">
            Transfer functionality coming soon. Use your wallet's built-in transfer feature for now.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
