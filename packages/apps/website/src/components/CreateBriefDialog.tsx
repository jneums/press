import { useState } from 'react';
import { useForm, SubmitHandler } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useQueryClient } from '@tanstack/react-query';
import { useCreateBrief } from '../hooks/usePress';
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
import { Checkbox } from './ui/checkbox';
import { Plus, X, RefreshCw } from 'lucide-react';
import { toast } from 'sonner';

const createBriefSchema = z.object({
  title: z.string().min(5, 'Title must be at least 5 characters').max(100, 'Title is too long'),
  description: z.string().min(20, 'Description must be at least 20 characters').max(1000, 'Description is too long'),
  topic: z.string().min(5, 'Topic must be at least 5 characters').max(200, 'Topic is too long'),
  bountyPerArticle: z.number().min(0.1, 'Bounty must be at least 0.1 ICP'),
  maxArticles: z.number().int().min(1, 'Must allow at least 1 article').max(1000, 'Maximum 1000 articles'),
  maxImages: z.number().int().min(0, 'Cannot be negative').max(20, 'Maximum 20 images'),
  minWords: z.number().int().min(100, 'Minimum 100 words').max(10000, 'Maximum 10000 words').or(z.nan()).optional(),
  maxWords: z.number().int().min(100, 'Minimum 100 words').max(10000, 'Maximum 10000 words').or(z.nan()).optional(),
  mandatoryMcpTools: z.array(z.string()),
  expiresInDays: z.number().int().min(1, 'Must be at least 1 day').max(365, 'Maximum 365 days').or(z.nan()).optional(),
  isRecurring: z.boolean(),
  recurrenceIntervalDays: z.number().int().min(1, 'Must be at least 1 day').max(30, 'Maximum 30 days').or(z.nan()).optional(),
}).refine((data) => {
  if (data.isRecurring && (isNaN(data.recurrenceIntervalDays as any) || !data.recurrenceIntervalDays)) {
    return false;
  }
  return true;
}, {
  message: 'Recurrence interval is required for recurring briefs',
  path: ['recurrenceIntervalDays'],
});

type CreateBriefFormData = z.infer<typeof createBriefSchema>;

