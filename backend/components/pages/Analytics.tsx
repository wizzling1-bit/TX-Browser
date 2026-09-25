'use client';

import React, { useEffect, useState } from 'react';
import { TrendingUp, AlertTriangle, Eye, RefreshCw, Send, BarChart2, Layers } from 'lucide-react';
import { api } from '@/lib/api-client';
import { AnalyticsOverview } from '@/types';
import { Skeleton } from '@/components/ui/Skeleton';

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
    <div className="space-y-6 sm:space-y-8 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-2 border-b border-tx-border/60">
        <div>
          <h2 className="text-xl sm:text-2xl font-bold text-tx-cream tracking-tight">
            Delivery & Engagement Analytics
          </h2>
          <p className="text-xs text-tx-textMuted mt-1">
            End-to-end telemetry from backend FCM dispatch to device display and tap interactions
          </p>
        </div>

        <button
          onClick={loadData}
          disabled={loading}
          className="px-3.5 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-textMuted hover:text-tx-cream text-xs font-semibold flex items-center gap-2 transition-all active:scale-95 shadow-card-elevated w-fit"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-tx-primary' : ''}`} />
          <span>Refresh Analytics</span>
        </button>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated hover:border-tx-primary/40 transition-all duration-200">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold text-tx-textMuted uppercase tracking-wider">
              Total Dispatched
            </span>
            <div className="w-8 h-8 rounded-xl bg-emerald-950/60 border border-emerald-800/30 flex items-center justify-center shadow-sm">
              <Send className="w-4 h-4 text-emerald-400" />
            </div>
          </div>
          {loading ? (
            <Skeleton className="h-8 w-24 mb-2" />
          ) : (
            <p className="text-3xl font-extrabold text-tx-cream tracking-tight font-mono">
              {data?.summary.totalDeliveries.toLocaleString() ?? 0}
            </p>
          )}
          <p className="text-xs text-tx-textMuted mt-2">
            Across {data?.summary.sentCampaigns ?? 0} finished campaigns
          </p>
        </div>

        <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated hover:border-emerald-500/40 transition-all duration-200">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold text-tx-textMuted uppercase tracking-wider">
              Confirmed Opens
            </span>
            <div className="w-8 h-8 rounded-xl bg-emerald-950/60 border border-emerald-800/30 flex items-center justify-center shadow-sm">
              <Eye className="w-4 h-4 text-emerald-400" />
            </div>
          </div>
          {loading ? (
            <Skeleton className="h-8 w-24 mb-2" />
          ) : (
            <p className="text-3xl font-extrabold text-tx-cream tracking-tight font-mono">
              {data?.summary.openedDeliveries.toLocaleString() ?? 0}
            </p>
          )}
          <p className="text-xs text-emerald-400 font-semibold mt-2">
            {data?.summary.overallOpenRate ?? 0}% overall conversion
          </p>
        </div>

        <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated hover:border-rose-500/40 transition-all duration-200">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold text-tx-textMuted uppercase tracking-wider">
              Failed / Stale
            </span>
            <div className="w-8 h-8 rounded-xl bg-rose-950/60 border border-rose-800/30 flex items-center justify-center shadow-sm">
              <AlertTriangle className="w-4 h-4 text-rose-400" />
            </div>
          </div>
          {loading ? (
            <Skeleton className="h-8 w-24 mb-2" />
          ) : (
            <p className="text-3xl font-extrabold text-rose-400 tracking-tight font-mono">
              {data?.summary.failedDeliveries.toLocaleString() ?? 0}
            </p>
          )}
          <p className="text-xs text-tx-textMuted mt-2">
            Unregistered or deactivated tokens
          </p>
        </div>

        <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated hover:border-amber-500/40 transition-all duration-200">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold text-tx-textMuted uppercase tracking-wider">
              Scheduled Queue
            </span>
            <div className="w-8 h-8 rounded-xl bg-amber-950/60 border border-amber-800/30 flex items-center justify-center shadow-sm">
              <TrendingUp className="w-4 h-4 text-amber-400" />
            </div>
          </div>
          {loading ? (
            <Skeleton className="h-8 w-24 mb-2" />
          ) : (
            <p className="text-3xl font-extrabold text-tx-cream tracking-tight font-mono">
              {data?.summary.scheduledCampaigns.toLocaleString() ?? 0}
            </p>
          )}
          <p className="text-xs text-tx-textMuted mt-2">
            Awaiting future dispatch time
          </p>
        </div>
      </div>

      {/* 14-Day Activity Trend */}
      <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated space-y-4">
        <div>
          <h3 className="text-sm font-bold text-tx-cream tracking-tight flex items-center gap-2">
            <BarChart2 className="w-4 h-4 text-tx-primary" />
            <span>14-Day Delivery & Open Trend</span>
          </h3>
          <p className="text-xs text-tx-textMuted mt-0.5">Daily dispatch volume and open engagement</p>
        </div>

        <div className="pt-4 overflow-x-auto">
          {loading ? (
            <Skeleton className="h-48 w-full" />
          ) : (
            <div className="min-w-[600px] h-48 flex items-end gap-3 pb-2 border-b border-tx-border">
              {data?.dailyTrend.map((d) => {
                const maxSent = Math.max(...(data?.dailyTrend.map((t) => t.sent) || [1]), 10);
                const heightPct = Math.max(8, Math.round((d.sent / maxSent) * 100));

                return (
                  <div key={d.date} className="flex-1 flex flex-col items-center gap-2 group">
                    {/* Tooltip info */}
                    <div className="text-[10px] text-tx-textDim opacity-0 group-hover:opacity-100 transition-opacity font-mono">
                      {d.sent}s / {d.opened}o
                    </div>
                    {/* Bar */}
                    <div
                      className="w-full max-w-[28px] bg-tx-surfaceInset rounded-t-lg relative overflow-hidden flex flex-col justify-end transition-all"
                      style={{ height: `${heightPct}%` }}
                    >
                      <div className="w-full bg-tx-primary/80 group-hover:bg-tx-primary transition-colors h-full" />
                      {d.opened > 0 && (
                        <div
                          className="w-full bg-emerald-400"
                          style={{ height: `${Math.round((d.opened / Math.max(d.sent, 1)) * 100)}%` }}
                        />
                      )}
                    </div>
                    {/* Date label */}
                    <span className="text-[10px] text-tx-textMuted font-mono">
                      {d.date.slice(5)}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
          <div className="flex items-center gap-5 text-xs text-tx-textMuted pt-3 font-medium">
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded bg-tx-primary" />
              <span>Dispatched Deliveries</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded bg-emerald-400" />
              <span>Tap Opens</span>
            </div>
          </div>
        </div>
      </div>

      {/* Category Breakdown & Top Performing Campaigns */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated">
          <h3 className="text-sm font-bold text-tx-cream tracking-tight mb-1 flex items-center gap-2">
            <Layers className="w-4 h-4 text-tx-primary" />
            <span>Campaigns by Category</span>
          </h3>
          <p className="text-xs text-tx-textMuted mb-4">Distribution across content types</p>

          <div className="space-y-2.5">
            {loading ? (
              Array.from({ length: 4 }).map((_, i) => (
                <Skeleton key={i} className="h-10 w-full" />
              ))
            ) : !data?.typeDistribution || data.typeDistribution.length === 0 ? (
              <p className="text-xs text-tx-textDim py-4 text-center">No categories recorded</p>
            ) : (
              data.typeDistribution.map((t) => (
                <div
                  key={t.type}
                  className="flex items-center justify-between p-3 rounded-xl bg-tx-card/80 border border-tx-border text-xs"
                >
                  <span className="font-semibold text-tx-cream">{t.type}</span>
                  <span className="font-bold text-tx-sage font-mono">{t.count} campaigns</span>
                </div>
              ))
            )}
          </div>
        </div>

        <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated">
          <h3 className="text-sm font-bold text-tx-cream tracking-tight mb-1 flex items-center gap-2">
            <TrendingUp className="w-4 h-4 text-emerald-400" />
            <span>Top Performing Campaigns</span>
          </h3>
          <p className="text-xs text-tx-textMuted mb-4">Highest volume and engagement broadcasts</p>

          <div className="space-y-2.5">
            {loading ? (
              Array.from({ length: 3 }).map((_, i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))
            ) : !data?.topCampaigns || data.topCampaigns.length === 0 ? (
              <p className="text-xs text-tx-textDim py-4 text-center">No campaign records yet</p>
            ) : (
              data.topCampaigns.map((c) => (
                <div
                  key={c.id}
                  className="p-3 rounded-xl bg-tx-card/80 border border-tx-border text-xs space-y-1 hover:border-tx-borderLight transition-all"
                >
                  <div className="flex items-center justify-between">
                    <span className="font-semibold text-tx-cream truncate max-w-[200px]">{c.title}</span>
                    <span className="text-[10px] font-semibold px-2 py-0.5 rounded-md bg-tx-surfaceInset text-tx-sage border border-tx-border">
                      {c.type}
                    </span>
                  </div>
                  <div className="text-[11px] text-tx-textMuted font-mono">
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
