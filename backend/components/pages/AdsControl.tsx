'use client';

import React, { useState, useEffect } from 'react';
import {
  DollarSign,
  ShieldAlert,
  Sliders,
  Sparkles,
  Save,
  RotateCcw,
  CheckCircle2,
  AlertTriangle,
  Clock,
  Layers,
  Radio,
  Eye,
  Key,
} from 'lucide-react';
import { api } from '@/lib/api-client';

interface AdConfigData {
  admobAppId: string;
  bannerEnabled: boolean;
  interstitialEnabled: boolean;
  rewardedEnabled: boolean;
  nativeEnabled: boolean;
  appOpenEnabled: boolean;
  bannerAdUnitId: string;
  interstitialAdUnitId: string;
  rewardedAdUnitId: string;
  appOpenAdUnitId: string;
  nativeAdUnitId: string;
  rewardedPerkMinutes: number;
  interstitialIntervalMinutes: number;
  interstitialPageThreshold: number;
  activePerkMultiplier: number;
  killSwitch: boolean;
  mediationNetwork: string;
}

const DEFAULT_CONFIG: AdConfigData = {
  admobAppId: 'ca-app-pub-3435015056397165~5473577665',
  bannerEnabled: true,
  interstitialEnabled: true,
  rewardedEnabled: true,
  nativeEnabled: true,
  appOpenEnabled: true,
  bannerAdUnitId: 'ca-app-pub-3435015056397165/1621912239',
  interstitialAdUnitId: 'ca-app-pub-3435015056397165/8850550042',
  rewardedAdUnitId: 'ca-app-pub-3435015056397165/8658978359',
  appOpenAdUnitId: 'ca-app-pub-3435015056397165/3538513614',
  nativeAdUnitId: 'ca-app-pub-3435015056397165/5210687936',
  rewardedPerkMinutes: 10,
  interstitialIntervalMinutes: 5,
  interstitialPageThreshold: 4,
  activePerkMultiplier: 1.0,
  killSwitch: false,
  mediationNetwork: 'ADMOB',
};

