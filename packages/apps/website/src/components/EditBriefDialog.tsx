import { useState, useEffect } from 'react';
import { useForm, SubmitHandler } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useUpdateBrief } from '../hooks/usePress';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from './ui/dialog';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Pencil, AlertTriangle } from 'lucide-react';
import { toast } from 'sonner';
import type { Press } from '@press/declarations';

type Brief = Press.Brief;

// Schema for edit form - validates that changes respect fairness constraints
const editBriefSchema = z.object({
  title: z.string().min(5, 'Title must be at least 5 characters').max(100, 'Title is too long'),
  topic: z.string().min(5, 'Topic must be at least 5 characters').max(200, 'Topic is too long'),
  description: z.string().max(2000, 'Description is too long').optional(),
  bountyPerArticle: z.number().min(0.1, 'Bounty must be at least 0.1 ICP'),
  maxArticles: z.number().int().min(1, 'Must allow at least 1 article').max(1000, 'Maximum 1000 articles'),
  minWords: z.number().int().min(1, 'Minimum 1 word').max(50000, 'Maximum 50000 words').or(z.nan()).optional(),
  maxWords: z.number().int().min(1, 'Minimum 1 word').max(50000, 'Maximum 50000 words').or(z.nan()).optional(),
  customInstructions: z.string().max(2000).optional(),
});

type EditBriefFormData = z.infer<typeof editBriefSchema>;

interface EditBriefDialogProps {
  brief: Brief;
  onSuccess?: () => void;
}

