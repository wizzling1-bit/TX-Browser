import React, { useEffect, useState } from 'react';
import {
  Smartphone,
  CheckCircle2,
  Eye,
  PlusCircle,
  RefreshCw,
  ArrowUpRight,
  TrendingUp,
} from 'lucide-react';
import { api } from '../lib/api.js';
import { AnalyticsOverview, AudienceStats, NotificationItem } from '../types/index.js';

interface DashboardProps {
  onNavigate: (tab: string, meta?: any) => void;
}

export const Dashboard: React.FC<DashboardProps> = ({ onNavigate }) => {
  const [analytics, setAnalytics] = useState<AnalyticsOverview | null>(null);
  const [audience, setAudience] = useState<AudienceStats | null>(null);
  const [recentNotifications, setRecentNotifications] = useState<NotificationItem[]>([]);
  const [loading, setLoading] = useState(true);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      const [analyticsData, audienceData, notifsData] = await Promise.all([
        api.get<AnalyticsOverview>('/analytics/overview'),
        api.get<AudienceStats>('/audiences/stats'),
        api.get<{ items: NotificationItem[] }>('/notifications?limit=5'),
      ]);

      setAnalytics(analyticsData);
      setAudience(audienceData);
      setRecentNotifications(notifsData.items || []);
    } catch (err) {
      console.error('Failed to load dashboard data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDashboardData();
  }, []);

  return (
    <div className="space-y-6">
      {/* Top Banner & Actions */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-tx-cream tracking-tight">Overview & Performance</h2>
          <p className="text-xs text-tx-textMuted mt-0.5">
            Real-time delivery pipeline metrics and device distribution
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={loadDashboardData}
            disabled={loading}
            className="px-3 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-textMuted hover:text-tx-cream text-xs font-medium flex items-center gap-2 transition-colors"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh</span>
          </button>

          <button
            onClick={() => onNavigate('composer')}
            className="px-4 py-2 rounded-xl bg-tx-primary hover:bg-tx-primaryHover text-white text-xs font-medium flex items-center gap-2 transition-all shadow-md shadow-tx-primary/20"
          >
            <PlusCircle className="w-4 h-4" />
            <span>Create Campaign</span>
          </button>
        </div>
      </div>

      {/* KPI Bento Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Total Devices */}
        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border relative overflow-hidden">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-medium text-tx-textMuted">Total Device Fleet</span>
            <div className="w-8 h-8 rounded-lg bg-emerald-950/60 border border-emerald-800/30 flex items-center justify-center">
              <Smartphone className="w-4 h-4 text-emerald-400" />
            </div>
          </div>
          <p className="text-2xl font-bold text-tx-cream tracking-tight">
            {audience?.summary.totalInstallations.toLocaleString() ?? '—'}
          </p>
          <div className="mt-2 flex items-center gap-1.5 text-[11px] text-tx-sage">
            <CheckCircle2 className="w-3.5 h-3.5" />
            <span>{audience?.summary.activeInstallations ?? 0} active installations</span>
          </div>
        </div>

        {/* Card 2: 30-Day Active Users */}
        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border relative overflow-hidden">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-medium text-tx-textMuted">Active Last 30 Days</span>
            <div className="w-8 h-8 rounded-lg bg-blue-950/60 border border-blue-800/30 flex items-center justify-center">
              <TrendingUp className="w-4 h-4 text-blue-400" />
            </div>
          </div>
          <p className="text-2xl font-bold text-tx-cream tracking-tight">
            {audience?.summary.activeLast30Days.toLocaleString() ?? '—'}
          </p>
          <div className="mt-2 text-[11px] text-tx-textDim">
            Ready for instant targeted push
          </div>
        </div>

        {/* Card 3: Permission Opt-in */}
        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border relative overflow-hidden">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-medium text-tx-textMuted">Permission Granted</span>
            <div className="w-8 h-8 rounded-lg bg-tx-card border border-tx-borderLight flex items-center justify-center">
              <CheckCircle2 className="w-4 h-4 text-tx-primary" />
            </div>
          </div>
          <p className="text-2xl font-bold text-tx-cream tracking-tight">
            {audience?.summary.grantedPercentage ?? 0}%
          </p>
          <div className="mt-2 flex items-center gap-1.5 text-[11px] text-tx-textDim">
            <span>{audience?.summary.permissionGranted.toLocaleString() ?? 0} devices opted-in</span>
          </div>
        </div>

        {/* Card 4: Open Rate */}
        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border relative overflow-hidden">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-medium text-tx-textMuted">Overall Open Rate</span>
            <div className="w-8 h-8 rounded-lg bg-purple-950/60 border border-purple-800/30 flex items-center justify-center">
              <Eye className="w-4 h-4 text-purple-400" />
            </div>
          </div>
          <p className="text-2xl font-bold text-tx-cream tracking-tight">
            {analytics?.summary.overallOpenRate ?? 0}%
          </p>
          <div className="mt-2 flex items-center gap-1.5 text-[11px] text-tx-textDim">
            <span>{analytics?.summary.openedDeliveries.toLocaleString() ?? 0} opens tracked</span>
          </div>
        </div>
      </div>

      {/* Two Column Layout: Recent Campaigns + Topic Subscriptions */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left: Recent Campaigns (2 Cols) */}
        <div className="lg:col-span-2 p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-sm font-semibold text-tx-cream">Recent Campaigns</h3>
              <p className="text-xs text-tx-textDim">Latest broadcast & scheduled notifications</p>
            </div>
            <button
              onClick={() => onNavigate('notifications')}
              className="text-xs text-tx-primary hover:text-tx-primaryHover font-medium flex items-center gap-1"
            >
              <span>View All</span>
              <ArrowUpRight className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-tx-border text-tx-textDim font-medium">
                  <th className="pb-3 pl-1">Campaign</th>
                  <th className="pb-3">Type</th>
                  <th className="pb-3">Status</th>
                  <th className="pb-3">Sent / Reach</th>
                  <th className="pb-3 text-right pr-1">Created</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-tx-border/50">
                {recentNotifications.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-8 text-center text-tx-textDim">
                      No notifications created yet. Click "Create Campaign" to begin.
                    </td>
                  </tr>
                ) : (
                  recentNotifications.map((notif) => {
                    const statusColor =
                      notif.status === 'SENT'
                        ? 'bg-emerald-950/50 text-emerald-400 border-emerald-800/40'
                        : notif.status === 'SCHEDULED'
                        ? 'bg-amber-950/50 text-amber-400 border-amber-800/40'
                        : notif.status === 'QUEUED' || notif.status === 'SENDING'
                        ? 'bg-blue-950/50 text-blue-400 border-blue-800/40'
                        : 'bg-zinc-900 text-zinc-400 border-zinc-700';

                    return (
                      <tr
                        key={notif.id}
                        onClick={() => onNavigate('notifications', { selectedId: notif.id })}
                        className="hover:bg-tx-card/60 transition-colors cursor-pointer"
                      >
                        <td className="py-3 pl-1 font-medium text-tx-cream max-w-[200px] truncate">
                          {notif.title}
                        </td>
                        <td className="py-3">
                          <span className="text-[11px] px-2 py-0.5 rounded bg-tx-card text-tx-textMuted border border-tx-border">
                            {notif.notificationType}
                          </span>
                        </td>
                        <td className="py-3">
                          <span
                            className={`text-[10px] font-semibold tracking-wider uppercase px-2 py-0.5 rounded border ${statusColor}`}
                          >
                            {notif.status}
                          </span>
                        </td>
                        <td className="py-3 text-tx-textMuted">
                          {notif.stats?.sent ?? 0} sent ({notif.stats?.openRate ?? 0}% opened)
                        </td>
                        <td className="py-3 text-right pr-1 text-tx-textDim">
                          {new Date(notif.createdAt).toLocaleDateString()}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right: Topic Subscriptions */}
        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border space-y-4">
          <div>
            <h3 className="text-sm font-semibold text-tx-cream">Audience Topics</h3>
            <p className="text-xs text-tx-textDim">Native Firebase Topic subscriber volume</p>
          </div>

          <div className="space-y-3">
            {[
              { id: 'tx_all', name: 'All Users (tx_all)', color: 'from-emerald-500 to-teal-600' },
              { id: 'tx_updates', name: 'Browser Updates', color: 'from-blue-500 to-indigo-600' },
              { id: 'tx_promotions', name: 'Promotions & Perks', color: 'from-amber-500 to-orange-600' },
              { id: 'tx_security', name: 'Security Alerts', color: 'from-red-500 to-rose-600' },
              { id: 'tx_general', name: 'General Announcements', color: 'from-purple-500 to-pink-600' },
            ].map((topic) => {
              const count = audience?.topics[topic.id] || 0;
              const max = audience?.summary.totalInstallations || 1;
              const pct = Math.min(100, Math.round((count / max) * 100));

              return (
                <div key={topic.id} className="p-3 rounded-xl bg-tx-card border border-tx-border">
                  <div className="flex items-center justify-between text-xs mb-1.5">
                    <span className="font-medium text-tx-cream">{topic.name}</span>
                    <span className="font-semibold text-tx-sage">{count.toLocaleString()}</span>
                  </div>
                  <div className="w-full h-1.5 rounded-full bg-tx-bg overflow-hidden">
                    <div
                      className={`h-full rounded-full bg-gradient-to-r ${topic.color}`}
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};
