import { Link } from 'react-router-dom';
import { useOpenBriefs } from '../../hooks/usePress';
import { useAuth } from '../../hooks/useAuth';
import { CreateBriefDialog } from '../../components/CreateBriefDialog';
import { RefreshCw } from 'lucide-react';

export default function BriefsPage() {
  const { data: briefs = [], isLoading, error, refetch, isFetching } = useOpenBriefs();
  const { user, isAuthenticated } = useAuth();
  
  // Filter briefs: show all but mark the user's own briefs
  const activeBriefs = briefs.filter(b => b.status.hasOwnProperty('open'));
  const completedBriefs = briefs.filter(b => !b.status.hasOwnProperty('open'));

  if (isLoading) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">Loading...</h1>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">Error loading briefs</h1>
          <p className="text-muted-foreground">{error.message}</p>
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

  const formatDeadline = (expiresAt: bigint | undefined, isRecurring?: boolean, recurrenceIntervalNanos?: bigint | null) => {
    if (!expiresAt) return null;
    const now = Date.now() * 1_000_000; // Current time in nanos
    const expiryNanos = Number(expiresAt);
    const remainingMs = (expiryNanos - now) / 1_000_000;
    
    if (remainingMs <= 0) {
      // For recurring briefs, show "Renewing soon" instead of expired
      if (isRecurring && recurrenceIntervalNanos) {
        const intervalDays = Math.floor(Number(recurrenceIntervalNanos) / (24 * 60 * 60 * 1_000_000_000));
        return { text: `Renewing (${intervalDays}d cycle)`, urgent: false, expired: false, renewing: true };
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

  const BriefCard = ({ brief }: { brief: any }) => {
    const acceptanceRate = 0; // TODO: Calculate from curator stats
    const slotsAvailable = Number(brief.maxArticles) - Number(brief.approvedCount);
    const deadline = formatDeadline(brief.expiresAt?.[0], brief.isRecurring, brief.recurrenceIntervalNanos?.[0]);
    
    // Check if this brief belongs to the current user
    const isOwnBrief = isAuthenticated && user && brief.curator?.toText?.() === user.principal;

    return (
      <Link 
        to={`/briefs/${brief.briefId}`}
        className={`block bg-[#1F1F24] border rounded-xl p-8 hover:border-primary/60 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10 ${isOwnBrief ? 'border-blue-500/40' : 'border-[#3A3A4A]'}`}
      >
        <div className="flex justify-between items-start gap-4 mb-6">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-3 mb-2">
              <h3 className="text-2xl font-bold">{brief.title}</h3>
              {isOwnBrief && (
                <span className="px-3 py-1 bg-blue-500/20 text-blue-400 rounded-full text-xs font-semibold border border-blue-500/30 whitespace-nowrap">
                  Your Brief
                </span>
              )}
            </div>
            <div className="flex flex-wrap items-center gap-2 mb-2">
              <span className="px-3 py-1 rounded text-xs font-semibold border border-primary/30 bg-primary/10 text-primary whitespace-nowrap">
                {brief.topic}
              </span>
            </div>
            <div className="text-sm text-[#9CA3AF]">
              Posted {formatDate(brief.createdAt)}
            </div>
          </div>
          <div className="flex-shrink-0">
            <span className="px-4 py-2 bg-green-500/20 text-green-400 rounded-full text-sm font-semibold border border-green-500/30 whitespace-nowrap">
              {slotsAvailable} Slots Available
            </span>
          </div>
        </div>

        {/* DEADLINE - Bold and prominent */}
        <div 
          className={`mb-6 p-4 rounded-xl border flex items-center gap-3 ${
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
          <span className="text-2xl">{deadline?.renewing ? '🔄' : '⏰'}</span>
          <div>
            <div className={`text-xs uppercase tracking-wide font-bold ${
              deadline?.expired ? 'text-red-400' : deadline?.renewing ? 'text-blue-400' : deadline?.urgent ? 'text-orange-400' : 'text-yellow-400'
            }`}>
              {deadline?.renewing ? 'RECURRING BRIEF' : 'SUBMISSION DEADLINE'}
            </div>
            <div className={`text-lg font-bold ${
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

        <div className="grid grid-cols-3 gap-4 mb-6">
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-primary">{Number(brief.bountyPerArticle) / 100_000_000} ICP</div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Per Article</div>
          </div>
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-[#F4F6FC]">{Number(brief.approvedCount)}</div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Approved</div>
          </div>
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-[#F4F6FC]">{Number(brief.maxArticles)}</div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Total Slots</div>
          </div>
        </div>

        <div className="border-t border-[#3A3A4A] pt-6 space-y-4">
          {(brief.requirements.minWords || brief.requirements.maxWords) && (
            <div className="flex items-start gap-3">
              <span className="text-sm text-[#9CA3AF] min-w-[120px]">Word Count:</span>
              <span className="font-semibold text-[#F4F6FC]">
                {brief.requirements.minWords && brief.requirements.maxWords
                  ? `${Number(brief.requirements.minWords)} - ${Number(brief.requirements.maxWords)} words`
                  : brief.requirements.minWords
                  ? `Min ${Number(brief.requirements.minWords)} words`
                  : `Max ${Number(brief.requirements.maxWords)} words`}
              </span>
            </div>
          )}
          {brief.requirements.requiredTopics && brief.requirements.requiredTopics.length > 0 && (
            <div className="flex items-start gap-3">
              <span className="text-sm text-[#9CA3AF] min-w-[120px]">Topics:</span>
              <div className="flex flex-wrap gap-2">
                {brief.requirements.requiredTopics.map((topic: string, idx: number) => (
                  <span 
                    key={idx}
                    className="px-3 py-1 rounded text-xs font-mono border border-primary/30 bg-primary/10 text-primary"
                  >
                    {topic}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      </Link>
    );
  };

  return (
    <div className="max-w-7xl mx-auto px-4 py-12 text-[#F4F6FC]">
      <div className="mb-12 text-center">
        <div className="flex items-center justify-center gap-4 mb-4">
          <h1 className="text-5xl font-bold text-primary">Active Briefs</h1>
          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="p-2 rounded-xl bg-[#1F1F24] border border-[#3A3A4A] hover:border-primary/60 transition-all disabled:opacity-50"
            title="Refresh briefs"
          >
            <RefreshCw className={`w-5 h-5 ${isFetching ? 'animate-spin' : ''}`} />
          </button>
          <CreateBriefDialog />
        </div>
        <div className="w-16 h-1 mx-auto mb-6 bg-primary"></div>
        <p className="text-lg text-[#9CA3AF] max-w-2xl mx-auto">
          Browse available content bounties and start creating articles
        </p>
      </div>

      {activeBriefs.length > 0 ? (
        <div className="grid grid-cols-1 gap-6 mb-12">
          {activeBriefs.map((brief) => (
            <BriefCard key={brief.id} brief={brief} />
          ))}
        </div>
      ) : (
        <div className="text-center py-12 text-[#9CA3AF]">
          No active briefs at the moment
        </div>
      )}

      {completedBriefs.length > 0 && (
        <>
          <div className="mb-8 mt-16">
            <h2 className="text-3xl font-bold mb-2 text-[#F4F6FC]">Completed Briefs</h2>
            <p className="text-[#9CA3AF]">
              Past bounties that have been fulfilled
            </p>
          </div>
          <div className="grid grid-cols-1 gap-6">
            {completedBriefs.map((brief) => (
              <BriefCard key={brief.id} brief={brief} />
            ))}
          </div>
        </>
      )}
    </div>
  );
}
