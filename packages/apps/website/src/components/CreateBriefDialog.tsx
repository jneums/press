import { useState, useEffect } from 'react';
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
import { Plus, X, RefreshCw, Twitter, Linkedin, FileText, Mail, Youtube, BookOpen, Globe, Pin } from 'lucide-react';
import { toast } from 'sonner';

// Platform types matching backend
type Platform = 'twitter' | 'linkedin' | 'medium' | 'blog' | 'newsletter' | 'youtube' | 'research' | 'pinterest' | 'other';

interface PlatformInfo {
  id: Platform;
  name: string;
  icon: React.ReactNode;
  description: string;
  defaultMinWords: number;
  defaultMaxWords: number;
  characterLimit?: number;
}

const platforms: PlatformInfo[] = [
  {
    id: 'twitter',
    name: 'X / Twitter',
    icon: <Twitter className="h-5 w-5" />,
    description: 'Short posts, threads, and viral content',
    defaultMinWords: 10,
    defaultMaxWords: 280,
    characterLimit: 280,
  },
  {
    id: 'linkedin',
    name: 'LinkedIn',
    icon: <Linkedin className="h-5 w-5" />,
    description: 'Professional posts and long-form articles',
    defaultMinWords: 100,
    defaultMaxWords: 3000,
    characterLimit: 3000,
  },
  {
    id: 'medium',
    name: 'Medium',
    icon: <FileText className="h-5 w-5" />,
    description: 'Long-form articles with SEO optimization',
    defaultMinWords: 500,
    defaultMaxWords: 5000,
  },
  {
    id: 'blog',
    name: 'Blog Post',
    icon: <Globe className="h-5 w-5" />,
    description: 'General blog content for websites',
    defaultMinWords: 300,
    defaultMaxWords: 3000,
  },
  {
    id: 'newsletter',
    name: 'Newsletter',
    icon: <Mail className="h-5 w-5" />,
    description: 'Email newsletters and digests',
    defaultMinWords: 200,
    defaultMaxWords: 2000,
  },
  {
    id: 'youtube',
    name: 'YouTube Script',
    icon: <Youtube className="h-5 w-5" />,
    description: 'Video scripts with timestamps and hooks',
    defaultMinWords: 500,
    defaultMaxWords: 5000,
  },
  {
    id: 'research',
    name: 'Research Article',
    icon: <BookOpen className="h-5 w-5" />,
    description: 'Academic papers and research reports',
    defaultMinWords: 1500,
    defaultMaxWords: 10000,
  },
  {
    id: 'pinterest',
    name: 'Pinterest',
    icon: <Pin className="h-5 w-5" />,
    description: 'Visual pins, idea pins, and board content',
    defaultMinWords: 50,
    defaultMaxWords: 500,
  },
  {
    id: 'other',
    name: 'Other',
    icon: <FileText className="h-5 w-5" />,
    description: 'Custom content with your own specifications',
    defaultMinWords: 100,
    defaultMaxWords: 5000,
  },
];

// Template suggestions for additional instructions
interface InstructionTemplate {
  label: string;
  text: string;
  platforms?: Platform[];
}

const instructionTemplates: InstructionTemplate[] = [
  {
    label: 'Tone: Professional',
    text: 'Write in a professional, authoritative tone. Avoid slang and casual language.',
  },
  {
    label: 'Tone: Casual',
    text: 'Use a conversational, friendly tone. Feel free to use contractions and casual language.',
  },
  {
    label: 'SEO Focus',
    text: 'Optimize for search engines. Include relevant keywords naturally throughout the content.',
    platforms: ['blog', 'medium'],
  },
  {
    label: 'Call to Action',
    text: 'Include a clear call-to-action at the end of the content.',
  },
  {
    label: 'Statistics Required',
    text: 'Include relevant statistics and data points to support claims. Cite sources when possible.',
    platforms: ['blog', 'medium', 'research', 'linkedin'],
  },
  {
    label: 'Visual Description',
    text: 'Include descriptions for accompanying visuals or suggest image placement.',
    platforms: ['blog', 'pinterest', 'medium'],
  },
  {
    label: 'Engagement Focused',
    text: 'Optimize for engagement. Ask questions, use hooks, and encourage comments/shares.',
    platforms: ['twitter', 'linkedin', 'youtube'],
  },
  {
    label: 'How-to Format',
    text: 'Structure as a step-by-step guide with numbered instructions.',
    platforms: ['blog', 'medium', 'youtube', 'pinterest'],
  },
];

