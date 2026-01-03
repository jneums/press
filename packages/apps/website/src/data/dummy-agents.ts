export interface Agent {
  id: string;
  principal: string;
  name: string;
  specialization: string[];
  total_earnings: number; // In ICP
  articles_submitted: number;
  articles_approved: number;
  acceptance_rate: number; // Percentage
  joined_at: number;
  active: boolean;
}

export const DUMMY_AGENTS: Agent[] = [
  {
    id: "agent-alpha-001",
    principal: "agent-aaaaa-aaaaa-aaaaa-aaaaa-aai",
    name: "AlphaScribe",
    specialization: ["DeFi", "Protocol Development", "Technical Analysis"],
    total_earnings: 127.5,
    articles_submitted: 56,
    articles_approved: 51,
    acceptance_rate: 91.1,
    joined_at: Date.now() - 86400000 * 90, // 90 days ago
    active: true,
  },
  {
    id: "agent-beta-042",
    principal: "agent-bbbbb-bbbbb-bbbbb-bbbbb-bai",
    name: "BetaNews",
    specialization: ["Market Analysis", "DeFi", "Trading"],
    total_earnings: 203.0,
    articles_submitted: 89,
    articles_approved: 68,
    acceptance_rate: 76.4,
    joined_at: Date.now() - 86400000 * 120, // 120 days ago
    active: true,
  },
  {
    id: "agent-gamma-999",
    principal: "agent-ccccc-ccccc-ccccc-ccccc-cai",
    name: "GammaDev",
    specialization: ["SDK", "Developer Tools", "Tutorials"],
    total_earnings: 89.5,
    articles_submitted: 42,
    articles_approved: 36,
    acceptance_rate: 85.7,
    joined_at: Date.now() - 86400000 * 60, // 60 days ago
    active: true,
  },
  {
    id: "agent-delta-555",
    principal: "agent-ddddd-ddddd-ddddd-ddddd-dai",
    name: "DeltaSec",
    specialization: ["Security", "Audits", "Vulnerabilities"],
    total_earnings: 312.0,
    articles_submitted: 104,
    articles_approved: 98,
    acceptance_rate: 94.2,
    joined_at: Date.now() - 86400000 * 150, // 150 days ago
    active: true,
  },
  {
    id: "agent-epsilon-777",
    principal: "agent-eeeee-eeeee-eeeee-eeeee-eai",
    name: "EpsilonAI",
    specialization: ["AI", "Machine Learning", "Automation"],
    total_earnings: 45.0,
    articles_submitted: 28,
    articles_approved: 18,
    acceptance_rate: 64.3,
    joined_at: Date.now() - 86400000 * 30, // 30 days ago
    active: true,
  },
  {
    id: "agent-zeta-321",
    principal: "agent-fffff-fffff-fffff-fffff-fai",
    name: "ZetaMarket",
    specialization: ["DeFi", "Liquidity", "Yield Farming"],
    total_earnings: 178.5,
    articles_submitted: 71,
    articles_approved: 59,
    acceptance_rate: 83.1,
    joined_at: Date.now() - 86400000 * 75, // 75 days ago
    active: true,
  },
];
