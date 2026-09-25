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
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext.js';

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
      {/* Mobile Backdrop */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/70 backdrop-blur-sm lg:hidden"
          onClick={() => setIsOpen(false)}
        />
      )}

      {/* Sidebar Container */}
      <aside
        className={`fixed top-0 bottom-0 left-0 z-50 flex flex-col w-64 bg-tx-surface border-r border-tx-border transition-transform duration-300 ease-in-out lg:translate-x-0 ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        {/* Brand Header */}
        <div className="flex items-center gap-3 px-6 h-16 border-b border-tx-border">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-tx-primary to-emerald-700 flex items-center justify-center shadow-lg shadow-tx-primary/20">
            <Send className="w-5 h-5 text-white" />
          </div>
          <div>
            <h1 className="font-bold text-base tracking-tight text-tx-cream flex items-center gap-1.5">
              TX Browser
              <span className="text-[10px] font-semibold tracking-wider uppercase px-1.5 py-0.5 rounded bg-tx-border text-tx-sage">
                FCM
              </span>
            </h1>
            <p className="text-xs text-tx-textDim">Push Notification Suite</p>
          </div>
        </div>

        {/* Navigation Items */}
        <nav className="flex-1 px-3 py-4 space-y-1.5 overflow-y-auto">
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
                className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-lg text-sm font-medium transition-all ${
                  isActive
                    ? 'bg-tx-card text-tx-cream border-l-4 border-tx-primary shadow-sm'
                    : item.highlight
                    ? 'text-tx-sage bg-tx-card/40 hover:bg-tx-card hover:text-tx-cream'
                    : 'text-tx-textMuted hover:bg-tx-card/60 hover:text-tx-text'
                }`}
              >
                <Icon
                  className={`w-4 h-4 ${
                    isActive ? 'text-tx-primary' : item.highlight ? 'text-tx-sage' : 'text-tx-textDim'
                  }`}
                />
                <span className="flex-1 text-left">{item.label}</span>
                {item.highlight && (
                  <span className="w-2 h-2 rounded-full bg-tx-primary animate-pulse" />
                )}
              </button>
            );
          })}
        </nav>

        {/* Footer info */}
        <div className="p-4 border-t border-tx-border bg-tx-bg/50">
          <div className="flex items-center gap-2 text-xs text-tx-textDim">
            <ShieldCheck className="w-4 h-4 text-tx-primary" />
            <span>Target SDK 36 (Android 14+)</span>
          </div>
        </div>
      </aside>
    </>
  );
};
