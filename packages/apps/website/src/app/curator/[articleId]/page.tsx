import { useParams, Link } from 'react-router-dom';
import { useState } from 'react';
import { toast } from 'sonner';
import ReactMarkdown from 'react-markdown';
import rehypeRaw from 'rehype-raw';
import remarkGfm from 'remark-gfm';
import { useQueryClient } from '@tanstack/react-query';
import { useArticle, useBrief } from '../../../hooks/usePress';
import { useAuth } from '../../../hooks/useAuth';
import { approveArticle, rejectArticle } from '@press/ic-js';

export default function ArticleReviewPage() {
  const { articleId } = useParams();
  const { data: article, isLoading: loadingArticle, refetch: refetchArticle } = useArticle(articleId ? BigInt(articleId) : undefined);
  const { data: brief, isLoading: loadingBrief } = useBrief(article?.briefId);
  const [isProcessing, setIsProcessing] = useState(false);
  const { getAgent } = useAuth();
  const queryClient = useQueryClient();

  if (loadingArticle || loadingBrief) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">Loading...</h1>
        </div>
      </div>
    );
  }

  if (!article) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">Article Not Found</h1>
          <Link to="/curator" className="text-primary hover:underline">
            ← Back to Curator Dashboard
          </Link>
        </div>
      </div>
    );
  }

  const formatDate = (timestampNanos: bigint) => {
    return new Date(Number(timestampNanos / 1_000_000n)).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    });
  };

  const isPending = article?.status?.hasOwnProperty('pending') ?? false;
  const isApproved = article?.status?.hasOwnProperty('approved') ?? false;
  const isRejected = article?.status?.hasOwnProperty('rejected') ?? false;

  const handleStar = async () => {
    if (!article || !brief) return;
    
    setIsProcessing(true);
    try {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      
      await approveArticle(agent, article.articleId, article.briefId);
      
      const bountyIcp = Number(brief.bountyPerArticle) / 100_000_000;
      toast.success(`Article approved! ${bountyIcp} ICP will be paid to ${article.agent.toText()}`);
      
      // Invalidate all related queries
      await queryClient.invalidateQueries({ queryKey: ['press', 'articles'] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'briefs'] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'stats'] });
      await refetchArticle();
    } catch (error) {
      toast.error(`Failed to approve article: ${error}`);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleReject = async () => {
    if (!article) return;
    
    setIsProcessing(true);
    try {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');
      
      await rejectArticle(agent, article.articleId, 'Rejected by curator');
      
      toast.info('Article rejected and removed from triage.');
      
      // Invalidate all related queries
      await queryClient.invalidateQueries({ queryKey: ['press', 'articles'] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'stats'] });
      await refetchArticle();
    } catch (error) {
      toast.error(`Failed to reject article: ${error}`);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-12">
      <Link to="/curator" className="text-primary hover:underline mb-6 inline-block">
        ← Back to Curator Dashboard
      </Link>

      {/* Article Header */}
      <div className="bg-card border-2 rounded-lg p-8 mb-6 shadow-lg" style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4), 0 0 20px rgba(197, 0, 34, 0.2)' }}>
        <div className="flex justify-between items-start mb-4">
          <div>
            <h1 className="text-3xl font-bold mb-2">{article.title}</h1>
            <div className="text-sm text-muted-foreground mb-2">
              By {article.agent.toText()} • {formatDate(article.submittedAt)}
            </div>
            {brief && (
              <div className="text-sm text-muted-foreground">
                Brief: {brief.topic}
              </div>
            )}
          </div>
          <span className={`px-3 py-1 rounded-full text-xs font-semibold ${
            isApproved ? 'bg-yellow-500/20 text-yellow-400' :
            isRejected ? 'bg-red-500/20 text-red-400' :
            'bg-blue-500/20 text-blue-400'
          }`}>
            {isApproved ? 'Approved' : isRejected ? 'Rejected' : 'In Triage'}
          </span>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-6">
          <div className="bg-black/30 rounded-lg p-4 border" style={{ borderColor: 'rgba(197, 0, 34, 0.2)' }}>
            <div className="text-3xl font-bold mb-1" style={{ color: '#C50022' }}>{brief?.bountyPerArticle ? Number(brief.bountyPerArticle) / 100_000_000 : 0} ICP</div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Reward</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 border border-white/10">
            <div className="text-3xl font-bold mb-1 text-white">{article.mediaAssets.length}</div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Media Assets</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 border border-white/10">
            <div className="text-3xl font-bold mb-1 text-white">{article.content.length}</div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">Characters</div>
          </div>
        </div>
      </div>

      {/* Article Content */}
      <div className="bg-card border-2 rounded-lg p-8 mb-6 prose prose-invert max-w-none shadow-lg" style={{ borderColor: 'rgba(197, 0, 34, 0.3)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 4px 16px rgba(0, 0, 0, 0.3), 0 0 15px rgba(197, 0, 34, 0.15)' }}>
        <ReactMarkdown 
          remarkPlugins={[remarkGfm]}
          rehypePlugins={[rehypeRaw]}
        >
          {article.content}
        </ReactMarkdown>
      </div>

      {/* Media Assets */}
      {article.mediaAssets.length > 0 && (
        <div className="bg-card border-2 rounded-lg p-8 mb-6 shadow-lg" style={{ borderColor: 'rgba(197, 0, 34, 0.3)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 4px 16px rgba(0, 0, 0, 0.3), 0 0 15px rgba(197, 0, 34, 0.15)' }}>
          <h2 className="text-xl font-bold mb-4">Media Assets ({article.mediaAssets.length})</h2>
          <div className="space-y-2">
            {article.mediaAssets.map((assetId: bigint, idx: number) => (
              <div key={idx} className="p-3 bg-primary/5 rounded-lg">
                <span className="text-sm text-muted-foreground">Asset ID: {assetId.toString()}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Action Buttons */}
      {isPending && (
        <div className="flex gap-4 justify-end">
          <button
            onClick={handleReject}
            disabled={isProcessing}
            className="px-6 py-3 border-2 border-red-500 text-red-400 rounded-lg font-semibold hover:bg-red-500/10 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isProcessing ? 'Processing...' : 'Reject'}
          </button>
          <button
            onClick={handleStar}
            disabled={isProcessing}
            className="px-6 py-3 bg-yellow-500 text-black rounded-lg font-semibold hover:bg-yellow-400 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <span className="text-xl">⭐</span>
            {isProcessing ? 'Processing...' : `Approve & Pay ${brief?.bountyPerArticle ? Number(brief.bountyPerArticle) / 100_000_000 : 0} ICP`}
          </button>
        </div>
      )}

      {isApproved && (
        <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-4 text-center">
          <span className="text-yellow-400 text-xl">⭐</span>
          <span className="ml-2 text-yellow-400 font-semibold">
            This article has been approved and the agent has been paid
          </span>
        </div>
      )}

      {isRejected && (
        <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-4 text-center">
          <span className="text-red-400 font-semibold">
            This article was rejected
          </span>
        </div>
      )}
    </div>
  );
}
