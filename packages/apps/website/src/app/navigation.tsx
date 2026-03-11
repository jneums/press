import { Link, useLocation } from "react-router-dom";
import { useState } from "react";
import WalletButton from "../components/WalletButton";

export default function Navigation() {
  const location = useLocation();
  const pathname = location.pathname;
  const [isOpen, setIsOpen] = useState(false);
  
  const isActive = (path: string) => {
    if (path === '/') return pathname === '/';
    // Only exact match for main sections, not sub-pages
    if (path === '/briefs') return pathname === '/briefs';
    if (path === '/agent') return pathname === '/agent' || pathname.startsWith('/agent/');
    if (path === '/curator') return pathname === '/curator' || pathname.startsWith('/curator/');
    if (path === '/docs') return pathname === '/docs' || pathname.startsWith('/docs/');
    return pathname === path;
  };
  
  const linkClass = (path: string) => {
    const base = "px-4 py-2 rounded-full text-sm font-semibold transition-all duration-300 relative";
    if (isActive(path)) {
      return `${base} text-white bg-primary shadow-lg shadow-primary/30`;
    }
    return `${base} text-[#F4F6FC] hover:text-primary hover:bg-white/5`;
  };
  
  const mobileLinkClass = (path: string) => {
    const base = "block px-4 py-3 text-base font-semibold transition-all border-l-4 rounded-r-lg";
    if (isActive(path)) {
      return `${base} text-white bg-primary border-primary`;
    }
    return `${base} text-[#9CA3AF] hover:text-[#F4F6FC] hover:bg-white/5 border-transparent`;
  };
  
  return (
    <>
      {/* Floating Navigation */}
      <header className="fixed top-6 left-1/2 -translate-x-1/2 z-50 w-[95%] max-w-6xl">
        <div className="backdrop-blur-xl bg-[#181A20]/80 border border-[#3A3A4A] rounded-full shadow-2xl px-8">
          <div className="flex h-16 items-center justify-between">
            <Link 
              to="/" 
              className="flex flex-col items-center transition-colors group"
            >
              <span className="text-2xl tracking-tight font-bold text-primary">press</span>
              <div className="w-8 h-0.5 mt-0.5 transition-all bg-primary"></div>
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
              className="md:hidden p-2 text-[#F4F6FC] hover:text-primary transition-colors rounded-full hover:bg-white/5"
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
            <div className="bg-[#181A20]/95 backdrop-blur-xl border border-[#3A3A4A] rounded-2xl shadow-2xl overflow-hidden">
              <div className="p-3 border-b border-[#3A3A4A]">
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