export function EditBriefDialog({ brief, onSuccess }: EditBriefDialogProps) {
  const [open, setOpen] = useState(false);
  const updateBrief = useUpdateBrief();

  // Convert bigint values to numbers for the form
  const currentBounty = Number(brief.bountyPerArticle) / 100_000_000;
  const currentMaxArticles = Number(brief.maxArticles);
  const currentMinWords = brief.requirements?.minWords?.[0] ? Number(brief.requirements.minWords[0]) : undefined;
  const currentMaxWords = brief.requirements?.maxWords?.[0] ? Number(brief.requirements.maxWords[0]) : undefined;
  const currentCustomInstructions = brief.platformConfig?.customInstructions?.[0] || '';

  const {
    register,
    handleSubmit,
    formState: { errors, isDirty },
    reset,
    watch,
  } = useForm<EditBriefFormData>({
    resolver: zodResolver(editBriefSchema),
    defaultValues: {
      title: brief.title,
      topic: brief.topic,
      description: brief.description,
      bountyPerArticle: currentBounty,
      maxArticles: currentMaxArticles,
      minWords: currentMinWords,
      maxWords: currentMaxWords,
      customInstructions: currentCustomInstructions,
    },
  });

  // Reset form when brief changes or dialog closes
  useEffect(() => {
    if (!open) {
      reset({
        title: brief.title,
        topic: brief.topic,
        description: brief.description,
        bountyPerArticle: currentBounty,
        maxArticles: currentMaxArticles,
        minWords: currentMinWords,
        maxWords: currentMaxWords,
        customInstructions: currentCustomInstructions,
      });
    }
  }, [open, brief, reset, currentBounty, currentMaxArticles, currentMinWords, currentMaxWords, currentCustomInstructions]);

  const watchedBounty = watch('bountyPerArticle');
  const watchedMaxArticles = watch('maxArticles');

  // Calculate if additional escrow is needed
  const currentTotalEscrow = currentBounty * currentMaxArticles;
  const newTotalEscrow = (watchedBounty || currentBounty) * (watchedMaxArticles || currentMaxArticles);
  const additionalEscrowNeeded = Math.max(0, newTotalEscrow - currentTotalEscrow);

  const onSubmit: SubmitHandler<EditBriefFormData> = async (data) => {
    try {
      // Build update params - only include changed fields
      const updateParams: any = {
        briefId: brief.briefId,
      };

      if (data.title !== brief.title) {
        updateParams.title = data.title;
      }
      if (data.topic !== brief.topic) {
        updateParams.topic = data.topic;
      }
      if (data.description !== brief.description) {
        updateParams.description = data.description;
      }

      // Bounty can only increase - backend will enforce this
      const newBountyE8s = BigInt(Math.floor(data.bountyPerArticle * 100_000_000));
      if (newBountyE8s !== brief.bountyPerArticle) {
        updateParams.bountyPerArticle = newBountyE8s;
      }

      // Max articles can only increase - backend will enforce this
      if (BigInt(data.maxArticles) !== brief.maxArticles) {
        updateParams.maxArticles = BigInt(data.maxArticles);
      }

      // Requirements - check if any changed
      const newMinWords = data.minWords && !isNaN(data.minWords) ? BigInt(data.minWords) : undefined;
      const newMaxWords = data.maxWords && !isNaN(data.maxWords) ? BigInt(data.maxWords) : undefined;
      
      const minWordsChanged = (newMinWords !== undefined) !== (currentMinWords !== undefined) ||
        (newMinWords !== undefined && currentMinWords !== undefined && newMinWords !== BigInt(currentMinWords));
      const maxWordsChanged = (newMaxWords !== undefined) !== (currentMaxWords !== undefined) ||
        (newMaxWords !== undefined && currentMaxWords !== undefined && newMaxWords !== BigInt(currentMaxWords));

      if (minWordsChanged || maxWordsChanged) {
        updateParams.requirements = {
          requiredTopics: brief.requirements?.requiredTopics || [],
          format: brief.requirements?.format?.[0] || null,
          minWords: newMinWords,
          maxWords: newMaxWords,
        };
      }

      // Platform config - update custom instructions if changed
      if (data.customInstructions !== currentCustomInstructions) {
        updateParams.platformConfig = {
          ...brief.platformConfig,
          pinType: brief.platformConfig?.pinType ?? [],
          boardSuggestion: brief.platformConfig?.boardSuggestion ?? [],
          customInstructions: data.customInstructions ? [data.customInstructions] : [],
        };
      }

      // Only submit if there are actual changes
      if (Object.keys(updateParams).length === 1) {
        toast.info('No changes to save');
        return;
      }

      await updateBrief.mutateAsync(updateParams);
      
      toast.success('Brief updated successfully!');
      setOpen(false);
      onSuccess?.();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Failed to update brief');
    }
  };

  // Check if brief is editable (only open briefs can be edited)
  const isEditable = brief.status?.hasOwnProperty('open');

  if (!isEditable) {
    return null;
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" className="gap-2">
          <Pencil className="h-4 w-4" />
          Edit Brief
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Edit Brief</DialogTitle>
          <DialogDescription>
            Update your brief's details. Some changes have restrictions to protect authors who have already submitted.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 mt-4">
          {/* Fairness Notice */}
          <div className="p-4 bg-blue-500/10 border border-blue-500/30 rounded-lg">
            <div className="flex items-start gap-2 text-sm text-blue-400">
              <AlertTriangle className="h-4 w-4 mt-0.5 flex-shrink-0" />
              <div>
                <strong>Fairness Constraints:</strong>
                <ul className="list-disc ml-4 mt-1 space-y-1 text-blue-300">
                  <li>Bounty can only be <strong>increased</strong> (protects authors who submitted)</li>
                  <li>Max articles can only be <strong>increased</strong></li>
                  <li>Expiry can only be <strong>extended</strong></li>
                </ul>
              </div>
            </div>
          </div>

          {/* Title */}
          <div>
            <Label htmlFor="title">Brief Title</Label>
            <Input
              id="title"
              {...register('title')}
              placeholder="e.g., Daily ICP Development Updates"
            />
            {errors.title && (
              <p className="text-sm text-red-500 mt-1">{errors.title.message}</p>
            )}
          </div>

          {/* Topic */}
          <div>
            <Label htmlFor="topic">Content Topic</Label>
            <Input
              id="topic"
              {...register('topic')}
              placeholder="e.g., Internet Computer Protocol Development Updates"
            />
            {errors.topic && (
              <p className="text-sm text-red-500 mt-1">{errors.topic.message}</p>
            )}
          </div>

          {/* Description */}
          <div>
            <Label htmlFor="description">Description</Label>
            <textarea
              id="description"
              {...register('description')}
              placeholder="Describe what you're looking for..."
              className="w-full min-h-[80px] px-3 py-2 border rounded-md bg-background"
            />
            {errors.description && (
              <p className="text-sm text-red-500 mt-1">{errors.description.message}</p>
            )}
          </div>

          {/* Custom Instructions */}
          <div>
            <Label htmlFor="customInstructions">Additional Instructions (optional)</Label>
            <textarea
              id="customInstructions"
              {...register('customInstructions')}
              placeholder="Any specific requirements, tone, style, or content guidelines..."
              className="w-full min-h-[80px] px-3 py-2 border rounded-md bg-background"
            />
            {errors.customInstructions && (
              <p className="text-sm text-red-500 mt-1">{errors.customInstructions.message}</p>
            )}
          </div>

          {/* Word Count Range */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="minWords">Minimum Words</Label>
              <Input
                id="minWords"
                type="number"
                {...register('minWords', { valueAsNumber: true })}
              />
              {errors.minWords && (
                <p className="text-sm text-red-500 mt-1">{errors.minWords.message}</p>
              )}
            </div>
            <div>
              <Label htmlFor="maxWords">Maximum Words</Label>
              <Input
                id="maxWords"
                type="number"
                {...register('maxWords', { valueAsNumber: true })}
              />
              {errors.maxWords && (
                <p className="text-sm text-red-500 mt-1">{errors.maxWords.message}</p>
              )}
            </div>
          </div>

          {/* Bounty and Articles Row */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="bountyPerArticle">
                Bounty per Article (ICP)
                <span className="text-xs text-muted-foreground ml-2">
                  (current: {currentBounty} ICP)
                </span>
              </Label>
              <Input
                id="bountyPerArticle"
                type="number"
                step="0.1"
                min={currentBounty}
                {...register('bountyPerArticle', { valueAsNumber: true })}
              />
              {errors.bountyPerArticle && (
                <p className="text-sm text-red-500 mt-1">{errors.bountyPerArticle.message}</p>
              )}
              <p className="text-xs text-muted-foreground mt-1">
                Can only increase from {currentBounty} ICP
              </p>
            </div>
            <div>
              <Label htmlFor="maxArticles">
                Max Articles
                <span className="text-xs text-muted-foreground ml-2">
                  (current: {currentMaxArticles})
                </span>
              </Label>
              <Input
                id="maxArticles"
                type="number"
                min={currentMaxArticles}
                {...register('maxArticles', { valueAsNumber: true })}
              />
              {errors.maxArticles && (
                <p className="text-sm text-red-500 mt-1">{errors.maxArticles.message}</p>
              )}
              <p className="text-xs text-muted-foreground mt-1">
                Can only increase from {currentMaxArticles}
              </p>
            </div>
          </div>

          {/* Additional Escrow Notice */}
          {additionalEscrowNeeded > 0 && (
            <div className="p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
              <p className="text-sm text-yellow-600 dark:text-yellow-400">
                <strong>Additional Escrow Needed:</strong> {additionalEscrowNeeded.toFixed(2)} ICP
                <span className="block mt-1 text-xs">
                  You'll need to approve this amount for transfer when saving changes.
                </span>
              </p>
            </div>
          )}

          {/* Current Stats */}
          <div className="p-4 bg-black/20 border border-white/10 rounded-lg">
            <h4 className="font-semibold mb-2 text-sm">Current Brief Stats</h4>
            <div className="grid grid-cols-3 gap-4 text-sm">
              <div>
                <span className="text-muted-foreground">Submitted:</span>{' '}
                <span className="font-semibold">{Number(brief.submittedCount)}</span>
              </div>
              <div>
                <span className="text-muted-foreground">Approved:</span>{' '}
                <span className="font-semibold">{Number(brief.approvedCount)}</span>
              </div>
              <div>
                <span className="text-muted-foreground">Escrow:</span>{' '}
                <span className="font-semibold">{(Number(brief.escrowBalance) / 100_000_000).toFixed(2)} ICP</span>
              </div>
            </div>
          </div>

          {/* Submit Button */}
          <div className="flex gap-3 justify-end">
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={updateBrief.isPending || !isDirty}
              style={{ backgroundColor: '#C50022' }}
            >
              {updateBrief.isPending ? 'Saving...' : 'Save Changes'}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
