'use client';

import React, { useState, useEffect } from 'react';
import {
  Send,
  Link,
  Users,
  Smartphone,
  AlertTriangle,
  Clock,
  Sparkles,
  Wifi,
  BatteryCharging,
  ChevronDown,
  Loader2,
  CheckCircle2,
  Flame,
  Link2,
  Copy,
  Check,
  Globe,
} from 'lucide-react';
import { api } from '@/lib/api-client';
import { NotificationType, DestinationType, AudienceType } from '@/types';
import { TestPushModal } from '../TestPushModal';
import { ImageUploadWithUrl } from '../ImageUploadWithUrl';

interface NotificationComposerProps {
  onSuccess: () => void;
  initialData?: any;
}

const CAMPAIGN_TEMPLATES = [
  {
    name: '🚀 App Version Release',
    title: 'TX Browser Update Available! ⚡',
    body: 'Faster page loading, updated Chromium engine, and enhanced battery saver mode. Tap to update.',
    notificationType: 'BROWSER_UPDATE' as NotificationType,
    destinationType: 'PLAY_STORE' as DestinationType,
    destinationValue: '',
  },
  {
    name: '🛡️ Security Advisory',
    title: 'Privacy Shield Active: Stay Protected',
    body: 'Automated fingerprinting protection and encrypted DNS are now active. Zero trackers allowed.',
    notificationType: 'SECURITY' as NotificationType,
    destinationType: 'INTERNAL_SCREEN' as DestinationType,
    destinationValue: 'settings',
  },
  {
    name: '⚡ Next-Gen AdBlock Boost',
    title: 'Zero Ads. Zero Lag. Pure Speed. 🛡️',
    body: 'Turbo Shield just blocked thousands of background tracking scripts. Experience the cleanest web.',
    notificationType: 'NEW_FEATURE' as NotificationType,
    destinationType: 'HOME' as DestinationType,
    destinationValue: '',
  },
  {
    name: '🎁 Partner Perk Bonus',
    title: 'Exclusive Browser Reward Unlocked 🎁',
    body: 'Claim your daily rewarded browser perk and unlock high-speed browsing privileges.',
    notificationType: 'PROMOTION' as NotificationType,
    destinationType: 'INTERNAL_SCREEN' as DestinationType,
    destinationValue: 'bookmarks',
  },
];

