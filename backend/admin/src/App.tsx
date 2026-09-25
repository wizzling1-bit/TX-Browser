import React, { useState } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext.js';
import { Layout } from './components/layout/Layout.js';
import { Login } from './pages/Login.js';
import { Dashboard } from './pages/Dashboard.js';
import { NotificationComposer } from './pages/NotificationComposer.js';
import { NotificationsList } from './pages/NotificationsList.js';
import { Audiences } from './pages/Audiences.js';
import { Devices } from './pages/Devices.js';
import { Analytics } from './pages/Analytics.js';
import { AdminUsers } from './pages/AdminUsers.js';
import { AuditLogs } from './pages/AuditLogs.js';
import { Loader2 } from 'lucide-react';

const AppContent: React.FC = () => {
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
      {currentTab === 'audiences' && <Audiences />}
      {currentTab === 'devices' && <Devices />}
      {currentTab === 'analytics' && <Analytics />}
      {currentTab === 'admin-users' && <AdminUsers />}
      {currentTab === 'audit-logs' && <AuditLogs />}
    </Layout>
  );
};

export const App: React.FC = () => {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
};

export default App;
