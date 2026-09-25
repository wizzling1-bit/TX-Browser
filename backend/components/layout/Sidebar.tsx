'use client';

import React from 'react';
import {
  Bell,
  Send,
  Users,
  Smartphone,
  BarChart3,
  ShieldCheck,
  UserCog,
  Compass,
  History,
  PlusCircle,
  X,
  Radio,
  Link2,
} from 'lucide-react';
import { useAuth } from '@/context/AuthContext';

interface SidebarProps {
  currentTab: string;
  setCurrentTab: (tab: string) => void;
  isOpen: boolean;
  setIsOpen: (open: boolean) => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  setCurrentTab,
  isOpen,
  setIsOpen,
}) => {
  const { user } = useAuth();

  const navItems = [
    { id: 'dashboard', label: 'Dashboard', icon: Compass },
    { id: 'composer', label: 'New Campaign', icon: PlusCircle, highlight: true },
    { id: 'notifications', label: 'Campaigns', icon: Bell },
    { id: 'backlinks', label: 'Target URLs / Backlinks', icon: Link2 },
    { id: 'audiences', label: 'Audiences & Topics', icon: Users },
    { id: 'devices', label: 'Device Registry', icon: Smartphone },
    { id: 'analytics', label: 'Analytics & Delivery', icon: BarChart3 },
    ...(user?.role === 'SUPER_ADMIN' || user?.role === 'ADMIN'
      ? [{ id: 'audit-logs', label: 'Audit Trail', icon: History }]
      : []),
    ...(user?.role === 'SUPER_ADMIN'
      ? [{ id: 'admin-users', label: 'Admin Access', icon: UserCog }]
      : []),
  ];

  return (
    <>
      {/* Mobile Backdrop with Blur */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/80 backdrop-blur-sm lg:hidden transition-opacity duration-300"
          onClick={() => setIsOpen(false)}
        />
      )}

      {/* Sidebar Container */}
      <aside
        className={`fixed top-0 bottom-0 left-0 z-50 flex flex-col w-64 bg-tx-card border-r border-tx-border shadow-2xl lg:shadow-none transition-transform duration-300 ease-in-out lg:translate-x-0 ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        {/* Brand Header */}
        <div className="flex items-center justify-between px-5 h-16 border-b border-tx-border bg-tx-card/80">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-tx-gold via-amber-500 to-amber-700 flex items-center justify-center shadow-glow">
              <Send className="w-4 h-4 text-black font-bold" />
            </div>
            <div>
              <div className="flex items-center gap-1.5">
                <span className="font-bold text-sm tracking-tight text-tx-cream">TX Browser</span>
                <span className="text-[9px] font-bold tracking-wider uppercase px-1.5 py-0.5 rounded-full bg-tx-gold/15 border border-tx-gold/40 text-tx-gold">
                  FCM v1
                </span>
              </div>
              <p className="text-[11px] text-tx-textMuted font-medium">Notification Console</p>
            </div>
          </div>

          {/* Close button for mobile screens */}
          <button
            onClick={() => setIsOpen(false)}
            className="p-1.5 rounded-lg text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface lg:hidden"
            aria-label="Close sidebar"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Section Label */}
        <div className="px-5 pt-5 pb-2">
          <p className="text-[10px] font-bold uppercase tracking-wider text-tx-textSubtle">
            Management & Operations
          </p>
        </div>

        {/* Navigation Items */}
        <nav className="flex-1 px-3 space-y-1 overflow-y-auto">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = currentTab === item.id;

            return (
              <button
                key={item.id}
                onClick={() => {
                  setCurrentTab(item.id);
                  setIsOpen(false);
                }}
                className={`w-full group flex items-center gap-3 px-3 py-2.5 rounded-xl text-xs font-medium transition-all duration-150 relative ${
                  isActive
                    ? 'bg-tx-surface text-tx-cream border border-tx-border shadow-card'
                    : item.highlight
                    ? 'text-tx-cream bg-tx-surface/40 hover:bg-tx-surface hover:text-tx-cream border border-transparent hover:border-tx-border/60'
                    : 'text-tx-textMuted hover:bg-tx-surface/50 hover:text-tx-cream'
                }`}
              >
                {/* Active indicator bar */}
                {isActive && (
                  <span className="absolute left-1 top-2.5 bottom-2.5 w-1 rounded-full bg-tx-gold shadow-glow" />
                )}

                <Icon
                  className={`w-4 h-4 ml-1 transition-transform group-hover:scale-110 ${
                    isActive
                      ? 'text-tx-gold'
                      : item.highlight
                      ? 'text-tx-goldLight'
                      : 'text-tx-textSubtle group-hover:text-tx-textMuted'
                  }`}
                />
                <span className="flex-1 text-left tracking-tight font-medium">{item.label}</span>
                {item.highlight && (
                  <span className="flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider px-1.5 py-0.5 rounded-full bg-tx-gold/15 text-tx-gold border border-tx-gold/30">
                    <span className="w-1.5 h-1.5 rounded-full bg-tx-gold animate-pulse" />
                    New
                  </span>
                )}
              </button>
            );
          })}
        </nav>

        {/* Footer Info & Connection Pill */}
        <div className="p-4 border-t border-tx-border bg-tx-surface/60 space-y-2">
          <div className="flex items-center justify-between text-[11px]">
            <div className="flex items-center gap-1.5 text-tx-textMuted font-medium">
              <ShieldCheck className="w-3.5 h-3.5 text-tx-gold" />
              <span>Target SDK 36</span>
            </div>
            <span className="text-[10px] text-tx-textSubtle font-mono">Android 14+</span>
          </div>

          <div className="flex items-center gap-2 px-2.5 py-1.5 rounded-lg bg-tx-card/80 border border-tx-border text-[11px] text-tx-textMuted">
            <Radio className="w-3 h-3 text-emerald-400 animate-pulse" />
            <span className="truncate">Gateway: Dual FCM + Topic</span>
          </div>
        </div>
      </aside>
    </>
  );
};