export const NotificationComposer: React.FC<NotificationComposerProps> = ({
  onSuccess,
  initialData,
}) => {
  const [title, setTitle] = useState(initialData?.title || '');
  const [body, setBody] = useState(initialData?.body || '');
  const [imageUrl, setImageUrl] = useState(initialData?.imageUrl || '');
  const [notificationType, setNotificationType] = useState<NotificationType>(
    initialData?.notificationType || 'PROMOTION'
  );
  const [destinationType, setDestinationType] = useState<DestinationType>(
    initialData?.destinationType || 'HOME'
  );
  const [destinationValue, setDestinationValue] = useState(
    initialData?.destinationValue || ''
  );
  const [audienceType, setAudienceType] = useState<AudienceType>(
    initialData?.audienceType || 'ALL_USERS'
  );
  const [topic, setTopic] = useState('tx_all');
  const [activeWithinDays, setActiveWithinDays] = useState<number>(30);
  const [appVersion, setAppVersion] = useState('');
  const [availableVersions, setAvailableVersions] = useState<string[]>(['1.0.5', '1.0.4']);

  const [timing, setTiming] = useState<'NOW' | 'SCHEDULED'>('NOW');
  const [scheduledAt, setScheduledAt] = useState('');

  const [estimatedReach, setEstimatedReach] = useState<number | null>(null);
  const [calculatingReach, setCalculatingReach] = useState(false);

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [showTestModal, setShowTestModal] = useState(false);
  const [previewMode, setPreviewMode] = useState<'expanded' | 'compact' | 'lockscreen'>('expanded');

  // Campaign Target URLs / Play Store Referrer Backlink States
  const isInitialReferrer = initialData?.destinationValue?.includes('referrer=target_url');
  const [playStoreMode, setPlayStoreMode] = useState<'standard' | 'referrer'>(
    isInitialReferrer ? 'referrer' : 'standard'
  );
  const [customTargetUrl, setCustomTargetUrl] = useState(() => {
    if (isInitialReferrer) {
      try {
        const match = initialData.destinationValue.match(/target_url%3D([^&]+)/);
        if (match) return decodeURIComponent(decodeURIComponent(match[1]));
      } catch {}
    }
    return 'https://www.indiansexstories3.com/videos/';
  });
  const [customCampaignSlug, setCustomCampaignSlug] = useState(() => {
    if (isInitialReferrer) {
      try {
        const match = initialData.destinationValue.match(/campaign%3D([^&]+)/);
        if (match) return decodeURIComponent(match[1]);
      } catch {}
    }
    return 'promo18';
  });
  const [copiedPlayLink, setCopiedPlayLink] = useState(false);
  const [savedBacklinks, setSavedBacklinks] = useState<any[]>([]);

  useEffect(() => {
    api.get<{ success: boolean; data: any[] }>('/backlinks')
      .then((res) => {
        if (res.data) setSavedBacklinks(res.data);
      })
      .catch(() => {});
  }, []);

  // Sync destinationValue when in Play Store referrer backlink mode
  useEffect(() => {
    if (destinationType === 'PLAY_STORE') {
      if (playStoreMode === 'referrer' && customTargetUrl.trim()) {
        const doubleEncoded = encodeURIComponent(encodeURIComponent(customTargetUrl.trim()));
        const slug = encodeURIComponent(customCampaignSlug.trim() || 'promo18');
        const generated = `https://play.google.com/store/apps/details?id=com.wizzling.tx_browser&referrer=target_url%3D${doubleEncoded}%26campaign%3D${slug}`;
        setDestinationValue(generated);
      } else if (playStoreMode === 'standard') {
        setDestinationValue('');
      }
    }
  }, [destinationType, playStoreMode, customTargetUrl, customCampaignSlug]);

  // Load active versions from fleet stats
  useEffect(() => {
    const loadStats = async () => {
      try {
        const stats: any = await api.get('/audiences/stats');
        if (stats?.versions?.app) {
          const vList = stats.versions.app.map((v: any) => v.version).filter(Boolean);
          if (vList.length > 0) {
            setAvailableVersions(vList);
          }
        }
      } catch (err) {
        console.error('Failed to load audience versions for composer:', err);
      }
    };
    loadStats();
  }, []);

  // Calculate estimated reach whenever audience selection changes
  useEffect(() => {
    const calcReach = async () => {
      try {
        setCalculatingReach(true);
        const res: any = await api.post('/audiences/estimate', {
          audienceType,
          audienceConfig:
            audienceType === 'TOPIC'
              ? { topic }
              : audienceType === 'SEGMENT'
              ? { activeWithinDays, appVersion: appVersion || undefined }
              : undefined,
        });
        setEstimatedReach(res?.estimatedReach ?? null);
      } catch {
        setEstimatedReach(null);
      } finally {
        setCalculatingReach(false);
      }
    };
    calcReach();
  }, [audienceType, topic, activeWithinDays, appVersion]);

  // Apply pre-configured template
  const applyTemplate = (tpl: typeof CAMPAIGN_TEMPLATES[0]) => {
    setTitle(tpl.title);
    setBody(tpl.body);
    setNotificationType(tpl.notificationType);
    setDestinationType(tpl.destinationType);
    setDestinationValue(tpl.destinationValue);
  };

  // Validation
  const validateForm = (): boolean => {
    setError(null);
    if (!title.trim()) {
      setError('Notification title is required.');
      return false;
    }
    if (title.length > 100) {
      setError('Notification title cannot exceed 100 characters.');
      return false;
    }
    if (!body.trim()) {
      setError('Notification message body is required.');
      return false;
    }
    if (body.length > 500) {
      setError('Notification message body cannot exceed 500 characters.');
      return false;
    }
    if (destinationType === 'WEB_URL') {
      if (!destinationValue.trim()) {
        setError('Destination URL is required for Web Link destinations.');
        return false;
      }
      if (!destinationValue.startsWith('https://')) {
        setError('Destination URL must start with secure https:// protocol.');
        return false;
      }
    }
    if (imageUrl && !imageUrl.startsWith('https://')) {
      setError('Image URL must start with https:// for Android compliance.');
      return false;
    }
    if (timing === 'SCHEDULED') {
      if (!scheduledAt) {
        setError('Please select a scheduled date and time.');
        return false;
      }
      if (new Date(scheduledAt) <= new Date()) {
        setError('Scheduled date must be in the future.');
        return false;
      }
    }
    return true;
  };

  const handleSaveDraft = async () => {
    if (!validateForm()) return;

    try {
      setSubmitting(true);
      const payload: any = {
        title,
        body,
        imageUrl: imageUrl.trim() || null,
        notificationType,
        destinationType,
        destinationValue: destinationValue.trim() || null,
        audienceType,
        audienceConfig:
          audienceType === 'TOPIC'
            ? { topic }
            : audienceType === 'SEGMENT'
            ? { activeWithinDays, appVersion: appVersion || undefined }
            : undefined,
        scheduledAt: timing === 'SCHEDULED' ? new Date(scheduledAt).toISOString() : null,
      };

      await api.post('/notifications', payload);
      onSuccess();
    } catch (err: any) {
      setError(err?.message || 'Failed to save notification draft.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleConfirmSend = async () => {
    try {
      setSubmitting(true);
      setShowConfirmModal(false);

      const payload: any = {
        title,
        body,
        imageUrl: imageUrl.trim() || null,
        notificationType,
        destinationType,
        destinationValue: destinationValue.trim() || null,
        audienceType,
        audienceConfig:
          audienceType === 'TOPIC'
            ? { topic }
            : audienceType === 'SEGMENT'
            ? { activeWithinDays, appVersion: appVersion || undefined }
            : undefined,
        scheduledAt: timing === 'SCHEDULED' ? new Date(scheduledAt).toISOString() : null,
      };

      // Create notification
      const created: any = await api.post('/notifications', payload);

      // If immediate, trigger send
      if (timing === 'NOW') {
        await api.post(`/notifications/${created.id}/send`);
      }

      onSuccess();
    } catch (err: any) {
      setError(err?.message || 'Failed to dispatch notification campaign.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-6 sm:space-y-8 animate-fade-in">
      {/* Header */}
      <div className="pb-2 border-b border-tx-border/60">
        <h2 className="text-xl sm:text-2xl font-bold text-tx-cream tracking-tight">
          Create Push Campaign
        </h2>
        <p className="text-xs text-tx-textMuted mt-1">
          Compose rich notifications, target specific cohorts, test live on Android 14+ frame, and dispatch.
        </p>
      </div>

      {error && (
        <div className="p-4 rounded-2xl bg-rose-950/40 border border-rose-800/50 flex items-start gap-3 text-rose-300 text-xs shadow-card animate-fade-in">
          <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
          <p className="flex-1 font-medium">{error}</p>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 lg:gap-8 items-start">
        {/* Left Form: 7 cols */}
        <div className="lg:col-span-7 space-y-6">
          {/* Card 1: Content & Creative */}
          <div className="p-5 sm:p-6 rounded-2xl bg-tx-card border border-tx-border shadow-card space-y-5">
            <div className="flex items-center gap-2.5 pb-3 border-b border-tx-border/60">
              <span className="w-6 h-6 rounded-lg bg-tx-surface border border-tx-border flex items-center justify-center text-xs font-bold text-tx-gold">
                1
              </span>
              <div>
                <h3 className="text-sm font-bold text-tx-cream tracking-tight flex items-center gap-2">
                  <span>Notification Content & Creative</span>
                  <Sparkles className="w-3.5 h-3.5 text-tx-gold" />
                </h3>
                <p className="text-[11px] text-tx-textMuted">Title, message text, and optional media banner</p>
              </div>
            </div>

            {/* Quick Templates Bar */}
            <div className="p-3.5 rounded-xl bg-tx-surface/60 border border-tx-border space-y-2">
              <div className="flex items-center gap-1.5 text-[11px] font-bold text-tx-gold uppercase tracking-wider">
                <Flame className="w-3.5 h-3.5 text-amber-400" />
                <span>Production Quick-Fill Templates</span>
              </div>
              <div className="flex flex-wrap gap-1.5">
                {CAMPAIGN_TEMPLATES.map((tpl) => (
                  <button
                    key={tpl.name}
                    type="button"
                    onClick={() => applyTemplate(tpl)}
                    className="px-2.5 py-1.5 rounded-lg bg-tx-card hover:bg-tx-elevated border border-tx-border text-tx-cream text-[11px] font-medium transition-all hover:border-tx-gold/40 active:scale-95 shadow-sm"
                  >
                    {tpl.name}
                  </button>
                ))}
              </div>
            </div>

            {/* Campaign Category Type */}
            <div>
              <label className="block text-xs font-semibold text-tx-textMuted mb-2">
                Notification Category & Android Channel
              </label>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {(
                  [
                    { id: 'PROMOTION', label: 'Promotion' },
                    { id: 'BROWSER_UPDATE', label: 'Browser Update' },
                    { id: 'SECURITY', label: 'Security Alert' },
                    { id: 'NEW_FEATURE', label: 'New Feature' },
                    { id: 'GENERAL', label: 'General Announcement' },
                    { id: 'MAINTENANCE', label: 'System Maintenance' },
                  ] as const
                ).map((cat) => (
                  <button
                    key={cat.id}
                    type="button"
                    onClick={() => setNotificationType(cat.id as NotificationType)}
                    className={`px-3 py-2.5 rounded-xl text-xs font-medium border text-center transition-all ${
                      notificationType === cat.id
                        ? 'bg-tx-surface border-tx-gold text-tx-cream shadow-glow font-semibold'
                        : 'bg-tx-surface/60 border-tx-border text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface'
                    }`}
                  >
                    {cat.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Title */}
            <div>
              <div className="flex justify-between items-center mb-1.5">
                <label className="text-xs font-semibold text-tx-textMuted">Notification Title</label>
                <span
                  className={`text-[10px] font-mono ${
                    title.length > 90 ? 'text-amber-400 font-bold' : 'text-tx-textSubtle'
                  }`}
                >
                  {title.length}/100
                </span>
              </div>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. 50% Faster Browsing with Turbo Shield"
                maxLength={100}
                className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-tx-cream text-sm placeholder-tx-textSubtle focus:outline-none focus:border-tx-gold"
              />
            </div>

            {/* Body */}
            <div>
              <div className="flex justify-between items-center mb-1.5">
                <label className="text-xs font-semibold text-tx-textMuted">Message Body</label>
                <span
                  className={`text-[10px] font-mono ${
                    body.length > 450 ? 'text-amber-400 font-bold' : 'text-tx-textSubtle'
                  }`}
                >
                  {body.length}/500
                </span>
              </div>
              <textarea
                value={body}
                onChange={(e) => setBody(e.target.value)}
                placeholder="Write your engaging message here. Tap actions and images encourage higher open rates."
                maxLength={500}
                rows={3}
                className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-tx-cream text-sm placeholder-tx-textSubtle resize-none focus:outline-none focus:border-tx-gold"
              />
            </div>

            {/* Rich Media Hero Image */}
            <ImageUploadWithUrl
              value={imageUrl}
              onChange={setImageUrl}
              label="Notification Hero Image (Optional)"
              helperText="Upload an image file or provide a public URL. Images appear as large expandable banners on Android devices."
            />
          </div>

          {/* Card 2: Destination & Tap Action */}
          <div className="p-5 sm:p-6 rounded-2xl bg-tx-card border border-tx-border shadow-card space-y-5">
            <div className="flex items-center gap-2.5 pb-3 border-b border-tx-border/60">
              <span className="w-6 h-6 rounded-lg bg-tx-surface border border-tx-border flex items-center justify-center text-xs font-bold text-tx-gold">
                2
              </span>
              <div>
                <h3 className="text-sm font-bold text-tx-cream tracking-tight flex items-center gap-2">
                  <span>Destination & Tap Action</span>
                  <Link className="w-3.5 h-3.5 text-tx-gold" />
                </h3>
                <p className="text-[11px] text-tx-textMuted">Determine what opens when user taps this notification</p>
              </div>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
              {[
                { id: 'HOME', label: 'Browser Home' },
                { id: 'WEB_URL', label: 'Web URL' },
                { id: 'PLAY_STORE', label: 'Play Store' },
                { id: 'INTERNAL_SCREEN', label: 'App Screen' },
              ].map((dest) => (
                <button
                  key={dest.id}
                  type="button"
                  onClick={() => {
                    setDestinationType(dest.id as DestinationType);
                    if (dest.id === 'HOME' || dest.id === 'PLAY_STORE') {
                      setDestinationValue('');
                    } else if (
                      dest.id === 'INTERNAL_SCREEN' &&
                      (!destinationValue || destinationValue.startsWith('http'))
                    ) {
                      setDestinationValue('settings');
                    }
                  }}
                  className={`px-3 py-2.5 rounded-xl text-xs font-medium border text-center transition-all ${
                    destinationType === dest.id
                      ? 'bg-tx-surface border-tx-gold text-tx-cream shadow-glow font-semibold'
                      : 'bg-tx-surface/60 border-tx-border text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface'
                  }`}
                >
                  {dest.label}
                </button>
              ))}
            </div>

            {destinationType === 'PLAY_STORE' && (
              <div className="space-y-4">
                {/* Mode Selector */}
                <div className="flex items-center gap-2 p-1 rounded-xl bg-tx-surface border border-tx-border text-xs">
                  <button
                    type="button"
                    onClick={() => {
                      setPlayStoreMode('standard');
                      setDestinationValue('');
                    }}
                    className={`flex-1 py-1.5 rounded-lg text-xs font-medium transition-all ${
                      playStoreMode === 'standard'
                        ? 'bg-tx-card text-tx-cream font-semibold border border-tx-border shadow-sm'
                        : 'text-tx-textMuted hover:text-tx-cream'
                    }`}
                  >
                    Direct Play Store Listing
                  </button>
                  <button
                    type="button"
                    onClick={() => setPlayStoreMode('referrer')}
                    className={`flex-1 py-1.5 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${
                      playStoreMode === 'referrer'
                        ? 'bg-emerald-950/80 text-emerald-400 font-semibold border border-emerald-700/60 shadow-sm'
                        : 'text-tx-textMuted hover:text-tx-cream'
                    }`}
                  >
                    <Link2 className="w-3.5 h-3.5 text-tx-gold" />
                    <span>Target URL / Backlink (Referrer)</span>
                  </button>
                </div>

                {playStoreMode === 'standard' ? (
                  <div className="p-3.5 rounded-xl bg-tx-surface/70 border border-tx-border text-xs text-tx-gold space-y-1">
                    <div className="font-semibold text-tx-cream flex items-center gap-1.5">
                      <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
                      <span>Direct Google Play Store Intent</span>
                    </div>
                    <p className="text-[11px] text-tx-textMuted leading-relaxed">
                      Tapping the notification opens Google Play Store directly to TX Browser (<code className="text-tx-gold font-mono">com.wizzling.tx_browser</code>) for seamless update downloads.
                    </p>
                  </div>
                ) : (
                  <div className="p-4 rounded-xl bg-tx-surface/60 border border-emerald-800/60 space-y-3.5">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-tx-cream flex items-center gap-1.5">
                        <Globe className="w-3.5 h-3.5 text-tx-gold" />
                        <span>The Campaign Target URL</span>
                      </span>
                      {savedBacklinks.length > 0 && (
                        <select
                          onChange={(e) => {
                            const found = savedBacklinks.find((b) => b.id === e.target.value);
                            if (found) {
                              setCustomTargetUrl(found.targetUrl);
                              setCustomCampaignSlug(found.campaignSlug);
                            }
                          }}
                          className="px-2 py-1 rounded-lg bg-tx-card border border-tx-border text-[11px] text-tx-gold font-medium"
                          defaultValue=""
                        >
                          <option value="" disabled>Load from Saved Hub...</option>
                          {savedBacklinks.map((b) => (
                            <option key={b.id} value={b.id}>
                              {b.title} ({b.campaignSlug})
                            </option>
                          ))}
                        </select>
                      )}
                    </div>

                    <input
                      type="url"
                      value={customTargetUrl}
                      onChange={(e) => setCustomTargetUrl(e.target.value)}
                      placeholder="https://www.indiansexstories3.com/videos/"
                      className="w-full px-3.5 py-2.5 rounded-xl bg-tx-card border border-tx-border font-mono text-xs text-emerald-300 placeholder-tx-textSubtle focus:outline-none focus:border-tx-gold"
                    />

                    <div>
                      <label className="block text-[11px] font-semibold text-tx-textMuted mb-1">
                        Campaign Slug / Identifier
                      </label>
                      <input
                        type="text"
                        value={customCampaignSlug}
                        onChange={(e) => setCustomCampaignSlug(e.target.value)}
                        placeholder="promo18"
                        className="w-full px-3.5 py-2 rounded-xl bg-tx-card border border-tx-border font-mono text-xs placeholder-tx-textSubtle text-tx-cream focus:outline-none focus:border-tx-gold"
                      />
                    </div>

                    {/* Live Generated Backlink Box */}
                    <div className="space-y-1.5 pt-1">
                      <div className="flex items-center justify-between">
                        <span className="text-[11px] font-bold text-emerald-400 flex items-center gap-1.5">
                          <Sparkles className="w-3 h-3 text-emerald-400" />
                          <span>Generated Play Store Backlink</span>
                        </span>
                        <button
                          type="button"
                          onClick={async () => {
                            if (destinationValue) {
                              await navigator.clipboard.writeText(destinationValue);
                              setCopiedPlayLink(true);
                              setTimeout(() => setCopiedPlayLink(false), 2000);
                            }
                          }}
                          className="text-[10px] text-tx-textSubtle hover:text-emerald-400 flex items-center gap-1"
                        >
                          {copiedPlayLink ? (
                            <>
                              <Check className="w-3 h-3 text-emerald-400" />
                              <span className="text-emerald-400">Copied</span>
                            </>
                          ) : (
                            <>
                              <Copy className="w-3 h-3" />
                              <span>Copy Full Link</span>
                            </>
                          )}
                        </button>
                      </div>
                      <div className="p-3 rounded-lg bg-tx-card border border-emerald-800/40 text-[10px] font-mono text-emerald-300 break-all select-all">
                        {destinationValue || 'Enter target URL above to generate backlink...'}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}

            {destinationType === 'WEB_URL' && (
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <label className="block text-xs font-semibold text-tx-textMuted">
                    Destination Web Page (Strict HTTPS)
                  </label>
                  {savedBacklinks.length > 0 && (
                    <select
                      onChange={(e) => {
                        const found = savedBacklinks.find((b) => b.id === e.target.value);
                        if (found) {
                          setDestinationValue(found.targetUrl);
                        }
                      }}
                      className="px-2 py-0.5 rounded-lg bg-tx-surface border border-tx-border text-[11px] text-tx-gold font-medium"
                      defaultValue=""
                    >
                      <option value="" disabled>Pick from Saved Target URLs...</option>
                      {savedBacklinks.map((b) => (
                        <option key={b.id} value={b.id}>
                          {b.title}
                        </option>
                      ))}
                    </select>
                  )}
                </div>
                <input
                  type="url"
                  value={destinationValue}
                  onChange={(e) => setDestinationValue(e.target.value)}
                  placeholder="https://txbrowser.com/news"
                  className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border font-mono text-xs text-tx-cream placeholder-tx-textSubtle focus:outline-none focus:border-tx-gold"
                />
              </div>
            )}

            {destinationType === 'INTERNAL_SCREEN' && (
              <div>
                <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">
                  Target In-App Screen
                </label>
                <select
                  value={destinationValue || 'settings'}
                  onChange={(e) => setDestinationValue(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-xs font-medium text-tx-cream focus:outline-none focus:border-tx-gold"
                >
                  <option value="settings">⚙️ Settings</option>
                  <option value="history">🕒 Browsing History</option>
                  <option value="downloads">📥 Downloads Center</option>
                  <option value="bookmarks">⭐ Bookmarks & Favorites</option>
                  <option value="tabs">📑 Tab Manager</option>
                  <option value="app_lock">🔒 Security & App Lock</option>
                  <option value="proxy">🌐 Proxy & DNS Settings</option>
                  <option value="pinned_sites">📌 Pinned Shortcuts</option>
                </select>
              </div>
            )}
          </div>

          {/* Card 3: Targeting Audience */}
          <div className="p-5 sm:p-6 rounded-2xl bg-tx-card border border-tx-border shadow-card space-y-5">
            <div className="flex items-center justify-between pb-3 border-b border-tx-border/60">
              <div className="flex items-center gap-2.5">
                <span className="w-6 h-6 rounded-lg bg-tx-surface border border-tx-border flex items-center justify-center text-xs font-bold text-tx-gold">
                  3
                </span>
                <div>
                  <h3 className="text-sm font-bold text-tx-cream tracking-tight flex items-center gap-2">
                    <span>Audience & Targeting</span>
                    <Users className="w-3.5 h-3.5 text-tx-gold" />
                  </h3>
                  <p className="text-[11px] text-tx-textMuted">Filter delivery by topics, versions, or full fleet</p>
                </div>
              </div>

              <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-tx-surface border border-tx-border text-xs text-tx-gold shadow-sm">
                <span className="text-[11px] text-tx-textMuted">Est. Reach:</span>
                {calculatingReach ? (
                  <Loader2 className="w-3 h-3 animate-spin text-tx-gold" />
                ) : (
                  <span className="font-bold text-tx-cream font-mono">
                    {estimatedReach !== null ? `${estimatedReach.toLocaleString()} devices` : '—'}
                  </span>
                )}
              </div>
            </div>

            <div className="grid grid-cols-3 gap-2">
              {[
                { id: 'ALL_USERS', label: 'All Users (tx_all)' },
                { id: 'TOPIC', label: 'Specific Topic' },
                { id: 'SEGMENT', label: 'Custom Cohort' },
              ].map((aud) => (
                <button
                  key={aud.id}
                  type="button"
                  onClick={() => setAudienceType(aud.id as AudienceType)}
                  className={`px-3 py-2.5 rounded-xl text-xs font-medium border text-center transition-all ${
                    audienceType === aud.id
                      ? 'bg-tx-surface border-tx-gold text-tx-cream shadow-glow font-semibold'
                      : 'bg-tx-surface/60 border-tx-border text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface'
                  }`}
                >
                  {aud.label}
                </button>
              ))}
            </div>

            {audienceType === 'TOPIC' && (
              <div className="space-y-2">
                <label className="block text-xs font-semibold text-tx-textMuted">
                  Select FCM Topic
                </label>
                <select
                  value={topic}
                  onChange={(e) => setTopic(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-xs font-medium text-tx-cream focus:outline-none focus:border-tx-gold"
                >
                  <option value="tx_all">tx_all (All Devices)</option>
                  <option value="tx_promotions">tx_promotions (Promotions & Perks)</option>
                  <option value="tx_updates">tx_updates (Browser Updates)</option>
                  <option value="tx_security">tx_security (Security Alerts)</option>
                  <option value="tx_general">tx_general (General Announcements)</option>
                </select>
                <p className="text-[11px] text-tx-textMuted">
                  Dispatched via dual route: Native FCM Topic multicast + direct token push fallback.
                </p>
              </div>
            )}

            {audienceType === 'SEGMENT' && (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">
                    Activity Window
                  </label>
                  <select
                    value={activeWithinDays}
                    onChange={(e) => setActiveWithinDays(Number(e.target.value))}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-xs font-medium text-tx-cream focus:outline-none focus:border-tx-gold"
                  >
                    <option value={7}>Active in Last 7 Days</option>
                    <option value={14}>Active in Last 14 Days</option>
                    <option value={30}>Active in Last 30 Days</option>
                    <option value={90}>Active in Last 90 Days</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">
                    App Version Cohort
                  </label>
                  <select
                    value={appVersion}
                    onChange={(e) => setAppVersion(e.target.value)}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-xs font-medium text-tx-cream focus:outline-none focus:border-tx-gold"
                  >
                    <option value="">All App Versions</option>
                    {availableVersions.map((v) => (
                      <option key={v} value={v}>
                        Version {v}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            )}
          </div>

          {/* Card 4: Timing & Delivery */}
          <div className="p-5 sm:p-6 rounded-2xl bg-tx-card border border-tx-border shadow-card space-y-4">
            <div className="flex items-center gap-2.5 pb-3 border-b border-tx-border/60">
              <span className="w-6 h-6 rounded-lg bg-tx-surface border border-tx-border flex items-center justify-center text-xs font-bold text-tx-gold">
                4
              </span>
              <div>
                <h3 className="text-sm font-bold text-tx-cream tracking-tight flex items-center gap-2">
                  <span>Dispatch Schedule & Timing</span>
                  <Clock className="w-3.5 h-3.5 text-tx-gold" />
                </h3>
                <p className="text-[11px] text-tx-textMuted">Broadcast immediately or schedule for a specific date</p>
              </div>
            </div>

            <div className="flex gap-6">
              <label className="flex items-center gap-2 cursor-pointer text-xs font-medium text-tx-cream">
                <input
                  type="radio"
                  name="timing"
                  checked={timing === 'NOW'}
                  onChange={() => setTiming('NOW')}
                  className="accent-tx-gold w-4 h-4 cursor-pointer"
                />
                <span>Send Immediately</span>
              </label>

              <label className="flex items-center gap-2 cursor-pointer text-xs font-medium text-tx-cream">
                <input
                  type="radio"
                  name="timing"
                  checked={timing === 'SCHEDULED'}
                  onChange={() => setTiming('SCHEDULED')}
                  className="accent-tx-gold w-4 h-4 cursor-pointer"
                />
                <span>Schedule for Later</span>
              </label>
            </div>

            {timing === 'SCHEDULED' && (
              <div className="pt-2">
                <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">
                  Delivery Time (Local Timezone)
                </label>
                <input
                  type="datetime-local"
                  value={scheduledAt}
                  onChange={(e) => setScheduledAt(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-xs text-tx-cream focus:outline-none focus:border-tx-gold"
                />
              </div>
            )}
          </div>

          {/* Action Row */}
          <div className="flex flex-wrap items-center justify-between gap-3 pt-3">
            <button
              type="button"
              onClick={() => setShowTestModal(true)}
              className="px-4 py-2.5 rounded-xl bg-tx-card hover:bg-tx-elevated border border-tx-border text-tx-gold hover:text-tx-cream text-xs font-semibold flex items-center gap-2 transition-all shadow-card active:scale-95"
            >
              <Smartphone className="w-3.5 h-3.5 text-emerald-400" />
              <span>Test on My Device</span>
            </button>

            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={handleSaveDraft}
                disabled={submitting}
                className="px-4 py-2.5 rounded-xl bg-tx-surface hover:bg-tx-elevated border border-tx-border text-tx-cream text-xs font-semibold transition-all active:scale-95"
              >
                Save as Draft
              </button>

              <button
                type="button"
                onClick={() => {
                  if (validateForm()) {
                    setShowConfirmModal(true);
                  }
                }}
                disabled={submitting}
                className="px-5 py-2.5 rounded-xl bg-tx-gold hover:bg-tx-goldLight text-black text-xs font-bold flex items-center gap-2 shadow-glow transition-all active:scale-95"
              >
                <Send className="w-4 h-4" />
                <span>{timing === 'SCHEDULED' ? 'Schedule Broadcast' : 'Dispatch Now'}</span>
              </button>
            </div>
          </div>
        </div>

        {/* Right Pane: Live Android 14+ Frame Preview: 5 cols */}
        <div className="lg:col-span-5 lg:sticky lg:top-20">
          <div className="p-4 sm:p-5 rounded-2xl bg-tx-card border border-tx-border shadow-card space-y-4">
            <div className="flex items-center justify-between px-1">
              <span className="text-xs font-bold text-tx-cream flex items-center gap-2">
                <Smartphone className="w-4 h-4 text-tx-gold" />
                <span>Live Android 14+ Preview</span>
              </span>

              {/* Preview Mode Switcher */}
              <div className="flex items-center gap-1 bg-tx-surface p-1 rounded-xl border border-tx-border text-[10px]">
                <button
                  type="button"
                  onClick={() => setPreviewMode('expanded')}
                  className={`px-2.5 py-1 rounded-lg transition-colors ${
                    previewMode === 'expanded'
                      ? 'bg-tx-card text-tx-cream font-bold shadow-sm'
                      : 'text-tx-textMuted hover:text-tx-cream'
                  }`}
                >
                  Expanded
                </button>
                <button
                  type="button"
                  onClick={() => setPreviewMode('compact')}
                  className={`px-2.5 py-1 rounded-lg transition-colors ${
                    previewMode === 'compact'
                      ? 'bg-tx-card text-tx-cream font-bold shadow-sm'
                      : 'text-tx-textMuted hover:text-tx-cream'
                  }`}
                >
                  Compact
                </button>
                <button
                  type="button"
                  onClick={() => setPreviewMode('lockscreen')}
                  className={`px-2.5 py-1 rounded-lg transition-colors ${
                    previewMode === 'lockscreen'
                      ? 'bg-tx-card text-tx-cream font-bold shadow-sm'
                      : 'text-tx-textMuted hover:text-tx-cream'
                  }`}
                >
                  Lockscreen
                </button>
              </div>
            </div>

            {/* Mobile Device Frame */}
            <div className="w-full max-w-[340px] mx-auto bg-[#0A0F0B] rounded-[38px] p-3.5 border-4 border-[#253628] shadow-2xl relative overflow-hidden select-none">
              {/* Dynamic Island / Camera cutout */}
              <div className="flex items-center justify-between px-3 py-1 text-[11px] text-[#A6B8A8] font-mono">
                <span>12:45</span>
                <div className="w-16 h-3 rounded-full bg-black/80 mx-auto" />
                <div className="flex items-center gap-1.5">
                  <Wifi className="w-3 h-3" />
                  <BatteryCharging className="w-3.5 h-3.5" />
                </div>
              </div>

              {/* Lockscreen Mode Clock Widget */}
              {previewMode === 'lockscreen' && (
                <div className="text-center py-5">
                  <div className="text-4xl font-extralight text-tx-cream tracking-tight font-sans">
                    12:45
                  </div>
                  <div className="text-[11px] text-tx-textMuted mt-1">Friday, September 25</div>
                </div>
              )}

              {/* Notification Shade / Card Container */}
              <div className="mt-2 space-y-2">
                {/* Real Android 14 Notification Card */}
                <div className="p-3.5 rounded-2xl bg-[#172219] border border-[#27392B] shadow-md transition-all">
                  {/* Notification App Header */}
                  <div className="flex items-center justify-between text-xs text-[#9BB09D] mb-2">
                    <div className="flex items-center gap-1.5">
                      <div className="w-4 h-4 rounded-full bg-tx-gold flex items-center justify-center text-[9px] font-bold text-black shadow-sm">
                        TX
                      </div>
                      <span className="font-semibold text-[11px] text-[#CCD9CD]">TX Browser</span>
                      <span className="text-[10px] text-[#6E8270]">&bull; now</span>
                    </div>
                    <ChevronDown className="w-3.5 h-3.5 text-[#6E8270]" />
                  </div>

                  {/* Title & Body */}
                  <div className="space-y-1">
                    <h4 className="text-xs font-bold text-[#F4F8F5] leading-snug">
                      {title || 'Your notification title will appear here'}
                    </h4>
                    <p className={`text-[11px] text-[#A3B5A5] leading-relaxed ${previewMode === 'compact' ? 'line-clamp-1' : 'line-clamp-3'}`}>
                      {body ||
                        'Enter a message body on the left to see it update dynamically in real time.'}
                    </p>
                  </div>

                  {/* Optional Large Image Banner Preview (only on expanded or lockscreen) */}
                  {imageUrl && previewMode !== 'compact' && (
                    <div className="mt-2.5 rounded-xl overflow-hidden bg-black/40 border border-[#27392B] aspect-video">
                      <img
                        src={imageUrl}
                        alt="Preview banner"
                        className="w-full h-full object-cover"
                        onError={(e) => {
                          (e.target as any).style.display = 'none';
                        }}
                      />
                    </div>
                  )}

                  {/* Action Buttons */}
                  <div className="mt-3 pt-2 border-t border-[#233326] flex items-center justify-end gap-2">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-400 px-2 py-1 rounded hover:bg-white/5 cursor-pointer">
                      {destinationType === 'WEB_URL'
                        ? 'Open Link'
                        : destinationType === 'PLAY_STORE'
                        ? 'Update App'
                        : destinationType === 'INTERNAL_SCREEN'
                        ? `Open ${destinationValue || 'Screen'}`
                        : 'Open TX'}
                    </span>
                    <span className="text-[10px] font-bold uppercase tracking-wider text-[#6E8270] px-2 py-1 rounded hover:bg-white/5 cursor-pointer">
                      Dismiss
                    </span>
                  </div>
                </div>

                {/* Subdued Background Card to simulate real lockscreen/shade */}
                <div className="p-3 rounded-2xl bg-[#121A14]/50 border border-[#1C281E] opacity-30">
                  <div className="h-2.5 w-20 rounded bg-tx-border mb-1.5" />
                  <div className="h-2 w-44 rounded bg-tx-border/60" />
                </div>
              </div>

              {/* Bottom Navigation Gesture Bar */}
              <div className="w-28 h-1 rounded-full bg-[#3B4D3D] mx-auto mt-6 mb-1" />
            </div>
          </div>
        </div>
      </div>

      {/* Confirmation Modal Before Mass Broadcast */}
      {showConfirmModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-md animate-fade-in">
          <div className="w-full max-w-md bg-tx-card border border-tx-border rounded-2xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-amber-950/80 border border-amber-800/40 flex items-center justify-center text-amber-400 shadow-sm">
                <AlertTriangle className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-tx-cream tracking-tight">Confirm Campaign Broadcast</h3>
                <p className="text-xs text-tx-textMuted">Production FCM push verification</p>
              </div>
            </div>

            <div className="p-4 rounded-xl bg-tx-surface border border-tx-border space-y-2.5 text-xs">
              <div className="flex justify-between">
                <span className="text-tx-textMuted">Audience Type:</span>
                <span className="font-semibold text-tx-cream">{audienceType}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-tx-textMuted">Estimated Reach:</span>
                <span className="font-bold text-tx-gold font-mono">
                  {estimatedReach !== null ? `${estimatedReach.toLocaleString()} devices` : 'Topic broadcast'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-tx-textMuted">Delivery Mode:</span>
                <span className="font-bold text-emerald-400">
                  {timing === 'NOW' ? 'Immediate Broadcast' : `Scheduled for ${scheduledAt}`}
                </span>
              </div>
              <div className="pt-2 border-t border-tx-border/60">
                <span className="text-tx-textMuted block mb-1">Title:</span>
                <p className="font-semibold text-tx-cream">{title}</p>
              </div>
            </div>

            <p className="text-[11px] text-tx-textMuted leading-relaxed">
              Are you sure you want to broadcast this message to production users? Notifications cannot be recalled once dispatched.
            </p>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                onClick={() => setShowConfirmModal(false)}
                disabled={submitting}
                className="px-4 py-2.5 rounded-xl bg-tx-surface hover:bg-tx-elevated border border-tx-border text-tx-cream text-xs font-semibold transition-all active:scale-95"
              >
                Back to Edit
              </button>

              <button
                type="button"
                onClick={handleConfirmSend}
                disabled={submitting}
                className="px-4 py-2.5 rounded-xl bg-tx-gold hover:bg-tx-goldLight text-black text-xs font-bold flex items-center gap-2 shadow-glow transition-all active:scale-95"
              >
                {submitting ? (
                  <>
                    <Loader2 className="w-3.5 h-3.5 animate-spin" />
                    <span>Sending...</span>
                  </>
                ) : (
                  <>
                    <Send className="w-3.5 h-3.5" />
                    <span>Confirm & Send</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Direct Test Push Modal */}
      <TestPushModal
        isOpen={showTestModal}
        defaultTitle={title || 'TX Browser Test Ping'}
        defaultBody={body || 'Testing push delivery directly from campaign composer.'}
        onClose={() => setShowTestModal(false)}
      />
    </div>
  );
};
