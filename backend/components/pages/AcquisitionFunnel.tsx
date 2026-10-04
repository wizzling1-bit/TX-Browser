'use client';

import React, { useState, useEffect } from 'react';
import {
  TrendingUp,
  MousePointerClick,
  Download,
  Users,
  Award,
  ArrowRight,
  Sparkles,
  Link2,
  ExternalLink,
  ChevronRight,
  PlusCircle,
  RefreshCw,
  BarChart2,
} from 'lucide-react';
import { api } from '@/lib/api-client';

interface FunnelStage {
  stage: number;
  name: string;
  description: string;
  count: number;
  dropoff: string;
  conversion: string;
}

interface CampaignStat {
  id: string;
  title: string;
  slug: string;
  targetUrl: string;
  clicks: number;
  installs: number;
  conversionRate: number;
  isActive: boolean;
}

interface FunnelData {
  funnel: FunnelStage[];
  metrics: {
    totalClicks: number;
    totalInstalls: number;
    activeUsers: number;
    retainedUsers: number;
    clickToInstall: number;
    installToActive: number;
    activeToRetained: number;
    overallConversion: number;
  };
  cohortRetention: {
    day1: number;
    day7: number;
    day14: number;
    day30: number;
  };
  campaigns: CampaignStat[];
}

export const AcquisitionFunnel: React.FC<{
  onNavigateToBacklinks?: () => void;
  onNavigateToComposer?: () => void;
}> = ({ onNavigateToBacklinks, onNavigateToComposer }) => {
  const [data, setData] = useState<FunnelData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchFunnelData();
  }, []);

  const fetchFunnelData = async () => {
    try {
      setLoading(true);
      const data = await api.get<any>('/analytics/funnel');
      if (data?.success) {
        setData(data);
      }
    } catch (err) {
      console.error('Failed to load funnel data:', err);
    } finally {
      setLoading(false);
    }
  };

  if (loading || !data) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[400px]">
        <div className="w-10 h-10 border-2 border-tx-gold/20 border-t-tx-gold rounded-full animate-spin" />
        <p className="mt-4 text-xs font-medium text-tx-textMuted">Computing Acquisition Funnel & Cohort Retention...</p>
      </div>
    );
  }

  const { funnel, metrics, cohortRetention, campaigns } = data;

  const getStageIcon = (idx: number) => {
    switch (idx) {
      case 0:
        return <MousePointerClick className="w-5 h-5 text-amber-400" />;
      case 1:
        return <Download className="w-5 h-5 text-sky-400" />;
      case 2:
        return <Users className="w-5 h-5 text-emerald-400" />;
      default:
        return <Award className="w-5 h-5 text-tx-gold" />;
    }
  };

  const getStageColor = (idx: number) => {
    switch (idx) {
      case 0:
        return 'from-amber-500/20 to-amber-500/5 border-amber-500/30';
      case 1:
        return 'from-sky-500/20 to-sky-500/5 border-sky-500/30';
      case 2:
        return 'from-emerald-500/20 to-emerald-500/5 border-emerald-500/30';
      default:
        return 'from-tx-gold/20 to-tx-gold/5 border-tx-gold/30';
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-tx-border pb-5">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-tx-gold/10 border border-tx-gold/30 flex items-center justify-center">
              <TrendingUp className="w-5 h-5 text-tx-gold" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-tx-cream tracking-tight">
                Acquisition Funnel & Backlinks Analytics
              </h1>
              <p className="text-xs text-tx-textMuted mt-0.5">
                Full-funnel conversion analysis from external promotional backlink clicks through 30-day retention.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={fetchFunnelData}
            className="p-2 text-tx-textMuted hover:text-tx-cream bg-tx-card border border-tx-border rounded-xl transition-all shadow-sm"
            title="Refresh metrics"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
          {onNavigateToBacklinks && (
            <button
              onClick={onNavigateToBacklinks}
              className="px-4 py-2 text-xs font-semibold text-black bg-gradient-to-r from-tx-gold to-amber-500 hover:from-amber-400 rounded-xl flex items-center gap-2 transition-all shadow-glow font-medium"
            >
              <Link2 className="w-4 h-4" />
              Manage Backlinks
            </button>
          )}
        </div>
      </div>

      {/* Visual 4-Stage Funnel */}
      <div className="p-6 rounded-2xl bg-tx-card border border-tx-border space-y-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <BarChart2 className="w-4 h-4 text-tx-gold" />
            <h2 className="text-sm font-bold text-tx-cream uppercase tracking-wider">
              4-Stage Acquisition Conversion Funnel
            </h2>
          </div>
          <span className="text-xs font-mono text-tx-gold font-bold">
            Overall Conversion: {metrics.overallConversion}%
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {funnel.map((stage, idx) => (
            <div
              key={stage.stage}
              className={`p-4 rounded-xl bg-gradient-to-b ${getStageColor(
                idx
              )} border relative flex flex-col justify-between space-y-3`}
            >
              <div className="flex items-center justify-between">
                <div className="p-2 rounded-lg bg-black/30 border border-white/5">{getStageIcon(idx)}</div>
                <span className="text-[10px] font-bold font-mono uppercase text-tx-textMuted px-2 py-0.5 rounded bg-black/20">
                  Stage {stage.stage}
                </span>
              </div>

              <div>
                <p className="text-2xl font-bold font-mono text-tx-cream tracking-tight">
                  {stage.count.toLocaleString()}
                </p>
                <p className="text-xs font-semibold text-tx-cream mt-0.5">{stage.name}</p>
                <p className="text-[11px] text-tx-textMuted mt-1 leading-snug">{stage.description}</p>
              </div>

              <div className="pt-2 border-t border-white/10 flex items-center justify-between text-[11px]">
                <span className="text-tx-textMuted">{stage.dropoff}</span>
                <span className="font-mono font-bold text-tx-gold">{stage.conversion}</span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Cohort Retention Matrix */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="p-6 rounded-2xl bg-tx-card border border-tx-border space-y-4 lg:col-span-1">
          <div className="flex items-center gap-2 border-b border-tx-border pb-3">
            <Sparkles className="w-4 h-4 text-tx-gold" />
            <h3 className="text-sm font-bold text-tx-cream">Cohort Retention Rates</h3>
          </div>

          <p className="text-xs text-tx-textMuted leading-relaxed">
            Percentage of acquired users returning to TX Browser across milestone intervals post-installation.
          </p>

          <div className="space-y-3.5 pt-1">
            {[
              { label: 'Day 1 Retention', rate: cohortRetention.day1, target: '70%+', color: 'bg-emerald-500' },
              { label: 'Day 7 Retention', rate: cohortRetention.day7, target: '45%+', color: 'bg-sky-500' },
              { label: 'Day 14 Retention', rate: cohortRetention.day14, target: '35%+', color: 'bg-indigo-500' },
              { label: 'Day 30 Retention', rate: cohortRetention.day30, target: '25%+', color: 'bg-amber-500' },
            ].map((cohort) => (
              <div key={cohort.label} className="space-y-1.5">
                <div className="flex items-center justify-between text-xs font-semibold">
                  <span className="text-tx-cream">{cohort.label}</span>
                  <span className="font-mono text-tx-gold">{cohort.rate}%</span>
                </div>
                <div className="w-full h-2 rounded-full bg-tx-surface overflow-hidden">
                  <div
                    className={`h-full ${cohort.color} rounded-full transition-all duration-500`}
                    style={{ width: `${Math.min(cohort.rate, 100)}%` }}
                  />
                </div>
                <div className="flex justify-between text-[10px] text-tx-textMuted">
                  <span>Industry benchmark</span>
                  <span>Target: {cohort.target}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Top Backlink Campaigns */}
        <div className="p-6 rounded-2xl bg-tx-card border border-tx-border space-y-4 lg:col-span-2">
          <div className="flex items-center justify-between border-b border-tx-border pb-3">
            <div className="flex items-center gap-2">
              <Link2 className="w-4 h-4 text-tx-gold" />
              <h3 className="text-sm font-bold text-tx-cream">Campaign Attribution & Backlinks Breakdown</h3>
            </div>
            <span className="text-[11px] text-tx-textMuted font-mono">Live Referral Data</span>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-tx-textMuted">
              <thead className="bg-tx-surface text-tx-cream border-b border-tx-border uppercase text-[10px] tracking-wider font-semibold">
                <tr>
                  <th className="px-4 py-3">Campaign</th>
                  <th className="px-4 py-3">Slug</th>
                  <th className="px-4 py-3 text-right">Clicks</th>
                  <th className="px-4 py-3 text-right">Installs</th>
                  <th className="px-4 py-3 text-right">Conv %</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-tx-border/60">
                {campaigns.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-tx-textMuted">
                      No campaign backlinks registered yet.
                    </td>
                  </tr>
                ) : (
                  campaigns.map((camp) => (
                    <tr key={camp.id} className="hover:bg-tx-surface/50 transition-colors">
                      <td className="px-4 py-3 font-semibold text-tx-cream">{camp.title}</td>
                      <td className="px-4 py-3 font-mono text-tx-gold">{camp.slug}</td>
                      <td className="px-4 py-3 text-right font-mono text-tx-cream">
                        {camp.clicks.toLocaleString()}
                      </td>
                      <td className="px-4 py-3 text-right font-mono text-emerald-400">
                        {camp.installs.toLocaleString()}
                      </td>
                      <td className="px-4 py-3 text-right font-mono font-bold text-amber-400">
                        {camp.conversionRate}%
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
};
