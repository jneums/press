import { useAuth } from '../hooks/useAuth';
import { useICPBalance, useTransferICP } from '../hooks/useLedger';
import { useWalletDrawer } from '../contexts/WalletDrawerContext';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { Button } from './ui/button';
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from './ui/sheet';
import { TransferICPDialog } from './TransferICPDialog';
import { AllowanceManager } from './AllowanceManager';
import { ApiKeysManager } from './ApiKeysManager';
import { AccountIdentifier } from '@icp-sdk/canisters/ledger/icp';
import { Principal } from '@icp-sdk/core/principal';
import { Copy, RefreshCw, Check, LogOut } from 'lucide-react';
import { useState } from 'react';

export function WalletDrawer() {
  const { user, logout } = useAuth();
  const [copiedPrincipal, setCopiedPrincipal] = useState(false);
  const [copiedAccount, setCopiedAccount] = useState(false);
  const { isOpen, closeDrawer } = useWalletDrawer();
  
  const { data: balance, isLoading: balanceLoading, refetch: refetchBalance } = useICPBalance();
  const transferICP = useTransferICP();

  const handleTransfer = async (to: string, amount: number) => {
    await transferICP.mutateAsync({ to, amount });
  };

  const copyPrincipal = () => {
    if (user?.principal) {
      navigator.clipboard.writeText(user.principal);
      setCopiedPrincipal(true);
      setTimeout(() => setCopiedPrincipal(false), 2000);
    }
  };

  const copyAccount = () => {
    if (user?.principal) {
      const accountId = AccountIdentifier.fromPrincipal({
        principal: Principal.fromText(user.principal),
      }).toHex();
      navigator.clipboard.writeText(accountId);
      setCopiedAccount(true);
      setTimeout(() => setCopiedAccount(false), 2000);
    }
  };

  return (
    <Sheet open={isOpen} onOpenChange={closeDrawer}>
      <SheetContent side="right" className="w-full sm:max-w-xl overflow-y-auto">
        <SheetHeader>
          <SheetTitle>Wallet & Account</SheetTitle>
          <SheetDescription>
            Manage your ICP balance, allowances, and API keys
          </SheetDescription>
        </SheetHeader>

        <div className="space-y-6 mt-6">
          {/* Wallet Section */}
          <Card className="border-2" style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 4px 16px rgba(0, 0, 0, 0.3), 0 0 15px rgba(197, 0, 34, 0.15)' }}>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle>ICP Balance</CardTitle>
                  <CardDescription>Your wallet balance</CardDescription>
                </div>
                <div className="flex items-center gap-2">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => refetchBalance()}
                    disabled={balanceLoading}
                  >
                    <RefreshCw className={`h-4 w-4 ${balanceLoading ? 'animate-spin' : ''}`} />
                  </Button>
                  <TransferICPDialog
                    onTransfer={handleTransfer}
                    maxBalance={balance ? Number(balance) / 100_000_000 : 0}
                  />
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                <div className="text-3xl font-bold">
                  {balance !== null && balance !== undefined 
                    ? (Number(balance) / 100_000_000).toFixed(8) 
                    : '—'}{' '}
                  <span className="text-lg text-muted-foreground">ICP</span>
                </div>
                <div className="text-xs text-muted-foreground">
                  {balance !== null && balance !== undefined 
                    ? `${balance.toString()} e8s` 
                    : 'Click refresh to load'}
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Account Details Section */}
          <Card className="border-2" style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 4px 16px rgba(0, 0, 0, 0.3), 0 0 15px rgba(197, 0, 34, 0.15)' }}>
            <CardHeader>
              <CardTitle>Account Details</CardTitle>
              <CardDescription>Your identity and receiving addresses</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {/* Principal ID */}
                <div>
                  <div className="text-sm font-medium text-muted-foreground mb-2">Principal ID</div>
                  <div className="flex items-center gap-2">
                    <code className="text-xs bg-muted px-3 py-2 rounded-md font-mono flex-1 truncate">
                      {user?.principal}
                    </code>
                    <Button
                      variant="outline"
                      size="sm"
                      className="h-9"
                      onClick={copyPrincipal}
                    >
                      {copiedPrincipal ? (
                        <Check className="h-4 w-4 text-green-600" />
                      ) : (
                        <Copy className="h-4 w-4" />
                      )}
                    </Button>
                  </div>
                </div>

                {/* Account ID */}
                <div>
                  <div className="text-sm font-medium text-muted-foreground mb-2">
                    Account ID <span className="text-xs font-normal">(for receiving)</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <code className="text-xs bg-muted px-3 py-2 rounded-md font-mono flex-1 truncate">
                      {user?.principal && AccountIdentifier.fromPrincipal({
                        principal: Principal.fromText(user.principal),
                      }).toHex()}
                    </code>
                    <Button
                      variant="outline"
                      size="sm"
                      className="h-9"
                      onClick={copyAccount}
                    >
                      {copiedAccount ? (
                        <Check className="h-4 w-4 text-green-600" />
                      ) : (
                        <Copy className="h-4 w-4" />
                      )}
                    </Button>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Allowance Manager */}
          <AllowanceManager />

          {/* API Keys Manager */}
          <ApiKeysManager />

          {/* Sign Out Button */}
          <div className="pt-4 border-t">
            <Button
              variant="destructive"
              className="w-full"
              onClick={() => {
                logout();
                closeDrawer();
              }}
            >
              <LogOut className="h-4 w-4 mr-2" />
              Sign Out
            </Button>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
