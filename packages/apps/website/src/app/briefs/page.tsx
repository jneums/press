import { Link } from 'react-router-dom';
import { useOpenBriefs } from '../../hooks/usePress';
import { CreateBriefDialog } from '../../components/CreateBriefDialog';

export default function BriefsPage() {
  const { data: briefs = [], isLoading, error } = useOpenBriefs();
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

  const formatDeadline = (expiresAt: bigint | undefined) => {
    if (!expiresAt) return null;
    const now = Date.now() * 1_000_000; // Current time in nanos
    const expiryNanos = Number(expiresAt);
    const remainingMs = (expiryNanos - now) / 1_000_000;
    
    if (remainingMs <= 0) return { text: 'EXPIRED', urgent: true, expired: true };
    
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
    const deadline = formatDeadline(brief.expiresAt?.[0]);

    return (
      <Link 
        to={`/briefs/${brief.briefId}`}
        className="block bg-card border-2 rounded-lg p-8 hover:border-primary transition-all shadow-lg hover:shadow-xl"
        style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4), 0 0 20px rgba(197, 0, 34, 0.2), inset 0 0 30px rgba(197, 0, 34, 0.05)' }}
      >
        <div className="flex justify-between items-start gap-4 mb-6">
          <div className="flex-1 min-w-0">
            <h3 className="text-2xl font-bold mb-2">{brief.title}</h3>
            <div className="flex flex-wrap items-center gap-2 mb-2">
              <span className="px-3 py-1 rounded text-xs font-semibold border whitespace-nowrap" style={{ backgroundColor: 'rgba(197, 0, 34, 0.1)', color: '#C50022', borderColor: 'rgba(197, 0, 34, 0.3)' }}>
                {brief.topic}
              </span>
            </div>
            <div className="text-sm text-muted-foreground">
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
          className={`mb-6 p-4 rounded-lg border-2 flex items-center gap-3 ${
            deadline?.expired 
              ? 'bg-red-900/30 border-red-500' 
              : deadline?.urgent 
                ? 'bg-orange-900/30 border-orange-500 animate-pulse' 
                : deadline 
                  ? 'bg-yellow-900/20 border-yellow-500/50' 
                  : 'bg-green-900/20 border-green-500/30'
          }`}
        >
          <span className="text-2xl">⏰</span>
          <div>
            <div className={`text-xs uppercase tracking-wide font-bold ${
              deadline?.expired ? 'text-red-400' : deadline?.urgent ? 'text-orange-400' : 'text-yellow-400'
            }`}>
              SUBMISSION DEADLINE
            </div>
            <div className={`text-lg font-bold ${
              deadline?.expired 
                ? 'text-red-400' 
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

        <div className="grid grid-cols-2 md:grid-cols-4 gap-6 mb-6">
          <div className="bg-black/30 rounded-lg p-4 border" style={{ borderColor: 'rgba(197, 0, 34, 0.2)' }}>
            <div className="text-3xl font-bold mb-1" style={{ color: '#C50022' }}>{Number(brief.bountyPerArticle) / 100_000_000} ICP</div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Per Article</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 border" style={{ borderColor: 'rgba(197, 0, 34, 0.2)' }}>
            <div className="text-3xl font-bold mb-1" style={{ color: '#C50022' }}>{Number(brief.escrowBalance) / 100_000_000} ICP</div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Escrow Balance</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 border border-white/10">
            <div className="text-3xl font-bold mb-1 text-white">{Number(brief.approvedCount)}</div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Approved</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 border border-white/10">
            <div className="text-3xl font-bold mb-1 text-white">{Number(brief.maxArticles)}</div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Total Slots</div>
          </div>
        </div>

        <div className="border-t pt-6 space-y-4" style={{ borderColor: 'rgba(197, 0, 34, 0.2)' }}>
          {(brief.requirements.minWords || brief.requirements.maxWords) && (
            <div className="flex items-start gap-3">
              <span className="text-sm text-muted-foreground min-w-[120px]">Word Count:</span>
              <span className="font-semibold text-white">
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
              <span className="text-sm text-muted-foreground min-w-[120px]">Topics:</span>
              <div className="flex flex-wrap gap-2">
                {brief.requirements.requiredTopics.map((topic: string, idx: number) => (
                  <span 
                    key={idx}
                    className="px-3 py-1 rounded text-xs font-mono border"
                    style={{ backgroundColor: 'rgba(197, 0, 34, 0.1)', color: '#C50022', borderColor: 'rgba(197, 0, 34, 0.3)' }}
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
    <div className="max-w-7xl mx-auto px-4 py-12">
      <div className="mb-12 text-center">
        <div className="flex items-center justify-center gap-4 mb-4">
          <h1 className="text-5xl font-bold" style={{ color: '#C50022' }}>Active Briefs</h1>
          <CreateBriefDialog />
        </div>
        <div className="w-16 h-1 mx-auto mb-6" style={{ background: '#C50022' }}></div>
        <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
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
        <div className="text-center py-12 text-muted-foreground">
          No active briefs at the moment
        </div>
      )}

      {completedBriefs.length > 0 && (
        <>
          <div className="mb-8 mt-16">
            <h2 className="text-3xl font-bold mb-2">Completed Briefs</h2>
            <p className="text-muted-foreground">
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
