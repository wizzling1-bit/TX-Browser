import React from 'react';
import { Menu, LogOut, User, Bell } from 'lucide-react';
import { useAuth } from '../../context/AuthContext.js';

interface HeaderProps {
  onToggleSidebar: () => void;
  title: string;
}

export const Header: React.FC<HeaderProps> = ({ onToggleSidebar, title }) => {
  const { user, logout } = useAuth();

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between h-16 px-4 md:px-8 bg-tx-surface/80 backdrop-blur-md border-b border-tx-border">
      <div className="flex items-center gap-3">
        <button
          onClick={onToggleSidebar}
          className="p-2 -ml-2 rounded-lg text-tx-textMuted hover:text-tx-text hover:bg-tx-card lg:hidden"
          aria-label="Open sidebar"
        >
          <Menu className="w-5 h-5" />
        </button>
        <h2 className="text-lg font-semibold tracking-tight text-tx-cream">{title}</h2>
      </div>

      <div className="flex items-center gap-4">
        {/* Environment Status Badge */}
        <div className="hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-950/60 border border-emerald-800/40 text-emerald-400 text-xs font-medium">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
          <span>FCM Live Gateway</span>
        </div>

        {/* User Pill */}
        {user && (
          <div className="flex items-center gap-3 pl-3 border-l border-tx-border">
            <div className="text-right hidden md:block">
              <p className="text-xs font-medium text-tx-cream">{user.name}</p>
              <p className="text-[10px] text-tx-textDim capitalize">{user.role.toLowerCase()}</p>
            </div>
            <div className="w-8 h-8 rounded-full bg-tx-card border border-tx-borderLight flex items-center justify-center text-tx-sage font-medium text-xs">
              {user.name.charAt(0).toUpperCase()}
            </div>
            <button
              onClick={logout}
              title="Sign Out"
              className="p-1.5 rounded-lg text-tx-textMuted hover:text-rose-400 hover:bg-rose-950/30 transition-colors"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        )}
      </div>
    </header>
  );
};