const createBriefSchema = z.object({
  title: z.string().min(5, 'Title must be at least 5 characters').max(100, 'Title is too long'),
  topic: z.string().min(5, 'Topic must be at least 5 characters').max(200, 'Topic is too long'),
  platform: z.enum(['twitter', 'linkedin', 'medium', 'blog', 'newsletter', 'youtube', 'research', 'pinterest', 'other']),
  bountyPerArticle: z.number().min(0.1, 'Bounty must be at least 0.1 ICP'),
  maxArticles: z.number().int().min(1, 'Must allow at least 1 article').max(1000, 'Maximum 1000 articles'),
  minWords: z.number().int().min(1, 'Minimum 1 word').max(50000, 'Maximum 50000 words').or(z.nan()).optional(),
  maxWords: z.number().int().min(1, 'Minimum 1 word').max(50000, 'Maximum 50000 words').or(z.nan()).optional(),
  expiresInDays: z.number().int().min(1, 'Must be at least 1 day').max(365, 'Maximum 365 days').or(z.nan()).optional(),
  isRecurring: z.boolean(),
  recurrenceIntervalDays: z.number().int().min(1, 'Must be at least 1 day').max(30, 'Maximum 30 days').or(z.nan()).optional(),
  // Platform-specific fields
  includeHashtags: z.boolean().optional(),
  threadCount: z.number().int().min(1).max(25).or(z.nan()).optional(),
  isLinkedInArticle: z.boolean().optional(),
  mediumTags: z.array(z.string()).optional(),
  includeTimestamps: z.boolean().optional(),
  targetDuration: z.number().int().min(1).max(180).or(z.nan()).optional(),
  subjectLine: z.string().max(100).optional(),
  citationStyle: z.enum(['APA', 'MLA', 'Chicago', 'Harvard', 'IEEE', '']).optional(),
  includeAbstract: z.boolean().optional(),
  customInstructions: z.string().max(2000).optional(),
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
  const [step, setStep] = useState<'platform' | 'details'>('platform');
  const [selectedPlatform, setSelectedPlatform] = useState<Platform | null>(null);
  const [mediumTagInput, setMediumTagInput] = useState('');
  const [mediumTags, setMediumTags] = useState<string[]>([]);
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
    getValues,
  } = useForm<CreateBriefFormData>({
    resolver: zodResolver(createBriefSchema),
    defaultValues: {
      title: '',
      topic: '',
      platform: 'blog',
      maxArticles: 1,
      bountyPerArticle: 1,
      isRecurring: false,
      minWords: 500,
      maxWords: 2000,
      includeHashtags: true,
      isLinkedInArticle: false,
      mediumTags: [],
      includeTimestamps: true,
      includeAbstract: true,
      citationStyle: '',
      customInstructions: '',
    },
  });

  const bountyPerArticle = watch('bountyPerArticle');
  const maxArticles = watch('maxArticles');
  const currentPlatform = watch('platform');

  // Update form defaults when platform changes
  useEffect(() => {
    if (selectedPlatform) {
      const platformInfo = platforms.find(p => p.id === selectedPlatform);
      if (platformInfo) {
        setValue('platform', selectedPlatform);
        setValue('minWords', platformInfo.defaultMinWords);
        setValue('maxWords', platformInfo.defaultMaxWords);
      }
    }
  }, [selectedPlatform, setValue]);

  const handlePlatformSelect = (platformId: Platform) => {
    setSelectedPlatform(platformId);
    setStep('details');
  };

  const handleBack = () => {
    setStep('platform');
  };

  const addMediumTag = () => {
    if (mediumTagInput.trim() && mediumTags.length < 5) {
      const newTags = [...mediumTags, mediumTagInput.trim()];
      setMediumTags(newTags);
      setValue('mediumTags', newTags);
      setMediumTagInput('');
    }
  };

  const removeMediumTag = (index: number) => {
    const newTags = mediumTags.filter((_, i) => i !== index);
    setMediumTags(newTags);
    setValue('mediumTags', newTags);
  };

  const onSubmit: SubmitHandler<CreateBriefFormData> = async (data) => {
    try {
      const expiryDays = data.isRecurring && data.recurrenceIntervalDays && !isNaN(data.recurrenceIntervalDays)
        ? data.recurrenceIntervalDays 
        : (data.expiresInDays && !isNaN(data.expiresInDays) ? data.expiresInDays : undefined);

      const expiresAt = expiryDays
        ? BigInt(Date.now() * 1_000_000 + expiryDays * 24 * 60 * 60 * 1_000_000_000)
        : undefined;

      const recurrenceIntervalNanos = data.isRecurring && data.recurrenceIntervalDays && !isNaN(data.recurrenceIntervalDays)
        ? BigInt(data.recurrenceIntervalDays * 24 * 60 * 60 * 1_000_000_000)
        : undefined;

      // Build platform config
      const platformConfig = {
        platform: { [data.platform]: null },
        includeHashtags: data.platform === 'twitter' ? [data.includeHashtags ?? true] : [],
        threadCount: data.platform === 'twitter' && data.threadCount && !isNaN(data.threadCount) ? [BigInt(data.threadCount)] : [],
        isArticle: data.platform === 'linkedin' ? [data.isLinkedInArticle ?? false] : [],
        tags: data.platform === 'medium' ? mediumTags : [],
        includeTimestamps: data.platform === 'youtube' ? [data.includeTimestamps ?? true] : [],
        targetDuration: data.platform === 'youtube' && data.targetDuration && !isNaN(data.targetDuration) ? [BigInt(data.targetDuration)] : [],
        subjectLine: data.platform === 'newsletter' && data.subjectLine ? [data.subjectLine] : [],
        citationStyle: data.platform === 'research' && data.citationStyle ? [data.citationStyle] : [],
        includeAbstract: data.platform === 'research' ? [data.includeAbstract ?? true] : [],
        pinType: [],
        boardSuggestion: [],
        customInstructions: data.customInstructions ? [data.customInstructions] : [],
      };

      // Build description from platform-specific info
      const platformInfo = platforms.find(p => p.id === data.platform);
      let description = `Platform: ${platformInfo?.name}\n`;
      
      // Add custom instructions first (the main content description)
      if (data.customInstructions) {
        description += `\n${data.customInstructions}`;
      }
      
      // Add hashtag instruction at the bottom after all other instructions
      if (data.platform === 'twitter' && data.includeHashtags) {
        description += `\n\n#️⃣ Include relevant hashtags`;
      }

      const result = await createBrief.mutateAsync({
        title: data.title,
        description,
        topic: data.topic,
        platformConfig,
        requirements: {
          requiredTopics: [],
          format: null,
          minWords: data.minWords && !isNaN(data.minWords) ? BigInt(data.minWords) : undefined,
          maxWords: data.maxWords && !isNaN(data.maxWords) ? BigInt(data.maxWords) : undefined,
        },
        bountyPerArticle: BigInt(Math.floor(data.bountyPerArticle * 100_000_000)),
        maxArticles: BigInt(data.maxArticles),
        expiresAt,
        isRecurring: data.isRecurring,
        recurrenceIntervalNanos,
      });

      await queryClient.invalidateQueries({ queryKey: ['press', 'briefs'] });
      await queryClient.invalidateQueries({ queryKey: ['press', 'stats'] });

      toast.success(
        data.isRecurring 
          ? `Recurring brief created! It will renew every ${data.recurrenceIntervalDays} days. ID: ${result.briefId}`
          : `Brief created successfully! ID: ${result.briefId}`
      );
      setOpen(false);
      resetForm();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Failed to create brief');
    }
  };

  const resetForm = () => {
    reset();
    setStep('platform');
    setSelectedPlatform(null);
    setMediumTags([]);
    setIsRecurring(false);
  };

  const renderPlatformSpecificFields = () => {
    switch (currentPlatform) {
      case 'twitter':
        return (
          <div className="space-y-4 p-4 bg-blue-500/5 border border-blue-500/20 rounded-lg">
            <h4 className="font-semibold text-blue-400 flex items-center gap-2">
              <Twitter className="h-4 w-4" /> X/Twitter Options
            </h4>
            <div className="flex items-center space-x-2">
              <Checkbox
                id="includeHashtags"
                {...register('includeHashtags')}
                defaultChecked={true}
              />
              <Label htmlFor="includeHashtags">Include relevant hashtags</Label>
            </div>
            <div>
              <Label htmlFor="threadCount">Thread Length (leave empty for single post)</Label>
              <Input
                id="threadCount"
                type="number"
                placeholder="e.g., 5 for a 5-tweet thread"
                {...register('threadCount', { valueAsNumber: true })}
              />
              <p className="text-xs text-muted-foreground mt-1">
                Specify number of tweets if you want a thread (1-25)
              </p>
            </div>
          </div>
        );

      case 'linkedin':
        return (
          <div className="space-y-4 p-4 bg-blue-600/5 border border-blue-600/20 rounded-lg">
            <h4 className="font-semibold text-blue-500 flex items-center gap-2">
              <Linkedin className="h-4 w-4" /> LinkedIn Options
            </h4>
            <div className="flex items-center space-x-2">
              <Checkbox
                id="isLinkedInArticle"
                {...register('isLinkedInArticle')}
              />
              <Label htmlFor="isLinkedInArticle">
                LinkedIn Article (longer format, vs regular post)
              </Label>
            </div>
            <p className="text-xs text-muted-foreground">
              Regular posts have a 3,000 character limit. Articles can be much longer.
            </p>
          </div>
        );

      case 'medium':
        return (
          <div className="space-y-4 p-4 bg-green-500/5 border border-green-500/20 rounded-lg">
            <h4 className="font-semibold text-green-400 flex items-center gap-2">
              <FileText className="h-4 w-4" /> Medium Options
            </h4>
            <div>
              <Label>Tags (up to 5 for discoverability)</Label>
              <div className="flex gap-2 mb-2">
                <Input
                  value={mediumTagInput}
                  onChange={(e) => setMediumTagInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      addMediumTag();
                    }
                  }}
                  placeholder="e.g., technology, blockchain"
                  disabled={mediumTags.length >= 5}
                />
                <Button 
                  type="button" 
                  onClick={addMediumTag} 
                  variant="outline"
                  disabled={mediumTags.length >= 5}
                >
                  <Plus className="h-4 w-4" />
                </Button>
              </div>
              {mediumTags.length > 0 && (
                <div className="flex flex-wrap gap-2">
                  {mediumTags.map((tag, index) => (
                    <div
                      key={index}
                      className="px-3 py-1 bg-green-500/10 text-green-400 rounded-full text-sm flex items-center gap-2"
                    >
                      {tag}
                      <button
                        type="button"
                        onClick={() => removeMediumTag(index)}
                        className="hover:text-red-500"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        );

      case 'youtube':
        return (
          <div className="space-y-4 p-4 bg-red-500/5 border border-red-500/20 rounded-lg">
            <h4 className="font-semibold text-red-400 flex items-center gap-2">
              <Youtube className="h-4 w-4" /> YouTube Script Options
            </h4>
            <div className="flex items-center space-x-2">
              <Checkbox
                id="includeTimestamps"
                {...register('includeTimestamps')}
                defaultChecked={true}
              />
              <Label htmlFor="includeTimestamps">Include timestamp markers</Label>
            </div>
            <div>
              <Label htmlFor="targetDuration">Target Video Duration (minutes)</Label>
              <Input
                id="targetDuration"
                type="number"
                placeholder="e.g., 10"
                {...register('targetDuration', { valueAsNumber: true })}
              />
              <p className="text-xs text-muted-foreground mt-1">
                Helps the AI calibrate script length appropriately
              </p>
            </div>
          </div>
        );

      case 'newsletter':
        return (
          <div className="space-y-4 p-4 bg-purple-500/5 border border-purple-500/20 rounded-lg">
            <h4 className="font-semibold text-purple-400 flex items-center gap-2">
              <Mail className="h-4 w-4" /> Newsletter Options
            </h4>
            <div>
              <Label htmlFor="subjectLine">Suggested Subject Line (optional)</Label>
              <Input
                id="subjectLine"
                placeholder="e.g., Weekly ICP Update: What You Missed"
                {...register('subjectLine')}
              />
              <p className="text-xs text-muted-foreground mt-1">
                AI will generate subject line if not provided
              </p>
            </div>
          </div>
        );

      case 'research':
        return (
          <div className="space-y-4 p-4 bg-amber-500/5 border border-amber-500/20 rounded-lg">
            <h4 className="font-semibold text-amber-400 flex items-center gap-2">
              <BookOpen className="h-4 w-4" /> Research Article Options
            </h4>
            <div>
              <Label htmlFor="citationStyle">Citation Style</Label>
              <select
                id="citationStyle"
                className="w-full px-3 py-2 border rounded-md bg-background"
                {...register('citationStyle')}
              >
                <option value="">Select style...</option>
                <option value="APA">APA</option>
                <option value="MLA">MLA</option>
                <option value="Chicago">Chicago</option>
                <option value="Harvard">Harvard</option>
                <option value="IEEE">IEEE</option>
              </select>
            </div>
            <div className="flex items-center space-x-2">
              <Checkbox
                id="includeAbstract"
                {...register('includeAbstract')}
                defaultChecked={true}
              />
              <Label htmlFor="includeAbstract">Include abstract/summary</Label>
            </div>
          </div>
        );

      case 'blog':
      case 'other':
      default:
        return null;
    }
  };

  return (
    <Dialog open={open} onOpenChange={(isOpen) => {
      setOpen(isOpen);
      if (!isOpen) resetForm();
    }}>
      <DialogTrigger asChild>
        <Button style={{ backgroundColor: '#C50022' }}>
          <Plus className="h-4 w-4 mr-2" />
          Create Brief
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
        {step === 'platform' ? (
          <>
            <DialogHeader>
              <DialogTitle>Select Publishing Platform</DialogTitle>
              <DialogDescription>
                Choose where this content will be published. This helps AI agents format content correctly.
              </DialogDescription>
            </DialogHeader>
            <div className="grid grid-cols-2 gap-3 mt-4">
              {platforms.map((platform) => (
                <button
                  key={platform.id}
                  type="button"
                  onClick={() => handlePlatformSelect(platform.id)}
                  className="flex items-start gap-3 p-4 border rounded-lg hover:border-primary hover:bg-primary/5 transition-all text-left"
                >
                  <div className="mt-0.5 text-muted-foreground">{platform.icon}</div>
                  <div>
                    <div className="font-semibold">{platform.name}</div>
                    <div className="text-xs text-muted-foreground">{platform.description}</div>
                  </div>
                </button>
              ))}
            </div>
          </>
        ) : (
          <>
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={handleBack}
                  className="text-muted-foreground hover:text-foreground"
                >
                  ← 
                </button>
                Create {platforms.find(p => p.id === selectedPlatform)?.name} Brief
              </DialogTitle>
              <DialogDescription>
                Configure your content bounty for {platforms.find(p => p.id === selectedPlatform)?.name}
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

              {/* Platform-specific fields */}
              {renderPlatformSpecificFields()}

              {/* Custom Instructions (always shown) */}
              <div>
                <Label htmlFor="customInstructions">Additional Instructions (optional)</Label>
                {/* Template suggestions */}
                <div className="flex flex-wrap gap-1 mb-2 mt-1">
                  {instructionTemplates
                    .filter(t => !t.platforms || t.platforms.includes(currentPlatform as Platform))
                    .map((template, idx) => (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => {
                          const current = getValues('customInstructions') || '';
                          const newValue = current ? `${current}\n${template.text}` : template.text;
                          setValue('customInstructions', newValue);
                        }}
                        className="px-2 py-0.5 text-xs bg-white/5 border border-white/10 rounded hover:bg-white/10 transition-colors"
                      >
                        + {template.label}
                      </button>
                    ))
                  }
                </div>
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
                  <Label htmlFor="minWords">
                    {currentPlatform === 'twitter' ? 'Min Characters' : 'Minimum Words'}
                  </Label>
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
                  <Label htmlFor="maxWords">
                    {currentPlatform === 'twitter' ? 'Max Characters' : 'Maximum Words'}
                  </Label>
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

              {/* Expiry */}
              <div>
                <Label htmlFor="expiresInDays">Expires In (Days)</Label>
                <Input
                  id="expiresInDays"
                  type="number"
                  placeholder="Optional - leave empty for no expiry"
                  {...register('expiresInDays', { valueAsNumber: true })}
                />
                {errors.expiresInDays && (
                  <p className="text-sm text-red-500 mt-1">{errors.expiresInDays.message}</p>
                )}
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
                        The brief will automatically reset every {watch('recurrenceIntervalDays') || 'X'} days.
                      </p>
                    </div>
                    
                    {/* Recurring Cost Summary */}
                    {watch('recurrenceIntervalDays') && watch('expiresInDays') && (
                      <div className="p-3 bg-blue-500/10 border border-blue-500/30 rounded-lg">
                        <p className="text-sm text-blue-400">
                          <strong>💰 Recurring Cost Estimate:</strong>
                        </p>
                        <p className="text-xs text-muted-foreground mt-1">
                          Per cycle: <strong className="text-white">{bountyPerArticle * maxArticles} ICP</strong> ({maxArticles} articles × {bountyPerArticle} ICP)
                        </p>
                        <p className="text-xs text-muted-foreground mt-1">
                          Number of cycles: <strong className="text-white">
                            {Math.ceil((watch('expiresInDays') || 14) / (watch('recurrenceIntervalDays') || 1))}
                          </strong> ({watch('expiresInDays')} days ÷ {watch('recurrenceIntervalDays')} day interval)
                        </p>
                        <p className="text-sm text-blue-300 mt-2 font-semibold">
                          Total potential spend: {(bountyPerArticle * maxArticles * Math.ceil((watch('expiresInDays') || 14) / (watch('recurrenceIntervalDays') || 1))).toFixed(2)} ICP
                        </p>
                      </div>
                    )}
                  </div>
                )}
              </div>

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
                    resetForm();
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
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
