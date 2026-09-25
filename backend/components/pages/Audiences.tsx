'use client';

import React, { useEffect, useState } from 'react';
import { CheckCircle2, XCircle, HelpCircle, RefreshCw, Layers, Smartphone, SmartphoneNfc } from 'lucide-react';
import { api } from '@/lib/api-client';
import { AudienceStats } from '@/types';
import { Skeleton } from '@/components/ui/Skeleton';

export const Audiences: React.FC = () => {
  const [stats, setStats] = useState<AudienceStats | null>(null);
  const [loading, setLoading] = useState(true);

  const loadData = async () => {
    try {
      setLoading(true);
      const data = await api.get<AudienceStats>('/audiences/stats');
      setStats(data);
    } catch (err) {
      console.error('Failed to load audience stats:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  return (
    <div className="space-y-6 sm:space-y-8 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-2 border-b border-tx-border/60">
        <div>
          <h2 className="text-xl sm:text-2xl font-bold text-tx-cream tracking-tight">
            Audiences & Topic Segments
          </h2>
          <p className="text-xs text-tx-textMuted mt-1">
            Subscribers breakdown across native FCM topics and Android version cohorts
          </p>
        </div>

        <button
          onClick={loadData}
          disabled={loading}
          className="px-3.5 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-textMuted hover:text-tx-cream text-xs font-semibold flex items-center gap-2 transition-all active:scale-95 shadow-card-elevated w-fit"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-tx-primary' : ''}`} />
          <span>Refresh Stats</span>
        </button>
      </div>

      {/* Permission Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated hover:border-emerald-500/40 transition-all duration-200">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold text-tx-textMuted uppercase tracking-wider">
              Opt-in Granted
            </span>
            <div className="w-8 h-8 rounded-xl bg-emerald-950/60 border border-emerald-800/30 flex items-center justify-center shadow-sm">
              <CheckCircle2 className="w-4 h-4 text-emerald-400" />
            </div>
          </div>
          {loading ? (
            <Skeleton className="h-8 w-24 mb-2" />
          ) : (
            <p className="text-3xl font-extrabold text-tx-cream tracking-tight font-mono">
              {stats?.summary.permissionGranted.toLocaleString() ?? 0}
            </p>
          )}
          <p className="text-xs text-tx-sage mt-2 font-medium">
            {stats?.summary.grantedPercentage ?? 0}% of active fleet
          </p>
        </div>

        <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated hover:border-rose-500/40 transition-all duration-200">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold text-tx-textMuted uppercase tracking-wider">
              Denied / Blocked
            </span>
            <div className="w-8 h-8 rounded-xl bg-rose-950/60 border border-rose-800/30 flex items-center justify-center shadow-sm">
              <XCircle className="w-4 h-4 text-rose-400" />
            </div>
          </div>
          {loading ? (
            <Skeleton className="h-8 w-24 mb-2" />
          ) : (
            <p className="text-3xl font-extrabold text-rose-400 tracking-tight font-mono">
              {stats?.summary.permissionDenied.toLocaleString() ?? 0}
            </p>
          )}
          <p className="text-xs text-tx-textMuted mt-2">
            Disabled at OS or app level
          </p>
        </div>

        <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated hover:border-amber-500/40 transition-all duration-200">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold text-tx-textMuted uppercase tracking-wider">
              Pending Decision
            </span>
            <div className="w-8 h-8 rounded-xl bg-amber-950/60 border border-amber-800/30 flex items-center justify-center shadow-sm">
              <HelpCircle className="w-4 h-4 text-amber-400" />
            </div>
          </div>
          {loading ? (
            <Skeleton className="h-8 w-24 mb-2" />
          ) : (
            <p className="text-3xl font-extrabold text-tx-cream tracking-tight font-mono">
              {stats?.summary.permissionUnknown.toLocaleString() ?? 0}
            </p>
          )}
          <p className="text-xs text-tx-textMuted mt-2">
            Yet to reach contextual in-app prompt
          </p>
        </div>
      </div>

      {/* Topics Detailed Grid */}
      <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated space-y-4">
        <div>
          <h3 className="text-sm font-bold text-tx-cream tracking-tight flex items-center gap-2">
            <Layers className="w-4 h-4 text-tx-primary" />
            <span>Native FCM Topic Subscribers</span>
          </h3>
          <p className="text-xs text-tx-textMuted mt-0.5">
            Real-time subscriber counts maintained automatically by TX Browser mobile client
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 pt-2">
          {[
            {
              id: 'tx_all',
              name: 'tx_all (All Devices)',
              desc: 'Subscribed by default on all active installs for global critical alerts',
              color: 'text-emerald-400',
              border: 'hover:border-emerald-500/50',
            },
            {
              id: 'tx_promotions',
              name: 'tx_promotions',
              desc: 'Special offers, sponsored partner extensions, rewarded perk bonuses',
              color: 'text-amber-400',
              border: 'hover:border-amber-500/50',
            },
            {
              id: 'tx_updates',
              name: 'tx_updates',
              desc: 'New releases, engine speed upgrades, and changelog highlights',
              color: 'text-sky-400',
              border: 'hover:border-sky-500/50',
            },
            {
              id: 'tx_security',
              name: 'tx_security',
              desc: 'Security patches, malicious domain alerts, and safe browsing warnings',
              color: 'text-rose-400',
              border: 'hover:border-rose-500/50',
            },
            {
              id: 'tx_general',
              name: 'tx_general',
              desc: 'General announcements and maintenance status broadcasts',
              color: 'text-purple-400',
              border: 'hover:border-purple-500/50',
            },
          ].map((topic) => {
            const count = (stats?.topics as Record<string, number> | undefined)?.[topic.id] || 0;
            return (
              <div
                key={topic.id}
                className={`p-4 rounded-xl bg-tx-card/80 border border-tx-border ${topic.border} transition-all duration-200 shadow-card-elevated space-y-2`}
              >
                <div className="flex items-center justify-between">
                  <span className={`text-xs font-bold font-mono ${topic.color}`}>
                    #{topic.id}
                  </span>
                  {loading ? (
                    <Skeleton className="h-5 w-12" />
                  ) : (
                    <span className="text-sm font-extrabold text-tx-cream font-mono">
                      {count.toLocaleString()}
                    </span>
                  )}
                </div>
                <p className="text-xs font-semibold text-tx-cream">{topic.name}</p>
                <p className="text-[11px] text-tx-textMuted leading-relaxed">{topic.desc}</p>
              </div>
            );
          })}
        </div>
      </div>

      {/* Cohorts Grid: App Versions + Android Versions */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* App Versions */}
        <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated">
          <h3 className="text-sm font-bold text-tx-cream tracking-tight mb-1 flex items-center gap-2">
            <Smartphone className="w-4 h-4 text-tx-primary" />
            <span>Active App Versions</span>
          </h3>
          <p className="text-xs text-tx-textMuted mb-4">Install base across client build releases</p>
          <div className="space-y-2">
            {loading ? (
              Array.from({ length: 3 }).map((_, i) => (
                <Skeleton key={i} className="h-10 w-full" />
              ))
            ) : !stats?.versions?.app || stats.versions.app.length === 0 ? (
              <p className="text-xs text-tx-textDim py-4 text-center">No version records found</p>
            ) : (
              stats.versions.app.map((v) => (
                <div
                  key={v.version}
                  className="flex items-center justify-between p-3 rounded-xl bg-tx-card/80 border border-tx-border text-xs"
                >
                  <span className="font-mono text-tx-sage font-semibold">{v.version}</span>
                  <span className="font-bold text-tx-cream font-mono">{v.count.toLocaleString()} devices</span>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Android OS Versions */}
        <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated">
          <h3 className="text-sm font-bold text-tx-cream tracking-tight mb-1 flex items-center gap-2">
            <SmartphoneNfc className="w-4 h-4 text-sky-400" />
            <span>Android OS Distribution</span>
          </h3>
          <p className="text-xs text-tx-textMuted mb-4">Target SDK 36 (Android 14+ opt-in compliance)</p>
          <div className="space-y-2">
            {loading ? (
              Array.from({ length: 3 }).map((_, i) => (
                <Skeleton key={i} className="h-10 w-full" />
              ))
            ) : !stats?.versions?.android || stats.versions.android.length === 0 ? (
              <p className="text-xs text-tx-textDim py-4 text-center">No OS records found</p>
            ) : (
              stats.versions.android.map((a) => (
                <div
                  key={a.version}
                  className="flex items-center justify-between p-3 rounded-xl bg-tx-card/80 border border-tx-border text-xs"
                >
                  <span className="font-medium text-tx-cream">{a.version}</span>
                  <span className="font-bold text-tx-sage font-mono">{a.count.toLocaleString()} devices</span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
