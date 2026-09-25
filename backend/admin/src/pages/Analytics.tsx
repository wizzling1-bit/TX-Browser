import React, { useEffect, useState } from 'react';
import { TrendingUp, AlertTriangle, Eye, RefreshCw, Send } from 'lucide-react';
import { api } from '../lib/api.js';
import { AnalyticsOverview } from '../types/index.js';

export const Analytics: React.FC = () => {
  const [data, setData] = useState<AnalyticsOverview | null>(null);
  const [loading, setLoading] = useState(true);

  const loadData = async () => {
    try {
      setLoading(true);
      const res = await api.get<AnalyticsOverview>('/analytics/overview');
      setData(res);
    } catch (err) {
      console.error('Failed to load analytics:', err);
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
          <h2 className="text-xl font-bold text-tx-cream tracking-tight">Delivery & Engagement Analytics</h2>
          <p className="text-xs text-tx-textMuted mt-0.5">
            End-to-end metrics from backend dispatch to client display and notification tap opens
          </p>
        </div>

        <button
          onClick={loadData}
          disabled={loading}
          className="px-3 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-textMuted hover:text-tx-cream text-xs font-medium flex items-center gap-2 transition-colors w-fit"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          <span>Refresh Analytics</span>
        </button>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-medium text-tx-textMuted">Total Dispatched</span>
            <Send className="w-4 h-4 text-tx-primary" />
          </div>
          <p className="text-2xl font-bold text-tx-cream">
            {data?.summary.totalDeliveries.toLocaleString() ?? 0}
          </p>
          <p className="text-[11px] text-tx-textDim mt-1">
            Across {data?.summary.sentCampaigns ?? 0} finished campaigns
          </p>
        </div>

        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-medium text-tx-textMuted">Confirmed Opens</span>
            <Eye className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-2xl font-bold text-tx-cream">
            {data?.summary.openedDeliveries.toLocaleString() ?? 0}
          </p>
          <p className="text-[11px] text-emerald-400 font-semibold mt-1">
            {data?.summary.overallOpenRate ?? 0}% overall conversion
          </p>
        </div>

        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-medium text-tx-textMuted">Failed / Rejected</span>
            <AlertTriangle className="w-4 h-4 text-rose-400" />
          </div>
          <p className="text-2xl font-bold text-rose-400">
            {data?.summary.failedDeliveries.toLocaleString() ?? 0}
          </p>
          <p className="text-[11px] text-tx-textDim mt-1">
            Expired or deactivated tokens
          </p>
        </div>

        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-medium text-tx-textMuted">Scheduled Pipeline</span>
            <TrendingUp className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-2xl font-bold text-tx-cream">
            {data?.summary.scheduledCampaigns.toLocaleString() ?? 0}
          </p>
          <p className="text-[11px] text-tx-textDim mt-1">
            Waiting for delivery time
          </p>
        </div>
      </div>

      {/* 14-Day Activity Trend */}
      <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border space-y-4">
        <div>
          <h3 className="text-sm font-semibold text-tx-cream">14-Day Delivery & Open Trend</h3>
          <p className="text-xs text-tx-textDim">Daily send volume and engagement tracking</p>
        </div>

        <div className="pt-4 overflow-x-auto">
          <div className="min-w-[600px] h-48 flex items-end gap-3 pb-2 border-b border-tx-border">
            {data?.dailyTrend.map((d) => {
              const maxSent = Math.max(...(data?.dailyTrend.map((t) => t.sent) || [1]), 10);
              const heightPct = Math.max(8, Math.round((d.sent / maxSent) * 100));

              return (
                <div key={d.date} className="flex-1 flex flex-col items-center gap-2 group">
                  {/* Tooltip info */}
                  <div className="text-[10px] text-tx-textDim opacity-0 group-hover:opacity-100 transition-opacity">
                    {d.sent} sent / {d.opened} opened
                  </div>
                  {/* Bar */}
                  <div className="w-full max-w-[28px] bg-tx-card rounded-t-lg relative overflow-hidden flex flex-col justify-end" style={{ height: `${heightPct}%` }}>
                    <div className="w-full bg-tx-primary/80 group-hover:bg-tx-primary transition-colors h-full" />
                    {d.opened > 0 && (
                      <div
                        className="w-full bg-emerald-400"
                        style={{ height: `${Math.round((d.opened / Math.max(d.sent, 1)) * 100)}%` }}
                      />
                    )}
                  </div>
                  {/* Date label */}
                  <span className="text-[10px] text-tx-textDim font-mono">
                    {d.date.slice(5)}
                  </span>
                </div>
              );
            })}
          </div>
          <div className="flex items-center gap-4 text-xs text-tx-textDim pt-2">
            <div className="flex items-center gap-1.5">
              <span className="w-3 h-3 rounded bg-tx-primary" />
              <span>Sent Deliveries</span>
            </div>
            <div className="flex items-center gap-1.5">
              <span className="w-3 h-3 rounded bg-emerald-400" />
              <span>Tap Opens</span>
            </div>
          </div>
        </div>
      </div>

      {/* Category Breakdown & Top Performing Campaigns */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <h3 className="text-sm font-semibold text-tx-cream mb-1">Campaigns by Category</h3>
          <p className="text-xs text-tx-textDim mb-4">Distribution across content types</p>

          <div className="space-y-3">
            {data?.typeDistribution.map((t) => (
              <div key={t.type} className="flex items-center justify-between p-3 rounded-xl bg-tx-card border border-tx-border text-xs">
                <span className="font-medium text-tx-cream">{t.type}</span>
                <span className="font-bold text-tx-sage">{t.count} campaigns</span>
              </div>
            ))}
          </div>
        </div>

        <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border">
          <h3 className="text-sm font-semibold text-tx-cream mb-1">Recent Top Campaigns</h3>
          <p className="text-xs text-tx-textDim mb-4">Most active push notification broadcasts</p>

          <div className="space-y-3">
            {data?.topCampaigns.length === 0 ? (
              <p className="text-xs text-tx-textDim py-4 text-center">No campaigns executed yet</p>
            ) : (
              data?.topCampaigns.map((c) => (
                <div key={c.id} className="p-3 rounded-xl bg-tx-card border border-tx-border text-xs space-y-1">
                  <div className="flex items-center justify-between">
                    <span className="font-semibold text-tx-cream truncate max-w-[200px]">{c.title}</span>
                    <span className="text-[10px] px-2 py-0.5 rounded bg-tx-bg text-tx-sage border border-tx-border">
                      {c.type}
                    </span>
                  </div>
                  <div className="text-[11px] text-tx-textDim">
                    {c.totalDeliveries.toLocaleString()} delivered
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
