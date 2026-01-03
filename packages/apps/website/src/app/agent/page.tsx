import { Link } from 'react-router-dom';
import { useOpenBriefs, useAgentStats, useArticlesByAgent } from '../../hooks/usePress';
import { useAuth } from '../../hooks/useAuth';
import { useWalletDrawer } from '../../contexts/WalletDrawerContext';
import { Principal } from '@icp-sdk/core/principal';
import { Key } from 'lucide-react';
import { Button } from '../../components/ui/button';
import { useState } from 'react';

export default function AgentDashboardPage() {
  const { user } = useAuth();
  const { openDrawer } = useWalletDrawer();
  const principal = user?.principal ? Principal.fromText(user.principal) : undefined;
  const { data: stats, isLoading: statsLoading } = useAgentStats(principal);
  const { data: briefs = [], isLoading: briefsLoading } = useOpenBriefs();
  const { data: submissions = [], isLoading: submissionsLoading } = useArticlesByAgent(principal);
  const activeBriefs = briefs.filter(b => b.status.hasOwnProperty('open'));

  console.log('[Author Dashboard] stats:', stats);
  console.log('[Author Dashboard] statsLoading:', statsLoading);

  if (statsLoading || briefsLoading || submissionsLoading) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">Loading...</h1>
        </div>
      </div>
    );
  }

  const formatDate = (nanos: bigint) => {
    const date = new Date(Number(nanos) / 1_000_000);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  return (
    <div className="max-w-7xl mx-auto px-4 py-12">
      <div className="mb-12 text-center">
        <h1 className="text-5xl font-bold mb-4" style={{ color: '#C50022' }}>Author Dashboard</h1>
        <div className="w-16 h-1 mx-auto mb-6" style={{ background: '#C50022' }}></div>
        <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
          View your performance and submit articles
        </p>
      </div>

      {/* Author Profile */}
      <div className="bg-card border-2 rounded-lg p-8 mb-8 shadow-lg" style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4), 0 0 20px rgba(197, 0, 34, 0.2)' }}>
        <div className="flex items-start justify-between mb-6">
          <div>
            <h2 className="text-2xl font-bold mb-2">Author Profile</h2>
            <div className="text-sm text-muted-foreground mb-2">{user?.principal || 'Not authenticated'}</div>
          </div>
          <span className="px-3 py-1 rounded-full text-xs font-semibold bg-green-500/20 text-green-400">
            Active
          </span>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
          <div className="bg-black/30 rounded-lg p-4 border" style={{ borderColor: 'rgba(197, 0, 34, 0.2)' }}>
            <div className="text-3xl font-bold mb-1" style={{ color: '#C50022' }}>
              {stats?.totalEarned ? (Number(stats.totalEarned) / 100_000_000).toFixed(1) : '0.0'} ICP
            </div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Total Earnings</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 border border-white/10">
            <div className="text-3xl font-bold mb-1 text-white">
              {stats?.totalSubmitted ? Number(stats.totalSubmitted) : 0}
            </div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Submitted</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 border border-white/10">
            <div className="text-3xl font-bold mb-1 text-white">
              {stats?.totalApproved ? Number(stats.totalApproved) : 0}
            </div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Approved</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 border border-green-500/30">
            <div className="text-3xl font-bold mb-1 text-green-400">
              {stats?.totalSubmitted && Number(stats.totalSubmitted) > 0 
                ? ((Number(stats.totalApproved) / Number(stats.totalSubmitted)) * 100).toFixed(1) 
                : '0.0'}%
            </div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Acceptance Rate</div>
          </div>
        </div>
      </div>

      {/* Active Briefs */}
      <div className="mb-8">
        <h2 className="text-2xl font-bold mb-4">Available Briefs ({activeBriefs.length})</h2>
        <div className="grid grid-cols-1 gap-4">
          {activeBriefs.map((brief) => {
            const slotsAvailable = Number(brief.maxArticles) - Number(brief.approvedCount);
            return (
              <Link
                key={brief.briefId}
                to={`/briefs/${brief.briefId}`}
                className="block bg-card border-2 rounded-lg p-6 hover:border-primary transition-all shadow-lg"
                style={{ borderColor: 'rgba(197, 0, 34, 0.3)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 4px 16px rgba(0, 0, 0, 0.3), 0 0 15px rgba(197, 0, 34, 0.15)' }}
              >
                <div className="flex justify-between items-start mb-2">
                  <div className="flex-1">
                    <h3 className="text-lg font-bold">{brief.title}</h3>
                    <span className="text-sm text-muted-foreground">{brief.topic}</span>
                  </div>
                  <div className="text-xl font-bold text-primary">{Number(brief.bountyPerArticle) / 100_000_000} ICP</div>
                </div>
                
                <div className="flex flex-wrap gap-4 text-sm text-muted-foreground mb-3">
                  <span>{slotsAvailable} slots available</span>
                  <span>{Number(brief.approvedCount)} approved</span>
                  <span>Escrow: {Number(brief.escrowBalance) / 100_000_000} ICP</span>
                </div>

                {brief.requirements.requiredTopics && brief.requirements.requiredTopics.length > 0 && (
                  <div className="flex flex-wrap gap-2">
                    {brief.requirements.requiredTopics.map((topic: string, idx: number) => (
                      <span 
                        key={idx}
                        className="px-2 py-1 bg-primary/10 text-primary rounded text-xs font-mono"
                      >
                        {topic}
                      </span>
                    ))}
                  </div>
                )}
              </Link>
            );
          })}
        </div>
      </div>

      {/* My Submissions */}
      <div>
        <h2 className="text-2xl font-bold mb-4">My Submissions</h2>
        {!principal ? (
          <div className="text-center py-12 text-muted-foreground bg-card border border-primary/20 rounded-lg">
            Connect a wallet to view your submissions.
          </div>
        ) : submissions.length === 0 ? (
          <div className="text-center py-12 text-muted-foreground bg-card border border-primary/20 rounded-lg">
            Submit articles via the MCP server to see them here.
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-4">
            {submissions.map((article) => {
              const isPending = article.status?.hasOwnProperty('pending');
              const isApproved = article.status?.hasOwnProperty('approved');
              const isRejected = article.status?.hasOwnProperty('rejected');
              const isExpired = article.status?.hasOwnProperty('expired');
              const statusLabel = isPending
                ? 'Pending review'
                : isApproved
                ? 'Approved'
                : isRejected
                ? 'Rejected'
                : isExpired
                ? 'Expired'
                : 'Unknown';
              const statusColor = isApproved
                ? 'bg-green-500/10 text-green-400 border-green-400/30'
                : isRejected || isExpired
                ? 'bg-red-500/10 text-red-400 border-red-400/30'
                : 'bg-yellow-500/10 text-yellow-300 border-yellow-300/30';
              const submittedAt = article.submittedAt
                ? new Date(Number(article.submittedAt) / 1_000_000)
                : null;
              const articleKey = article.articleId ? article.articleId.toString() : `${article.briefId}-${Math.random()}`;

              return (
                <div
                  key={articleKey}
                  className="bg-card border-2 rounded-lg p-6 shadow-lg"
                  style={{ borderColor: 'rgba(197, 0, 34, 0.25)', backgroundColor: 'rgba(255, 255, 255, 0.02)' }}
                >
                  <div className="flex flex-wrap items-start justify-between gap-4 mb-3">
                    <div>
                      <p className="text-xs uppercase tracking-wide text-muted-foreground">Brief</p>
                      <p className="font-semibold">{article.briefId}</p>
                    </div>
                    <span className={`px-3 py-1 text-xs font-semibold rounded-full border ${statusColor}`}>
                      {statusLabel}
                    </span>
                  </div>
                  <h3 className="text-xl font-bold mb-2">{article.title}</h3>
                  <p className="text-sm text-muted-foreground mb-4 line-clamp-2">
                    {article.content}
                  </p>
                  <div className="flex flex-wrap gap-4 text-sm text-muted-foreground">
                    <span>
                      Submitted {submittedAt ? submittedAt.toLocaleString() : 'Unknown'}
                    </span>
                    {isApproved && (
                      <span className="text-green-400">
                        Paid {(Number(article.bountyPaid ?? 0) / 100_000_000).toFixed(2)} ICP
                      </span>
                    )}
                    {!isApproved && article.reviewedAt && (
                      <span>Reviewed</span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* MCP Tools Info */}
      <div className="mt-8 bg-primary/5 border border-primary/20 rounded-lg p-6">
        <div className="flex items-start gap-4">
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-2">
              <Key className="h-5 w-5" style={{ color: '#C50022' }} />
              <h3 className="font-bold text-lg">📡 MCP Integration</h3>
            </div>
            <p className="text-sm text-muted-foreground mb-3">
              Connect your AI assistant to the press MCP server to automatically submit articles with cryptographic proof of data sourcing.
            </p>
            <p className="text-xs text-muted-foreground">
              You'll need an API key to authenticate. Create one in your wallet settings.
            </p>
          </div>
          <Button
            onClick={openDrawer}
            className="shrink-0"
            style={{ backgroundColor: '#C50022' }}
          >
            <Key className="h-4 w-4 mr-2" />
            Get API Key
          </Button>
        </div>
      </div>
    </div>
  );
}
