export interface Brief {
  id: string;
  owner: string; // Principal
  bounty_pool: number; // Total ICP allocated
  reward_per_article: number; // Payment for each "Starred" submission
  requirements: {
    topic: string;
    mandatory_mcp_tools: string[]; // e.g., ["racing_mcp.get_results"]
    max_images: number;
  };
  active: boolean;
  created_at: number;
  articles_submitted: number;
  articles_approved: number;
  recurring?: boolean; // If true, accepts multiple submissions on a schedule
  recurring_schedule?: 'daily' | 'weekly' | 'monthly'; // Frequency for recurring briefs
  max_articles_per_period?: number; // Max approved articles per period (e.g., 1 per day)
}

export const DUMMY_BRIEFS: Brief[] = [
  {
    id: "brief-001",
    owner: "rkp4c-7iaaa-aaaaa-aaaca-cai",
    bounty_pool: 50.0,
    reward_per_article: 2.5,
    requirements: {
      topic: "Internet Computer Protocol Development Updates",
      mandatory_mcp_tools: ["github_mcp.get_commits", "web_search.search"],
      max_images: 3,
    },
    active: true,
    created_at: Date.now() - 86400000 * 2, // 2 days ago
    articles_submitted: 12,
    articles_approved: 8,
  },
  {
    id: "brief-002",
    owner: "rrkah-fqaaa-aaaaa-aaaaq-cai",
    bounty_pool: 100.0,
    reward_per_article: 5.0,
    requirements: {
      topic: "DeFi Protocol Analysis on ICP",
      mandatory_mcp_tools: ["blockchain_mcp.get_defi_stats", "price_feed.get_rates"],
      max_images: 5,
    },
    active: true,
    created_at: Date.now() - 86400000 * 5, // 5 days ago
    articles_submitted: 23,
    articles_approved: 15,
  },
  {
    id: "brief-003",
    owner: "rkp4c-7iaaa-aaaaa-aaaca-cai",
    bounty_pool: 25.0,
    reward_per_article: 1.0,
    requirements: {
      topic: "AI Agent Developments in Web3",
      mandatory_mcp_tools: ["web_search.search"],
      max_images: 2,
    },
    active: true,
    created_at: Date.now() - 86400000 * 1, // 1 day ago
    articles_submitted: 7,
    articles_approved: 3,
  },
  {
    id: "brief-004",
    owner: "ryjl3-tyaaa-aaaaa-aaaba-cai",
    bounty_pool: 75.0,
    reward_per_article: 3.5,
    requirements: {
      topic: "Canister Smart Contract Security Audits",
      mandatory_mcp_tools: ["github_mcp.get_repos", "code_analysis.scan_vulnerabilities"],
      max_images: 4,
    },
    active: true,
    created_at: Date.now() - 86400000 * 7, // 7 days ago
    articles_submitted: 18,
    articles_approved: 12,
  },
  {
    id: "brief-005",
    owner: "rrkah-fqaaa-aaaaa-aaaaq-cai",
    bounty_pool: 150.0, // Recurring briefs maintain larger pools
    reward_per_article: 5.0,
    requirements: {
      topic: "Daily ICP Ecosystem News Digest",
      mandatory_mcp_tools: ["web_search.search", "github_mcp.get_trending"],
      max_images: 3,
    },
    active: true,
    recurring: true,
    recurring_schedule: 'daily',
    max_articles_per_period: 1, // Only 1 article approved per day
    created_at: Date.now() - 86400000 * 15, // 15 days ago
    articles_submitted: 32,
    articles_approved: 12, // ~1 per day average
  },
  {
    id: "brief-006",
    owner: "rkp4c-7iaaa-aaaaa-aaaca-cai",
    bounty_pool: 200.0,
    reward_per_article: 10.0,
    requirements: {
      topic: "Weekly DeFi Market Analysis Report",
      mandatory_mcp_tools: ["blockchain_mcp.get_defi_stats", "price_feed.get_rates", "web_search.search"],
      max_images: 8,
    },
    active: true,
    recurring: true,
    recurring_schedule: 'weekly',
    max_articles_per_period: 1, // Only 1 comprehensive report per week
    created_at: Date.now() - 86400000 * 21, // 3 weeks ago
    articles_submitted: 9,
    articles_approved: 3, // 1 per week
  },
];
