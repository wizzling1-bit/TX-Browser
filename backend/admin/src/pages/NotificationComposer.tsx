import React, { useState, useEffect } from 'react';
import {
  Send,
  Image as ImageIcon,
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
} from 'lucide-react';
import { api } from '../lib/api.js';
import { NotificationType, DestinationType, AudienceType } from '../types/index.js';

interface NotificationComposerProps {
  onSuccess: () => void;
  initialData?: any;
}

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

  const [timing, setTiming] = useState<'NOW' | 'SCHEDULED'>('NOW');
  const [scheduledAt, setScheduledAt] = useState('');

  const [estimatedReach, setEstimatedReach] = useState<number | null>(null);
  const [calculatingReach, setCalculatingReach] = useState(false);

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showConfirmModal, setShowConfirmModal] = useState(false);

  // Fetch estimated reach when audience changes
  useEffect(() => {
    let isMounted = true;
    const fetchEstimate = async () => {
      setCalculatingReach(true);
      try {
        const payload: any = { audienceType };
        if (audienceType === 'TOPIC') {
          payload.audienceConfig = { topic };
        } else if (audienceType === 'SEGMENT') {
          payload.audienceConfig = {
            activeWithinDays: Number(activeWithinDays),
            appVersion: appVersion || undefined,
          };
        }

        const res = await api.post<{ estimatedReach: number }>('/audiences/estimate', payload);
        if (isMounted) setEstimatedReach(res.estimatedReach);
      } catch (err) {
        console.error('Estimate error:', err);
      } finally {
        if (isMounted) setCalculatingReach(false);
      }
    };

    fetchEstimate();
    return () => {
      isMounted = false;
    };
  }, [audienceType, topic, activeWithinDays, appVersion]);

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
      const created = await api.post<any>('/notifications', payload);

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
    <div className="space-y-6">
      {/* Title */}
      <div>
        <h2 className="text-xl font-bold text-tx-cream tracking-tight">Create Push Campaign</h2>
        <p className="text-xs text-tx-textMuted mt-0.5">
          Compose, target, preview on live Android frame, and broadcast or schedule.
        </p>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-rose-950/40 border border-rose-800/50 flex items-start gap-3 text-rose-300 text-xs">
          <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
          <p className="flex-1">{error}</p>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Left Form: 7 cols */}
        <div className="lg:col-span-7 space-y-6">
          {/* Card 1: Content */}
          <div className="p-6 rounded-2xl bg-tx-surface border border-tx-border space-y-4">
            <h3 className="text-sm font-semibold text-tx-cream flex items-center gap-2">
              <Sparkles className="w-4 h-4 text-tx-primary" />
              <span>Notification Content</span>
            </h3>

            {/* Campaign Category Type */}
            <div>
              <label className="block text-xs font-medium text-tx-textMuted mb-1.5">
                Campaign Category & Android Channel
              </label>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                {(
                  [
                    { id: 'PROMOTION', label: 'Promotion' },
                    { id: 'BROWSER_UPDATE', label: 'App Update' },
                    { id: 'GENERAL', label: 'General' },
                    { id: 'NEW_FEATURE', label: 'New Feature' },
                    { id: 'SECURITY', label: 'Security' },
                    { id: 'ANNOUNCEMENT', label: 'Notice' },
                  ] as const
                ).map((cat) => (
                  <button
                    key={cat.id}
                    type="button"
                    onClick={() => setNotificationType(cat.id)}
                    className={`px-3 py-2 rounded-xl text-xs font-medium border text-center transition-all ${
                      notificationType === cat.id
                        ? 'bg-tx-card border-tx-primary text-tx-cream shadow-sm'
                        : 'bg-tx-bg/50 border-tx-border text-tx-textMuted hover:text-tx-text hover:bg-tx-card'
                    }`}
                  >
                    {cat.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Title */}
            <div>
              <div className="flex justify-between items-center mb-1">
                <label className="text-xs font-medium text-tx-textMuted">Title</label>
                <span
                  className={`text-[10px] ${
                    title.length > 90 ? 'text-amber-400' : 'text-tx-textDim'
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
                className="w-full px-3.5 py-2.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream placeholder-tx-textDim text-sm focus:outline-none focus:border-tx-primary transition-colors"
              />
            </div>

            {/* Body */}
            <div>
              <div className="flex justify-between items-center mb-1">
                <label className="text-xs font-medium text-tx-textMuted">Message Body</label>
                <span
                  className={`text-[10px] ${
                    body.length > 450 ? 'text-amber-400' : 'text-tx-textDim'
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
                className="w-full px-3.5 py-2.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream placeholder-tx-textDim text-sm focus:outline-none focus:border-tx-primary transition-colors resize-none"
              />
            </div>

            {/* Optional Banner Image */}
            <div>
              <label className="block text-xs font-medium text-tx-textMuted mb-1">
                Hero Image URL (Optional HTTPS)
              </label>
              <div className="relative">
                <ImageIcon className="w-4 h-4 text-tx-textDim absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="url"
                  value={imageUrl}
                  onChange={(e) => setImageUrl(e.target.value)}
                  placeholder="https://images.unsplash.com/... or hosted CDN image"
                  className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream placeholder-tx-textDim text-sm focus:outline-none focus:border-tx-primary transition-colors"
                />
              </div>
            </div>
          </div>

          {/* Card 2: Destination & Tap Action */}
          <div className="p-6 rounded-2xl bg-tx-surface border border-tx-border space-y-4">
            <h3 className="text-sm font-semibold text-tx-cream flex items-center gap-2">
              <Link className="w-4 h-4 text-tx-primary" />
              <span>Tap Action & Deep Link</span>
            </h3>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
              {[
                { id: 'HOME', label: 'Home Screen' },
                { id: 'WEB_URL', label: 'Web URL' },
                { id: 'PLAY_STORE', label: 'Play Store' },
                { id: 'INTERNAL_SCREEN', label: 'Internal Screen' },
              ].map((dest) => (
                <button
                  key={dest.id}
                  type="button"
                  onClick={() => {
                    setDestinationType(dest.id as DestinationType);
                    if (dest.id === 'HOME') setDestinationValue('');
                    if (dest.id === 'INTERNAL_SCREEN' && !destinationValue)
                      setDestinationValue('settings');
                  }}
                  className={`px-3 py-2 rounded-xl text-xs font-medium border text-center transition-all ${
                    destinationType === dest.id
                      ? 'bg-tx-card border-tx-primary text-tx-cream shadow-sm'
                      : 'bg-tx-bg/50 border-tx-border text-tx-textMuted hover:text-tx-text hover:bg-tx-card'
                  }`}
                >
                  {dest.label}
                </button>
              ))}
            </div>

            {destinationType === 'WEB_URL' && (
              <div>
                <label className="block text-xs font-medium text-tx-textMuted mb-1">
                  Destination Web Page (Strict HTTPS)
                </label>
                <input
                  type="url"
                  value={destinationValue}
                  onChange={(e) => setDestinationValue(e.target.value)}
                  placeholder="https://example.com/promo-landing"
                  className="w-full px-3.5 py-2.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream placeholder-tx-textDim text-sm focus:outline-none focus:border-tx-primary transition-colors"
                />
              </div>
            )}

            {destinationType === 'INTERNAL_SCREEN' && (
              <div>
                <label className="block text-xs font-medium text-tx-textMuted mb-1">
                  Target Browser Screen
                </label>
                <select
                  value={destinationValue || 'settings'}
                  onChange={(e) => setDestinationValue(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-sm focus:outline-none focus:border-tx-primary transition-colors"
                >
                  <option value="settings">Settings</option>
                  <option value="history">History</option>
                  <option value="downloads">Downloads</option>
                  <option value="bookmarks">Bookmarks</option>
                  <option value="adblock">Content Blocker / AdBlock</option>
                </select>
              </div>
            )}
          </div>

          {/* Card 3: Targeting Audience */}
          <div className="p-6 rounded-2xl bg-tx-surface border border-tx-border space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-semibold text-tx-cream flex items-center gap-2">
                <Users className="w-4 h-4 text-tx-primary" />
                <span>Audience & Targeting</span>
              </h3>
              <div className="flex items-center gap-2 px-2.5 py-1 rounded-lg bg-tx-card border border-tx-border text-xs text-tx-sage">
                <span>Reach:</span>
                {calculatingReach ? (
                  <Loader2 className="w-3 h-3 animate-spin text-tx-primary" />
                ) : (
                  <span className="font-bold text-tx-cream">
                    {estimatedReach !== null ? estimatedReach.toLocaleString() : '—'} devices
                  </span>
                )}
              </div>
            </div>

            <div className="grid grid-cols-3 gap-2">
              {[
                { id: 'ALL_USERS', label: 'All Users (tx_all)' },
                { id: 'TOPIC', label: 'Specific Topic' },
                { id: 'SEGMENT', label: 'Custom Segment' },
              ].map((aud) => (
                <button
                  key={aud.id}
                  type="button"
                  onClick={() => setAudienceType(aud.id as AudienceType)}
                  className={`px-3 py-2 rounded-xl text-xs font-medium border text-center transition-all ${
                    audienceType === aud.id
                      ? 'bg-tx-card border-tx-primary text-tx-cream shadow-sm'
                      : 'bg-tx-bg/50 border-tx-border text-tx-textMuted hover:text-tx-text hover:bg-tx-card'
                  }`}
                >
                  {aud.label}
                </button>
              ))}
            </div>

            {audienceType === 'TOPIC' && (
              <div>
                <label className="block text-xs font-medium text-tx-textMuted mb-1">
                  Select Topic
                </label>
                <select
                  value={topic}
                  onChange={(e) => setTopic(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-sm focus:outline-none focus:border-tx-primary transition-colors"
                >
                  <option value="tx_all">tx_all (All Devices)</option>
                  <option value="tx_promotions">tx_promotions (Promotions & Perks)</option>
                  <option value="tx_updates">tx_updates (Browser Updates)</option>
                  <option value="tx_security">tx_security (Security Alerts)</option>
                  <option value="tx_general">tx_general (General Announcements)</option>
                </select>
              </div>
            )}

            {audienceType === 'SEGMENT' && (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium text-tx-textMuted mb-1">
                    Active Within
                  </label>
                  <select
                    value={activeWithinDays}
                    onChange={(e) => setActiveWithinDays(Number(e.target.value))}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-sm focus:outline-none focus:border-tx-primary transition-colors"
                  >
                    <option value={7}>Last 7 Days</option>
                    <option value={14}>Last 14 Days</option>
                    <option value={30}>Last 30 Days</option>
                    <option value={90}>Last 90 Days</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-medium text-tx-textMuted mb-1">
                    App Version (Optional)
                  </label>
                  <input
                    type="text"
                    value={appVersion}
                    onChange={(e) => setAppVersion(e.target.value)}
                    placeholder="e.g. 1.0.4"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-sm focus:outline-none focus:border-tx-primary transition-colors"
                  />
                </div>
              </div>
            )}
          </div>

          {/* Card 4: Timing & Delivery */}
          <div className="p-6 rounded-2xl bg-tx-surface border border-tx-border space-y-4">
            <h3 className="text-sm font-semibold text-tx-cream flex items-center gap-2">
              <Clock className="w-4 h-4 text-tx-primary" />
              <span>Scheduling & Timing</span>
            </h3>

            <div className="flex gap-4">
              <label className="flex items-center gap-2 cursor-pointer text-xs font-medium text-tx-cream">
                <input
                  type="radio"
                  name="timing"
                  checked={timing === 'NOW'}
                  onChange={() => setTiming('NOW')}
                  className="accent-tx-primary"
                />
                <span>Send Immediately</span>
              </label>

              <label className="flex items-center gap-2 cursor-pointer text-xs font-medium text-tx-cream">
                <input
                  type="radio"
                  name="timing"
                  checked={timing === 'SCHEDULED'}
                  onChange={() => setTiming('SCHEDULED')}
                  className="accent-tx-primary"
                />
                <span>Schedule for Later</span>
              </label>
            </div>

            {timing === 'SCHEDULED' && (
              <div>
                <label className="block text-xs font-medium text-tx-textMuted mb-1">
                  Delivery Time (Local Timezone)
                </label>
                <input
                  type="datetime-local"
                  value={scheduledAt}
                  onChange={(e) => setScheduledAt(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-sm focus:outline-none focus:border-tx-primary transition-colors"
                />
              </div>
            )}
          </div>

          {/* Action Row */}
          <div className="flex items-center justify-end gap-3 pt-2">
            <button
              type="button"
              onClick={handleSaveDraft}
              disabled={submitting}
              className="px-4 py-2.5 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-cream text-xs font-medium transition-colors"
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
              className="px-5 py-2.5 rounded-xl bg-tx-primary hover:bg-tx-primaryHover text-white text-xs font-semibold flex items-center gap-2 shadow-lg shadow-tx-primary/20 transition-all"
            >
              <Send className="w-4 h-4" />
              <span>{timing === 'SCHEDULED' ? 'Schedule Broadcast' : 'Dispatch Now'}</span>
            </button>
          </div>
        </div>

        {/* Right Pane: Live Android 14+ Frame Preview: 5 cols */}
        <div className="lg:col-span-5 sticky top-20">
          <div className="p-4 rounded-2xl bg-tx-surface border border-tx-border">
            <div className="flex items-center justify-between mb-3 px-1">
              <span className="text-xs font-semibold text-tx-cream flex items-center gap-1.5">
                <Smartphone className="w-3.5 h-3.5 text-tx-primary" />
                <span>Live Android 14+ Preview</span>
              </span>
              <span className="text-[10px] text-tx-textDim">Interactive preview</span>
            </div>

            {/* Mobile Device Frame */}
            <div className="w-full max-w-[340px] mx-auto bg-[#0F1410] rounded-[32px] p-3 border-4 border-[#243326] shadow-2xl relative overflow-hidden">
              {/* Device Status Bar */}
              <div className="flex items-center justify-between px-3 py-1.5 text-[11px] text-[#A6B8A8] font-mono select-none">
                <span>12:45</span>
                <div className="w-16 h-3 rounded-full bg-black/60 mx-auto" />
                <div className="flex items-center gap-1.5">
                  <Wifi className="w-3 h-3" />
                  <BatteryCharging className="w-3.5 h-3.5" />
                </div>
              </div>

              {/* Notification Shade / Card Container */}
              <div className="mt-3 space-y-2">
                {/* Real Android 14 Notification Card */}
                <div className="p-3.5 rounded-2xl bg-[#1C261E] border border-[#2D3E30] shadow-md transition-all">
                  {/* Notification App Header */}
                  <div className="flex items-center justify-between text-xs text-[#9BB09D] mb-2 select-none">
                    <div className="flex items-center gap-1.5">
                      <div className="w-4 h-4 rounded-full bg-tx-primary flex items-center justify-center text-[9px] font-bold text-white">
                        TX
                      </div>
                      <span className="font-medium text-[11px] text-[#CCD9CD]">TX Browser</span>
                      <span className="text-[10px] text-[#6E8270]">&bull; now</span>
                    </div>
                    <ChevronDown className="w-3.5 h-3.5 text-[#6E8270]" />
                  </div>

                  {/* Title & Body */}
                  <div className="space-y-1">
                    <h4 className="text-xs font-semibold text-[#F1F6F2] leading-snug">
                      {title || 'Your notification title will appear here'}
                    </h4>
                    <p className="text-[11px] text-[#A3B5A5] leading-relaxed line-clamp-3">
                      {body ||
                        'Enter a message body on the left to see it update dynamically in real time.'}
                    </p>
                  </div>

                  {/* Optional Large Image Banner Preview */}
                  {imageUrl && (
                    <div className="mt-2.5 rounded-xl overflow-hidden bg-black/40 border border-[#2D3E30] aspect-video">
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
                  <div className="mt-3 pt-2 border-t border-[#27382A] flex items-center justify-end gap-2">
                    <span className="text-[10px] font-semibold uppercase tracking-wider text-[#73B079] px-2 py-1 rounded hover:bg-[#27382A] cursor-pointer">
                      {destinationType === 'WEB_URL' ? 'Open Link' : 'Open TX'}
                    </span>
                    <span className="text-[10px] font-semibold uppercase tracking-wider text-[#6E8270] px-2 py-1 rounded hover:bg-[#27382A] cursor-pointer">
                      Dismiss
                    </span>
                  </div>
                </div>

                {/* Subdued Background Card to simulate real lockscreen/shade */}
                <div className="p-3 rounded-2xl bg-[#141B15]/60 border border-[#202B21] opacity-40">
                  <div className="h-3 w-24 rounded bg-tx-border mb-2" />
                  <div className="h-2 w-48 rounded bg-tx-border/60" />
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
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="w-full max-w-md bg-tx-surface border border-tx-border rounded-2xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-amber-950/80 border border-amber-800/40 flex items-center justify-center text-amber-400">
                <AlertTriangle className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-tx-cream">Confirm Campaign Broadcast</h3>
                <p className="text-xs text-tx-textDim">Production FCM push verification</p>
              </div>
            </div>

            <div className="p-3.5 rounded-xl bg-tx-card border border-tx-border space-y-2 text-xs">
              <div className="flex justify-between">
                <span className="text-tx-textDim">Audience Type:</span>
                <span className="font-semibold text-tx-cream">{audienceType}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-tx-textDim">Estimated Reach:</span>
                <span className="font-bold text-tx-sage">
                  {estimatedReach !== null ? `${estimatedReach.toLocaleString()} devices` : 'Topic broadcast'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-tx-textDim">Delivery Mode:</span>
                <span className="font-semibold text-emerald-400">
                  {timing === 'NOW' ? 'Immediate Broadcast' : `Scheduled for ${scheduledAt}`}
                </span>
              </div>
              <div className="pt-2 border-t border-tx-border">
                <span className="text-tx-textDim block mb-1">Title:</span>
                <p className="font-medium text-tx-cream">{title}</p>
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
                className="px-4 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-cream text-xs font-medium transition-colors"
              >
                Back to Edit
              </button>

              <button
                type="button"
                onClick={handleConfirmSend}
                disabled={submitting}
                className="px-4 py-2 rounded-xl bg-tx-primary hover:bg-tx-primaryHover text-white text-xs font-semibold flex items-center gap-2 shadow-lg shadow-tx-primary/20 transition-all"
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
    </div>
  );
};
