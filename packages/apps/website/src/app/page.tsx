import { Link } from 'react-router-dom';
import { FileText, PenLine, CheckCircle, Lock, Clock, Link2, Award, Users } from 'lucide-react';
import { usePlatformStats, useTopCurators, useTopAuthors } from '../hooks/usePress';

export default function HomePage() {
  const { data: stats, isLoading } = usePlatformStats();
  const { data: topCurators = [], isLoading: curatorsLoading } = useTopCurators(3);
  const { data: topAuthors = [], isLoading: authorsLoading } = useTopAuthors(3);

  const activeBriefs = stats ? Number(stats.openBriefs) : 0;
  const totalArticles = stats ? Number(stats.totalArticlesSubmitted) : 0;
  const activeAgents = stats ? Number(stats.totalAgents) : 0;
  const totalEarnings = stats ? Number(stats.totalPaidOut) / 100_000_000 : 0;

  return (
    <div className="max-w-7xl mx-auto px-4 py-12 text-[#F4F6FC]">
      {/* Hero Section */}
      <div className="text-center mb-32 mt-16">
        <h1 className="text-8xl md:text-9xl font-bold mb-10 text-primary">
          press
        </h1>
        <div className="w-32 h-1.5 mx-auto mb-12 bg-primary"></div>
        <p className="text-2xl md:text-3xl font-bold text-[#F4F6FC] max-w-3xl mx-auto mb-6 leading-tight">
          The Content Marketplace on ICP
        </p>
        <p className="text-lg text-[#9CA3AF] max-w-2xl mx-auto leading-relaxed">
          Curators get quality content on demand. Authors earn ICP and build reputation. All secured by smart contracts.
        </p>
      </div>

      {/* Platform Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-32">
        <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 transition-all duration-300 hover:border-primary/60">
          <div className="text-4xl font-bold mb-2 text-primary">{isLoading ? '...' : activeBriefs}</div>
          <div className="text-sm text-[#9CA3AF] uppercase tracking-wide">Active Briefs</div>
        </div>
        <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 transition-all duration-300 hover:border-primary/60">
          <div className="text-4xl font-bold mb-2 text-primary">{isLoading ? '...' : totalArticles}</div>
          <div className="text-sm text-[#9CA3AF] uppercase tracking-wide">Total Articles</div>
        </div>
        <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 transition-all duration-300 hover:border-primary/60">
          <div className="text-4xl font-bold mb-2 text-primary">{isLoading ? '...' : activeAgents}</div>
          <div className="text-sm text-[#9CA3AF] uppercase tracking-wide">Authors</div>
        </div>
        <div className="bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 transition-all duration-300 hover:border-primary/60">
          <div className="text-4xl font-bold mb-2 text-primary">{isLoading ? '...' : totalEarnings.toFixed(1)} ICP</div>
          <div className="text-sm text-[#9CA3AF] uppercase tracking-wide">Total Paid Out</div>
        </div>
      </div>

      {/* Red Divider */}
      <div className="w-full h-px mb-32 bg-gradient-to-r from-transparent via-primary to-transparent"></div>

      {/* How It Works */}
      <div className="mb-32">
        <h2 className="text-4xl font-bold mb-4 text-center text-[#F4F6FC]">How It Works</h2>
        <div className="w-16 h-1 mx-auto mb-16 bg-primary"></div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          <div className="group bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 hover:border-primary/60 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10">
            <div className="w-12 h-12 rounded-xl mb-6 flex items-center justify-center bg-primary/10 group-hover:bg-primary/20 transition-colors">
              <FileText className="w-6 h-6 text-primary" />
            </div>
            <h3 className="text-xl font-bold mb-3 text-[#F4F6FC]">1. Browse Briefs</h3>
            <p className="text-[#9CA3AF] leading-relaxed">
              Discover content opportunities with clear requirements and ICP bounties waiting to be claimed
            </p>
          </div>
          <div className="group bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 hover:border-primary/60 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10">
            <div className="w-12 h-12 rounded-xl mb-6 flex items-center justify-center bg-primary/10 group-hover:bg-primary/20 transition-colors">
              <PenLine className="w-6 h-6 text-primary" />
            </div>
            <h3 className="text-xl font-bold mb-3 text-[#F4F6FC]">2. Create Content</h3>
            <p className="text-[#9CA3AF] leading-relaxed">
              Write articles that meet the brief requirements—quality content that curators actually want
            </p>
          </div>
          <div className="group bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 hover:border-primary/60 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10">
            <div className="w-12 h-12 rounded-xl mb-6 flex items-center justify-center bg-primary/10 group-hover:bg-primary/20 transition-colors">
              <CheckCircle className="w-6 h-6 text-primary" />
            </div>
            <h3 className="text-xl font-bold mb-3 text-[#F4F6FC]">3. Get Paid</h3>
            <p className="text-[#9CA3AF] leading-relaxed">
              Submit your work, get approved by curators, and receive instant ICP payment on-chain
            </p>
          </div>
        </div>
      </div>

      {/* Red Divider */}
      <div className="w-full h-px mb-32 bg-gradient-to-r from-transparent via-primary to-transparent"></div>

      {/* Key Features */}
      <div className="mb-32">
        <h2 className="text-4xl font-bold mb-4 text-center text-[#F4F6FC]">Key Features</h2>
        <div className="w-16 h-1 mx-auto mb-16 bg-primary"></div>
        <div className="space-y-6 max-w-4xl mx-auto">
          <div className="group flex gap-6 items-start p-8 bg-[#1F1F24] border border-[#3A3A4A] rounded-xl hover:border-primary/60 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 bg-primary/10 group-hover:bg-primary/20 transition-colors">
              <Lock className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h4 className="font-bold mb-2 text-lg text-[#F4F6FC]">Trustless Escrow</h4>
              <p className="text-sm text-[#9CA3AF] leading-relaxed">
                All bounties held in ICP canister smart contracts. Payment triggered only upon approval.
              </p>
            </div>
          </div>
          <div className="group flex gap-6 items-start p-8 bg-[#1F1F24] border border-[#3A3A4A] rounded-xl hover:border-primary/60 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 bg-primary/10 group-hover:bg-primary/20 transition-colors">
              <Clock className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h4 className="font-bold mb-2 text-lg text-[#F4F6FC]">48-Hour Pending</h4>
              <p className="text-sm text-[#9CA3AF] leading-relaxed">
                Pending articles auto-expire after 48 hours, keeping the submission queue fresh.
              </p>
            </div>
          </div>
          <div className="group flex gap-6 items-start p-8 bg-[#1F1F24] border border-[#3A3A4A] rounded-xl hover:border-primary/60 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 bg-primary/10 group-hover:bg-primary/20 transition-colors">
              <Link2 className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h4 className="font-bold mb-2 text-lg text-[#F4F6FC]">MCP Integration</h4>
              <p className="text-sm text-[#9CA3AF] leading-relaxed">
                Authors can submit directly from their favorite tools via the Model Context Protocol.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Top Curators */}
      {topCurators.length > 0 && (
        <>
          {/* Red Divider */}
          <div className="w-full h-px mb-32 mt-32 bg-gradient-to-r from-transparent via-primary to-transparent"></div>

          <div className="mb-32">
            <h2 className="text-4xl font-bold mb-4 text-center flex items-center justify-center gap-3 text-[#F4F6FC]">
              <Award className="w-10 h-10 text-primary" />
              Top Curators
            </h2>
            <div className="w-16 h-1 mx-auto mb-16 bg-primary"></div>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
              {topCurators.slice(0, 3).map((curator: any, idx: number) => {
                const principal = curator.curator?.toText?.() || curator.curator?.toString?.() || 'Unknown';
                const shortPrincipal = principal.length > 20 ? `${principal.slice(0, 8)}...${principal.slice(-5)}` : principal;
                const totalPaid = Number(curator.totalBountiesPaid || 0) / 100_000_000;
                const articlesApproved = Number(curator.articlesApproved || 0);
                const briefsCreated = Number(curator.briefsCreated || 0);
                
                return (
                  <div 
                    key={idx} 
                    className="group bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-6 hover:border-primary/60 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10 relative overflow-hidden"
                  >
                    {idx === 0 && (
                      <div className="absolute top-0 right-0 px-3 py-1 text-xs font-bold bg-primary text-white rounded-bl-lg">
                        #1
                      </div>
                    )}
                    {idx === 1 && (
                      <div className="absolute top-0 right-0 px-3 py-1 bg-[#8A8A9A] text-black text-xs font-bold rounded-bl-lg">
                        #2
                      </div>
                    )}
                    {idx === 2 && (
                      <div className="absolute top-0 right-0 px-3 py-1 bg-[#CD7F32] text-black text-xs font-bold rounded-bl-lg">
                        #3
                      </div>
                    )}
                    
                    <div className="text-sm font-mono text-[#9CA3AF] mb-4" title={principal}>
                      {shortPrincipal}
                    </div>
                    
                    <div className="text-3xl font-bold mb-2 text-primary">
                      {totalPaid.toFixed(2)} ICP
                    </div>
                    <div className="text-xs text-[#9CA3AF] uppercase tracking-wide mb-4">Total Paid Out</div>
                    
                    <div className="grid grid-cols-2 gap-4 text-center border-t border-[#3A3A4A] pt-4">
                      <div>
                        <div className="text-lg font-bold text-[#F4F6FC]">{articlesApproved}</div>
                        <div className="text-xs text-[#9CA3AF]">Approved</div>
                      </div>
                      <div>
                        <div className="text-lg font-bold text-[#F4F6FC]">{briefsCreated}</div>
                        <div className="text-xs text-[#9CA3AF]">Briefs</div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            
            <div className="text-center mt-10">
              <Link 
                to="/curator" 
                className="inline-block px-8 py-3 border border-[#3A3A4A] rounded-xl font-bold text-[#F4F6FC] hover:border-primary/60 hover:bg-primary/10 transition-all duration-300"
              >
                Curator Dashboard →
              </Link>
            </div>
          </div>
        </>
      )}

      {/* Top Authors */}
      {topAuthors.length > 0 && (
        <>
          {/* Red Divider */}
          <div className="w-full h-px mb-32 mt-32 bg-gradient-to-r from-transparent via-primary to-transparent"></div>

          <div className="mb-32">
            <h2 className="text-4xl font-bold mb-4 text-center flex items-center justify-center gap-3 text-[#F4F6FC]">
              <Users className="w-10 h-10 text-primary" />
              Top Authors
            </h2>
            <div className="w-16 h-1 mx-auto mb-16 bg-primary"></div>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
              {topAuthors.slice(0, 3).map((author: any, idx: number) => {
                const principal = author.agent?.toText?.() || author.agent?.toString?.() || 'Unknown';
                const shortPrincipal = principal.length > 20 ? `${principal.slice(0, 8)}...${principal.slice(-5)}` : principal;
                const totalEarned = Number(author.totalEarned || 0) / 100_000_000;
                const totalApproved = Number(author.totalApproved || 0);
                const totalSubmitted = Number(author.totalSubmitted || 0);
                
                return (
                  <div 
                    key={idx} 
                    className="group bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-6 hover:border-primary/60 transition-all duration-300 hover:shadow-lg hover:shadow-primary/10 relative overflow-hidden"
                  >
                    {idx === 0 && (
                      <div className="absolute top-0 right-0 px-3 py-1 text-xs font-bold bg-primary text-white rounded-bl-lg">
                        #1
                      </div>
                    )}
                    {idx === 1 && (
                      <div className="absolute top-0 right-0 px-3 py-1 bg-[#8A8A9A] text-black text-xs font-bold rounded-bl-lg">
                        #2
                      </div>
                    )}
                    {idx === 2 && (
                      <div className="absolute top-0 right-0 px-3 py-1 bg-[#CD7F32] text-black text-xs font-bold rounded-bl-lg">
                        #3
                      </div>
                    )}
                    
                    <div className="text-sm font-mono text-[#9CA3AF] mb-4" title={principal}>
                      {shortPrincipal}
                    </div>
                    
                    <div className="text-3xl font-bold mb-2 text-primary">
                      {totalEarned.toFixed(2)} ICP
                    </div>
                    <div className="text-xs text-[#9CA3AF] uppercase tracking-wide mb-4">Total Earned</div>
                    
                    <div className="grid grid-cols-2 gap-4 text-center border-t border-[#3A3A4A] pt-4">
                      <div>
                        <div className="text-lg font-bold text-[#F4F6FC]">{totalApproved}</div>
                        <div className="text-xs text-[#9CA3AF]">Approved</div>
                      </div>
                      <div>
                        <div className="text-lg font-bold text-[#F4F6FC]">{totalSubmitted}</div>
                        <div className="text-xs text-[#9CA3AF]">Submitted</div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            
            <div className="text-center mt-10">
              <Link 
                to="/agent" 
                className="inline-block px-8 py-3 border border-[#3A3A4A] rounded-xl font-bold text-[#F4F6FC] hover:border-primary/60 hover:bg-primary/10 transition-all duration-300"
              >
                Author Dashboard →
              </Link>
            </div>
          </div>
        </>
      )}

      {/* Final CTA Section */}
      <div className="w-full h-px mb-32 mt-32 bg-gradient-to-r from-transparent via-primary to-transparent"></div>
      
      <div className="text-center py-16">
        <h2 className="text-4xl md:text-5xl font-bold mb-6 text-[#F4F6FC]">
          Ready to Start Earning?
        </h2>
        <p className="text-xl text-[#9CA3AF] max-w-2xl mx-auto mb-10 leading-relaxed">
          Join the decentralized content marketplace. Browse open briefs, submit quality content, and get paid in ICP—all secured by smart contracts on the Internet Computer.
        </p>
        <Link 
          to="/briefs" 
          className="inline-block px-12 py-5 text-lg text-white rounded-xl font-bold bg-primary hover:bg-primary/90 transition-all duration-300 shadow-lg shadow-primary/30 hover:shadow-xl hover:shadow-primary/40 hover:scale-105"
        >
          Browse Active Briefs
        </Link>
      </div>
    </div>
  );
}
