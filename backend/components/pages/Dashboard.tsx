'use client';

import React, { useEffect, useState } from 'react';
import {
  Smartphone,
  CheckCircle2,
  Eye,
  PlusCircle,
  RefreshCw,
  ArrowUpRight,
  TrendingUp,
  Zap,
  Send,
  Cloud,
  Database,
  ShieldCheck,
  BellRing,
  Activity,
  Layers,
} from 'lucide-react';
import { api } from '@/lib/api-client';
import { AnalyticsOverview, AudienceStats, NotificationItem, SystemHealth } from '@/types';
import { TestPushModal } from '../TestPushModal';
import { SystemHealthModal } from '../SystemHealthModal';
import { Skeleton } from '../ui/Skeleton';
import { EmptyState } from '../ui/EmptyState';

interface DashboardProps {
  onNavigate: (tab: string, meta?: any) => void;
}

export const Dashboard: React.FC<DashboardProps> = ({ onNavigate }) => {
  const [analytics, setAnalytics] = useState<AnalyticsOverview | null>(null);
  const [audience, setAudience] = useState<AudienceStats | null>(null);
  const [recentNotifications, setRecentNotifications] = useState<NotificationItem[]>([]);
  const [health, setHealth] = useState<SystemHealth | null>(null);
  const [loading, setLoading] = useState(true);

  const [showTestPushModal, setShowTestPushModal] = useState(false);
  const [showHealthModal, setShowHealthModal] = useState(false);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      const [analyticsData, audienceData, notifsData, healthData]: any = await Promise.all([
        api.get<AnalyticsOverview>('/analytics/overview'),
        api.get<AudienceStats>('/audiences/stats'),
        api.get<{ items: NotificationItem[]; data: NotificationItem[] }>('/notifications?limit=5'),
        api.get<SystemHealth>('/analytics/system-health').catch(() => null),
      ]);

      setAnalytics(analyticsData);
      setAudience(audienceData);
      setRecentNotifications(notifsData?.data || notifsData?.items || []);
      setHealth(healthData);
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
    <div className="space-y-6 sm:space-y-8 animate-fade-in">
      {/* Top Banner & Quick Actions */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-2 border-b border-tx-border/60">
        <div>
          <div className="flex items-center gap-2.5">
            <h2 className="text-xl sm:text-2xl font-bold text-tx-cream tracking-tight">
              Telemetry & Live Pipeline
            </h2>
            <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-emerald-950/90 border border-emerald-700/60 text-emerald-400 shadow-sm">
              Live Gateway
            </span>
          </div>
          <p className="text-xs text-tx-textMuted mt-1">
            Real-time push delivery metrics across active TX Browser installations (Android 14+)
          </p>
        </div>

        <div className="flex items-center gap-2.5 self-start sm:self-auto flex-wrap">
          <button
            onClick={() => setShowTestPushModal(true)}
            className="px-3.5 py-2 rounded-xl bg-tx-card hover:bg-tx-elevated border border-tx-border text-tx-cream text-xs font-semibold flex items-center gap-2 transition-all duration-150 shadow-card hover:-translate-y-0.5 active:scale-95"
          >
            <Send className="w-3.5 h-3.5 text-tx-gold" />
            <span>Test Push</span>
          </button>

          <button
            onClick={loadDashboardData}
            disabled={loading}
            className="px-3 py-2 rounded-xl bg-tx-card hover:bg-tx-elevated border border-tx-border text-tx-textMuted hover:text-tx-cream text-xs font-medium flex items-center gap-1.5 transition-all duration-150 active:scale-95"
            title="Refresh metrics"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-tx-gold' : ''}`} />
            <span className="hidden sm:inline">Refresh</span>
          </button>

          <button
            onClick={() => onNavigate('composer')}
            className="px-4 py-2 rounded-xl bg-tx-gold hover:bg-tx-goldLight text-black text-xs font-semibold flex items-center gap-2 transition-all duration-150 shadow-glow hover:-translate-y-0.5 active:scale-95"
          >
            <PlusCircle className="w-4 h-4" />
            <span>Create Campaign</span>
          </button>
        </div>
      </div>

      {/* Cloud Sync & Architecture Status Card */}
      <div className="p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-tx-card via-tx-surface to-tx-card border border-tx-border shadow-card">
        <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 lg:gap-6 flex-1">
            {/* Supabase status badge */}
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-emerald-950/80 border border-emerald-700/50 flex items-center justify-center text-emerald-400 shrink-0 shadow-sm">
                <Database className="w-4 h-4" />
              </div>
              <div className="min-w-0">
                <p className="font-semibold text-xs text-tx-cream flex items-center gap-1.5">
                  <span>Supabase Cloud</span>
                  <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                </p>
                <p className="text-[11px] text-tx-textMuted font-mono truncate">
                  {health?.database.region || 'ap-south-1'} ({health?.database.latencyMs ?? 45}ms)
                </p>
              </div>
            </div>

            {/* Firebase status badge */}
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-sky-950/80 border border-sky-700/50 flex items-center justify-center text-sky-400 shrink-0 shadow-sm">
                <Cloud className="w-4 h-4" />
              </div>
              <div className="min-w-0">
                <p className="font-semibold text-xs text-tx-cream flex items-center gap-1.5">
                  <span>Firebase FCM v1</span>
                  <span className="w-2 h-2 rounded-full bg-sky-400 animate-pulse" />
                </p>
                <p className="text-[11px] text-tx-textMuted font-mono truncate">tx-browser (Ready)</p>
              </div>
            </div>

            {/* Mobile Privacy badge */}
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-purple-950/80 border border-purple-700/50 flex items-center justify-center text-purple-400 shrink-0 shadow-sm">
                <ShieldCheck className="w-4 h-4" />
              </div>
              <div className="min-w-0">
                <p className="font-semibold text-xs text-tx-cream">Anonymous Security</p>
                <p className="text-[11px] text-tx-textMuted truncate">Zero PII • Device UUID</p>
              </div>
            </div>
          </div>

          <button
            onClick={() => setShowHealthModal(true)}
            className="px-3.5 py-2 rounded-xl bg-tx-surface hover:bg-tx-elevated border border-tx-border text-tx-gold hover:text-tx-cream text-xs font-semibold flex items-center gap-2 self-start lg:self-auto transition-all active:scale-95 shadow-sm"
          >
            <Zap className="w-3.5 h-3.5 text-emerald-400" />
            <span>Diagnostics</span>
          </button>
        </div>
      </div>

      {/* KPI Bento Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Total Devices */}
        <div className="p-5 rounded-2xl bg-tx-card border border-tx-border relative overflow-hidden group hover:border-tx-gold/40 transition-all duration-200 shadow-card hover:-translate-y-0.5">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold text-tx-textMuted uppercase tracking-wider">
              Device Fleet
            </span>
            <div className="w-8 h-8 rounded-xl bg-emerald-950/60 border border-emerald-800/30 flex items-center justify-center shadow-sm">
              <Smartphone className="w-4 h-4 text-emerald-400" />
            </div>
          </div>
          {loading ? (
            <Skeleton className="h-8 w-24 mb-2" />
          ) : (
            <p className="text-3xl font-extrabold text-tx-cream tracking-tight font-mono">
              {audience?.summary.totalInstallations.toLocaleString() ?? '—'}
            </p>
          )}
          <div className="mt-2.5 flex items-center gap-1.5 text-xs text-tx-gold font-medium">
            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
            <span>{audience?.summary.activeInstallations ?? 0} active in registry</span>
          </div>
        </div>

        {/* Card 2: 30-Day Active Users */}
        <div className="p-5 rounded-2xl bg-tx-card border border-tx-border relative overflow-hidden group hover:border-sky-500/40 transition-all duration-200 shadow-card hover:-translate-y-0.5">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold text-tx-textMuted uppercase tracking-wider">
              30-Day Reach
            </span>
            <div className="w-8 h-8 rounded-xl bg-sky-950/60 border border-sky-800/30 flex items-center justify-center shadow-sm">
              <TrendingUp className="w-4 h-4 text-sky-400" />
            </div>
          </div>
          {loading ? (
            <Skeleton className="h-8 w-24 mb-2" />
          ) : (
            <p className="text-3xl font-extrabold text-tx-cream tracking-tight font-mono">
              {audience?.summary.activeLast30Days.toLocaleString() ?? '—'}
            </p>
          )}
          <div className="mt-2.5 text-xs text-tx-textMuted flex items-center gap-1.5">
            <Activity className="w-3.5 h-3.5 text-sky-400" />
            <span>Online within last 30 days</span>
          </div>
        </div>

        {/* Card 3: Permission Opt-in */}
        <div className="p-5 rounded-2xl bg-tx-card border border-tx-border relative overflow-hidden group hover:border-emerald-500/40 transition-all duration-200 shadow-card hover:-translate-y-0.5">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold text-tx-textMuted uppercase tracking-wider">
              Opt-in Rate
            </span>
            <div className="w-8 h-8 rounded-xl bg-tx-surface border border-tx-border flex items-center justify-center shadow-sm">
              <CheckCircle2 className="w-4 h-4 text-tx-gold" />
            </div>
          </div>
          {loading ? (
            <Skeleton className="h-8 w-24 mb-2" />
          ) : (
            <p className="text-3xl font-extrabold text-tx-cream tracking-tight font-mono">
              {audience?.summary.grantedPercentage ?? 0}%
            </p>
          )}
          <div className="mt-2.5 text-xs text-tx-textMuted flex items-center gap-1.5">
            <span>{audience?.summary.permissionGranted.toLocaleString() ?? 0} granted push permission</span>
          </div>
        </div>

        {/* Card 4: Open Rate */}
        <div className="p-5 rounded-2xl bg-tx-card border border-tx-border relative overflow-hidden group hover:border-purple-500/40 transition-all duration-200 shadow-card hover:-translate-y-0.5">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold text-tx-textMuted uppercase tracking-wider">
              Engagement CTR
            </span>
            <div className="w-8 h-8 rounded-xl bg-purple-950/60 border border-purple-800/30 flex items-center justify-center shadow-sm">
              <Eye className="w-4 h-4 text-purple-400" />
            </div>
          </div>
          {loading ? (
            <Skeleton className="h-8 w-24 mb-2" />
          ) : (
            <p className="text-3xl font-extrabold text-tx-cream tracking-tight font-mono">
              {analytics?.summary.overallOpenRate ?? 0}%
            </p>
          )}
          <div className="mt-2.5 text-xs text-tx-textMuted flex items-center gap-1.5">
            <BellRing className="w-3.5 h-3.5 text-purple-400" />
            <span>{analytics?.summary.openedDeliveries.toLocaleString() ?? 0} opened deliveries</span>
          </div>
        </div>
      </div>

      {/* Two Column Layout: Recent Campaigns + Topic Subscriptions */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left: Recent Campaigns (2 Cols) */}
        <div className="lg:col-span-2 p-5 sm:p-6 rounded-2xl bg-tx-card border border-tx-border shadow-card flex flex-col">
          <div className="flex items-center justify-between mb-5">
            <div>
              <h3 className="text-sm font-bold text-tx-cream tracking-tight flex items-center gap-2">
                <span>Recent Campaigns</span>
                <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-tx-surface border border-tx-border text-tx-textMuted">
                  Last 5
                </span>
              </h3>
              <p className="text-xs text-tx-textMuted mt-0.5">
                Broadcast history & scheduled notification status
              </p>
            </div>
            <button
              onClick={() => onNavigate('notifications')}
              className="text-xs text-tx-gold hover:text-tx-goldLight font-semibold flex items-center gap-1 transition-colors"
            >
              <span>View All</span>
              <ArrowUpRight className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="overflow-x-auto flex-1">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-tx-border text-tx-textMuted font-semibold uppercase tracking-wider text-[11px]">
                  <th className="pb-3.5 pl-2">Campaign</th>
                  <th className="pb-3.5">Category</th>
                  <th className="pb-3.5">Status</th>
                  <th className="pb-3.5">Dispatched</th>
                  <th className="pb-3.5 text-right pr-2">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-tx-border/40">
                {loading ? (
                  Array.from({ length: 4 }).map((_, i) => (
                    <tr key={i}>
                      <td className="py-3.5 pl-2"><Skeleton className="h-4 w-36" /></td>
                      <td className="py-3.5"><Skeleton className="h-4 w-20" /></td>
                      <td className="py-3.5"><Skeleton className="h-4 w-16" /></td>
                      <td className="py-3.5"><Skeleton className="h-4 w-24" /></td>
                      <td className="py-3.5 pr-2 text-right"><Skeleton className="h-4 w-16 ml-auto" /></td>
                    </tr>
                  ))
                ) : recentNotifications.length === 0 ? (
                  <tr>
                    <td colSpan={5}>
                      <EmptyState
                        icon={BellRing}
                        title="No campaigns yet"
                        description="You haven't dispatched any push notifications yet. Create your first campaign to connect with your users."
                        action={{
                          label: 'Create Campaign',
                          onClick: () => onNavigate('composer'),
                          icon: PlusCircle,
                        }}
                      />
                    </td>
                  </tr>
                ) : (
                  recentNotifications.map((notif) => {
                    const statusColor =
                      notif.status === 'SENT'
                        ? 'bg-emerald-950/70 text-emerald-300 border-emerald-700/60'
                        : notif.status === 'SCHEDULED'
                        ? 'bg-amber-950/70 text-amber-300 border-amber-700/60'
                        : notif.status === 'QUEUED' || notif.status === 'SENDING'
                        ? 'bg-sky-950/70 text-sky-300 border-sky-700/60'
                        : 'bg-zinc-900 text-zinc-400 border-zinc-700';

                    return (
                      <tr
                        key={notif.id}
                        onClick={() => onNavigate('notifications', { selectedId: notif.id })}
                        className="hover:bg-tx-surface/70 transition-colors cursor-pointer group"
                      >
                        <td className="py-3.5 pl-2 font-medium text-tx-cream max-w-[220px] truncate group-hover:text-tx-gold transition-colors">
                          {notif.title}
                        </td>
                        <td className="py-3.5">
                          <span className="text-[11px] px-2 py-0.5 rounded-md bg-tx-surface text-tx-textMuted border border-tx-border font-medium">
                            {notif.notificationType}
                          </span>
                        </td>
                        <td className="py-3.5">
                          <span
                            className={`text-[10px] font-bold tracking-wider uppercase px-2 py-0.5 rounded-full border ${statusColor}`}
                          >
                            {notif.status}
                          </span>
                        </td>
                        <td className="py-3.5 text-tx-textMuted font-mono">
                          {notif.stats?.sent ?? (notif._count?.deliveries ?? 0)} sent ({notif.stats?.openRate ?? 0}% opened)
                        </td>
                        <td className="py-3.5 text-right pr-2 text-tx-textSubtle font-mono">
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
        <div className="p-5 sm:p-6 rounded-2xl bg-tx-card border border-tx-border shadow-card space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-sm font-bold text-tx-cream tracking-tight flex items-center gap-2">
                <Layers className="w-4 h-4 text-tx-gold" />
                <span>Audience Topics</span>
              </h3>
              <p className="text-xs text-tx-textMuted mt-0.5">
                Native Firebase FCM subscriber volume
              </p>
            </div>
            <button
              onClick={() => onNavigate('audiences')}
              className="text-xs text-tx-gold hover:text-tx-goldLight font-semibold transition-colors"
            >
              Details
            </button>
          </div>

          <div className="space-y-3 pt-2">
            {[
              { id: 'tx_all', name: 'All Users (tx_all)', color: 'from-amber-500 to-yellow-500' },
              { id: 'tx_updates', name: 'Browser Updates', color: 'from-sky-500 to-indigo-500' },
              { id: 'tx_promotions', name: 'Promotions & Perks', color: 'from-emerald-500 to-teal-500' },
              { id: 'tx_security', name: 'Security Alerts', color: 'from-rose-500 to-red-500' },
              { id: 'tx_general', name: 'General Announcements', color: 'from-purple-500 to-pink-500' },
            ].map((topic) => {
              const count = audience?.topics?.[topic.id] || 0;
              const max = audience?.summary.totalInstallations || 1;
              const pct = Math.min(100, Math.round((count / max) * 100));

              return (
                <div
                  key={topic.id}
                  className="p-3 rounded-xl bg-tx-surface/80 border border-tx-border hover:border-tx-borderGlow transition-all"
                >
                  <div className="flex items-center justify-between text-xs mb-1.5">
                    <span className="font-semibold text-tx-cream">{topic.name}</span>
                    <span className="font-bold text-tx-gold font-mono">{count.toLocaleString()}</span>
                  </div>
                  <div className="w-full h-1.5 rounded-full bg-tx-card overflow-hidden">
                    <div
                      className={`h-full rounded-full bg-gradient-to-r ${topic.color} transition-all duration-500`}
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Modals */}
      <TestPushModal isOpen={showTestPushModal} onClose={() => setShowTestPushModal(false)} />
      <SystemHealthModal isOpen={showHealthModal} onClose={() => setShowHealthModal(false)} />
    </div>
  );
};
