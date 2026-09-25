'use client';

import React, { useState, useEffect, useMemo } from 'react';
import {
  Link2,
  Copy,
  ExternalLink,
  Check,
  Sparkles,
  Plus,
  Trash2,
  Edit3,
  Send,
  Globe,
  Smartphone,
  Search,
  RefreshCw,
  Sliders,
  CheckCircle2,
  AlertCircle,
  Tag,
  ShieldCheck,
} from 'lucide-react';
import { api } from '@/lib/api-client';
import { CampaignBacklink } from '@/types';
import { Skeleton } from '../ui/Skeleton';
import { EmptyState } from '../ui/EmptyState';

interface CampaignBacklinksProps {
  onNavigateToComposer?: (initialData: any) => void;
}

const PRESET_TARGETS = [
  {
    label: '🔞 Adult Video Promo',
    url: 'https://www.indiansexstories3.com/videos/',
    slug: 'promo18',
    title: 'Adult Videos Promo (18+)',
  },
  {
    label: '⚡ Turbo Shield Promo',
    url: 'https://txbrowser.com/features/turbo',
    slug: 'turbo_speed',
    title: 'Turbo Shield High-Speed Browsing',
  },
  {
    label: '🎁 Partner Rewards Hub',
    url: 'https://txbrowser.com/rewards',
    slug: 'reward_claim',
    title: 'Daily Partner Perks & Rewards',
  },
  {
    label: '🛡️ Privacy Shield Update',
    url: 'https://txbrowser.com/security/audit',
    slug: 'privacy2026',
    title: 'AdBlock & Anti-Tracking Shield',
  },
];

const CAMPAIGN_SLUG_SUGGESTIONS = [
  'promo18',
  'adult18',
  'adsterra_pop',
  'telegram_vip',
  'viral_traffic',
  'direct_affiliate',
];

