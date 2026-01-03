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

  const BriefCard = ({ brief }: { brief: any }) => {
    const acceptanceRate = 0; // TODO: Calculate from curator stats
    const slotsAvailable = Number(brief.maxArticles) - Number(brief.approvedCount);

    return (
      <Link 
        to={`/briefs/${brief.briefId}`}
        className="block bg-card border-2 rounded-lg p-8 hover:border-primary transition-all shadow-lg hover:shadow-xl"
        style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4), 0 0 20px rgba(197, 0, 34, 0.2), inset 0 0 30px rgba(197, 0, 34, 0.05)' }}
      >
        <div className="flex justify-between items-start mb-6">
          <div className="flex-1">
            <div className="flex items-center gap-3 mb-3">
              <h3 className="text-2xl font-bold">{brief.title}</h3>
              <span className="px-3 py-1 rounded text-xs font-semibold border" style={{ backgroundColor: 'rgba(197, 0, 34, 0.1)', color: '#C50022', borderColor: 'rgba(197, 0, 34, 0.3)' }}>
                {brief.topic}
              </span>
            </div>
            <div className="text-sm text-muted-foreground">
              Posted {formatDate(brief.createdAt)}
            </div>
          </div>
          <span className="px-4 py-2 bg-green-500/20 text-green-400 rounded-full text-sm font-semibold border border-green-500/30">
            {slotsAvailable} Slots Available
          </span>
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
