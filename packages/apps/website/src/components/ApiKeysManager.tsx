import { useState } from 'react';
import { useMyApiKeys, useCreateApiKey, useRevokeApiKey, type ApiKeyMetadata } from '../hooks/useApiKeys';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from './ui/dialog';
import { Badge } from './ui/badge';
import { toast } from 'sonner';
import { Copy, Key, Trash2, Plus, RefreshCw, Eye, EyeOff } from 'lucide-react';

export function ApiKeysManager() {
  const { data: keys = [], isLoading: loading, error, refetch } = useMyApiKeys();
  const createMutation = useCreateApiKey();
  const revokeMutation = useRevokeApiKey();
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [showNewKeyDialog, setShowNewKeyDialog] = useState(false);
  const [showRevokeDialog, setShowRevokeDialog] = useState(false);
  const [keyToRevoke, setKeyToRevoke] = useState<{ id: string; name: string } | null>(null);
  const [newKeyName, setNewKeyName] = useState('');
  const [newApiKey, setNewApiKey] = useState('');
  const [revealedKeys, setRevealedKeys] = useState<Set<string>>(new Set());

  const handleCreateKey = async () => {
    if (!newKeyName.trim()) return;
    
    try {
      // Create key with all available scopes
      const rawKey = await createMutation.mutateAsync({ 
        name: newKeyName.trim(), 
        scopes: ['*'] 
      });
      setNewApiKey(rawKey);
      setShowCreateDialog(false);
      setShowNewKeyDialog(true);
      setNewKeyName('');
      toast.success('API key created successfully!');
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to create API key');
    }
  };

  const handleRevokeKey = async () => {
    if (!keyToRevoke) return;
    
    try {
      await revokeMutation.mutateAsync(keyToRevoke.id);
      setShowRevokeDialog(false);
      setKeyToRevoke(null);
      toast.success('API key revoked successfully');
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to revoke API key');
    }
  };

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text);
    toast.success(`${label} copied to clipboard`);
  };

  const toggleRevealKey = (keyId: string) => {
    setRevealedKeys(prev => {
      const next = new Set(prev);
      if (next.has(keyId)) {
        next.delete(keyId);
      } else {
        next.add(keyId);
      }
      return next;
    });
  };

  const formatDate = (nanos: bigint) => {
    const date = new Date(Number(nanos) / 1_000_000);
    return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  };

  const maskKey = (key: string) => {
    if (key.length < 12) return key;
    return `${key.slice(0, 8)}...${key.slice(-4)}`;
  };

  return (
    <>
      <Card className="border-2" style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 4px 16px rgba(0, 0, 0, 0.3), 0 0 15px rgba(197, 0, 34, 0.15)' }}>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="flex items-center gap-2">
                <Key className="h-5 w-5" />
                API Keys
              </CardTitle>
              <CardDescription>
                Manage API keys for MCP integration and external access
              </CardDescription>
            </div>
            <div className="flex gap-2">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => refetch()}
                disabled={loading}
              >
                <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
              </Button>
              <Button
                size="sm"
                onClick={() => setShowCreateDialog(true)}
                disabled={loading || createMutation.isPending}
              >
                <Plus className="h-4 w-4 mr-2" />
                Create Key
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {/* MCP Server Configuration - Always visible */}
          <div className="mb-6 p-5 border-2 rounded-lg space-y-4" style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(197, 0, 34, 0.05)' }}>
            <div className="flex items-center gap-2">
              <div className="p-2 rounded-md" style={{ backgroundColor: 'rgba(197, 0, 34, 0.2)' }}>
                <Key className="h-4 w-4" style={{ color: '#C50022' }} />
              </div>
              <div>
                <p className="text-sm font-semibold" style={{ color: '#C50022' }}>
                  MCP Server Configuration
                </p>
                <p className="text-xs text-muted-foreground">
                  Use these settings to connect your MCP client
                </p>
              </div>
            </div>
            <div className="space-y-3">
              <div>
                <Label className="text-xs font-medium text-muted-foreground mb-2 block">Header Name</Label>
                <div className="flex items-center gap-2">
                  <code className="flex-1 px-3 py-2 bg-background rounded-md border text-sm font-mono">
                    x-api-key
                  </code>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => copyToClipboard('x-api-key', 'Header name')}
                    className="shrink-0"
                  >
                    <Copy className="h-4 w-4" />
                  </Button>
                </div>
              </div>
              <div>
                <Label className="text-xs font-medium text-muted-foreground mb-2 block">MCP Server URL</Label>
                <div className="flex items-center gap-2">
                  <code className="flex-1 px-3 py-2 bg-background rounded-md border text-sm font-mono break-all">
                    https://{process.env.CANISTER_ID_PRESS}.icp0.io/mcp
                  </code>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => copyToClipboard(`https://${process.env.CANISTER_ID_PRESS}.icp0.io/mcp`, 'MCP URL')}
                    className="shrink-0"
                  >
                    <Copy className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </div>
          </div>

          {error && (
            <div className="p-4 bg-destructive/10 border border-destructive/30 rounded-lg mb-4">
              <p className="text-sm text-destructive">
                {error instanceof Error ? error.message : 'Failed to load API keys'}
              </p>
            </div>
          )}
          {loading ? (
            <div className="text-center py-8">
              <RefreshCw className="h-8 w-8 mx-auto mb-3 animate-spin text-muted-foreground" />
              <p className="text-muted-foreground">Loading API keys...</p>
            </div>
          ) : keys.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <Key className="h-12 w-12 mx-auto mb-3 opacity-20" />
              <p>No API keys yet</p>
              <p className="text-sm mt-1">Create a key to use with MCP tools and external integrations</p>
            </div>
          ) : (
            <div className="space-y-3">
              {keys.map((key: ApiKeyMetadata) => (
                <div
                  key={key.hashed_key}
                  className="flex items-center justify-between p-3 border rounded-lg hover:bg-accent/50 transition-colors"
                >
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-medium">{key.info.name}</span>
                      <Badge variant="outline" className="text-xs">
                        {key.info.scopes.join(', ')}
                      </Badge>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-muted-foreground">
                      <span>Created {formatDate(key.info.created)}</span>
                      <span>•</span>
                      <button
                        onClick={() => toggleRevealKey(key.hashed_key)}
                        className="flex items-center gap-1 hover:text-foreground transition-colors"
                        title="Key ID (for identification only - not the actual API key)"
                      >
                        {revealedKeys.has(key.hashed_key) ? (
                          <>
                            <EyeOff className="h-3 w-3" />
                            <span className="mr-1">Key ID:</span>
                            <code className="font-mono">{key.hashed_key}</code>
                          </>
                        ) : (
                          <>
                            <Eye className="h-3 w-3" />
                            <span className="mr-1">Key ID:</span>
                            <code className="font-mono">{maskKey(key.hashed_key)}</code>
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => {
                      setKeyToRevoke({ id: key.hashed_key, name: key.info.name });
                      setShowRevokeDialog(true);
                    }}
                    disabled={revokeMutation.isPending}
                  >
                    <Trash2 className="h-4 w-4 text-destructive" />
                  </Button>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Create Key Dialog */}
      <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Create New API Key</DialogTitle>
            <DialogDescription>
              Give your API key a descriptive name. The key will have full access to your account.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="key-name">Key Name</Label>
              <Input
                id="key-name"
                placeholder="e.g., MCP Claude Desktop, Production Bot"
                value={newKeyName}
                onChange={(e) => setNewKeyName(e.target.value)}
                maxLength={50}
              />
              <p className="text-xs text-muted-foreground">
                Choose a name that helps you identify where this key is used
              </p>
            </div>
          </div>
          <div className="flex gap-2">
            <Button
              onClick={handleCreateKey}
              disabled={createMutation.isPending || !newKeyName.trim()}
              className="flex-1"
            >
              {createMutation.isPending ? 'Creating...' : 'Create Key'}
            </Button>
            <Button
              variant="outline"
              onClick={() => setShowCreateDialog(false)}
              disabled={createMutation.isPending}
            >
              Cancel
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* New Key Display Dialog */}
      <Dialog open={showNewKeyDialog} onOpenChange={setShowNewKeyDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2" style={{ color: '#C50022' }}>
              <Key className="h-5 w-5" />
              Save Your API Key
            </DialogTitle>
            <DialogDescription>
              This is the only time you'll see this key. Copy it now and store it securely!
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="p-4 bg-muted rounded-lg space-y-3">
              <Label className="text-xs text-muted-foreground">Your New API Key</Label>
              <div className="flex items-center gap-2">
                <code className="flex-1 p-2 bg-background rounded border text-sm font-mono break-all">
                  {newApiKey}
                </code>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => copyToClipboard(newApiKey, 'API key')}
                >
                  <Copy className="h-4 w-4" />
                </Button>
              </div>
            </div>
            <div className="p-4 border-2 rounded-lg space-y-2" style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(197, 0, 34, 0.05)' }}>
              <p className="text-sm font-medium" style={{ color: '#C50022' }}>
                MCP Server Configuration
              </p>
              <div className="space-y-1">
                <p className="text-xs text-muted-foreground">Header Name:</p>
                <code className="block p-2 bg-background rounded border text-xs font-mono">
                  x-api-key
                </code>
              </div>
              <div className="space-y-1">
                <p className="text-xs text-muted-foreground">MCP Server URL:</p>
                <code className="block p-2 bg-background rounded border text-xs font-mono break-all">
                  https://{process.env.CANISTER_ID_PRESS}.icp0.io/mcp
                </code>
              </div>
            </div>
            <div className="p-3 border-2 rounded-lg" style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(197, 0, 34, 0.05)' }}>
              <p className="text-sm" style={{ color: '#C50022' }}>
                ⚠️ Make sure to copy this key now. You won't be able to see it again!
              </p>
            </div>
          </div>
          <Button onClick={() => setShowNewKeyDialog(false)} className="w-full">
            I've Saved My Key
          </Button>
        </DialogContent>
      </Dialog>

      {/* Revoke Key Confirmation Dialog */}
      <Dialog open={showRevokeDialog} onOpenChange={setShowRevokeDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="text-destructive">Revoke API Key</DialogTitle>
            <DialogDescription>
              Are you sure you want to revoke the API key "{keyToRevoke?.name}"? This action cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <div className="p-4 bg-destructive/10 border border-destructive/30 rounded-lg">
            <p className="text-sm text-destructive">
              ⚠️ Any applications or integrations using this key will immediately lose access.
            </p>
          </div>
          <div className="flex gap-2">
            <Button
              variant="destructive"
              onClick={handleRevokeKey}
              disabled={revokeMutation.isPending}
              className="flex-1"
            >
              {revokeMutation.isPending ? 'Revoking...' : 'Revoke Key'}
            </Button>
            <Button
              variant="outline"
              onClick={() => {
                setShowRevokeDialog(false);
                setKeyToRevoke(null);
              }}
              disabled={revokeMutation.isPending}
            >
              Cancel
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
