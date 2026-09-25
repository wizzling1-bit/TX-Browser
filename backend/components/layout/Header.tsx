'use client';

import React, { useState } from 'react';
import { Menu, LogOut, Send, Zap, Shield } from 'lucide-react';
import { useAuth } from '@/context/AuthContext';
import { SystemHealthModal } from '../SystemHealthModal';
import { TestPushModal } from '../TestPushModal';

interface HeaderProps {
  onToggleSidebar: () => void;
  title: string;
  subtitle?: string;
}

export const Header: React.FC<HeaderProps> = ({ onToggleSidebar, title, subtitle }) => {
  const { user, logout } = useAuth();
  const [showHealthModal, setShowHealthModal] = useState(false);
  const [showTestPushModal, setShowTestPushModal] = useState(false);

  return (
    <>
      <header className="sticky top-0 z-30 flex items-center justify-between h-16 px-4 sm:px-6 lg:px-8 bg-tx-card/90 backdrop-blur-xl border-b border-tx-border shadow-sm">
        {/* Left: Mobile Toggle & Page Title */}
        <div className="flex items-center gap-3 min-w-0">
          <button
            onClick={onToggleSidebar}
            className="p-2 -ml-2 rounded-xl text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface transition-colors lg:hidden active:scale-95"
            aria-label="Open sidebar navigation"
          >
            <Menu className="w-5 h-5" />
          </button>
          <div className="min-w-0">
            <h2 className="text-base sm:text-lg font-bold tracking-tight text-tx-cream truncate">
              {title}
            </h2>
            {subtitle && (
              <p className="text-[11px] text-tx-textMuted hidden sm:block truncate leading-tight">
                {subtitle}
              </p>
            )}
          </div>
        </div>

        {/* Right: Actions, Diagnostics & User Profile */}
        <div className="flex items-center gap-2.5 sm:gap-3 shrink-0">
          {/* Quick Test Push Action Button */}
          <button
            onClick={() => setShowTestPushModal(true)}
            className="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-xl bg-tx-surface hover:bg-tx-elevated border border-tx-border text-xs font-medium text-tx-cream transition-all duration-150 shadow-card hover:-translate-y-0.5 active:scale-95"
            title="Send direct test notification to an individual device FCM token"
          >
            <Send className="w-3.5 h-3.5 text-tx-gold" />
            <span>Test Push</span>
          </button>

          {/* Cloud Sync Diagnostic Badge */}
          <button
            onClick={() => setShowHealthModal(true)}
            className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-emerald-950/60 hover:bg-emerald-950/90 border border-emerald-700/50 text-emerald-300 text-xs font-medium transition-all hover:border-emerald-600/70 group active:scale-95"
            title="Click to view live Supabase DB & Firebase FCM diagnostics"
          >
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse group-hover:scale-125 transition-transform" />
            <span className="hidden md:inline text-[11px] text-emerald-300/80">Cloud:</span>
            <span className="font-semibold text-emerald-200 text-xs">Supabase + FCM</span>
            <Zap className="w-3 h-3 text-emerald-400 ml-0.5 group-hover:rotate-12 transition-transform" />
          </button>

          {/* User Profile Pill */}
          {user && (
            <div className="flex items-center gap-2.5 pl-2 sm:pl-3 border-l border-tx-border">
              <div className="text-right hidden md:block">
                <p className="text-xs font-semibold text-tx-cream tracking-tight leading-tight">
                  {user.name}
                </p>
                <div className="flex items-center justify-end gap-1 text-[10px] text-tx-textMuted font-medium">
                  <Shield className="w-2.5 h-2.5 text-tx-gold" />
                  <span className="capitalize">{user.role.toLowerCase().replace('_', ' ')}</span>
                </div>
              </div>
              <div className="w-8 h-8 rounded-full bg-tx-surface border border-tx-border flex items-center justify-center text-tx-gold font-bold text-xs shadow-card">
                {user.name.charAt(0).toUpperCase()}
              </div>
              <button
                onClick={logout}
                title="Sign Out"
                className="p-1.5 rounded-xl text-tx-textMuted hover:text-rose-400 hover:bg-rose-950/30 transition-all duration-150 active:scale-95"
              >
                <LogOut className="w-4 h-4" />
              </button>
            </div>
          )}
        </div>
      </header>

      {/* Modals */}
      <SystemHealthModal isOpen={showHealthModal} onClose={() => setShowHealthModal(false)} />
      <TestPushModal isOpen={showTestPushModal} onClose={() => setShowTestPushModal(false)} />
    </>
  );
};
