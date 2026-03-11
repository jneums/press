import { Link } from 'react-router-dom';
import { useTriageArticles, useArchivedArticles, useMyBriefs, useBriefsByIds } from '../../hooks/usePress';
import { useState, useMemo } from 'react';
import { CreateBriefDialog } from '../../components/CreateBriefDialog';
import { RefreshCw, ChevronLeft, ChevronRight } from 'lucide-react';

const BRIEFS_PER_PAGE = 6;

export default function CuratorDashboardPage() {
  const [filter, setFilter] = useState<'pending' | 'approved' | 'rejected'>('pending');
  const [briefsPage, setBriefsPage] = useState(0);
  
  const { data: triageArticles = [], isLoading: triageLoading, error: triageError, refetch: refetchTriage, isFetching: triageFetching } = useTriageArticles();
  const { data: approvedData, isLoading: approvedLoading, refetch: refetchApproved, isFetching: approvedFetching } = useArchivedArticles(0n, 50n, 'approved');
  const { data: rejectedData, isLoading: rejectedLoading, refetch: refetchRejected, isFetching: rejectedFetching } = useArchivedArticles(0n, 50n, 'rejected');
  const { data: myBriefs = [], isLoading: briefsLoading, refetch: refetchMyBriefs, isFetching: briefsFetching } = useMyBriefs();

  // Combine all articles to find unique briefIds
  const allArticles = useMemo(() => {
    return [
      ...triageArticles,
      ...(approvedData?.articles || []),
      ...(rejectedData?.articles || [])
    ];
  }, [triageArticles, approvedData?.articles, rejectedData?.articles]);

  // Collect unique briefIds not in myBriefs
  const missingBriefIds = useMemo(() => {
    const myBriefIds = new Set(myBriefs.map((b: any) => b.briefId.toString()));
    const neededIds = new Set<string>();
    allArticles.forEach((article: any) => {
      const briefId = article.briefId?.toString();
      if (briefId && !myBriefIds.has(briefId)) {
        neededIds.add(briefId);
      }
    });
    return Array.from(neededIds);
  }, [myBriefs, allArticles]);

  // Fetch brief info for missing briefs
  const { data: additionalBriefs = [] } = useBriefsByIds(missingBriefIds);

  // Create lookup map for brief titles
  const briefTitleMap = useMemo(() => {
    const map = new Map<string, string>();
    myBriefs.forEach((b: any) => map.set(b.briefId.toString(), b.title));
    additionalBriefs.forEach((b: any) => map.set(b.briefId.toString(), b.title));
    return map;
  }, [myBriefs, additionalBriefs]);

  const isFetching = triageFetching || approvedFetching || rejectedFetching || briefsFetching;

  const handleRefresh = () => {
    refetchTriage();
    refetchApproved();
    refetchRejected();
    refetchMyBriefs();
  };

  const pendingCount = triageArticles.length;
  const approvedCount = approvedData?.total ? Number(approvedData.total) : 0;
  const rejectedCount = rejectedData?.total ? Number(rejectedData.total) : 0;

  // Select articles based on filter
  const articles = filter === 'pending' 
    ? triageArticles 
    : filter === 'approved'
    ? (approvedData?.articles || [])
    : (rejectedData?.articles || []);

  const isLoading = triageLoading || approvedLoading || rejectedLoading;

  if (isLoading && articles.length === 0) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">Loading...</h1>
        </div>
      </div>
    );
  }

  if (triageError) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">Error loading articles</h1>
          <p className="text-muted-foreground">{triageError.message}</p>
        </div>
      </div>
    );
  }

  const formatDate = (nanos: bigint) => {
    const date = new Date(Number(nanos) / 1_000_000);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    });
  };

  const getStatusLabel = (article: any) => {
    if (article.status?.hasOwnProperty('revisionRequested')) {
      return 'Revision Requested';
    }
    if (article.status?.hasOwnProperty('revisionSubmitted')) {
      return 'Revision Submitted';
    }
    if (article.status?.hasOwnProperty('pending')) {
      return 'Pending';
    }
    if (article.status?.hasOwnProperty('approved')) {
      return 'Approved';
    }
    if (article.status?.hasOwnProperty('rejected')) {
      return 'Rejected';
    }
    return 'Unknown';
  };

  return (
    <div className="max-w-7xl mx-auto px-4 py-12 text-[#F4F6FC]">
      <div className="mb-12 text-center">
        <div className="flex items-center justify-center gap-4 mb-4">
          <h1 className="text-5xl font-bold text-primary">Curator Dashboard</h1>
          <button
            onClick={handleRefresh}
            disabled={isFetching}
            className="p-2 rounded-xl bg-[#1F1F24] border border-[#3A3A4A] hover:border-primary/60 transition-all disabled:opacity-50"
            title="Refresh all"
          >
            <RefreshCw className={`w-5 h-5 ${isFetching ? 'animate-spin' : ''}`} />
          </button>
          <CreateBriefDialog />
        </div>
        <div className="w-16 h-1 mx-auto mb-6 bg-primary"></div>
        <p className="text-lg text-[#9CA3AF] max-w-2xl mx-auto">
          Review and approve submitted articles
        </p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-6">
          <div className="text-3xl font-bold mb-2 text-blue-400">{pendingCount}</div>
          <div className="text-sm text-[#9CA3AF] uppercase tracking-wide">Pending Review</div>
        </div>
        <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-6">
          <div className="text-3xl font-bold mb-2 text-green-400">{approvedCount}</div>
          <div className="text-sm text-[#9CA3AF] uppercase tracking-wide">Approved</div>
        </div>
        <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-6">
          <div className="text-3xl font-bold mb-2 text-red-400">{rejectedCount}</div>
          <div className="text-sm text-[#9CA3AF] uppercase tracking-wide">Rejected</div>
        </div>
        <div className="bg-[#1F1F24] border border-purple-500/30 rounded-xl p-6">
          <div className="text-3xl font-bold mb-2 text-purple-400">{myBriefs.length}</div>
          <div className="text-sm text-[#9CA3AF] uppercase tracking-wide">My Briefs</div>
        </div>
      </div>

      {/* My Briefs Section - Always visible */}
      {(() => {
        const totalPages = Math.ceil(myBriefs.length / BRIEFS_PER_PAGE);
        const paginatedBriefs = myBriefs.slice(
          briefsPage * BRIEFS_PER_PAGE,
          (briefsPage + 1) * BRIEFS_PER_PAGE
        );
        
        return (
          <div className="mb-8 p-6 bg-[#1F1F24] border border-purple-500/30 rounded-xl">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-2xl font-bold text-purple-400">My Briefs</h2>
              {totalPages > 1 && (
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setBriefsPage(p => Math.max(0, p - 1))}
                    disabled={briefsPage === 0}
                    className="p-2 rounded-lg bg-[#181A20] border border-[#3A3A4A] hover:border-purple-500/60 disabled:opacity-40 disabled:cursor-not-allowed transition-all"
                  >
                    <ChevronLeft className="w-4 h-4" />
                  </button>
                  <span className="text-sm text-[#9CA3AF] px-2">
                    {briefsPage + 1} / {totalPages}
                  </span>
                  <button
                    onClick={() => setBriefsPage(p => Math.min(totalPages - 1, p + 1))}
                    disabled={briefsPage >= totalPages - 1}
                    className="p-2 rounded-lg bg-[#181A20] border border-[#3A3A4A] hover:border-purple-500/60 disabled:opacity-40 disabled:cursor-not-allowed transition-all"
                  >
                    <ChevronRight className="w-4 h-4" />
                  </button>
                </div>
              )}
            </div>
            {briefsLoading ? (
              <p className="text-[#9CA3AF]">Loading...</p>
            ) : myBriefs.length === 0 ? (
              <p className="text-[#9CA3AF]">You haven't created any briefs yet. Click "Create Brief" above to get started.</p>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {paginatedBriefs.map((brief: any) => {
                  const isOpen = brief.status?.hasOwnProperty('open');
                  const isClosed = brief.status?.hasOwnProperty('closed');
                  const slotsAvailable = Number(brief.maxArticles) - Number(brief.approvedCount);
                  
                  return (
                    <Link
                      key={brief.briefId}
                      to={`/briefs/${brief.briefId}`}
                      state={{ from: 'curator' }}
                      className="block p-4 bg-[#181A20] border border-[#3A3A4A] rounded-xl hover:border-purple-500/50 transition-all"
                    >
                      <div className="flex justify-between items-start mb-2">
                        <h3 className="font-semibold text-lg text-[#F4F6FC]">{brief.title}</h3>
                        <span className={`px-2 py-1 rounded text-xs font-semibold ${
                          isOpen ? 'bg-green-500/20 text-green-400' :
                          isClosed ? 'bg-gray-500/20 text-gray-400' :
                          'bg-red-500/20 text-red-400'
                        }`}>
                          {isOpen ? 'Open' : isClosed ? 'Closed' : 'Cancelled'}
                        </span>
                      </div>
                      <div className="text-sm text-[#9CA3AF] mb-2">{brief.topic}</div>
                      <div className="flex gap-4 text-xs text-[#6B7280]">
                        <span>{Number(brief.bountyPerArticle) / 100_000_000} ICP/article</span>
                        <span>{slotsAvailable}/{Number(brief.maxArticles)} slots</span>
                        <span>{Number(brief.escrowBalance) / 100_000_000} ICP escrowed</span>
                      </div>
                    </Link>
                  );
                })}
              </div>
            )}
          </div>
        );
      })()}

      {/* Filter Buttons */}
      <div className="flex gap-2 mb-6">
        <button
          onClick={() => setFilter('pending')}
          className={`px-4 py-2 rounded-xl font-semibold transition-all duration-300 ${
            filter === 'pending'
              ? 'bg-yellow-500 text-white'
              : 'bg-[#1F1F24] text-[#9CA3AF] hover:text-[#F4F6FC] border border-[#3A3A4A] hover:border-yellow-500/60'
          }`}
        >
          Pending ({pendingCount})
        </button>
        <button
          onClick={() => setFilter('approved')}
          className={`px-4 py-2 rounded-xl font-semibold transition-all duration-300 ${
            filter === 'approved'
              ? 'bg-green-500 text-white'
              : 'bg-[#1F1F24] text-[#9CA3AF] hover:text-[#F4F6FC] border border-[#3A3A4A] hover:border-green-500/60'
          }`}
        >
          Approved ({approvedCount})
        </button>
        <button
          onClick={() => setFilter('rejected')}
          className={`px-4 py-2 rounded-xl font-semibold transition-all duration-300 ${
            filter === 'rejected'
              ? 'bg-red-500 text-white'
              : 'bg-[#1F1F24] text-[#9CA3AF] hover:text-[#F4F6FC] border border-[#3A3A4A] hover:border-red-500/60'
          }`}
        >
          Rejected ({rejectedCount})
        </button>
      </div>

      {/* Articles List */}
      {articles.length > 0 ? (
        <div className="space-y-4">
          {[...articles].sort((a, b) => Number(b.submittedAt ?? 0n) - Number(a.submittedAt ?? 0n)).map((article) => {
            const now = Date.now() * 1_000_000; // Convert to nanos
            const expiresAt = Number(article.submittedAt) + (48 * 60 * 60 * 1_000_000_000); // 48 hours in nanos
            const timeRemaining = expiresAt - now;
            const hoursRemaining = Math.max(0, Math.floor(timeRemaining / (1_000_000_000 * 60 * 60)));
            
            const isRevisionRequested = article.status?.hasOwnProperty('revisionRequested');
            const isRevisionSubmitted = article.status?.hasOwnProperty('revisionSubmitted');
            const isPendingRevision = isRevisionRequested || isRevisionSubmitted;
            
            const statusColor = filter === 'pending' 
              ? isPendingRevision
                ? 'bg-orange-500/20 text-orange-400'
                : 'bg-blue-500/20 text-blue-400'
              : filter === 'approved'
              ? 'bg-green-500/20 text-green-400'
              : 'bg-red-500/20 text-red-400';
            
            const statusLabel = filter === 'pending' 
              ? getStatusLabel(article)
              : filter === 'approved'
              ? 'Approved'
              : 'Rejected';

            return (
              <Link
                key={article.articleId.toString()}
                to={`/curator/${article.articleId}`}
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

                {isPendingRevision && article.revisionsRequested && (
                  <div className="mb-4 p-3 bg-orange-500/10 border border-orange-500/30 rounded-xl">
                    <div className="text-sm font-semibold text-orange-400 mb-2">
                      Revision {Number(article.revisionsRequested)}/3
                    </div>
                  </div>
                )}

                {filter === 'rejected' && article.rejectionReason && (
                  <div className="mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-xl">
                    <div className="text-xs font-semibold text-red-400 mb-1">Rejection Reason:</div>
                    <div className="text-sm text-red-300 line-clamp-2">{article.rejectionReason}</div>
                  </div>
                )}

                <p className="text-sm text-[#9CA3AF] mb-4 line-clamp-2">
                  {article.content}
                </p>

                <div className="flex flex-wrap gap-4 text-sm text-[#9CA3AF]">
                  <span>
                    Submitted {formatDate(article.submittedAt)}
                  </span>
                  {filter === 'pending' && (
                    <span className="text-[#6B7280]">
                      {hoursRemaining}h remaining
                    </span>
                  )}
                </div>

                {filter === 'pending' && (
                  <div className="text-sm">
                    <span className="text-blue-400 font-semibold">
                      → Click to Review
                    </span>
                  </div>
                )}
              </Link>
            );
          })}
        </div>
      ) : (
        <div className="text-center py-12 text-[#9CA3AF] bg-[#1F1F24] border border-[#3A3A4A] rounded-xl">
          No articles to display
        </div>
      )}
    </div>
  );
}
