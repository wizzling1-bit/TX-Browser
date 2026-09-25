import React, { useEffect, useState } from 'react';
import { Users, Smartphone, CheckCircle2, XCircle, HelpCircle, Hash, RefreshCw } from 'lucide-react';
import { api } from '../lib/api.js';
import { AudienceStats } from '../types/index.js';

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
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-tx-cream tracking-tight">Audiences & Topics</h2>
          <p className="text-xs text-tx-textMuted mt-0.5">
            Subscribers breakdown across native FCM topics and Android version cohorts
          </p>
        </div>

        <button
          onClick={loadData}
          disabled={loading}
          className="px-3 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-textMuted hover:text-tx-cream text-xs font-medium flex items-center gap-2 transition-colors w-fit"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          <span>Refresh Stats</span>
        </button>
      </div>

      {/* Permission Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-medium text-tx-textMuted">Opt-in Granted</span>
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-2xl font-bold text-tx-cream">
            {stats?.summary.permissionGranted.toLocaleString() ?? 0}
          </p>
          <p className="text-[11px] text-tx-sage mt-1">
            {stats?.summary.grantedPercentage ?? 0}% of active fleet
          </p>
        </div>

        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-medium text-tx-textMuted">Denied / Blocked</span>
            <XCircle className="w-4 h-4 text-rose-400" />
          </div>
          <p className="text-2xl font-bold text-tx-cream">
            {stats?.summary.permissionDenied.toLocaleString() ?? 0}
          </p>
          <p className="text-[11px] text-tx-textDim mt-1">
            Disabled at OS or app level
          </p>
        </div>

        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-medium text-tx-textMuted">Pending Decision</span>
            <HelpCircle className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-2xl font-bold text-tx-cream">
            {stats?.summary.permissionUnknown.toLocaleString() ?? 0}
          </p>
          <p className="text-[11px] text-tx-textDim mt-1">
            Yet to reach contextual prompt
          </p>
        </div>
      </div>

      {/* Topics Detailed Grid */}
      <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border space-y-4">
        <div>
          <h3 className="text-sm font-semibold text-tx-cream">Native FCM Topic Subscribers</h3>
          <p className="text-xs text-tx-textDim">
            Real-time subscriber counts maintained automatically by TX Browser mobile app
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {[
            {
              id: 'tx_all',
              name: 'tx_all (All Devices)',
              desc: 'Subscribed by default on all active installs for global critical alerts',
              color: 'text-emerald-400',
            },
            {
              id: 'tx_promotions',
              name: 'tx_promotions',
              desc: 'Special offers, sponsored partner extensions, rewarded perk bonuses',
              color: 'text-amber-400',
            },
            {
              id: 'tx_updates',
              name: 'tx_updates',
              desc: 'New releases, engine speed upgrades, and changelog highlights',
              color: 'text-blue-400',
            },
            {
              id: 'tx_security',
              name: 'tx_security',
              desc: 'Security patches, malicious domain alerts, and safe browsing warnings',
              color: 'text-rose-400',
            },
            {
              id: 'tx_general',
              name: 'tx_general',
              desc: 'General announcements and maintenance status broadcasts',
              color: 'text-purple-400',
            },
          ].map((topic) => {
            const count = stats?.topics[topic.id] || 0;
            return (
              <div key={topic.id} className="p-4 rounded-xl bg-tx-card border border-tx-border space-y-2">
                <div className="flex items-center justify-between">
                  <span className={`text-xs font-bold font-mono ${topic.color}`}>
                    #{topic.id}
                  </span>
                  <span className="text-sm font-bold text-tx-cream">
                    {count.toLocaleString()}
                  </span>
                </div>
                <p className="text-xs font-medium text-tx-cream">{topic.name}</p>
                <p className="text-[11px] text-tx-textDim leading-relaxed">{topic.desc}</p>
              </div>
            );
          })}
        </div>
      </div>

      {/* Cohorts Grid: App Versions + Android Versions */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* App Versions */}
        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <h3 className="text-sm font-semibold text-tx-cream mb-1">Active App Versions</h3>
          <p className="text-xs text-tx-textDim mb-4">Install base across client build releases</p>
          <div className="space-y-2">
            {stats?.versions.app.length === 0 ? (
              <p className="text-xs text-tx-textDim py-4 text-center">No devices recorded yet</p>
            ) : (
              stats?.versions.app.map((v) => (
                <div key={v.version} className="flex items-center justify-between p-2.5 rounded-lg bg-tx-card border border-tx-border text-xs">
                  <span className="font-mono text-tx-sage font-medium">{v.version}</span>
                  <span className="font-bold text-tx-cream">{v.count.toLocaleString()} devices</span>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Android OS Versions */}
        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <h3 className="text-sm font-semibold text-tx-cream mb-1">Android OS Distribution</h3>
          <p className="text-xs text-tx-textDim mb-4">Target SDK 36 (Android 14+ opt-in compliance)</p>
          <div className="space-y-2">
            {stats?.versions.android.length === 0 ? (
              <p className="text-xs text-tx-textDim py-4 text-center">No devices recorded yet</p>
            ) : (
              stats?.versions.android.map((a) => (
                <div key={a.version} className="flex items-center justify-between p-2.5 rounded-lg bg-tx-card border border-tx-border text-xs">
                  <span className="font-medium text-tx-cream">{a.version}</span>
                  <span className="font-bold text-tx-sage">{a.count.toLocaleString()} devices</span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
