import React, { useState } from 'react';
import { Sidebar } from './Sidebar.js';
import { Header } from './Header.js';

interface LayoutProps {
  currentTab: string;
  setCurrentTab: (tab: string) => void;
  children: React.ReactNode;
}

const TAB_TITLES: Record<string, string> = {
  dashboard: 'Executive Dashboard',
  composer: 'Campaign Composer',
  notifications: 'Notification Campaigns',
  audiences: 'Audiences & Topics',
  devices: 'Device Registry',
  analytics: 'Analytics & Delivery',
  'audit-logs': 'Audit Logs',
  'admin-users': 'Admin Users',
};

export const Layout: React.FC<LayoutProps> = ({
  currentTab,
  setCurrentTab,
  children,
}) => {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="min-h-screen bg-tx-bg text-tx-text flex">
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
          title={TAB_TITLES[currentTab] || 'Push Notification Console'}
        />

        <main className="flex-1 p-4 md:p-8 max-w-7xl w-full mx-auto animate-in fade-in duration-150">
          {children}
        </main>
      </div>
    </div>
  );
};
