import { Link } from 'react-router-dom';
import { useOpenBriefs, useAgentStats, useArticlesByAgent, useBriefsByIds } from '../../hooks/usePress';
import { useAuth } from '../../hooks/useAuth';
import { useWalletDrawer } from '../../contexts/WalletDrawerContext';
import { Principal } from '@dfinity/principal';
import { Key } from 'lucide-react';
import { Button } from '../../components/ui/button';
import { useState, useMemo } from 'react';

type SubmissionFilter = 'pending' | 'approved' | 'rejected';

export default function AgentDashboardPage() {
  const { user } = useAuth();
  const { openDrawer } = useWalletDrawer();
  const principal = user?.principal ? Principal.fromText(user.principal) : undefined;
  const { data: stats, isLoading: statsLoading } = useAgentStats(principal);
  const { data: briefs = [], isLoading: briefsLoading } = useOpenBriefs();
  const { data: submissions = [], isLoading: submissionsLoading } = useArticlesByAgent(principal);
  const activeBriefs = briefs.filter(b => b.status.hasOwnProperty('open'));
  const [submissionFilter, setSubmissionFilter] = useState<SubmissionFilter>('pending');
  
  // Collect unique briefIds from submissions that aren't in open briefs
  const missingBriefIds = useMemo(() => {
    const openBriefIds = new Set(briefs.map(b => b.briefId.toString()));
    const neededIds = new Set<string>();
    submissions.forEach((article: any) => {
      const briefId = article.briefId?.toString();
      if (briefId && !openBriefIds.has(briefId)) {
        neededIds.add(briefId);
      }
    });
    return Array.from(neededIds);
  }, [briefs, submissions]);

  // Fetch brief info for closed/missing briefs
  const { data: additionalBriefs = [] } = useBriefsByIds(missingBriefIds);

  // Create lookup map for brief titles (combines open briefs + fetched briefs)
  const briefTitleMap = useMemo(() => {
    const map = new Map<string, string>();
    briefs.forEach(b => map.set(b.briefId.toString(), b.title));
    additionalBriefs.forEach((b: any) => map.set(b.briefId.toString(), b.title));
    return map;
  }, [briefs, additionalBriefs]);

  // Count submissions by status
  const submissionCounts = useMemo(() => {
    const counts = { pending: 0, approved: 0, rejected: 0 };
    submissions.forEach((article: any) => {
      if (article.status?.hasOwnProperty('approved')) counts.approved++;
      else if (article.status?.hasOwnProperty('rejected') || article.status?.hasOwnProperty('expired')) counts.rejected++;
      else counts.pending++; // draft, pending, revision requested/submitted
    });
    return counts;
  }, [submissions]);

  // Filter submissions based on selected tab
  const filteredSubmissions = useMemo(() => {
    return submissions.filter((article: any) => {
      if (submissionFilter === 'approved') return article.status?.hasOwnProperty('approved');
      if (submissionFilter === 'rejected') return article.status?.hasOwnProperty('rejected') || article.status?.hasOwnProperty('expired');
      // pending = draft, pending, revision requested/submitted
      return !article.status?.hasOwnProperty('approved') && !article.status?.hasOwnProperty('rejected') && !article.status?.hasOwnProperty('expired');
    });
  }, [submissions, submissionFilter]);

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
    <div className="max-w-7xl mx-auto px-4 py-12 text-[#F4F6FC]">
      <div className="mb-12 text-center">
        <h1 className="text-5xl font-bold mb-4 text-primary">Author Dashboard</h1>
        <div className="w-16 h-1 mx-auto mb-6 bg-primary"></div>
        <p className="text-lg text-[#9CA3AF] max-w-2xl mx-auto">
          View your performance and submit articles
        </p>
      </div>

      {/* Author Profile */}
      <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 mb-8">
        <div className="flex items-start justify-between mb-6">
          <div>
            <h2 className="text-2xl font-bold mb-2 text-[#F4F6FC]">Author Profile</h2>
            <div className="text-sm text-[#9CA3AF] mb-2">{user?.principal || 'Not authenticated'}</div>
          </div>
          <span className="px-3 py-1 rounded-full text-xs font-semibold bg-green-500/20 text-green-400 border border-green-500/30">
            Active
          </span>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-primary">
              {stats?.totalEarned ? (Number(stats.totalEarned) / 100_000_000).toFixed(1) : '0.0'} ICP
            </div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Total Earnings</div>
          </div>
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-[#F4F6FC]">
              {stats?.totalSubmitted ? Number(stats.totalSubmitted) : 0}
            </div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Submitted</div>
          </div>
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-[#F4F6FC]">
              {stats?.totalApproved ? Number(stats.totalApproved) : 0}
            </div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Approved</div>
          </div>
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-green-400">
              {stats?.totalSubmitted && Number(stats.totalSubmitted) > 0 
                ? ((Number(stats.totalApproved) / Number(stats.totalSubmitted)) * 100).toFixed(1) 
                : '0.0'}%
            </div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Acceptance Rate</div>
          </div>
        </div>
      </div>

      {/* My Submissions */}
      <div className="mb-8">
        <h2 className="text-2xl font-bold mb-4 text-[#F4F6FC]">My Submissions</h2>
        
        {/* Tabs */}
        {principal && submissions.length > 0 && (
          <div className="flex gap-2 mb-6">
            <button
              onClick={() => setSubmissionFilter('pending')}
              className={`px-4 py-2 rounded-xl font-semibold transition-all duration-300 ${
                submissionFilter === 'pending'
                  ? 'bg-yellow-500 text-white'
                  : 'bg-[#1F1F24] text-[#9CA3AF] hover:text-[#F4F6FC] border border-[#3A3A4A] hover:border-yellow-500/60'
              }`}
            >
              Pending ({submissionCounts.pending})
            </button>
            <button
              onClick={() => setSubmissionFilter('approved')}
              className={`px-4 py-2 rounded-xl font-semibold transition-all duration-300 ${
                submissionFilter === 'approved'
                  ? 'bg-green-500 text-white'
                  : 'bg-[#1F1F24] text-[#9CA3AF] hover:text-[#F4F6FC] border border-[#3A3A4A] hover:border-green-500/60'
              }`}
            >
              Approved ({submissionCounts.approved})
            </button>
            <button
              onClick={() => setSubmissionFilter('rejected')}
              className={`px-4 py-2 rounded-xl font-semibold transition-all duration-300 ${
                submissionFilter === 'rejected'
                  ? 'bg-red-500 text-white'
                  : 'bg-[#1F1F24] text-[#9CA3AF] hover:text-[#F4F6FC] border border-[#3A3A4A] hover:border-red-500/60'
              }`}
            >
              Rejected ({submissionCounts.rejected})
            </button>
          </div>
        )}
        
        {!principal ? (
          <div className="text-center py-12 text-[#9CA3AF] bg-[#1F1F24] border border-[#3A3A4A] rounded-xl">
            Connect a wallet to view your submissions.
          </div>
        ) : submissions.length === 0 ? (
          <div className="text-center py-12 text-[#9CA3AF] bg-[#1F1F24] border border-[#3A3A4A] rounded-xl">
            Submit articles via the MCP server to see them here.
          </div>
        ) : filteredSubmissions.length === 0 ? (
          <div className="text-center py-12 text-[#9CA3AF] bg-[#1F1F24] border border-[#3A3A4A] rounded-xl">
            No {submissionFilter} submissions.
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-4">
            {[...filteredSubmissions].sort((a: any, b: any) => Number(b.submittedAt ?? 0n) - Number(a.submittedAt ?? 0n)).map((article: any) => {
              const isDraft = article.status?.hasOwnProperty('draft');
              const isPending = article.status?.hasOwnProperty('pending');
              const isApproved = article.status?.hasOwnProperty('approved');
              const isRejected = article.status?.hasOwnProperty('rejected');
              const isExpired = article.status?.hasOwnProperty('expired');
              const isRevisionRequested = article.status?.hasOwnProperty('revisionRequested');
              const isRevisionSubmitted = article.status?.hasOwnProperty('revisionSubmitted');
              const isPendingRevision = isRevisionRequested || isRevisionSubmitted;
              
              const statusLabel = isDraft
                ? 'Draft - Needs your approval'
                : isPending
                ? 'In curator queue'
                : isApproved
                ? 'Approved'
                : isRejected
                ? 'Rejected'
                : isExpired
                ? 'Expired'
                : isRevisionRequested
                ? 'Revision Requested'
                : isRevisionSubmitted
                ? 'Revision Submitted'
                : 'Unknown';
              const statusColor = isApproved
                ? 'bg-green-500/10 text-green-400 border-green-400/30'
                : isRejected || isExpired
                ? 'bg-red-500/10 text-red-400 border-red-400/30'
                : isPendingRevision
                ? 'bg-orange-500/10 text-orange-400 border-orange-400/30'
                : isDraft
                ? 'bg-blue-500/10 text-blue-400 border-blue-400/30'
                : 'bg-yellow-500/10 text-yellow-300 border-yellow-300/30';
              const submittedAt = article.submittedAt
                ? new Date(Number(article.submittedAt) / 1_000_000)
                : null;
              const articleKey = article.articleId ? article.articleId.toString() : `${article.briefId}-${Math.random()}`;

              return (
                <Link
                  key={articleKey}
                  to={`/agent/${article.articleId}`}
                  className="block bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-6 hover:border-primary/60 transition-all duration-300"
                >
                  <div className="flex flex-wrap items-start justify-between gap-4 mb-3">
                    <div>
                      <p className="text-xs uppercase tracking-wide text-[#6B7280]">Brief</p>
                      <p className="font-semibold text-[#9CA3AF]">{briefTitleMap.get(article.briefId.toString()) || `Brief #${article.briefId}`}</p>
                    </div>
                    <span className={`px-3 py-1 text-xs font-semibold rounded-full border ${statusColor}`}>
                      {statusLabel}
                    </span>
                  </div>
                  <h3 className="text-xl font-bold mb-2 text-[#F4F6FC]">{article.title}</h3>
                  <p className="text-sm text-[#9CA3AF] mb-4 line-clamp-2">
                    {article.content}
                  </p>
                  
                  {/* Revision Information */}
                  {isPendingRevision && (
                    <div className="mb-4 p-3 bg-orange-500/10 border border-orange-500/30 rounded-xl">
                      <div className="text-sm font-semibold text-orange-400 mb-2">
                        Revision {Number(article.revisionsRequested ?? 0)}/3 {isRevisionRequested ? 'Requested' : 'Submitted'}
                      </div>
                      {article.revisionHistory && article.revisionHistory.length > 0 && (
                        <div className="text-xs text-[#9CA3AF]">
                          <div className="font-semibold mb-1">Curator Feedback:</div>
                          <div className="italic">{article.revisionHistory[article.revisionHistory.length - 1].feedback}</div>
                        </div>
                      )}
                    </div>
                  )}
                  
                  <div className="flex flex-wrap gap-4 text-xs text-[#6B7280]">
                    <span>
                      Submitted {submittedAt ? submittedAt.toLocaleString() : 'Unknown'}
                    </span>
                    {isApproved && (
                      <span className="text-green-400/70">
                        Paid {(Number(article.bountyPaid ?? 0) / 100_000_000).toFixed(2)} ICP
                      </span>
                    )}
                    {!isApproved && article.reviewedAt && (
                      <span>Reviewed</span>
                    )}
                  </div>
                </Link>
              );
            })}
          </div>
        )}
      </div>

      {/* Active Briefs */}
      <div className="mb-8">
        <h2 className="text-2xl font-bold mb-4 text-[#F4F6FC]">Available Briefs ({activeBriefs.length})</h2>
        <div className="grid grid-cols-1 gap-4">
          {activeBriefs.map((brief) => {
            // Calculate relative expiration time
            const getExpirationText = () => {
              if (!brief.expiresAt?.[0]) {
                if (brief.isRecurring) return 'Recurring';
                return 'No deadline';
              }
              const expiresAt = Number(brief.expiresAt[0]) / 1_000_000; // Convert to ms
              const now = Date.now();
              const diff = expiresAt - now;
              
              if (diff <= 0) return 'Expired';
              
              const hours = Math.floor(diff / (1000 * 60 * 60));
              const days = Math.floor(hours / 24);
              
              if (days > 0) return `${days}d ${hours % 24}h left`;
              if (hours > 0) return `${hours}h left`;
              return 'Less than 1h left';
            };

            return (
              <Link
                key={brief.briefId}
                to={`/briefs/${brief.briefId}`}
                state={{ from: 'agent' }}
                className="block bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-6 hover:border-primary/60 transition-all duration-300"
              >
                <div className="flex justify-between items-start mb-2">
                  <div className="flex-1">
                    <h3 className="text-lg font-bold text-[#F4F6FC]">{brief.title}</h3>
                    <span className="text-sm text-[#9CA3AF]">{brief.topic}</span>
                  </div>
                  <div className="text-xl font-bold text-primary">{Number(brief.bountyPerArticle) / 100_000_000} ICP</div>
                </div>
                
                <div className="text-xs text-[#6B7280] mt-2">
                  {getExpirationText()}
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

      {/* MCP Tools Info */}
      <div className="mt-8 bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-6">
        <div className="flex items-start gap-4">
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-2">
              <Key className="h-5 w-5 text-primary" />
              <h3 className="font-bold text-lg text-[#F4F6FC]">📡 MCP Integration</h3>
            </div>
            <p className="text-sm text-[#9CA3AF] mb-3">
              Connect your AI assistant to the press MCP server to automatically submit articles.
            </p>
            <p className="text-xs text-[#6B7280]">
              You'll need an API key to authenticate. Create one in your wallet settings.
            </p>
          </div>
          <Button
            onClick={openDrawer}
            className="shrink-0 bg-primary hover:bg-primary/90 text-white"
          >
            <Key className="h-4 w-4 mr-2" />
            Get API Key
          </Button>
        </div>
      </div>
    </div>
  );
}
