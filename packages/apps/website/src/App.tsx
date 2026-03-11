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
import DraftArticleEditPage from './app/agent/[articleId]/page';
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
      <div className="min-h-screen flex flex-col">
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
          <Route path="/agent/:articleId" element={<DraftArticleEditPage />} />
          <Route path="/agent" element={<AgentDashboardPage />} />
          <Route path="/docs" element={<DocsListPage />} />
          <Route path="/docs/:slug" element={<DocPage />} />
        </Routes>
      </main>
      <footer className="border-t border-[#3A3A4A] py-8 mt-16 bg-[#181A20]">
        <div className="container mx-auto px-4">
          <div className="flex flex-col md:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-2">
              <span className="text-xl font-bold text-primary">press</span>
            </div>
            
            <div className="flex items-center gap-6 text-sm">
              <a 
                href="https://github.com/jneums/press" 
                target="_blank"
                rel="noopener noreferrer"
                className="text-[#9CA3AF] hover:text-primary transition-colors duration-300"
              >
                GitHub
              </a>
              <a 
                href="https://internetcomputer.org" 
                target="_blank" 
                rel="noopener noreferrer"
                className="text-[#9CA3AF] hover:text-primary transition-colors duration-300"
              >
                Internet Computer
              </a>
            </div>
            
            <div className="text-xs text-[#9CA3AF]">
              © 2026 Press
            </div>
          </div>
        </div>
      </footer>
      </div>
    </WalletDrawerProvider>
  );
}
