import { useState } from 'react';
import { Button } from './ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { useAllowance, useSetAllowance } from '../hooks/useAllowance';
import { AlertCircle, CheckCircle2 } from 'lucide-react';
import { Alert, AlertDescription } from './ui/alert';

const PRESET_AMOUNTS = [10, 25, 100];

export function AllowanceManager() {
  const { data: currentAllowance, isLoading } = useAllowance();
  const setAllowance = useSetAllowance();
  const [customAmount, setCustomAmount] = useState('');
  const [showCustom, setShowCustom] = useState(false);

  const handleSetAllowance = async (amount: number) => {
    try {
      await setAllowance.mutateAsync(amount);
      setCustomAmount('');
      setShowCustom(false);
    } catch (error) {
      console.error('Failed to set allowance:', error);
    }
  };

  const handleCustomSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(customAmount);
    if (isNaN(amount) || amount <= 0) {
      return;
    }
    handleSetAllowance(amount);
  };

  return (
    <Card className="border-2" style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 4px 16px rgba(0, 0, 0, 0.3), 0 0 15px rgba(197, 0, 34, 0.15)' }}>
      <CardHeader>
        <CardTitle>Spending Allowance</CardTitle>
        <CardDescription>
          Pre-approve ICP for racing operations (entry fees, upgrades, recharge, repair)
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Current Allowance */}
        <div className="flex items-center justify-between p-3 bg-muted rounded-lg">
          <span className="text-sm font-medium">Current Allowance</span>
          <span className="text-lg font-bold">
            {isLoading ? '...' : `${currentAllowance?.toFixed(4) || '0.0000'} ICP`}
          </span>
        </div>

        {/* Status Alert */}
        {currentAllowance !== undefined && (
          <Alert variant={currentAllowance > 0 ? 'default' : 'destructive'}>
            {currentAllowance > 0 ? (
              <>
                <CheckCircle2 className="h-4 w-4" />
                <AlertDescription>
                  You can perform operations without additional approval prompts
                </AlertDescription>
              </>
            ) : (
              <>
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>
                  Set an allowance to enable seamless operations
                </AlertDescription>
              </>
            )}
          </Alert>
        )}

        {/* Preset Amounts */}
        <div className="space-y-2">
          <Label>Quick Set</Label>
          <div className="grid grid-cols-3 gap-2">
            {PRESET_AMOUNTS.map((amount) => (
              <Button
                key={amount}
                variant="outline"
                onClick={() => handleSetAllowance(amount)}
                disabled={setAllowance.isPending}
              >
                {amount} ICP
              </Button>
            ))}
          </div>
        </div>

        {/* Custom Amount */}
        {!showCustom ? (
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setShowCustom(true)}
            className="w-full"
          >
            Set Custom Amount
          </Button>
        ) : (
          <form onSubmit={handleCustomSubmit} className="space-y-2">
            <Label htmlFor="custom-amount">Custom Amount (ICP)</Label>
            <div className="flex gap-2">
              <Input
                id="custom-amount"
                type="number"
                step="0.01"
                min="0.01"
                placeholder="Enter amount"
                value={customAmount}
                onChange={(e) => setCustomAmount(e.target.value)}
                disabled={setAllowance.isPending}
              />
              <Button
                type="submit"
                disabled={setAllowance.isPending || !customAmount}
              >
                Set
              </Button>
              <Button
                type="button"
                variant="ghost"
                onClick={() => {
                  setShowCustom(false);
                  setCustomAmount('');
                }}
                disabled={setAllowance.isPending}
              >
                Cancel
              </Button>
            </div>
          </form>
        )}

        {setAllowance.isError && (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              {setAllowance.error instanceof Error
                ? setAllowance.error.message
                : 'Failed to set allowance'}
            </AlertDescription>
          </Alert>
        )}
      </CardContent>
    </Card>
  );
}
