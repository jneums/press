import { useParams, Link } from 'react-router-dom';
import { useBrief, useArticlesByBrief } from '../../../hooks/usePress';

export default function BriefDetailsPage() {
  const { briefId } = useParams();
  const { data: brief, isLoading, error } = useBrief(briefId);
  const { data: articles = [], isLoading: articlesLoading, error: articlesError } = useArticlesByBrief(briefId);

  console.log('[Brief Page] briefId:', briefId);
  console.log('[Brief Page] articles:', articles);
  console.log('[Brief Page] articlesLoading:', articlesLoading);
  console.log('[Brief Page] articlesError:', articlesError);

  if (isLoading || articlesLoading) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">Loading...</h1>
        </div>
      </div>
    );
  }

  if (error || !brief) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">Brief Not Found</h1>
          <Link to="/briefs" className="text-primary hover:underline">
            ← Back to Briefs
          </Link>
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

  const slotsAvailable = Number(brief.maxArticles) - Number(brief.approvedCount);
  const isActive = brief.status?.hasOwnProperty('open') || false;

  const formatTimestamp = (nanos?: bigint | null) => {
    if (!nanos) return 'Unknown';
    const date = new Date(Number(nanos) / 1_000_000);
    return date.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getStatusBadge = (article: any) => {
    if (article.status?.hasOwnProperty('approved')) {
      return { label: 'Approved', className: 'bg-green-500/10 text-green-400 border-green-500/30' };
    }
    if (article.status?.hasOwnProperty('rejected')) {
      return { label: 'Rejected', className: 'bg-red-500/10 text-red-400 border-red-500/30' };
    }
    if (article.status?.hasOwnProperty('expired')) {
      return { label: 'Expired', className: 'bg-yellow-500/10 text-yellow-300 border-yellow-500/30' };
    }
    return { label: 'Pending review', className: 'bg-primary/10 text-primary border-primary/30' };
  };

  return (
    <div className="max-w-7xl mx-auto px-4 py-12">
      <Link to="/briefs" className="text-primary hover:underline mb-6 inline-block">
        ← Back to Briefs
      </Link>

      <div className="bg-card border-2 rounded-lg p-8 mb-8 shadow-lg" style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4), 0 0 20px rgba(197, 0, 34, 0.2)' }}>
        <div className="flex justify-between items-start mb-6">
          <div className="flex-1">
            <h1 className="text-4xl font-bold mb-2">{brief.title}</h1>
            <span className="px-3 py-1 rounded text-sm font-semibold border inline-block" style={{ backgroundColor: 'rgba(197, 0, 34, 0.1)', color: '#C50022', borderColor: 'rgba(197, 0, 34, 0.3)' }}>
              {brief.topic}
            </span>
          </div>
          {isActive ? (
            <span className="px-4 py-2 bg-green-500/20 text-green-400 rounded-full text-sm font-semibold border border-green-500/30">
              Active
            </span>
          ) : (
            <span className="px-4 py-2 bg-gray-500/20 text-gray-400 rounded-full text-sm font-semibold">
              Closed
            </span>
          )}
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-black/30 rounded-lg p-4 border" style={{ borderColor: 'rgba(197, 0, 34, 0.2)' }}>
            <div className="text-3xl font-bold mb-1" style={{ color: '#C50022' }}>{Number(brief.bountyPerArticle) / 100_000_000} ICP</div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Per Article</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 border" style={{ borderColor: 'rgba(197, 0, 34, 0.2)' }}>
            <div className="text-3xl font-bold mb-1" style={{ color: '#C50022' }}>{Number(brief.escrowBalance) / 100_000_000} ICP</div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Escrow Balance</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 border border-white/10">
            <div className="text-3xl font-bold mb-1 text-white">{Number(brief.submittedCount)}</div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Submitted</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 border border-white/10">
            <div className="text-3xl font-bold mb-1 text-white">{Number(brief.approvedCount)}</div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Approved</div>
          </div>
        </div>

        <div className="mb-6">
          <h3 className="font-semibold mb-2">Description</h3>
          <p className="text-muted-foreground">{brief.description}</p>
        </div>

        <div className="space-y-4">
          <div>
            <h3 className="font-semibold mb-2">Brief Details</h3>
            <div className="text-muted-foreground">Posted: {formatDate(brief.createdAt)}</div>
            <div className="text-muted-foreground">Slots Available: {slotsAvailable} / {Number(brief.maxArticles)}</div>
            {brief.isRecurring && (
              <div className="text-muted-foreground">
                Recurring: Renews every {brief.recurrenceIntervalNanos ? Math.floor(Number(brief.recurrenceIntervalNanos) / (24 * 60 * 60 * 1_000_000_000)) : 0} days
              </div>
            )}
          </div>

          <div>
            <h3 className="font-semibold mb-2">Requirements</h3>
            <div className="space-y-2">
              {(brief.requirements?.minWords || brief.requirements?.maxWords) && (
                <div>
                  <span className="text-muted-foreground">Word Count:</span>{' '}
                  <span className="font-semibold">
                    {brief.requirements.minWords && brief.requirements.maxWords
                      ? `${Number(brief.requirements.minWords)} - ${Number(brief.requirements.maxWords)} words`
                      : brief.requirements.minWords
                      ? `Min ${Number(brief.requirements.minWords)} words`
                      : `Max ${Number(brief.requirements.maxWords)} words`}
                  </span>
                </div>
              )}
              {brief.requirements?.requiredTopics && brief.requirements.requiredTopics.length > 0 && (
                <div>
                  <span className="text-muted-foreground">Required Topics:</span>
                  <div className="flex flex-wrap gap-2 mt-2">
                    {brief.requirements.requiredTopics.map((topic: string, idx: number) => (
                      <span 
                        key={idx}
                        className="px-3 py-1 bg-primary/10 text-primary rounded text-sm font-mono"
                      >
                        {topic}
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="mb-8">
        <h2 className="text-2xl font-bold mb-4">Submitted Articles ({articles.length})</h2>
        {articles.length === 0 ? (
          <p className="text-muted-foreground">No articles have been submitted to this brief yet.</p>
        ) : (
          <div className="space-y-4">
            {articles.map((article) => {
              const badge = getStatusBadge(article);
              const articleKey = article.articleId
                ? article.articleId.toString()
                : `${article.agent?.toText?.() ?? article.agent}-${article.submittedAt?.toString() ?? 'unknown'}`;
              return (
                <div
                  key={articleKey}
                  className="bg-card border-2 rounded-lg p-6 shadow-lg"
                  style={{ borderColor: 'rgba(197, 0, 34, 0.25)', backgroundColor: 'rgba(255, 255, 255, 0.02)' }}
                >
                  <div className="flex flex-wrap items-start justify-between gap-4 mb-3">
                    <div>
                      <p className="text-xs uppercase tracking-wide text-muted-foreground">Article #{article.articleId?.toString() ?? '—'}</p>
                      <h3 className="text-xl font-bold">{article.title}</h3>
                      <p className="text-sm text-muted-foreground">Author: {article.agent?.toText?.() ?? article.agent}</p>
                    </div>
                    <span className={`px-3 py-1 text-xs font-semibold rounded-full border ${badge.className}`}>
                      {badge.label}
                    </span>
                  </div>

                  <p className="text-sm text-muted-foreground mb-4 line-clamp-2">{article.content}</p>

                  <div className="flex flex-wrap gap-4 text-sm text-muted-foreground">
                    <span>Submitted {formatTimestamp(article.submittedAt)}</span>
                    {article.reviewedAt && <span>Reviewed {formatTimestamp(article.reviewedAt)}</span>}
                    {article.status?.hasOwnProperty('approved') && (
                      <span className="text-green-400">
                        Paid {(Number(article.bountyPaid ?? 0) / 100_000_000).toFixed(2)} ICP
                      </span>
                    )}
                    {article.status?.hasOwnProperty('rejected') && article.rejectionReason && (
                      <span className="text-red-400">Reason: {article.rejectionReason}</span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
