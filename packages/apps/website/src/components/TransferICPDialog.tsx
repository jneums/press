import { useState } from 'react';
import { Button } from './ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from './ui/dialog';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Send } from 'lucide-react';

interface TransferICPDialogProps {
  onTransfer: (to: string, amount: number) => Promise<void>;
  maxBalance: number;
}

export function TransferICPDialog({ onTransfer, maxBalance }: TransferICPDialogProps) {
  const [open, setOpen] = useState(false);
  const [to, setTo] = useState('');
  const [amount, setAmount] = useState('');
  const [isTransferring, setIsTransferring] = useState(false);
  const [error, setError] = useState('');

  const handleTransfer = async () => {
    setError('');
    
    if (!to.trim()) {
      setError('Please enter a recipient address');
      return;
    }

    const amountNum = parseFloat(amount);
    if (isNaN(amountNum) || amountNum <= 0) {
      setError('Please enter a valid amount');
      return;
    }

    if (amountNum > maxBalance) {
      setError(`Amount exceeds balance (${maxBalance.toFixed(8)} ICP)`);
      return;
    }

    setIsTransferring(true);
    try {
      await onTransfer(to, amountNum);
      setOpen(false);
      setTo('');
      setAmount('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Transfer failed');
    } finally {
      setIsTransferring(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" className="gap-2">
          <Send className="h-4 w-4" />
          Transfer
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle>Transfer ICP</DialogTitle>
          <DialogDescription>
            Send ICP to another address. Transfers are final and cannot be undone.
          </DialogDescription>
        </DialogHeader>
        <div className="grid gap-4 py-4">
          <div className="grid gap-2">
            <Label htmlFor="to">Recipient Address</Label>
            <Input
              id="to"
              placeholder="Principal ID or Account ID"
              value={to}
              onChange={(e) => setTo(e.target.value)}
              className="font-mono text-sm"
            />
            <p className="text-xs text-muted-foreground">
              Enter a principal ID or account identifier
            </p>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="amount">Amount (ICP)</Label>
            <div className="flex gap-2">
              <Input
                id="amount"
                type="number"
                step="0.00000001"
                min="0"
                max={maxBalance}
                placeholder="0.00000000"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="font-mono"
              />
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => setAmount(maxBalance.toFixed(8))}
              >
                Max
              </Button>
            </div>
            <p className="text-xs text-muted-foreground">
              Available: {maxBalance.toFixed(8)} ICP (fee: ~0.0001 ICP)
            </p>
          </div>
          {error && (
            <div className="text-sm text-destructive bg-destructive/10 p-3 rounded-md">
              {error}
            </div>
          )}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => setOpen(false)} disabled={isTransferring}>
            Cancel
          </Button>
          <Button onClick={handleTransfer} disabled={isTransferring}>
            {isTransferring ? 'Transferring...' : 'Send ICP'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
