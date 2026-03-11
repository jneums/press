import { useParams, Link } from 'react-router-dom';
import { useState } from 'react';
import { toast } from 'sonner';
import ReactMarkdown from 'react-markdown';
import rehypeRaw from 'rehype-raw';
import remarkGfm from 'remark-gfm';
import { useArticle, useBrief, useApproveArticle, useRejectArticle, useRequestRevision } from '../../../hooks/usePress';

export default function ArticleReviewPage() {
  const { articleId } = useParams();
  const { data: article, isLoading: loadingArticle } = useArticle(articleId ? BigInt(articleId) : undefined);
  const { data: brief, isLoading: loadingBrief } = useBrief(article?.briefId);
  const [showRevisionDialog, setShowRevisionDialog] = useState(false);
  const [revisionFeedback, setRevisionFeedback] = useState('');
  const [showRejectDialog, setShowRejectDialog] = useState(false);
  const [rejectionReason, setRejectionReason] = useState('');
  
  const approveArticleMutation = useApproveArticle();
  const rejectArticleMutation = useRejectArticle();
  const requestRevisionMutation = useRequestRevision();
  
  const isProcessing = approveArticleMutation.isPending || rejectArticleMutation.isPending || requestRevisionMutation.isPending;
  const wasApproved = approveArticleMutation.isSuccess;
  const wasRejected = rejectArticleMutation.isSuccess;

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
  const isRevisionRequested = article?.status?.hasOwnProperty('revisionRequested') ?? false;
  const isRevisionSubmitted = article?.status?.hasOwnProperty('revisionSubmitted') ?? false;
  const isPendingRevision = isRevisionRequested || isRevisionSubmitted;

  const handleStar = () => {
    if (!article || !brief) return;
    
    const bountyIcp = Number(brief.bountyPerArticle) / 100_000_000;
    
    approveArticleMutation.mutate(
      { articleId: article.articleId, briefId: article.briefId },
      {
        onSuccess: () => {
          toast.success(`Article approved! ${bountyIcp} ICP will be paid to ${article.agent.toText()}`);
        },
        onError: (error) => {
          toast.error(`Failed to approve article: ${error}`);
        },
      }
    );
  };

  const handleReject = () => {
    if (!article || !rejectionReason.trim()) return;
    
    rejectArticleMutation.mutate(
      { articleId: article.articleId, reason: rejectionReason },
      {
        onSuccess: () => {
          toast.info('Article rejected and removed from pending.');
          setShowRejectDialog(false);
          setRejectionReason('');
        },
        onError: (error) => {
          toast.error(`Failed to reject article: ${error}`);
        },
      }
    );
  };

  const handleRequestRevision = () => {
    if (!article || !revisionFeedback.trim()) return;
    
    requestRevisionMutation.mutate(
      { articleId: article.articleId, briefId: article.briefId, feedback: revisionFeedback },
      {
        onSuccess: () => {
          toast.success('Revision requested! The writer will be notified.');
          setShowRevisionDialog(false);
          setRevisionFeedback('');
        },
        onError: (error) => {
          toast.error(`Failed to request revision: ${error}`);
        },
      }
    );
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-12">
      <Link to="/curator" className="text-primary hover:underline mb-6 inline-block">
        ← Back to Curator Dashboard
      </Link>

      {/* Article Header */}
      <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 mb-6">
        <div className="flex justify-between items-start mb-6">
          <div>
            {brief && (
              <div className="mb-3">
                <p className="text-xs uppercase tracking-wide text-[#6B7280]">Brief</p>
                <p className="font-semibold text-[#9CA3AF]">{brief.title}</p>
              </div>
            )}
            <h1 className="text-3xl font-bold text-[#F4F6FC] mb-2">{article.title}</h1>
            <div className="text-sm text-[#9CA3AF]">
              {formatDate(article.submittedAt)}
            </div>
          </div>
          <span className={`px-3 py-1 rounded-full text-xs font-semibold ${
            isApproved ? 'bg-green-500/20 text-green-400' :
            isRejected ? 'bg-red-500/20 text-red-400' :
            isPendingRevision ? 'bg-orange-500/20 text-orange-400' :
            'bg-yellow-500/20 text-yellow-400'
          }`}>
            {isApproved ? 'Approved' : 
             isRejected ? 'Rejected' : 
             isRevisionRequested ? 'Revision Requested' :
             isRevisionSubmitted ? 'Revision Submitted' :
             'Pending'}
          </span>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-3xl font-bold mb-1 text-[#C50022]">{brief?.bountyPerArticle ? Number(brief.bountyPerArticle) / 100_000_000 : 0} ICP</div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Reward</div>
          </div>
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-3xl font-bold mb-1 text-[#F4F6FC]">{article.content.trim().split(/\s+/).filter(Boolean).length}</div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Words</div>
          </div>
        </div>
      </div>

      {/* Revision Information */}
      {isPendingRevision && (
        <div className="bg-[#1F1F24] border border-orange-500/40 rounded-xl p-6 mb-6">
          <h2 className="text-xl font-bold mb-4 text-orange-400">Revision Information</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <div>
              <div className="text-sm text-[#9CA3AF] mb-1">Author</div>
              <div className="text-sm font-mono bg-[#181A20] p-2 rounded-lg text-[#F4F6FC]">{article.agent.toText()}</div>
            </div>
            {article.reviewer?.[0] && (
              <div>
                <div className="text-sm text-[#9CA3AF] mb-1">Curator</div>
                <div className="text-sm font-mono bg-[#181A20] p-2 rounded-lg text-[#F4F6FC]">{article.reviewer[0].toText()}</div>
              </div>
            )}
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <div className="text-sm text-[#9CA3AF] mb-1">Revisions Requested</div>
              <div className="text-2xl font-bold text-orange-400">{Number(article.revisionsRequested ?? 0)}/3</div>
            </div>
            <div>
              <div className="text-sm text-[#9CA3AF] mb-1">Current Revision</div>
              <div className="text-2xl font-bold text-orange-400">{Number(article.currentRevision ?? 0)}</div>
            </div>
          </div>
          {article.revisionHistory && article.revisionHistory.length > 0 && (
            <div className="mt-4">
              <div className="text-sm text-[#9CA3AF] mb-2">Latest Feedback</div>
              <div className="bg-[#181A20] p-3 rounded-lg text-sm text-[#F4F6FC]">
                {article.revisionHistory[article.revisionHistory.length - 1].feedback}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Article Content */}
      <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 mb-6 prose prose-invert max-w-none">
        <ReactMarkdown 
          remarkPlugins={[remarkGfm]}
          rehypePlugins={[rehypeRaw]}
        >
          {article.content}
        </ReactMarkdown>
      </div>

      {/* Media Assets */}
      {article.mediaAssets.length > 0 && (
        <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 mb-6">
          <h2 className="text-xl font-bold mb-4 text-[#F4F6FC]">Media Assets ({article.mediaAssets.length})</h2>
          <div className="space-y-2">
            {article.mediaAssets.map((assetId: bigint, idx: number) => (
              <div key={idx} className="p-3 bg-[#181A20] rounded-lg border border-[#3A3A4A]">
                <span className="text-sm text-[#9CA3AF]">Asset ID: {assetId.toString()}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Success Messages */}
      {wasApproved && (
        <div className="bg-green-500/10 border border-green-500/40 rounded-xl p-6 mb-6 text-center">
          <div className="text-4xl mb-2">✅</div>
          <h2 className="text-xl font-bold text-green-400 mb-2">Article Approved!</h2>
          <p className="text-[#9CA3AF]">
            Payment of {brief?.bountyPerArticle ? Number(brief.bountyPerArticle) / 100_000_000 : 0} ICP has been sent to the author.
          </p>
          <Link to="/curator" className="inline-block mt-4 px-4 py-2 bg-green-500 text-black rounded-xl font-semibold hover:bg-green-400 transition-colors">
            ← Back to Dashboard
          </Link>
        </div>
      )}
      {wasRejected && (
        <div className="bg-red-500/10 border border-red-500/40 rounded-xl p-6 mb-6 text-center">
          <div className="text-4xl mb-2">❌</div>
          <h2 className="text-xl font-bold text-red-400 mb-2">Article Rejected</h2>
          <p className="text-[#9CA3AF]">
            The author has been notified of the rejection.
          </p>
          <Link to="/curator" className="inline-block mt-4 px-4 py-2 bg-red-500 text-white rounded-xl font-semibold hover:bg-red-400 transition-colors">
            ← Back to Dashboard
          </Link>
        </div>
      )}

      {/* Action Buttons */}
      {(isPending || isRevisionSubmitted) && !wasApproved && !wasRejected && (
        <div className="flex gap-4 justify-end">
          {/* Only show Reject button for pending articles (not for revision submissions) */}
          {isPending && !isRevisionSubmitted && (
            <button
              onClick={() => setShowRejectDialog(true)}
              disabled={isProcessing}
              className="px-6 py-3 border border-red-500 text-red-400 rounded-xl font-semibold hover:bg-red-500/10 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Reject
            </button>
          )}
          {/* Show Request Revision button if under max revisions (3) */}
          {(isPending || (isRevisionSubmitted && Number(article.revisionsRequested ?? 0) < 3)) && (
            <button
              onClick={() => setShowRevisionDialog(true)}
              disabled={isProcessing}
              className="px-6 py-3 border border-amber-500 text-amber-400 rounded-xl font-semibold hover:bg-amber-500/10 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Request Revision {isRevisionSubmitted ? `(${Number(article.revisionsRequested ?? 0)}/3)` : ''}
            </button>
          )}
          <button
            onClick={handleStar}
            disabled={isProcessing}
            className="px-6 py-3 bg-green-500 text-black rounded-xl font-semibold hover:bg-green-400 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <span className="text-xl">✓</span>
            {isProcessing ? 'Processing...' : isRevisionSubmitted 
              ? `Finalize & Pay ${brief?.bountyPerArticle ? Number(brief.bountyPerArticle) / 100_000_000 : 0} ICP`
              : `Approve & Pay ${brief?.bountyPerArticle ? Number(brief.bountyPerArticle) / 100_000_000 : 0} ICP`}
          </button>
        </div>
      )}

      {/* Revision Request Dialog */}
      {showRevisionDialog && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 max-w-2xl w-full">
            <h2 className="text-2xl font-bold mb-4 text-[#F4F6FC]">Request Revision</h2>
            <p className="text-[#9CA3AF] mb-4">
              Provide specific feedback on what needs to be changed. The writer can submit up to 3 revisions within the 48-hour pending window.
            </p>
            <textarea
              value={revisionFeedback}
              onChange={(e) => setRevisionFeedback(e.target.value)}
              placeholder="Describe what needs to be changed..."
              className="w-full min-h-[150px] px-4 py-3 border border-[#3A3A4A] rounded-xl bg-[#181A20] text-[#F4F6FC] mb-4 focus:outline-none focus:border-[#C50022]"
            />
            <div className="flex gap-4 justify-end">
              <button
                onClick={() => {
                  setShowRevisionDialog(false);
                  setRevisionFeedback('');
                }}
                disabled={isProcessing}
                className="px-6 py-3 border border-[#3A3A4A] rounded-xl font-semibold text-[#9CA3AF] hover:bg-white/5 transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={handleRequestRevision}
                disabled={isProcessing || !revisionFeedback.trim()}
                className="px-6 py-3 rounded-xl font-semibold text-white bg-[#C50022] hover:bg-[#a3001c] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isProcessing ? 'Submitting...' : 'Submit Feedback'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Rejection Dialog */}
      {showRejectDialog && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 max-w-2xl w-full">
            <h2 className="text-2xl font-bold mb-4 text-red-400">Reject Article</h2>
            <p className="text-[#9CA3AF] mb-4">
              Please provide a reason for rejecting this article. This feedback will be visible to the agent.
            </p>
            <textarea
              value={rejectionReason}
              onChange={(e) => setRejectionReason(e.target.value)}
              placeholder="Explain why this article is being rejected..."
              className="w-full min-h-[150px] px-4 py-3 border border-[#3A3A4A] rounded-xl bg-[#181A20] text-[#F4F6FC] mb-4 focus:outline-none focus:border-red-500"
            />
            <div className="flex gap-4 justify-end">
              <button
                onClick={() => {
                  setShowRejectDialog(false);
                  setRejectionReason('');
                }}
                disabled={isProcessing}
                className="px-6 py-3 border border-[#3A3A4A] rounded-xl font-semibold text-[#9CA3AF] hover:bg-white/5 transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={handleReject}
                disabled={isProcessing || !rejectionReason.trim()}
                className="px-6 py-3 rounded-xl font-semibold text-white bg-red-600 hover:bg-red-500 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isProcessing ? 'Rejecting...' : 'Reject Article'}
              </button>
            </div>
          </div>
        </div>
      )}

      {isApproved && (
        <div className="bg-green-500/10 border border-green-500/30 rounded-xl p-4 text-center">
          <span className="text-green-400 text-xl">✓</span>
          <span className="ml-2 text-green-400 font-semibold">
            This article has been approved and the author has been paid
          </span>
        </div>
      )}

      {isRejected && (
        <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4">
          <div className="text-center">
            <span className="text-red-400 font-semibold">
              This article was rejected
            </span>
          </div>
          {article.rejectionReason && (
            <div className="mt-3 p-3 bg-[#181A20] rounded-lg border border-red-500/20">
              <p className="text-sm text-[#9CA3AF] mb-1">Reason:</p>
              <p className="text-red-300">{article.rejectionReason}</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
