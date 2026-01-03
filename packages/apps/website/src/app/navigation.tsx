import { Link, useLocation } from "react-router-dom";
import { useState } from "react";
import WalletButton from "../components/WalletButton";

export default function Navigation() {
  const location = useLocation();
  const pathname = location.pathname;
  const [isOpen, setIsOpen] = useState(false);
  
  const isActive = (path: string) => {
    if (path === '/') return pathname === '/';
    return pathname.startsWith(path);
  };
  
  const linkClass = (path: string) => {
    const base = "px-4 py-2 rounded-full text-sm font-semibold transition-all duration-300";
    if (isActive(path)) {
      return `${base} text-white shadow-lg`
        .concat(' ', 'bg-[#C50022]');
    }
    return `${base} text-foreground hover:bg-white/5`;
  };
  
  const mobileLinkClass = (path: string) => {
    const base = "block px-4 py-3 text-base font-semibold transition-all border-l-4 rounded-r-lg";
    if (isActive(path)) {
      return `${base} text-white bg-[#C50022] border-[#C50022]`;
    }
    return `${base} text-muted-foreground hover:text-foreground hover:bg-white/5 border-transparent`;
  };
  
  return (
    <>
      {/* Floating Navigation */}
      <header className="fixed top-6 left-1/2 -translate-x-1/2 z-50 w-[95%] max-w-7xl">
        <div className="backdrop-blur-xl border-2 rounded-full shadow-2xl px-8" style={{ backgroundColor: 'rgba(255, 255, 255, 0.02)', borderColor: 'rgba(197, 0, 34, 0.4)', boxShadow: '0 20px 60px rgba(0, 0, 0, 0.8), 0 0 40px rgba(197, 0, 34, 0.3), 0 0 10px rgba(197, 0, 34, 0.5)' }}>
          <div className="flex h-16 items-center justify-between">
            <Link 
              to="/" 
              className="flex flex-col items-center transition-colors group"
            >
              <span className="text-2xl tracking-tight font-bold" style={{ color: '#C50022' }}>press</span>
              <div className="w-8 h-0.5 mt-0.5 transition-all" style={{ background: '#C50022' }}></div>
            </Link>
            
            {/* Desktop Navigation */}
            <nav className="hidden md:flex items-center gap-2">
              <Link to="/briefs" className={linkClass('/briefs')}>
                Active Briefs
              </Link>
              <Link to="/agent" className={linkClass('/agent')}>
                Author Dashboard
              </Link>
              <Link to="/curator" className={linkClass('/curator')}>
                Curator Dashboard
              </Link>
              <Link to="/docs" className={linkClass('/docs')}>
                Docs
              </Link>
              <WalletButton />
            </nav>
            
            {/* Mobile Hamburger Button */}
            <button
              onClick={() => setIsOpen(!isOpen)}
              className="md:hidden p-2 text-foreground hover:text-[#C50022] transition-colors rounded-full hover:bg-white/5"
              aria-label="Toggle menu"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                {isOpen ? (
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                ) : (
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                )}
              </svg>
            </button>
          </div>
        </div>
      </header>

      {/* Add spacing to prevent content from being hidden under floating nav */}
      <div className="h-24" />

      {/* Mobile Menu Overlay */}
      {isOpen && (
        <>
          {/* Backdrop */}
          <div 
            className="fixed inset-0 bg-black/70 backdrop-blur-sm z-40 md:hidden"
            onClick={() => setIsOpen(false)}
          />
          
          {/* Mobile Drawer with Frosted Glass */}
          <div className="fixed top-24 right-4 w-72 z-50 md:hidden">
            <div className="bg-black/60 backdrop-blur-xl border border-white/10 rounded-2xl shadow-2xl overflow-hidden">
              <div className="p-3 border-b border-white/10">
                <WalletButton />
              </div>
              <nav className="flex flex-col p-2">
                <Link 
                  to="/briefs" 
                  className={mobileLinkClass('/briefs')}
                  onClick={() => setIsOpen(false)}
                >
                  Active Briefs
                </Link>
                <Link 
                  to="/agent" 
                  className={mobileLinkClass('/agent')}
                  onClick={() => setIsOpen(false)}
                >
                  Author Dashboard
                </Link>
                <Link 
                  to="/curator" 
                  className={mobileLinkClass('/curator')}
                  onClick={() => setIsOpen(false)}
                >
                  Curator Dashboard
                </Link>
                <Link 
                  to="/docs" 
                  className={mobileLinkClass('/docs')}
                  onClick={() => setIsOpen(false)}
                >
                  Docs
                </Link>
              </nav>
            </div>
          </div>
        </>
      )}
    </>
  );
}