export const AdsControl: React.FC = () => {
  const [config, setConfig] = useState<AdConfigData>(DEFAULT_CONFIG);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  useEffect(() => {
    fetchConfig();
  }, []);

  const fetchConfig = async () => {
    try {
      setLoading(true);
      const data = await api.get<any>('/admin/ads/config');
      if (data?.success && data?.config) {
        setConfig(data.config);
      }
    } catch (err: any) {
      setErrorMsg('Failed to load ad configuration');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      setErrorMsg('');
      setSaveSuccess(false);

      const data = await api.put<any>('/admin/ads/config', config);

      if (data?.success) {
        setSaveSuccess(true);
        setTimeout(() => setSaveSuccess(false), 3500);
      } else {
        setErrorMsg(data?.error || 'Failed to save configuration');
      }
    } catch (err: any) {
      setErrorMsg(err?.message || 'Network error saving ad settings');
    } finally {
      setSaving(false);
    }
  };

  const resetToDefaults = () => {
    if (confirm('Reset all AdMob units and frequency caps to production defaults?')) {
      setConfig(DEFAULT_CONFIG);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[400px]">
        <div className="w-10 h-10 border-2 border-tx-gold/20 border-t-tx-gold rounded-full animate-spin" />
        <p className="mt-4 text-xs font-medium text-tx-textMuted">Syncing AdMob & Mediation Controls...</p>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-tx-border pb-5">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center">
              <DollarSign className="w-5 h-5 text-tx-gold" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-tx-cream tracking-tight">Remote AdMob & Mediation Controls</h1>
              <p className="text-xs text-tx-textMuted mt-0.5">
                Centralized cloud control over ad unit IDs, frequency thresholds, perk duration, and kill-switches.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={resetToDefaults}
            className="px-3.5 py-2 text-xs font-semibold text-tx-textMuted hover:text-tx-cream bg-tx-card border border-tx-border hover:border-tx-borderHover rounded-xl flex items-center gap-2 transition-all shadow-sm"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            Reset Defaults
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="px-4 py-2 text-xs font-semibold text-black bg-gradient-to-r from-tx-gold to-amber-500 hover:from-amber-400 hover:to-amber-500 disabled:opacity-50 rounded-xl flex items-center gap-2 transition-all shadow-glow font-medium"
          >
            {saving ? (
              <div className="w-4 h-4 border-2 border-black/30 border-t-black rounded-full animate-spin" />
            ) : (
              <Save className="w-4 h-4" />
            )}
            Save Controls
          </button>
        </div>
      </div>

      {/* Notifications */}
      {saveSuccess && (
        <div className="flex items-center gap-2.5 p-3.5 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs">
          <CheckCircle2 className="w-4 h-4 flex-shrink-0" />
          <span>Ad controls successfully updated! Changes are live across all active TX Browser clients.</span>
        </div>
      )}

      {errorMsg && (
        <div className="flex items-center gap-2.5 p-3.5 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-xs">
          <AlertTriangle className="w-4 h-4 flex-shrink-0" />
          <span>{errorMsg}</span>
        </div>
      )}

      {/* Emergency Kill-Switch Banner */}
      <div
        className={`p-5 rounded-2xl border transition-all ${
          config.killSwitch
            ? 'bg-red-950/40 border-red-500/50 shadow-lg shadow-red-950/20'
            : 'bg-tx-card border-tx-border'
        }`}
      >
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="flex items-start gap-3.5">
            <div
              className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ${
                config.killSwitch
                  ? 'bg-red-500 text-white animate-pulse'
                  : 'bg-tx-surface text-tx-textMuted border border-tx-border'
              }`}
            >
              <ShieldAlert className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-sm font-bold text-tx-cream">Emergency Ad Kill-Switch</h3>
                {config.killSwitch ? (
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-red-500/20 border border-red-500/50 text-red-400">
                    ALL ADS MUTED WORLDWIDE
                  </span>
                ) : (
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 border border-emerald-500/30 text-emerald-400">
                    NORMAL ADS ACTIVE
                  </span>
                )}
              </div>
              <p className="text-xs text-tx-textMuted mt-1">
                Instantly deactivates all ad formats across every TX Browser installation without requiring an app store update.
              </p>
            </div>
          </div>

          <label className="relative inline-flex items-center cursor-pointer">
            <input
              type="checkbox"
              checked={config.killSwitch}
              onChange={(e) => setConfig({ ...config, killSwitch: e.target.checked })}
              className="sr-only peer"
            />
            <div className="w-14 h-7 bg-tx-surface peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[4px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:bg-red-600 border border-tx-border"></div>
          </label>
        </div>
      </div>

      {/* Grid: Formats & Frequency Caps */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Ad Formats Matrix */}
        <div className="p-5 rounded-2xl bg-tx-card border border-tx-border space-y-4">
          <div className="flex items-center justify-between border-b border-tx-border pb-3">
            <div className="flex items-center gap-2">
              <Layers className="w-4 h-4 text-tx-gold" />
              <h3 className="text-sm font-bold text-tx-cream">Ad Formats Active Matrix</h3>
            </div>
            <span className="text-[11px] text-tx-textMuted font-mono">5 Placements</span>
          </div>

          <div className="space-y-3">
            {[
              {
                key: 'bannerEnabled',
                label: 'In-Feed & MREC Banners',
                desc: 'Home page and tab manager lightweight banner slots',
              },
              {
                key: 'interstitialEnabled',
                label: 'Transition Interstitials',
                desc: 'Full-screen transitions shown between high-intent actions',
              },
              {
                key: 'rewardedEnabled',
                label: 'Rewarded Video Perk Ads',
                desc: '10-minute ad-free browsing reward after user opt-in view',
              },
              {
                key: 'nativeEnabled',
                label: 'Native Content Ads',
                desc: 'Integrated cards in downloads, history, and search suggestions',
              },
              {
                key: 'appOpenEnabled',
                label: 'App Open Ads',
                desc: 'Premium splash launch & background resume display',
              },
            ].map((format) => (
              <div
                key={format.key}
                className="flex items-center justify-between p-3 rounded-xl bg-tx-surface border border-tx-border/60 hover:border-tx-border transition-all"
              >
                <div>
                  <p className="text-xs font-semibold text-tx-cream">{format.label}</p>
                  <p className="text-[11px] text-tx-textMuted">{format.desc}</p>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={(config as any)[format.key]}
                    onChange={(e) =>
                      setConfig({ ...config, [format.key]: e.target.checked })
                    }
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-tx-bg peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-amber-500 border border-tx-border"></div>
                </label>
              </div>
            ))}
          </div>
        </div>

        {/* Frequency & Perks Control */}
        <div className="p-5 rounded-2xl bg-tx-card border border-tx-border space-y-4">
          <div className="flex items-center justify-between border-b border-tx-border pb-3">
            <div className="flex items-center gap-2">
              <Sliders className="w-4 h-4 text-tx-gold" />
              <h3 className="text-sm font-bold text-tx-cream">Frequency Caps & Perks</h3>
            </div>
            <span className="text-[11px] text-tx-textMuted font-mono">User Experience Tuning</span>
          </div>

          <div className="space-y-4">
            {/* Rewarded Perk Duration */}
            <div className="p-3.5 rounded-xl bg-tx-surface border border-tx-border/60 space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Sparkles className="w-3.5 h-3.5 text-amber-400" />
                  <span className="text-xs font-semibold text-tx-cream">Rewarded Perk Duration</span>
                </div>
                <span className="px-2 py-0.5 rounded-lg text-xs font-mono font-bold bg-amber-500/15 text-tx-gold border border-amber-500/30">
                  {config.rewardedPerkMinutes} min
                </span>
              </div>
              <p className="text-[11px] text-tx-textMuted">
                How many minutes of 100% ad-free browsing the user receives after watching a rewarded ad.
              </p>
              <input
                type="range"
                min="5"
                max="60"
                step="5"
                value={config.rewardedPerkMinutes}
                onChange={(e) =>
                  setConfig({ ...config, rewardedPerkMinutes: parseInt(e.target.value) })
                }
                className="w-full h-1.5 bg-tx-bg rounded-lg appearance-none cursor-pointer accent-amber-500"
              />
            </div>

            {/* Interstitial Cooldown */}
            <div className="p-3.5 rounded-xl bg-tx-surface border border-tx-border/60 space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Clock className="w-3.5 h-3.5 text-sky-400" />
                  <span className="text-xs font-semibold text-tx-cream">Interstitial Cooldown Interval</span>
                </div>
                <span className="px-2 py-0.5 rounded-lg text-xs font-mono font-bold bg-sky-500/15 text-sky-400 border border-sky-500/30">
                  {config.interstitialIntervalMinutes} min
                </span>
              </div>
              <p className="text-[11px] text-tx-textMuted">
                Minimum cooldown required between full-screen interstitials to protect user retention.
              </p>
              <input
                type="range"
                min="1"
                max="30"
                step="1"
                value={config.interstitialIntervalMinutes}
                onChange={(e) =>
                  setConfig({ ...config, interstitialIntervalMinutes: parseInt(e.target.value) })
                }
                className="w-full h-1.5 bg-tx-bg rounded-lg appearance-none cursor-pointer accent-sky-500"
              />
            </div>

            {/* Page Threshold */}
            <div className="p-3.5 rounded-xl bg-tx-surface border border-tx-border/60 space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Eye className="w-3.5 h-3.5 text-emerald-400" />
                  <span className="text-xs font-semibold text-tx-cream">Pages Between Interstitial</span>
                </div>
                <span className="px-2 py-0.5 rounded-lg text-xs font-mono font-bold bg-emerald-500/15 text-emerald-400 border border-emerald-500/30">
                  {config.interstitialPageThreshold} pages
                </span>
              </div>
              <p className="text-[11px] text-tx-textMuted">
                User must visit at least this many web pages before an interstitial may trigger.
              </p>
              <input
                type="range"
                min="2"
                max="10"
                step="1"
                value={config.interstitialPageThreshold}
                onChange={(e) =>
                  setConfig({ ...config, interstitialPageThreshold: parseInt(e.target.value) })
                }
                className="w-full h-1.5 bg-tx-bg rounded-lg appearance-none cursor-pointer accent-emerald-500"
              />
            </div>

            {/* Mediation Network Selector */}
            <div className="p-3.5 rounded-xl bg-tx-surface border border-tx-border/60 space-y-2">
              <label className="text-xs font-semibold text-tx-cream block">Mediation Routing</label>
              <select
                value={config.mediationNetwork}
                onChange={(e) => setConfig({ ...config, mediationNetwork: e.target.value })}
                className="w-full px-3 py-2 text-xs bg-tx-bg border border-tx-border rounded-lg text-tx-cream focus:outline-none focus:border-tx-gold"
              >
                <option value="ADMOB">Google AdMob (Primary Direct)</option>
                <option value="APPLOVIN">AppLovin MAX Mediation Waterfall</option>
                <option value="UNITY">Unity Ads Mediation Bidding</option>
                <option value="CUSTOM">Custom Server-Side Waterfall</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      {/* Production Unit IDs Card */}
      <div className="p-5 rounded-2xl bg-tx-card border border-tx-border space-y-4">
        <div className="flex items-center justify-between border-b border-tx-border pb-3">
          <div className="flex items-center gap-2">
            <Key className="w-4 h-4 text-tx-gold" />
            <h3 className="text-sm font-bold text-tx-cream">Production Ad Unit IDs</h3>
          </div>
          <span className="text-[11px] text-tx-textMuted font-mono">Dynamic Remote Sync</span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="text-xs font-medium text-tx-textMuted block mb-1">AdMob App ID</label>
            <input
              type="text"
              value={config.admobAppId}
              onChange={(e) => setConfig({ ...config, admobAppId: e.target.value })}
              className="w-full px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream font-mono focus:outline-none focus:border-tx-gold"
            />
          </div>

          <div>
            <label className="text-xs font-medium text-tx-textMuted block mb-1">Banner Ad Unit ID</label>
            <input
              type="text"
              value={config.bannerAdUnitId}
              onChange={(e) => setConfig({ ...config, bannerAdUnitId: e.target.value })}
              className="w-full px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream font-mono focus:outline-none focus:border-tx-gold"
            />
          </div>

          <div>
            <label className="text-xs font-medium text-tx-textMuted block mb-1">Interstitial Ad Unit ID</label>
            <input
              type="text"
              value={config.interstitialAdUnitId}
              onChange={(e) => setConfig({ ...config, interstitialAdUnitId: e.target.value })}
              className="w-full px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream font-mono focus:outline-none focus:border-tx-gold"
            />
          </div>

          <div>
            <label className="text-xs font-medium text-tx-textMuted block mb-1">Rewarded Video Ad Unit ID</label>
            <input
              type="text"
              value={config.rewardedAdUnitId}
              onChange={(e) => setConfig({ ...config, rewardedAdUnitId: e.target.value })}
              className="w-full px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream font-mono focus:outline-none focus:border-tx-gold"
            />
          </div>

          <div>
            <label className="text-xs font-medium text-tx-textMuted block mb-1">App Open Ad Unit ID</label>
            <input
              type="text"
              value={config.appOpenAdUnitId}
              onChange={(e) => setConfig({ ...config, appOpenAdUnitId: e.target.value })}
              className="w-full px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream font-mono focus:outline-none focus:border-tx-gold"
            />
          </div>

          <div>
            <label className="text-xs font-medium text-tx-textMuted block mb-1">Native Ad Unit ID</label>
            <input
              type="text"
              value={config.nativeAdUnitId}
              onChange={(e) => setConfig({ ...config, nativeAdUnitId: e.target.value })}
              className="w-full px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream font-mono focus:outline-none focus:border-tx-gold"
            />
          </div>
        </div>
      </div>
    </div>
  );
};
