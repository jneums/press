import { Link } from 'react-router-dom';
import { useTriageArticles, useArchivedArticles } from '../../hooks/usePress';
import { useState } from 'react';

export default function CuratorDashboardPage() {
  const [filter, setFilter] = useState<'pending' | 'approved' | 'rejected'>('pending');
  
  const { data: triageArticles = [], isLoading: triageLoading, error: triageError } = useTriageArticles();
  const { data: approvedData, isLoading: approvedLoading } = useArchivedArticles(0n, 50n, 'approved');
  const { data: rejectedData, isLoading: rejectedLoading } = useArchivedArticles(0n, 50n, 'rejected');

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

  return (
    <div className="max-w-7xl mx-auto px-4 py-12">
      <div className="mb-12 text-center">
        <h1 className="text-5xl font-bold mb-4" style={{ color: '#C50022' }}>Curator Dashboard</h1>
        <div className="w-16 h-1 mx-auto mb-6" style={{ background: '#C50022' }}></div>
        <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
          Review and approve submitted articles
        </p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-card border-2 rounded-lg p-8 shadow-lg" style={{ borderColor: 'rgba(59, 130, 246, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4), 0 0 20px rgba(59, 130, 246, 0.2)' }}>
          <div className="text-4xl font-bold mb-2 text-blue-400">{pendingCount}</div>
          <div className="text-sm text-muted-foreground uppercase tracking-wide">Pending Review</div>
        </div>
        <div className="bg-card border-2 rounded-lg p-8 shadow-lg" style={{ borderColor: 'rgba(34, 197, 94, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4), 0 0 20px rgba(34, 197, 94, 0.2)' }}>
          <div className="text-4xl font-bold mb-2 text-green-400">{approvedCount}</div>
          <div className="text-sm text-muted-foreground uppercase tracking-wide">Approved</div>
        </div>
        <div className="bg-card border-2 rounded-lg p-8 shadow-lg" style={{ borderColor: 'rgba(239, 68, 68, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4), 0 0 20px rgba(239, 68, 68, 0.2)' }}>
          <div className="text-4xl font-bold mb-2 text-red-400">{rejectedCount}</div>
          <div className="text-sm text-muted-foreground uppercase tracking-wide">Rejected</div>
        </div>
      </div>

      {/* Filter Buttons */}
      <div className="flex gap-2 mb-6">
        <button
          onClick={() => setFilter('pending')}
          className={`px-4 py-2 rounded-lg font-semibold transition-colors ${
            filter === 'pending'
              ? 'bg-blue-500 text-white'
              : 'bg-card text-muted-foreground hover:text-foreground border border-primary/20'
          }`}
        >
          Pending ({pendingCount})
        </button>
        <button
          onClick={() => setFilter('approved')}
          className={`px-4 py-2 rounded-lg font-semibold transition-colors ${
            filter === 'approved'
              ? 'bg-green-500 text-white'
              : 'bg-card text-muted-foreground hover:text-foreground border border-primary/20'
          }`}
        >
          Approved ({approvedCount})
        </button>
        <button
          onClick={() => setFilter('rejected')}
          className={`px-4 py-2 rounded-lg font-semibold transition-colors ${
            filter === 'rejected'
              ? 'bg-red-500 text-white'
              : 'bg-card text-muted-foreground hover:text-foreground border border-primary/20'
          }`}
        >
          Rejected ({rejectedCount})
        </button>
      </div>

      {/* Articles List */}
      {articles.length > 0 ? (
        <div className="space-y-4">
          {articles.map((article) => {
            const now = Date.now() * 1_000_000; // Convert to nanos
            const expiresAt = Number(article.submittedAt) + (48 * 60 * 60 * 1_000_000_000); // 48 hours in nanos
            const timeRemaining = expiresAt - now;
            const hoursRemaining = Math.max(0, Math.floor(timeRemaining / (1_000_000_000 * 60 * 60)));
            
            const statusColor = filter === 'pending' 
              ? 'bg-blue-500/20 text-blue-400'
              : filter === 'approved'
              ? 'bg-green-500/20 text-green-400'
              : 'bg-red-500/20 text-red-400';
            
            const statusLabel = filter === 'pending' 
              ? 'In Triage'
              : filter === 'approved'
              ? 'Approved'
              : 'Rejected';

            return (
              <Link
                key={article.articleId.toString()}
                to={`/curator/${article.articleId}`}
                className="block bg-card border-2 rounded-lg p-8 hover:border-primary transition-all shadow-lg hover:shadow-xl"
                style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4), 0 0 20px rgba(197, 0, 34, 0.2)' }}
              >
                <div className="flex justify-between items-start mb-4">
                  <div className="flex-1">
                    <h3 className="text-xl font-bold mb-2">{article.title}</h3>
                    <div className="text-sm text-muted-foreground mb-2">
                      By {article.agent.toText()} • {formatDate(article.submittedAt)}
                    </div>
                    <div className="text-sm text-muted-foreground">
                      Brief: {article.briefId}
                    </div>
                  </div>
                  <div className="flex flex-col gap-2 items-end">
                    <span className={`px-3 py-1 rounded-full text-xs font-semibold whitespace-nowrap ${statusColor}`}>
                      {statusLabel}
                    </span>
                    {filter === 'pending' && (
                      <span className="text-xs text-muted-foreground whitespace-nowrap">
                        {hoursRemaining}h remaining
                      </span>
                    )}
                  </div>
                </div>

                <div className="text-sm text-muted-foreground mb-4 line-clamp-2">
                  {article.content.split('\n').find((line: string) => line.trim() && !line.startsWith('#'))}
                </div>

                <div className="flex gap-6 text-sm">
                  <span className="text-muted-foreground">
                    {article.mediaAssets.length} media assets
                  </span>
                  {filter === 'pending' && (
                    <span className="text-blue-400 font-semibold">
                      → Click to Review
                    </span>
                  )}
                </div>
              </Link>
            );
          })}
        </div>
      ) : (
        <div className="text-center py-12 text-muted-foreground bg-card border border-primary/20 rounded-lg">
          No articles to display
        </div>
      )}
    </div>
  );
}
