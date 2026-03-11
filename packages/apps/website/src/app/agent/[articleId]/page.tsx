import { useParams, Link, useNavigate } from 'react-router-dom';
import { useState } from 'react';
import { toast } from 'sonner';
import ReactMarkdown from 'react-markdown';
import rehypeRaw from 'rehype-raw';
import remarkGfm from 'remark-gfm';
import { useQueryClient } from '@tanstack/react-query';
import { useArticle, useBrief } from '../../../hooks/usePress';
import { useAuth } from '../../../hooks/useAuth';
import { approveDraft, updateDraft, deleteDraft } from '@press/ic-js';

export default function DraftArticleEditPage() {
  const { articleId } = useParams();
  const navigate = useNavigate();
  const { data: article, isLoading: loadingArticle, refetch: refetchArticle } = useArticle(articleId ? BigInt(articleId) : undefined);
  const { data: brief, isLoading: loadingBrief } = useBrief(article?.briefId);
  const [isProcessing, setIsProcessing] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editedTitle, setEditedTitle] = useState('');
  const [editedContent, setEditedContent] = useState('');
  const { getAgent } = useAuth();
  const queryClient = useQueryClient();

  if (loadingArticle || loadingBrief) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12 text-[#F4F6FC]">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">Loading...</h1>
        </div>
      </div>
    );
  }

  if (!article) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12 text-[#F4F6FC]">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">Article Not Found</h1>
          <Link to="/agent" className="text-primary hover:underline">
            ← Back to Author Dashboard
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

  const isDraft = article?.status?.hasOwnProperty('draft') ?? false;
  const isPending = article?.status?.hasOwnProperty('pending') ?? false;
  const isApproved = article?.status?.hasOwnProperty('approved') ?? false;
  const isRejected = article?.status?.hasOwnProperty('rejected') ?? false;
  const isRevisionRequested = article?.status?.hasOwnProperty('revisionRequested') ?? false;
  const isRevisionSubmitted = article?.status?.hasOwnProperty('revisionSubmitted') ?? false;
  const isPendingRevision = isRevisionRequested || isRevisionSubmitted;

  const handleEdit = () => {
    setEditedTitle(article.title);
    setEditedContent(article.content);
    setIsEditing(true);
  };

  const handleSaveEdit = async () => {
    if (!article || !editedTitle.trim() || !editedContent.trim()) {
      toast.error('Title and content cannot be empty');
      return;
    }

    setIsProcessing(true);
    try {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');

      await updateDraft(agent, article.articleId, editedTitle, editedContent);

      toast.success('Draft updated successfully!');
      setIsEditing(false);

      // Invalidate and refetch
      await queryClient.invalidateQueries({ queryKey: ['press', 'articles'] });
      await refetchArticle();
    } catch (error) {
      toast.error(`Failed to update draft: ${error}`);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleApproveToCurator = async () => {
    if (!article) return;

    setIsProcessing(true);
    try {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');

      await approveDraft(agent, article.articleId);

      toast.success('Article sent to curator queue! They will review within 48 hours.');

      // Invalidate all related queries
      await queryClient.invalidateQueries({ queryKey: ['press', 'articles'] });
      await refetchArticle();

      // Navigate back to dashboard
      setTimeout(() => navigate('/agent'), 1500);
    } catch (error) {
      toast.error(`Failed to approve draft: ${error}`);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleDeleteDraft = async () => {
    if (!article) return;

    setIsDeleting(true);
    try {
      const agent = getAgent();
      if (!agent) throw new Error('Not authenticated');

      await deleteDraft(agent, article.articleId);

      toast.success('Draft deleted successfully.');

      // Invalidate all related queries
      await queryClient.invalidateQueries({ queryKey: ['press', 'articles'] });

      // Navigate back to dashboard
      navigate('/agent');
    } catch (error) {
      toast.error(`Failed to delete draft: ${error}`);
    } finally {
      setIsDeleting(false);
      setShowDeleteConfirm(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-12 text-[#F4F6FC]">
      <Link to="/agent" className="text-primary hover:text-primary/80 mb-6 inline-block transition-colors">
        ← Back to Author Dashboard
      </Link>

      {/* Article Header */}
      <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 mb-6">
        <div className="flex justify-between items-start mb-4">
          <div className="flex-1">
            {isEditing ? (
              <input
                type="text"
                value={editedTitle}
                onChange={(e) => setEditedTitle(e.target.value)}
                className="text-3xl font-bold mb-2 w-full bg-[#181A20] border border-[#3A3A4A] rounded-xl px-3 py-2 text-[#F4F6FC]"
              />
            ) : (
              <h1 className="text-3xl font-bold mb-2 text-[#F4F6FC]">{article.title}</h1>
            )}
            <div className="text-sm text-[#9CA3AF] mb-2">
              Submitted {formatDate(article.submittedAt)}
            </div>
            {brief && (
              <div className="text-sm text-[#9CA3AF]">
                Brief: {brief.title}
              </div>
            )}
          </div>
          <span className={`px-3 py-1 rounded-full text-xs font-semibold border ${
            isApproved ? 'bg-green-500/10 text-green-400 border-green-500/30' :
            isRejected ? 'bg-red-500/10 text-red-400 border-red-500/30' :
            isPendingRevision ? 'bg-orange-500/10 text-orange-400 border-orange-500/30' :
            isPending ? 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30' :
            isDraft ? 'bg-blue-500/10 text-blue-400 border-blue-500/30' :
            'bg-[#3A3A4A] text-[#9CA3AF]'
          }`}>
            {isApproved ? 'Approved' : isRejected ? 'Rejected' : isRevisionRequested ? 'Revision Requested' : isRevisionSubmitted ? 'Revision Submitted' : isPending ? 'In Curator Queue' : isDraft ? 'Draft' : 'Unknown'}
          </span>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-primary">{brief?.bountyPerArticle ? Number(brief.bountyPerArticle) / 100_000_000 : 0} ICP</div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Reward</div>
          </div>
          <div className="bg-[#181A20] rounded-xl p-4 border border-[#3A3A4A]">
            <div className="text-2xl font-bold mb-1 text-[#F4F6FC]">{(isEditing ? editedContent : article.content).trim().split(/\s+/).filter(Boolean).length}</div>
            <div className="text-xs text-[#9CA3AF] uppercase tracking-wide">Words</div>
          </div>
        </div>
      </div>

      {/* Revision Information */}
      {isPendingRevision && (
        <div className="bg-[#1F1F24] border border-orange-500/40 rounded-xl p-6 mb-6">
          <div className="flex items-center gap-3 mb-4">
            <span className="text-2xl">🔄</span>
            <div>
              <h2 className="text-xl font-bold text-orange-400">
                Revision {Number(article.revisionsRequested ?? 0)}/3 {isRevisionRequested ? 'Requested' : 'Submitted'}
              </h2>
              <p className="text-sm text-[#9CA3AF]">
                {isRevisionRequested ? 'The curator has requested changes to your article' : 'Your revised content has been submitted for review'}
              </p>
            </div>
          </div>
          {article.revisionHistory && article.revisionHistory.length > 0 && (
            <div className="bg-[#181A20] rounded-xl p-4 border border-orange-500/30">
              <div className="text-sm font-semibold text-orange-400 mb-2">Curator Feedback:</div>
              <div className="text-[#9CA3AF] italic">
                {article.revisionHistory[article.revisionHistory.length - 1].feedback}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Article Content */}
      <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 mb-6">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-bold text-[#F4F6FC]">Content</h2>
          {isDraft && !isEditing && (
            <button
              onClick={handleEdit}
              className="px-4 py-2 border border-[#3A3A4A] rounded-xl font-semibold hover:border-primary/60 hover:bg-primary/10 transition-all text-[#F4F6FC]"
            >
              Edit
            </button>
          )}
        </div>

        {isEditing ? (
          <textarea
            value={editedContent}
            onChange={(e) => setEditedContent(e.target.value)}
            className="w-full min-h-[400px] bg-[#181A20] border border-[#3A3A4A] rounded-xl p-4 font-mono text-sm text-[#F4F6FC]"
          />
        ) : (
          <div className="prose prose-invert max-w-none">
            <ReactMarkdown 
              remarkPlugins={[remarkGfm]}
              rehypePlugins={[rehypeRaw]}
            >
              {article.content}
            </ReactMarkdown>
          </div>
        )}
      </div>

      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50">
          <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-6 max-w-md mx-4">
            <h3 className="text-xl font-bold mb-4 text-red-400">Delete Draft?</h3>
            <p className="text-[#9CA3AF] mb-6">
              Are you sure you want to delete this draft? This action cannot be undone.
            </p>
            <div className="flex gap-4 justify-end">
              <button
                onClick={() => setShowDeleteConfirm(false)}
                disabled={isDeleting}
                className="px-4 py-2 border border-[#3A3A4A] rounded-xl font-semibold hover:border-primary/60 transition-all disabled:opacity-50 text-[#F4F6FC]"
              >
                Cancel
              </button>
              <button
                onClick={handleDeleteDraft}
                disabled={isDeleting}
                className="px-4 py-2 rounded-xl font-semibold text-white transition-colors disabled:opacity-50 bg-red-600 hover:bg-red-700"
              >
                {isDeleting ? 'Deleting...' : 'Delete Draft'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Action Buttons */}
      {isDraft && (
        <div className="flex gap-4 justify-between">
          <button
            onClick={() => setShowDeleteConfirm(true)}
            disabled={isProcessing || isEditing}
            className="px-4 py-3 border border-red-500/30 rounded-xl font-semibold text-red-400 hover:bg-red-500/10 transition-all disabled:opacity-50"
          >
            🗑️ Delete Draft
          </button>
          <div className="flex gap-4">
            {isEditing ? (
              <>
                <button
                  onClick={() => {
                    setIsEditing(false);
                    setEditedTitle('');
                    setEditedContent('');
                  }}
                  disabled={isProcessing}
                  className="px-6 py-3 border border-[#3A3A4A] rounded-xl font-semibold hover:border-primary/60 transition-all disabled:opacity-50 text-[#F4F6FC]"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSaveEdit}
                  disabled={isProcessing}
                  className="px-6 py-3 rounded-xl font-semibold text-white transition-colors disabled:opacity-50 bg-primary hover:bg-primary/90"
                >
                  {isProcessing ? 'Saving...' : 'Save Changes'}
                </button>
              </>
            ) : (
              <button
                onClick={handleApproveToCurator}
                disabled={isProcessing}
                className="px-6 py-3 rounded-xl font-semibold text-white transition-colors disabled:opacity-50 flex items-center gap-2 bg-primary hover:bg-primary/90"
              >
                {isProcessing ? 'Processing...' : '✓ Approve & Send to Curator'}
              </button>
            )}
          </div>
        </div>
      )}

      {isPending && (
        <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl p-4 text-center">
          <span className="text-yellow-400 font-semibold">
            This article is in the curator's queue for review
          </span>
        </div>
      )}

      {isApproved && (
        <div className="bg-green-500/10 border border-green-500/30 rounded-xl p-4 text-center">
          <span className="text-green-400 text-xl">⭐</span>
          <span className="ml-2 text-green-400 font-semibold">
            This article has been approved and you've been paid!
          </span>
        </div>
      )}

      {isRejected && (
        <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4 text-center">
          <span className="text-red-400 font-semibold">
            This article was rejected by the curator
          </span>
        </div>
      )}
    </div>
  );
}