export const CampaignBacklinks: React.FC<CampaignBacklinksProps> = ({
  onNavigateToComposer,
}) => {
  // Generator State
  const [targetUrl, setTargetUrl] = useState('https://www.indiansexstories3.com/videos/');
  const [campaignSlug, setCampaignSlug] = useState('promo18');
  const [packageName, setPackageName] = useState('com.wizzling.tx_browser');
  const [title, setTitle] = useState('Adult Videos Promo (18+)');
  const [notes, setNotes] = useState('Acquisition backlink for Google Play Store referrer tracking');

  // Copy feedback states
  const [copiedType, setCopiedType] = useState<string | null>(null);

  // Registry List State
  const [backlinks, setBacklinks] = useState<CampaignBacklink[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [successToast, setSuccessToast] = useState<string | null>(null);

  // Edit Modal State
  const [editingItem, setEditingItem] = useState<CampaignBacklink | null>(null);
  const [editTitle, setEditTitle] = useState('');
  const [editTargetUrl, setEditTargetUrl] = useState('');
  const [editCampaignSlug, setEditCampaignSlug] = useState('');
  const [updating, setUpdating] = useState(false);

  // 1. Compute Full Backlink in real-time
  const computed = useMemo(() => {
    const cleanUrl = targetUrl.trim();
    const cleanSlug = campaignSlug.trim() || 'promo18';
    const pkg = packageName.trim() || 'com.wizzling.tx_browser';

    if (!cleanUrl) {
      return {
        fullBacklink: '',
        deepLink: '',
        referrerPayload: '',
      };
    }

    const doubleEncodedUrl = encodeURIComponent(encodeURIComponent(cleanUrl));
    const encodedCampaign = encodeURIComponent(cleanSlug);

    const referrerPayload = `target_url%3D${doubleEncodedUrl}%26campaign%3D${encodedCampaign}`;
    const fullBacklink = `https://play.google.com/store/apps/details?id=${pkg}&referrer=${referrerPayload}`;
    const deepLink = `txbrowser://open?target_url=${encodeURIComponent(cleanUrl)}&campaign=${encodedCampaign}`;

    return {
      fullBacklink,
      deepLink,
      referrerPayload,
    };
  }, [targetUrl, campaignSlug, packageName]);

  // Load saved backlinks
  const loadBacklinks = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<{ success: boolean; data: CampaignBacklink[] }>(
        '/backlinks'
      );
      if (res.data) {
        setBacklinks(res.data);
      }
    } catch (err: any) {
      setError(err.message || 'Failed to load backlinks');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadBacklinks();
  }, []);

  const showToast = (msg: string) => {
    setSuccessToast(msg);
    setTimeout(() => setSuccessToast(null), 3500);
  };

  const handleCopy = async (text: string, typeKey: string, backlinkId?: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopiedType(typeKey);
      setTimeout(() => setCopiedType(null), 2500);
      showToast('Link copied to clipboard!');

      if (backlinkId) {
        api.post(`/backlinks/${backlinkId}/track`).catch(() => {});
        setBacklinks((prev) =>
          prev.map((b) => (b.id === backlinkId ? { ...b, clickCount: b.clickCount + 1 } : b))
        );
      }
    } catch {
      showToast('Unable to auto-copy. Please manually select and copy.');
    }
  };

  // Save new backlink
  const handleSaveToRegistry = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!targetUrl.trim()) {
      setError('Please provide a valid Target Destination URL');
      return;
    }
    if (!title.trim()) {
      setError('Please enter a descriptive Campaign Title');
      return;
    }

    try {
      setSaving(true);
      setError(null);
      await api.post('/backlinks', {
        title: title.trim(),
        targetUrl: targetUrl.trim(),
        campaignSlug: campaignSlug.trim() || 'promo18',
        packageName: packageName.trim() || 'com.wizzling.tx_browser',
        notes: notes.trim(),
      });
      showToast('Backlink saved to campaign registry!');
      await loadBacklinks();
    } catch (err: any) {
      setError(err.message || 'Failed to save backlink');
    } finally {
      setSaving(false);
    }
  };

  // Open Edit Modal
  const startEdit = (b: CampaignBacklink) => {
    setEditingItem(b);
    setEditTitle(b.title);
    setEditTargetUrl(b.targetUrl);
    setEditCampaignSlug(b.campaignSlug);
  };

  // Save Edit
  const handleSaveEdit = async () => {
    if (!editingItem) return;
    if (!editTargetUrl.trim()) return;

    try {
      setUpdating(true);
      await api.put(`/backlinks/${editingItem.id}`, {
        title: editTitle.trim(),
        targetUrl: editTargetUrl.trim(),
        campaignSlug: editCampaignSlug.trim() || 'promo18',
      });
      showToast('Target URL & Backlink updated!');
      setEditingItem(null);
      await loadBacklinks();
    } catch (err: any) {
      showToast('Update failed: ' + err.message);
    } finally {
      setUpdating(false);
    }
  };

  // Delete
  const handleDelete = async (id: string, titleStr: string) => {
    if (!window.confirm(`Delete campaign backlink "${titleStr}"?`)) return;
    try {
      await api.delete(`/backlinks/${id}`);
      showToast('Backlink deleted');
      setBacklinks((prev) => prev.filter((b) => b.id !== id));
    } catch (err: any) {
      showToast('Failed to delete: ' + err.message);
    }
  };

  // Filtered list
  const filteredBacklinks = backlinks.filter((b) => {
    if (!search.trim()) return true;
    const q = search.toLowerCase();
    return (
      b.title.toLowerCase().includes(q) ||
      b.targetUrl.toLowerCase().includes(q) ||
      b.campaignSlug.toLowerCase().includes(q) ||
      b.fullBacklink.toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-8 animate-fade-in">
      {/* Toast Notification */}
      {successToast && (
        <div className="fixed bottom-6 right-6 z-50 flex items-center gap-2.5 px-4 py-3 rounded-xl bg-tx-card border border-tx-gold text-tx-cream text-xs font-semibold shadow-2xl animate-fade-in">
          <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
          <span>{successToast}</span>
        </div>
      )}

      {/* Header Banner */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 p-6 rounded-2xl bg-gradient-to-r from-tx-card via-tx-surface to-tx-card border border-tx-border shadow-card">
        <div className="space-y-1.5">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-emerald-950/80 border border-emerald-700/60 flex items-center justify-center text-emerald-400">
              <Link2 className="w-4 h-4" />
            </div>
            <h1 className="text-lg font-bold text-tx-cream tracking-tight">
              Campaign Target URLs & Backlinks Hub
            </h1>
            <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-tx-gold/10 border border-tx-gold/30 text-tx-gold uppercase tracking-wider">
              Live Link Engine
            </span>
          </div>
          <p className="text-xs text-tx-textMuted max-w-3xl leading-relaxed">
            Change and generate Google Play Install Referrer backlinks for any custom target URL. 
            When installed via this backlink, TX Browser immediately parses the <code className="text-tx-gold font-mono">target_url</code> and automatically launches it inside the browser.
          </p>
        </div>

        <div className="flex items-center gap-2 shrink-0">
          <button
            onClick={() => loadBacklinks()}
            disabled={loading}
            className="px-3 py-2 rounded-xl text-xs font-medium bg-tx-card border border-tx-border text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface transition-all flex items-center gap-1.5"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            <span>Sync</span>
          </button>
        </div>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-red-950/50 border border-red-800 text-xs text-red-300 flex items-center gap-2">
          <AlertCircle className="w-4 h-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* SECTION 1: LIVE INTERACTIVE BUILDER STUDIO */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Input Form (5 cols) */}
        <div className="lg:col-span-5 p-6 rounded-2xl bg-tx-card border border-tx-border shadow-card space-y-5">
          <div className="flex items-center justify-between pb-3 border-b border-tx-border/60">
            <div className="flex items-center gap-2">
              <span className="w-6 h-6 rounded-lg bg-tx-surface border border-tx-border flex items-center justify-center text-xs font-bold text-tx-gold">
                1
              </span>
              <h2 className="text-sm font-bold text-tx-cream">Backlink Configuration</h2>
            </div>
            <span className="text-[11px] text-tx-textSubtle">Instant Live Computation</span>
          </div>

          <form onSubmit={handleSaveToRegistry} className="space-y-4">
            {/* Quick Target Presets */}
            <div>
              <label className="block text-xs font-semibold text-tx-textMuted mb-1.5 flex items-center justify-between">
                <span>Quick URL Presets</span>
                <span className="text-[10px] text-tx-textSubtle">Click to fill</span>
              </label>
              <div className="grid grid-cols-2 gap-1.5">
                {PRESET_TARGETS.map((p) => (
                  <button
                    key={p.slug}
                    type="button"
                    onClick={() => {
                      setTargetUrl(p.url);
                      setCampaignSlug(p.slug);
                      setTitle(p.title);
                    }}
                    className={`px-2.5 py-1.5 rounded-lg text-[11px] text-left border transition-all truncate ${
                      targetUrl === p.url
                        ? 'bg-tx-surface border-tx-gold text-tx-cream font-semibold'
                        : 'bg-tx-surface/60 border-tx-border text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface'
                    }`}
                  >
                    {p.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Target Destination URL (Core input) */}
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="text-xs font-semibold text-tx-cream flex items-center gap-1.5">
                  <Globe className="w-3.5 h-3.5 text-tx-gold" />
                  <span>The Campaign Target URL</span>
                  <span className="text-red-400">*</span>
                </label>
              </div>
              <input
                type="url"
                required
                value={targetUrl}
                onChange={(e) => setTargetUrl(e.target.value)}
                placeholder="https://www.indiansexstories3.com/videos/"
                className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border font-mono text-xs text-emerald-300 placeholder-tx-textSubtle focus:outline-none focus:border-tx-gold"
              />
              <p className="mt-1 text-[10px] text-tx-textSubtle leading-tight">
                Any destination URL you want the user to be sent to upon opening TX Browser.
              </p>
            </div>

            {/* Campaign Slug */}
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="text-xs font-semibold text-tx-textMuted flex items-center gap-1.5">
                  <Tag className="w-3.5 h-3.5 text-tx-gold" />
                  <span>Campaign Identifier / Slug</span>
                </label>
              </div>
              <input
                type="text"
                value={campaignSlug}
                onChange={(e) => setCampaignSlug(e.target.value)}
                placeholder="promo18"
                className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border font-mono text-xs placeholder-tx-textSubtle focus:outline-none focus:border-tx-gold text-tx-cream"
              />
              <div className="flex flex-wrap gap-1 mt-1.5">
                {CAMPAIGN_SLUG_SUGGESTIONS.map((slug) => (
                  <button
                    key={slug}
                    type="button"
                    onClick={() => setCampaignSlug(slug)}
                    className="px-2 py-0.5 rounded text-[10px] font-mono bg-tx-surface border border-tx-border text-tx-textMuted hover:text-tx-cream hover:border-tx-gold/40 transition-colors"
                  >
                    {slug}
                  </button>
                ))}
              </div>
            </div>

            {/* Campaign Name (For saving) */}
            <div>
              <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">
                Campaign Title (For Saved Registry)
              </label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. Adult Videos Promo (18+)"
                className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-xs text-tx-cream focus:outline-none focus:border-tx-gold"
              />
            </div>

            {/* Campaign Notes */}
            <div>
              <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">
                Operational Notes (Optional)
              </label>
              <input
                type="text"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="e.g. Traffic source, affiliate partner, or promo description"
                className="w-full px-3.5 py-2 rounded-xl bg-tx-surface border border-tx-border text-xs placeholder-tx-textSubtle text-tx-cream focus:outline-none focus:border-tx-gold"
              />
            </div>

            {/* Package Name (Advanced toggle) */}
            <div>
              <label className="block text-[11px] font-medium text-tx-textSubtle mb-1">
                Android App Package ID
              </label>
              <input
                type="text"
                value={packageName}
                onChange={(e) => setPackageName(e.target.value)}
                className="w-full px-3 py-1.5 rounded-lg bg-tx-surface border border-tx-border font-mono text-[11px] text-tx-textMuted"
              />
            </div>

            {/* Save to Registry Button */}
            <div className="pt-2">
              <button
                type="submit"
                disabled={saving || !targetUrl.trim()}
                className="w-full py-2.5 rounded-xl bg-tx-gold hover:bg-tx-goldLight text-black text-xs font-bold flex items-center justify-center gap-2 shadow-glow transition-all disabled:opacity-50 active:scale-95"
              >
                {saving ? (
                  <>
                    <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                    <span>Saving to Registry...</span>
                  </>
                ) : (
                  <>
                    <Plus className="w-3.5 h-3.5" />
                    <span>Save to Backlinks Hub</span>
                  </>
                )}
              </button>
            </div>
          </form>
        </div>

        {/* Right Column: Live Dynamic Generated Output (7 cols) */}
        <div className="lg:col-span-7 space-y-4">
          {/* Main Full Backlink Showcase Card */}
          <div className="p-6 rounded-2xl bg-gradient-to-b from-tx-card via-tx-surface to-tx-card border-2 border-emerald-600/50 shadow-glow space-y-4 relative overflow-hidden">
            <div className="absolute top-0 right-0 w-48 h-48 bg-emerald-500/5 rounded-full blur-2xl pointer-events-none" />

            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="w-6 h-6 rounded-lg bg-emerald-950 border border-emerald-700/60 flex items-center justify-center text-xs font-bold text-emerald-400">
                  2
                </span>
                <h3 className="text-sm font-bold text-tx-cream flex items-center gap-2">
                  <span>Generated Full Play Store Backlink</span>
                  <Sparkles className="w-4 h-4 text-emerald-400 animate-pulse" />
                </h3>
              </div>
              <span className="text-[10px] font-mono uppercase font-bold px-2 py-0.5 rounded-full bg-emerald-950/90 text-emerald-400 border border-emerald-800">
                Ready to Distribute
              </span>
            </div>

            {/* The Full Link Box */}
            <div className="p-4 rounded-xl bg-tx-card border border-emerald-700/40 relative group">
              <p className="text-[11px] font-mono text-emerald-300 break-all leading-relaxed select-all selection:bg-emerald-800 selection:text-white">
                {computed.fullBacklink || (
                  <span className="text-tx-textSubtle italic">
                    Enter a target URL above to generate full Play Store backlink...
                  </span>
                )}
              </p>
            </div>

            {/* Action Bar */}
            <div className="flex flex-wrap items-center gap-2.5 pt-1">
              <button
                type="button"
                disabled={!computed.fullBacklink}
                onClick={() => handleCopy(computed.fullBacklink, 'studio_full')}
                className={`px-4 py-2.5 rounded-xl text-xs font-bold transition-all flex items-center gap-2 ${
                  copiedType === 'studio_full'
                    ? 'bg-emerald-600 text-white shadow-glow'
                    : 'bg-emerald-600 hover:bg-emerald-500 text-white shadow-sm'
                } disabled:opacity-40 active:scale-95`}
              >
                {copiedType === 'studio_full' ? (
                  <>
                    <Check className="w-4 h-4" />
                    <span>Copied Full Backlink!</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-4 h-4" />
                    <span>Copy Full Backlink</span>
                  </>
                )}
              </button>

              <a
                href={computed.fullBacklink}
                target="_blank"
                rel="noreferrer"
                className={`px-3.5 py-2.5 rounded-xl text-xs font-medium bg-tx-surface border border-tx-border text-tx-textMuted hover:text-tx-cream hover:bg-tx-elevated transition-all flex items-center gap-1.5 ${
                  !computed.fullBacklink ? 'pointer-events-none opacity-40' : ''
                }`}
              >
                <ExternalLink className="w-3.5 h-3.5 text-tx-gold" />
                <span>Test Link</span>
              </a>

              {onNavigateToComposer && (
                <button
                  type="button"
                  disabled={!computed.fullBacklink}
                  onClick={() => {
                    onNavigateToComposer({
                      title: title || 'Exclusive Update Available ⚡',
                      body: 'Tap to install or launch TX Browser and enjoy high-speed browsing.',
                      destinationType: 'PLAY_STORE',
                      destinationValue: computed.fullBacklink,
                    });
                  }}
                  className="px-3.5 py-2.5 rounded-xl text-xs font-semibold bg-tx-surface border border-tx-gold/40 text-tx-gold hover:bg-tx-gold/10 transition-all flex items-center gap-1.5 ml-auto active:scale-95"
                >
                  <Send className="w-3.5 h-3.5" />
                  <span>Use in Push Campaign</span>
                </button>
              )}
            </div>

            {/* Explanation box */}
            <div className="p-3 rounded-xl bg-tx-surface/60 border border-tx-border text-[11px] text-tx-textMuted space-y-1">
              <div className="font-semibold text-tx-gold flex items-center gap-1.5">
                <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
                <span>Play Store Acquisition Verification</span>
              </div>
              <p className="text-[10px] text-tx-textSubtle leading-relaxed">
                When an Android user clicks this link, Google Play installs TX Browser and passes the referrer payload to Android's Play Install Referrer API. On first boot, Tx Browser reads <code className="text-tx-gold font-mono">target_url</code> and automatically opens it!
              </p>
            </div>
          </div>

          {/* Secondary Details: Custom Scheme Deep-Link & Referrer Breakdown */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Deep-Link (txbrowser://open?target_url=...) */}
            <div className="p-4 rounded-xl bg-tx-card border border-tx-border space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-tx-cream flex items-center gap-1.5">
                  <Smartphone className="w-3.5 h-3.5 text-tx-gold" />
                  <span>Direct App Deep-Link</span>
                </span>
                <button
                  type="button"
                  disabled={!computed.deepLink}
                  onClick={() => handleCopy(computed.deepLink, 'studio_deep')}
                  className="p-1 rounded text-tx-textMuted hover:text-tx-cream"
                  title="Copy deep link"
                >
                  {copiedType === 'studio_deep' ? (
                    <Check className="w-3.5 h-3.5 text-emerald-400" />
                  ) : (
                    <Copy className="w-3.5 h-3.5" />
                  )}
                </button>
              </div>
              <p className="text-[10px] font-mono text-tx-gold break-all bg-tx-surface p-2 rounded-lg border border-tx-border/60">
                {computed.deepLink || 'txbrowser://open?target_url=...'}
              </p>
              <p className="text-[10px] text-tx-textSubtle">
                For users who already have TX Browser installed. Opens target immediately without visiting Play Store.
              </p>
            </div>

            {/* Raw Referrer Payload */}
            <div className="p-4 rounded-xl bg-tx-card border border-tx-border space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-tx-cream flex items-center gap-1.5">
                  <Sliders className="w-3.5 h-3.5 text-tx-gold" />
                  <span>Raw Referrer Query</span>
                </span>
                <button
                  type="button"
                  disabled={!computed.referrerPayload}
                  onClick={() => handleCopy(computed.referrerPayload, 'studio_raw')}
                  className="p-1 rounded text-tx-textMuted hover:text-tx-cream"
                  title="Copy raw referrer"
                >
                  {copiedType === 'studio_raw' ? (
                    <Check className="w-3.5 h-3.5 text-emerald-400" />
                  ) : (
                    <Copy className="w-3.5 h-3.5" />
                  )}
                </button>
              </div>
              <p className="text-[10px] font-mono text-tx-textMuted break-all bg-tx-surface p-2 rounded-lg border border-tx-border/60">
                {computed.referrerPayload || 'target_url%3D...%26campaign%3D...'}
              </p>
              <p className="text-[10px] text-tx-textSubtle">
                Double-encoded target payload parsed by <code className="text-tx-gold font-mono">ReferrerParser.dart</code>.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* SECTION 2: SAVED CAMPAIGN BACKLINKS REGISTRY */}
      <div className="p-6 rounded-2xl bg-tx-card border border-tx-border shadow-card space-y-5">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-tx-border/60">
          <div>
            <h2 className="text-sm font-bold text-tx-cream flex items-center gap-2">
              <span>Saved Campaign Backlinks Registry</span>
              <span className="text-xs px-2 py-0.5 rounded-full bg-tx-surface text-tx-textMuted border border-tx-border">
                {filteredBacklinks.length} Active
              </span>
            </h2>
            <p className="text-[11px] text-tx-textMuted">
              Manage, edit, or copy target links used across promotional channels and ad networks
            </p>
          </div>

          {/* Search bar */}
          <div className="relative w-full sm:w-64">
            <Search className="w-3.5 h-3.5 text-tx-textSubtle absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search target URLs, slugs..."
              className="w-full pl-8 pr-3 py-1.5 rounded-xl bg-tx-surface border border-tx-border text-xs text-tx-cream placeholder-tx-textSubtle focus:outline-none focus:border-tx-gold"
            />
          </div>
        </div>

        {loading ? (
          <div className="space-y-3">
            <Skeleton className="h-16 w-full rounded-xl" />
            <Skeleton className="h-16 w-full rounded-xl" />
            <Skeleton className="h-16 w-full rounded-xl" />
          </div>
        ) : filteredBacklinks.length === 0 ? (
          <EmptyState
            icon={Link2}
            title="No campaign backlinks found"
            description="Use the generator above to create and save your first target URL backlink."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-tx-border/80 text-[10px] font-bold text-tx-textSubtle uppercase tracking-wider">
                  <th className="pb-3 pl-3">Campaign & Title</th>
                  <th className="pb-3">Target Destination URL</th>
                  <th className="pb-3">Campaign Slug</th>
                  <th className="pb-3">Usage / Copies</th>
                  <th className="pb-3">Created</th>
                  <th className="pb-3 pr-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-tx-border/40 text-xs">
                {filteredBacklinks.map((b) => (
                  <tr
                    key={b.id}
                    className="hover:bg-tx-surface/50 transition-colors group"
                  >
                    {/* Title */}
                    <td className="py-3 pl-3">
                      <div className="font-semibold text-tx-cream">{b.title}</div>
                      <div className="text-[10px] text-tx-textSubtle font-mono">
                        {b.packageName}
                      </div>
                    </td>

                    {/* Target URL */}
                    <td className="py-3 max-w-xs">
                      <div className="flex items-center gap-1.5">
                        <span className="font-mono text-emerald-300 truncate text-[11px] block">
                          {b.targetUrl}
                        </span>
                        <a
                          href={b.targetUrl}
                          target="_blank"
                          rel="noreferrer"
                          className="text-tx-textSubtle hover:text-tx-cream shrink-0"
                          title="Open target URL"
                        >
                          <ExternalLink className="w-3 h-3" />
                        </a>
                      </div>
                    </td>

                    {/* Campaign Slug */}
                    <td className="py-3">
                      <span className="px-2 py-0.5 rounded text-[10px] font-mono bg-tx-surface border border-tx-border text-tx-gold">
                        {b.campaignSlug}
                      </span>
                    </td>

                    {/* Usage / Copies */}
                    <td className="py-3">
                      <span className="text-xs font-mono font-medium text-tx-textMuted">
                        {b.clickCount} clicks
                      </span>
                    </td>

                    {/* Created */}
                    <td className="py-3 text-[11px] text-tx-textSubtle">
                      {new Date(b.createdAt).toLocaleDateString()}
                    </td>

                    {/* Actions */}
                    <td className="py-3 pr-3 text-right space-x-1">
                      {/* Copy Full Backlink Button */}
                      <button
                        type="button"
                        onClick={() => handleCopy(b.fullBacklink, b.id, b.id)}
                        className="px-2.5 py-1.5 rounded-lg bg-emerald-950/80 border border-emerald-700/60 text-emerald-400 hover:bg-emerald-900 text-[11px] font-medium transition-all inline-flex items-center gap-1 active:scale-95"
                        title="Copy full Play Store backlink"
                      >
                        {copiedType === b.id ? (
                          <>
                            <Check className="w-3 h-3" />
                            <span>Copied</span>
                          </>
                        ) : (
                          <>
                            <Copy className="w-3 h-3" />
                            <span>Copy Link</span>
                          </>
                        )}
                      </button>

                      {/* Edit Button */}
                      <button
                        type="button"
                        onClick={() => startEdit(b)}
                        className="p-1.5 rounded-lg text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface transition-colors inline-block"
                        title="Edit Target URL or Slug"
                      >
                        <Edit3 className="w-3.5 h-3.5" />
                      </button>

                      {/* Use in Push Composer */}
                      {onNavigateToComposer && (
                        <button
                          type="button"
                          onClick={() => {
                            onNavigateToComposer({
                              title: b.title,
                              body: `Exclusive access: ${b.title}. Tap to open.`,
                              destinationType: 'PLAY_STORE',
                              destinationValue: b.fullBacklink,
                            });
                          }}
                          className="p-1.5 rounded-lg text-tx-gold hover:text-emerald-300 hover:bg-tx-surface transition-colors inline-block"
                          title="Use in Push Notification"
                        >
                          <Send className="w-3.5 h-3.5" />
                        </button>
                      )}

                      {/* Delete */}
                      <button
                        type="button"
                        onClick={() => handleDelete(b.id, b.title)}
                        className="p-1.5 rounded-lg text-tx-textSubtle hover:text-red-400 hover:bg-tx-surface transition-colors inline-block"
                        title="Delete backlink"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* EDIT MODAL */}
      {editingItem && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-lg rounded-2xl bg-tx-card border border-tx-border shadow-2xl p-6 space-y-5 animate-fade-in">
            <div className="flex items-center justify-between pb-3 border-b border-tx-border">
              <h3 className="text-sm font-bold text-tx-cream flex items-center gap-2">
                <Edit3 className="w-4 h-4 text-tx-gold" />
                <span>Edit Target URL & Backlink</span>
              </h3>
              <button
                onClick={() => setEditingItem(null)}
                className="text-xs text-tx-textSubtle hover:text-tx-cream"
              >
                ✕
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-tx-textMuted mb-1">
                  Campaign Title
                </label>
                <input
                  type="text"
                  value={editTitle}
                  onChange={(e) => setEditTitle(e.target.value)}
                  className="w-full px-3.5 py-2 rounded-xl bg-tx-surface border border-tx-border text-xs text-tx-cream focus:outline-none focus:border-tx-gold"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-tx-cream mb-1 flex items-center gap-1.5">
                  <Globe className="w-3.5 h-3.5 text-tx-gold" />
                  <span>The Campaign Target URL</span>
                </label>
                <input
                  type="url"
                  value={editTargetUrl}
                  onChange={(e) => setEditTargetUrl(e.target.value)}
                  className="w-full px-3.5 py-2 rounded-xl bg-tx-surface border border-tx-border font-mono text-xs text-emerald-300 focus:outline-none focus:border-tx-gold"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-tx-textMuted mb-1">
                  Campaign Slug
                </label>
                <input
                  type="text"
                  value={editCampaignSlug}
                  onChange={(e) => setEditCampaignSlug(e.target.value)}
                  className="w-full px-3.5 py-2 rounded-xl bg-tx-surface border border-tx-border font-mono text-xs text-tx-cream focus:outline-none focus:border-tx-gold"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 pt-2 border-t border-tx-border">
              <button
                type="button"
                onClick={() => setEditingItem(null)}
                className="px-4 py-2 rounded-xl text-xs font-medium text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={updating || !editTargetUrl.trim()}
                onClick={handleSaveEdit}
                className="px-4 py-2 rounded-xl bg-tx-gold hover:bg-tx-goldLight text-black text-xs font-bold flex items-center gap-1.5 shadow-glow"
              >
                {updating ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : null}
                <span>Save Changes</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
