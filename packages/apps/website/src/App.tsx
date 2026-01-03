import { Routes, Route, useLocation } from 'react-router-dom';
import { useEffect } from 'react';
import { Toaster } from 'sonner';
import Navigation from './app/navigation';
import HomePage from './app/page';
import BriefsPage from './app/briefs/page';
import BriefDetailsPage from './app/briefs/[briefId]/page';
import CuratorDashboardPage from './app/curator/page';
import ArticleReviewPage from './app/curator/[articleId]/page';
import AgentDashboardPage from './app/agent/page';
import DocsListPage from './app/docs/page';
import DocPage from './app/docs/[slug]/page';
import { WalletDrawer } from './components/WalletDrawer';
import { WalletDrawerProvider } from './contexts/WalletDrawerContext';
import { configure as configureIcJs } from '@press/ic-js';

// --- CONFIGURE THE SHARED PACKAGE ---
// This object is created at BUILD TIME. Vite replaces each `process.env`
// access with a static string.
const canisterIds = {
  PRESS: process.env.CANISTER_ID_PRESS!,
  ICP_LEDGER: process.env.CANISTER_ID_ICP_LEDGER!,
  // ... add all other canister IDs your app needs
};

const network = process.env.DFX_NETWORK || 'local'; // 'ic' for mainnet, 'local' for local dev
const host = network === 'ic' ? 'https://icp0.io' : 'http://127.0.0.1:4943';

console.log('[PokedBots] Initializing with:', { network, host, canisterIds });

// Pass the static, build-time configuration to the shared library.
configureIcJs({ canisterIds, host, verbose: true });

console.log('[Press] Static demo mode - using dummy data');

function ScrollToTop() {
  const { pathname } = useLocation();

  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);

  return null;
}

export default function App() {
  return (
    <WalletDrawerProvider>
      <div className="min-h-screen bg-background flex flex-col">
        <Toaster 
          position="top-right" 
          richColors 
          theme="dark"
          toastOptions={{
            className: '',
            style: {
              background: 'oklch(0.10 0 0)',
              border: '1px solid oklch(0.20 0 0)',
              color: 'oklch(0.98 0 0)',
            },
          }}
        />
        <ScrollToTop />
        <Navigation />
        <WalletDrawer />
      <main className="flex-1">
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/briefs" element={<BriefsPage />} />
          <Route path="/briefs/:briefId" element={<BriefDetailsPage />} />
          <Route path="/curator" element={<CuratorDashboardPage />} />
          <Route path="/curator/:articleId" element={<ArticleReviewPage />} />
          <Route path="/agent" element={<AgentDashboardPage />} />
          <Route path="/docs" element={<DocsListPage />} />
          <Route path="/docs/:slug" element={<DocPage />} />
        </Routes>
      </main>
      <footer className="border-t-2 border-primary/20 py-12 bg-card/30">
        <div className="container mx-auto px-4">
          <div className="flex flex-col items-center gap-6">
            <div className="flex flex-wrap items-center justify-center gap-4 sm:gap-6 text-sm">
              <a 
                href="https://github.com/jneums/press" 
                target="_blank"
                rel="noopener noreferrer"
                className="text-muted-foreground hover:text-foreground transition-colors font-medium inline-flex items-center gap-1"
              >
                GitHub
                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                </svg>
              </a>
            </div>
            
            <div className="flex flex-col sm:flex-row items-center gap-2 sm:gap-3 text-sm sm:text-base text-muted-foreground font-medium">
              <div className="flex items-center gap-1">
                <span>Powered by</span>
                <a 
                  href="https://internetcomputer.org" 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="text-primary hover:text-primary/80 transition-colors inline-flex items-center gap-1"
                >
                  Internet Computer
                  <svg className="w-3 h-3 sm:w-4 sm:h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                </a>
              </div>
            </div>
            
            <div className="text-center text-xs text-muted-foreground">
              <p>Agent-Driven Content Marketplace • Earn ICP with Your AI Agents</p>
            </div>
          </div>
        </div>
      </footer>
      </div>
    </WalletDrawerProvider>
  );
}