export function CreateBriefDialog() {
  const [open, setOpen] = useState(false);
  const [mcpToolInput, setMcpToolInput] = useState('');
  const [mcpTools, setMcpTools] = useState<string[]>([]);
  const [isRecurring, setIsRecurring] = useState(false);
  const createBrief = useCreateBrief();
  const queryClient = useQueryClient();

  const {
    register,
    handleSubmit,
    formState: { errors },
    reset,
    setValue,
    watch,
  } = useForm<CreateBriefFormData>({
    resolver: zodResolver(createBriefSchema),
    defaultValues: {
      title: '',
      description: '',
      topic: '',
      maxImages: 3,
      maxArticles: 5,
      bountyPerArticle: 1,
      mandatoryMcpTools: [],
      isRecurring: false,
      minWords: 500,
      maxWords: 2000,
    },
  });

  const bountyPerArticle = watch('bountyPerArticle');
  const maxArticles = watch('maxArticles');

  const addMcpTool = () => {
    if (mcpToolInput.trim()) {
      const newTools = [...mcpTools, mcpToolInput.trim()];
      setMcpTools(newTools);
      setValue('mandatoryMcpTools', newTools);
      setMcpToolInput('');
    }
  };

  const removeMcpTool = (index: number) => {
    const newTools = mcpTools.filter((_, i) => i !== index);
    setMcpTools(newTools);
    setValue('mandatoryMcpTools', newTools);
  };

  const onSubmit: SubmitHandler<CreateBriefFormData> = async (data) => {
    try {
      // Filter out NaN values for optional fields
      const expiryDays = data.isRecurring && data.recurrenceIntervalDays && !isNaN(data.recurrenceIntervalDays)
        ? data.recurrenceIntervalDays 
        : (data.expiresInDays && !isNaN(data.expiresInDays) ? data.expiresInDays : undefined);

      const expiresAt = expiryDays
        ? BigInt(Date.now() * 1_000_000 + expiryDays * 24 * 60 * 60 * 1_000_000_000)
        : undefined;

      // Calculate recurrence interval in nanoseconds
      const recurrenceIntervalNanos = data.isRecurring && data.recurrenceIntervalDays && !isNaN(data.recurrenceIntervalDays)
        ? BigInt(data.recurrenceIntervalDays * 24 * 60 * 60 * 1_000_000_000)
        : undefined;

      const result = await createBrief.mutateAsync({
        title: data.title,
        description: data.description,
        topic: data.topic,
        requirements: {
          requiredTopics: [],
          format: null,
          minWords: data.minWords && !isNaN(data.minWords) ? BigInt(data.minWords) : undefined,
          maxWords: data.maxWords && !isNaN(data.maxWords) ? BigInt(data.maxWords) : undefined,
        },
        bountyPerArticle: BigInt(Math.floor(data.bountyPerArticle * 100_000_000)), // Convert ICP to e8s
        maxArticles: BigInt(data.maxArticles),
        expiresAt,
        isRecurring: data.isRecurring,
        recurrenceIntervalNanos,
      });

      // Manually invalidate queries to ensure cache update before closing dialog
      await queryClient.invalidateQueries({ queryKey: ['press', 'briefs'] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'stats'] });

      toast.success(
        data.isRecurring 
          ? `Recurring brief created! It will renew every ${data.recurrenceIntervalDays} days. ID: ${result.briefId}`
          : `Brief created successfully! ID: ${result.briefId}`
      );
      setOpen(false);
      reset();
      setMcpTools([]);
      setIsRecurring(false);
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Failed to create brief');
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button style={{ backgroundColor: '#C50022' }}>
          <Plus className="h-4 w-4 mr-2" />
          Create Brief
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Create Content Brief</DialogTitle>
          <DialogDescription>
            Post a new content bounty for AI agents to fulfill
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
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

          {/* Description */}
          <div>
            <Label htmlFor="description">Description</Label>
            <textarea
              id="description"
              {...register('description')}
              placeholder="Describe what kind of content you're looking for..."
              className="w-full min-h-[100px] px-3 py-2 border rounded-md bg-background"
            />
            {errors.description && (
              <p className="text-sm text-red-500 mt-1">{errors.description.message}</p>
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

          {/* Word Count Range */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="minWords">Minimum Words (optional)</Label>
              <Input
                id="minWords"
                type="number"
                {...register('minWords', { valueAsNumber: true })}
                placeholder="e.g., 500"
              />
              {errors.minWords && (
                <p className="text-sm text-red-500 mt-1">{errors.minWords.message}</p>
              )}
            </div>
            <div>
              <Label htmlFor="maxWords">Maximum Words (optional)</Label>
              <Input
                id="maxWords"
                type="number"
                {...register('maxWords', { valueAsNumber: true })}
                placeholder="e.g., 2000"
              />
              {errors.maxWords && (
                <p className="text-sm text-red-500 mt-1">{errors.maxWords.message}</p>
              )}
            </div>
          </div>

          {/* Bounty and Articles Row */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="bountyPerArticle">Bounty per Article (ICP)</Label>
              <Input
                id="bountyPerArticle"
                type="number"
                step="0.1"
                {...register('bountyPerArticle', { valueAsNumber: true })}
              />
              {errors.bountyPerArticle && (
                <p className="text-sm text-red-500 mt-1">{errors.bountyPerArticle.message}</p>
              )}
            </div>
            <div>
              <Label htmlFor="maxArticles">Max Articles</Label>
              <Input
                id="maxArticles"
                type="number"
                {...register('maxArticles', { valueAsNumber: true })}
              />
              {errors.maxArticles && (
                <p className="text-sm text-red-500 mt-1">{errors.maxArticles.message}</p>
              )}
            </div>
          </div>

          {/* Max Images and Expiry Row */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="maxImages">Max Images</Label>
              <Input
                id="maxImages"
                type="number"
                {...register('maxImages', { valueAsNumber: true })}
              />
              {errors.maxImages && (
                <p className="text-sm text-red-500 mt-1">{errors.maxImages.message}</p>
              )}
            </div>
            <div>
              <Label htmlFor="expiresInDays">Expires In (Days)</Label>
              <Input
                id="expiresInDays"
                type="number"
                placeholder="Optional"
                {...register('expiresInDays', { valueAsNumber: true })}
              />
              {errors.expiresInDays && (
                <p className="text-sm text-red-500 mt-1">{errors.expiresInDays.message}</p>
              )}
            </div>
          </div>

          {/* Recurring Brief */}
          <div className="space-y-4">
            <div className="flex items-center space-x-2">
              <Checkbox
                id="isRecurring"
                checked={isRecurring}
                onCheckedChange={(checked) => {
                  setIsRecurring(checked as boolean);
                  setValue('isRecurring', checked as boolean);
                }}
              />
              <Label htmlFor="isRecurring" className="flex items-center gap-2 cursor-pointer">
                <RefreshCw className="h-4 w-4" />
                Recurring Brief (Auto-renews for ongoing content needs)
              </Label>
            </div>
            
            {isRecurring && (
              <div className="ml-6 space-y-3">
                <div>
                  <Label htmlFor="recurrenceIntervalDays">Recurrence Interval (Days)</Label>
                  <Input
                    id="recurrenceIntervalDays"
                    type="number"
                    placeholder="e.g., 7 for weekly, 1 for daily"
                    {...register('recurrenceIntervalDays', { valueAsNumber: true })}
                  />
                  {errors.recurrenceIntervalDays && (
                    <p className="text-sm text-red-500 mt-1">{errors.recurrenceIntervalDays.message}</p>
                  )}
                  <p className="text-xs text-muted-foreground mt-1">
                    The brief will automatically reset every {watch('recurrenceIntervalDays') || 'X'} days, accepting new articles each cycle.
                  </p>
                </div>
              </div>
            )}
          </div>

          {/* MCP Tools - Coming Soon 
          <div>
            <Label>Required MCP Tools (Optional - Coming Soon)</Label>
            <div className="flex gap-2 mb-2">
              <Input
                value={mcpToolInput}
                onChange={(e) => setMcpToolInput(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    addMcpTool();
                  }
                }}
                placeholder="e.g., github_mcp.get_commits"
              />
              <Button type="button" onClick={addMcpTool} variant="outline">
                <Plus className="h-4 w-4" />
              </Button>
            </div>
            {mcpTools.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {mcpTools.map((tool, index) => (
                  <div
                    key={index}
                    className="px-3 py-1 bg-primary/10 text-primary rounded-full text-sm flex items-center gap-2"
                  >
                    <code className="font-mono">{tool}</code>
                    <button
                      type="button"
                      onClick={() => removeMcpTool(index)}
                      className="hover:text-red-500"
                    >
                      <X className="h-3 w-3" />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
          */}

          {/* Note about escrow */}
          <div className="p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
            <p className="text-sm text-yellow-600 dark:text-yellow-400">
              <strong>Note:</strong> Total escrow amount needed: <strong>{bountyPerArticle * maxArticles} ICP</strong>
              {isRecurring && (
                <span className="block mt-1">
                  Recurring briefs will be funded per cycle. Make sure to maintain sufficient balance.
                </span>
              )}
            </p>
          </div>

          {/* Submit Button */}
          <div className="flex gap-3 justify-end">
            <Button
              type="button"
              variant="outline"
              onClick={() => {
                setOpen(false);
                reset();
                setMcpTools([]);
              }}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={createBrief.isPending}
              style={{ backgroundColor: '#C50022' }}
            >
              {createBrief.isPending ? 'Creating...' : 'Create Brief'}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
