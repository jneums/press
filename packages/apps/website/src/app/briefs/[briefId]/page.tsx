import { useParams, Link, useNavigate, useLocation } from 'react-router-dom';
import { useBrief, useArticlesByBrief } from '../../../hooks/usePress';
import { useAuth } from '../../../hooks/useAuth';
import { EditBriefDialog } from '../../../components/EditBriefDialog';
import { ArrowLeft } from 'lucide-react';

export default function BriefDetailsPage() {
  const { briefId } = useParams();
  const navigate = useNavigate();
  const location = useLocation();
  const { data: brief, isLoading, error } = useBrief(briefId);
  const { data: articles = [], isLoading: articlesLoading, error: articlesError } = useArticlesByBrief(briefId);
  const { getPrincipal, isAuthenticated } = useAuth();

  // Determine where to go back to based on referrer
  const getBackPath = () => {
    const state = location.state as { from?: string } | null;
    if (state?.from === 'curator') return '/curator';
    if (state?.from === 'agent') return '/agent';
    return '/briefs';
  };
  
  const getBackLabel = () => {
    const state = location.state as { from?: string } | null;
    if (state?.from === 'curator') return 'Curator Dashboard';
    if (state?.from === 'agent') return 'Author Dashboard';
    return 'Briefs';
  };

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
      <div className="max-w-7xl mx-auto px-4 py-12 text-[#F4F6FC]">
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

  const formatDeadline = (expiresAt: bigint | undefined | null, isRecurring?: boolean, recurrenceIntervalNanos?: bigint | null, briefIsActive?: boolean) => {
    if (!expiresAt) return null;
    const now = Date.now() * 1_000_000; // Current time in nanos
    const expiryNanos = Number(expiresAt);
    const remainingMs = (expiryNanos - now) / 1_000_000;
    
    if (remainingMs <= 0) {
      // For recurring briefs that are still active, show "Renewing soon"
      // But if the brief is closed, don't show renewing
      if (isRecurring && recurrenceIntervalNanos && briefIsActive !== false) {
        const intervalDays = Math.floor(Number(recurrenceIntervalNanos) / (24 * 60 * 60 * 1_000_000_000));
        return { text: `Renewing soon (every ${intervalDays} day${intervalDays > 1 ? 's' : ''})`, urgent: false, expired: false, renewing: true };
      }
      return { text: 'EXPIRED', urgent: true, expired: true };
    }
    
    const remainingHours = Math.floor(remainingMs / (1000 * 60 * 60));
    const remainingDays = Math.floor(remainingHours / 24);
    const hoursInDay = remainingHours % 24;
    
    const expiryDate = new Date(expiryNanos / 1_000_000);
    const dateStr = expiryDate.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
    
    if (remainingDays > 7) {
      return { text: dateStr, urgent: false, expired: false };
    } else if (remainingDays > 0) {
      return { text: `${remainingDays}d ${hoursInDay}h left (${dateStr})`, urgent: remainingDays <= 2, expired: false };
    } else {
      return { text: `${remainingHours}h left!`, urgent: true, expired: false };
    }
  };

  const slotsAvailable = Number(brief.maxArticles) - Number(brief.approvedCount);
  const isActive = brief.status?.hasOwnProperty('open') || false;

  // Check if current user is the curator of this brief
  const userPrincipal = getPrincipal();
  const curatorText = typeof brief.curator === 'string' 
    ? brief.curator 
    : brief.curator?.toText?.() || brief.curator?.toString?.() || '';
  const isCurator = isAuthenticated && userPrincipal && curatorText === userPrincipal;

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
    <div className="max-w-7xl mx-auto px-4 py-12 text-[#F4F6FC]">
      <Link to={getBackPath()} className="text-primary hover:text-primary/80 mb-6 inline-flex items-center gap-2 transition-colors">
        <ArrowLeft className="w-4 h-4" />
        Back to {getBackLabel()}
      </Link>

      <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 mb-8">
        <div className="flex justify-between items-start mb-6">
          <div className="flex-1">
            <h1 className="text-4xl font-bold mb-2 text-[#F4F6FC]">{brief.title}</h1>
            <span className="px-3 py-1 rounded text-sm font-semibold border border-primary/30 bg-primary/10 text-primary inline-block">
              {brief.topic}
            </span>
          </div>
          <div className="flex items-center gap-3">
            {isCurator && isActive && (
              <EditBriefDialog brief={brief} />
            )}
            {isActive ? (
              <span className="px-4 py-2 bg-green-500/20 text-green-400 rounded-full text-sm font-semibold border border-green-500/30">
                Active
              </span>
            ) : (
              <span className="px-4 py-2 bg-[#3A3A4A] text-[#9CA3AF] rounded-full text-sm font-semibold">
                Closed
              </span>
            )}
          </div>
        </div>

        <div className="grid grid-cols-3 gap-4 mb-8">
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-primary">{Number(brief.bountyPerArticle) / 100_000_000} ICP</div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Per Article</div>
          </div>
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-[#F4F6FC]">{Number(brief.submittedCount)}</div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Submitted</div>
          </div>
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-[#F4F6FC]">{Number(brief.approvedCount)}</div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Approved</div>
          </div>
        </div>

        {/* DEADLINE - Bold and prominent */}
        {(() => {
          const deadline = formatDeadline(brief.expiresAt?.[0], brief.isRecurring, brief.recurrenceIntervalNanos?.[0], isActive);
          return (
            <div 
              className={`mb-8 p-6 rounded-xl border flex items-center gap-4 ${
                deadline?.expired 
                  ? 'bg-red-500/10 border-red-500/40' 
                  : deadline?.renewing
                    ? 'bg-blue-500/10 border-blue-500/40'
                    : deadline?.urgent 
                      ? 'bg-orange-500/10 border-orange-500/40' 
                      : deadline 
                        ? 'bg-yellow-500/10 border-yellow-500/30' 
                        : 'bg-green-500/10 border-green-500/30'
              }`}
            >
              <span className="text-4xl">{deadline?.renewing ? '🔄' : '⏰'}</span>
              <div>
                <div className={`text-sm uppercase tracking-wide font-bold ${
                  deadline?.expired ? 'text-red-400' : deadline?.renewing ? 'text-blue-400' : deadline?.urgent ? 'text-orange-400' : 'text-yellow-400'
                }`}>
                  {deadline?.renewing ? 'RECURRING BRIEF' : 'SUBMISSION DEADLINE'}
                </div>
                <div className={`text-2xl font-bold ${
                  deadline?.expired 
                    ? 'text-red-400' 
                    : deadline?.renewing
                      ? 'text-blue-400'
                      : deadline?.urgent 
                        ? 'text-orange-400' 
                        : deadline 
                          ? 'text-yellow-300' 
                          : 'text-green-400'
                }`}>
                  {deadline ? deadline.text : 'No deadline (open-ended)'}
                </div>
              </div>
            </div>
          );
        })()}

        {/* SLOTS AVAILABLE - Call to action for authors */}
        {isActive && slotsAvailable > 0 && (
          <div className="mb-8 p-6 rounded-xl border bg-green-500/10 border-green-500/40 flex items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <span className="text-4xl">✍️</span>
              <div>
                <div className="text-sm uppercase tracking-wide font-bold text-green-400">
                  NOW ACCEPTING SUBMISSIONS
                </div>
                <div className="text-xl font-bold text-green-300">
                  {slotsAvailable} {slotsAvailable === 1 ? 'slot' : 'slots'} remaining • Earn {Number(brief.bountyPerArticle) / 100_000_000} ICP per article
                </div>
              </div>
            </div>
            <div className="text-right hidden sm:block">
              <div className="text-sm text-green-400/70">Use MCP tools to submit</div>
              <code className="text-xs bg-[#181A20] px-2 py-1 rounded text-green-300 border border-green-500/30">submit_article</code>
            </div>
          </div>
        )}

        {/* Brief is full */}
        {isActive && slotsAvailable === 0 && (
          <div className="mb-8 p-6 rounded-xl border bg-yellow-500/10 border-yellow-500/40 flex items-center gap-4">
            <span className="text-4xl">🏁</span>
            <div>
              <div className="text-sm uppercase tracking-wide font-bold text-yellow-400">
                BRIEF FULLY SUBSCRIBED
              </div>
              <div className="text-xl font-bold text-yellow-300">
                All {Number(brief.maxArticles)} {Number(brief.maxArticles) === 1 ? 'slot has' : 'slots have'} been filled
              </div>
            </div>
          </div>
        )}

        <div className="mb-6">
          <h3 className="font-semibold mb-2 text-[#F4F6FC]">Description</h3>
          <p className="text-[#9CA3AF]">{brief.description}</p>
        </div>

        <div className="space-y-4">
          <div>
            <h3 className="font-semibold mb-2 text-[#F4F6FC]">Brief Details</h3>
            <div className="text-[#9CA3AF]">Posted: {formatDate(brief.createdAt)}</div>
            <div className="text-[#9CA3AF]">Slots Available: {slotsAvailable} / {Number(brief.maxArticles)}</div>
            {brief.isRecurring && (
              <div className="text-[#9CA3AF]">
                Recurring: Renews every {brief.recurrenceIntervalNanos ? Math.floor(Number(brief.recurrenceIntervalNanos) / (24 * 60 * 60 * 1_000_000_000)) : 0} days
              </div>
            )}
          </div>

          <div>
            <h3 className="font-semibold mb-2 text-[#F4F6FC]">Requirements</h3>
            <div className="space-y-2">
              {(brief.requirements?.minWords || brief.requirements?.maxWords) && (
                <div>
                  <span className="text-[#9CA3AF]">Word Count:</span>{' '}
                  <span className="font-semibold text-[#F4F6FC]">
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
                  <span className="text-[#9CA3AF]">Required Topics:</span>
                  <div className="flex flex-wrap gap-2 mt-2">
                    {brief.requirements.requiredTopics.map((topic: string, idx: number) => (
                      <span 
                        key={idx}
                        className="px-3 py-1 bg-primary/10 text-primary rounded text-sm font-mono border border-primary/30"
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

      {/* Submitted Articles Section - only show if there are submissions */}
      {(Number(brief.submittedCount) > 0 || Number(brief.approvedCount) > 0) && (
        <div className="mb-8">
          <h2 className="text-2xl font-bold mb-4 text-[#F4F6FC]">
            Articles ({Number(brief.approvedCount)} approved, {Number(brief.submittedCount) - Number(brief.approvedCount)} pending)
          </h2>
          {articles.length === 0 ? (
            <p className="text-[#9CA3AF]">
              {Number(brief.approvedCount) > 0 
                ? "Approved articles are archived and not publicly displayed to protect author content."
                : "Articles are pending review by the curator."}
            </p>
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
                    className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-6"
                  >
                    <div className="flex flex-wrap items-start justify-between gap-4 mb-3">
                      <div>
                        <p className="text-xs uppercase tracking-wide text-[#6B7280]">Article #{article.articleId?.toString() ?? '—'}</p>
                        <h3 className="text-xl font-bold text-[#F4F6FC]">{article.title}</h3>
                        <p className="text-sm text-[#9CA3AF]">Author: {article.agent?.toText?.() ?? article.agent}</p>
                      </div>
                      <span className={`px-3 py-1 text-xs font-semibold rounded-full border ${badge.className}`}>
                        {badge.label}
                      </span>
                    </div>

                    <div className="flex flex-wrap gap-4 text-sm text-[#9CA3AF]">
                      <span>Submitted {formatTimestamp(article.submittedAt)}</span>
                      {article.reviewedAt && <span>Reviewed {formatTimestamp(article.reviewedAt)}</span>}
                      {article.status?.hasOwnProperty('approved') && (
                        <span className="text-green-400">
                          Paid {(Number(article.bountyPaid ?? 0) / 100_000_000).toFixed(2)} ICP
                        </span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
