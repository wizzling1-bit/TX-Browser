'use client';

import React, { useState } from 'react';
import { Sidebar } from './Sidebar';
import { Header } from './Header';

interface LayoutProps {
  currentTab: string;
  setCurrentTab: (tab: string) => void;
  children: React.ReactNode;
}

const TAB_METADATA: Record<string, { title: string; subtitle: string }> = {
  dashboard: {
    title: 'Executive Dashboard',
    subtitle: 'Real-time telemetry, fleet connectivity & delivery funnel',
  },
  composer: {
    title: 'Campaign Composer',
    subtitle: 'Craft rich notifications with live Android 14+ shade preview',
  },
  notifications: {
    title: 'Notification Campaigns',
    subtitle: 'Broadcast history, scheduled automation & campaign management',
  },
  backlinks: {
    title: 'Target URLs & Campaign Backlinks',
    subtitle: 'Dynamic Google Play Install Referrer generator & acquisition links hub',
  },
  audiences: {
    title: 'Audiences & Topics',
    subtitle: 'Subscriber segments, opt-in permissions & version cohorts',
  },
  devices: {
    title: 'Device Registry',
    subtitle: 'Active mobile fleet, FCM registration tokens & OS metrics',
  },
  analytics: {
    title: 'Analytics & Delivery',
    subtitle: 'End-to-end conversion rates, open metrics & delivery logs',
  },
  'audit-logs': {
    title: 'Audit Logs',
    subtitle: 'Immutable record of administrative operations & security events',
  },
  'admin-users': {
    title: 'Admin Users',
    subtitle: 'RBAC access control, security credentials & team roles',
  },
};

export const Layout: React.FC<LayoutProps> = ({
  currentTab,
  setCurrentTab,
  children,
}) => {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const meta = TAB_METADATA[currentTab] || {
    title: 'Push Notification Console',
    subtitle: 'TX Browser FCM Control Suite',
  };

  return (
    <div className="min-h-screen bg-tx-bg text-tx-cream flex relative overflow-x-hidden">
      {/* Background ambient lighting accents */}
      <div className="fixed top-0 left-64 right-0 h-96 bg-gradient-to-b from-tx-gold/[0.03] to-transparent pointer-events-none -z-10" />

      {/* Sidebar */}
      <Sidebar
        currentTab={currentTab}
        setCurrentTab={setCurrentTab}
        isOpen={sidebarOpen}
        setIsOpen={setSidebarOpen}
      />

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0 lg:pl-64">
        <Header
          onToggleSidebar={() => setSidebarOpen(!sidebarOpen)}
          title={meta.title}
          subtitle={meta.subtitle}
        />

        <main className="flex-1 p-4 sm:p-6 lg:p-8 max-w-7xl w-full mx-auto animate-fade-in">
          {children}
        </main>
      </div>
    </div>
  );
};
