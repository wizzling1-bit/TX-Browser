'use client';

import React, { useState } from 'react';
import { useAuth } from '@/context/AuthContext';
import { Layout } from '@/components/layout/Layout';
import { Login } from '@/components/pages/Login';
import { Dashboard } from '@/components/pages/Dashboard';
import { NotificationComposer } from '@/components/pages/NotificationComposer';
import { NotificationsList } from '@/components/pages/NotificationsList';
import { CampaignBacklinks } from '@/components/pages/CampaignBacklinks';
import { Audiences } from '@/components/pages/Audiences';
import { Devices } from '@/components/pages/Devices';
import { Analytics } from '@/components/pages/Analytics';
import { AdminUsers } from '@/components/pages/AdminUsers';
import { AuditLogs } from '@/components/pages/AuditLogs';
import { Loader2 } from 'lucide-react';

export default function HomePage() {
  const { user, loading } = useAuth();
  const [currentTab, setCurrentTab] = useState('dashboard');
  const [selectedNotificationId, setSelectedNotificationId] = useState<string | undefined>();
  const [composerInitialData, setComposerInitialData] = useState<any>(undefined);

  if (loading) {
    return (
      <div className="min-h-screen bg-tx-bg flex items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="w-8 h-8 animate-spin text-tx-primary" />
          <p className="text-xs text-tx-textDim font-medium">Connecting to TX Gateway...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return <Login />;
  }

  const navigateTo = (tab: string, meta?: any) => {
    if (meta?.selectedId) {
      setSelectedNotificationId(meta.selectedId);
    }
    if (meta?.initialData) {
      setComposerInitialData(meta.initialData);
    }
    setCurrentTab(tab);
  };

  return (
    <Layout currentTab={currentTab} setCurrentTab={setCurrentTab}>
      {currentTab === 'dashboard' && <Dashboard onNavigate={navigateTo} />}
      {currentTab === 'composer' && (
        <NotificationComposer
          initialData={composerInitialData}
          onSuccess={() => {
            setComposerInitialData(undefined);
            setCurrentTab('notifications');
          }}
        />
      )}
      {currentTab === 'notifications' && (
        <NotificationsList
          onNavigate={navigateTo}
          selectedId={selectedNotificationId}
        />
      )}
      {currentTab === 'backlinks' && (
        <CampaignBacklinks
          onNavigateToComposer={(initialData) => {
            navigateTo('composer', { initialData });
          }}
        />
      )}
      {currentTab === 'audiences' && <Audiences />}
      {currentTab === 'devices' && <Devices />}
      {currentTab === 'analytics' && <Analytics />}
      {currentTab === 'admin-users' && <AdminUsers />}
      {currentTab === 'audit-logs' && <AuditLogs />}
    </Layout>
  );
}
