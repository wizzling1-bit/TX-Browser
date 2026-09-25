'use client';

import React, { useState, useEffect } from 'react';
import { X, Send, Smartphone, CheckCircle2, AlertCircle, Loader2 } from 'lucide-react';
import { api } from '@/lib/api-client';
import { DeviceItem } from '@/types';
import { ImageUploadWithUrl } from './ImageUploadWithUrl';

interface TestPushModalProps {
  isOpen: boolean;
  onClose: () => void;
  defaultToken?: string;
  defaultTitle?: string;
  defaultBody?: string;
  defaultImageUrl?: string;
}

export const TestPushModal: React.FC<TestPushModalProps> = ({
  isOpen,
  onClose,
  defaultToken = '',
  defaultTitle = 'TX Browser Test Ping',
  defaultBody = 'This is a live test notification dispatched directly through Firebase Cloud Messaging.',
  defaultImageUrl = '',
}) => {
  const [token, setToken] = useState(defaultToken);
  const [title, setTitle] = useState(defaultTitle);
  const [body, setBody] = useState(defaultBody);
  const [imageUrl, setImageUrl] = useState(defaultImageUrl);
  const [channel, setChannel] = useState('GENERAL');
  const [destinationUrl, setDestinationUrl] = useState('');
  const [devices, setDevices] = useState<DeviceItem[]>([]);

  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<{
    success: boolean;
    message: string;
    details?: any;
  } | null>(null);

  useEffect(() => {
    if (defaultToken) setToken(defaultToken);
    if (defaultImageUrl) setImageUrl(defaultImageUrl);
  }, [defaultToken, defaultImageUrl]);

  useEffect(() => {
    if (isOpen) {
      setResult(null);
      const loadDevices = async () => {
        try {
          const res = await api.get<{ items: DeviceItem[] }>('/devices?limit=10&isActive=true');
          setDevices(res.items || []);
          if (!token && res.items?.length > 0) {
            setToken(res.items[0].fcmToken);
          }
        } catch {
          // ignore
        }
      };
      loadDevices();
    }
  }, [isOpen]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token.trim()) return;

    setSending(true);
    setResult(null);

    try {
      const res = await api.post<any>('/notifications/test-send', {
        targetFcmToken: token.trim(),
        title: title.trim(),
        body: body.trim(),
        imageUrl: imageUrl.trim() || null,
        notificationType: channel,
        destinationType: destinationUrl ? 'WEB_URL' : 'HOME',
        destinationValue: destinationUrl.trim() || null,
      });

      if (res.success) {
        setResult({
          success: true,
          message: `Dispatched successfully to FCM! Message ID: ${res.result?.messageId || 'Delivered'}`,
          details: res.result,
        });
      } else {
        setResult({
          success: false,
          message: res.error || 'FCM rejected delivery to this token.',
          details: res.result,
        });
      }
    } catch (err: any) {
      setResult({
        success: false,
        message: err?.message || 'Network exception while connecting to push gateway.',
      });
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-md animate-fade-in">
      <div className="w-full max-w-lg rounded-3xl bg-tx-card border border-tx-border shadow-2xl overflow-hidden flex flex-col max-h-[90vh] animate-slide-up">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-tx-border bg-tx-surface/80">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-emerald-950/80 border border-emerald-700/50 flex items-center justify-center text-emerald-400 shadow-sm">
              <Smartphone className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-tx-cream tracking-tight">Direct FCM Test Push</h3>
              <p className="text-[11px] text-tx-textMuted">Deliver an instant test notification to a specific device</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-xl text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface transition-colors active:scale-95"
            aria-label="Close"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Content */}
        <form onSubmit={handleSend} className="p-6 space-y-4 overflow-y-auto">
          {/* Quick Select from Active Devices */}
          {devices.length > 0 && (
            <div>
              <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">
                Select from Active Fleet ({devices.length} available)
              </label>
              <select
                onChange={(e) => setToken(e.target.value)}
                value={token}
                className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-tx-cream text-xs font-medium focus:outline-none focus:border-tx-gold"
              >
                <option value="">-- Custom Token or Paste Manually --</option>
                {devices.map((d) => (
                  <option key={d.id} value={d.fcmToken}>
                    {d.deviceModel} ({d.androidVersion}) — {d.fcmToken.substring(0, 16)}...
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Target FCM Token */}
          <div>
            <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">
              Target FCM Registration Token <span className="text-rose-400">*</span>
            </label>
            <textarea
              required
              rows={2}
              value={token}
              onChange={(e) => setToken(e.target.value)}
              placeholder="Paste device FCM token here..."
              className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-tx-cream text-xs font-mono placeholder:text-tx-textSubtle resize-none focus:outline-none focus:border-tx-gold"
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">Notification Title</label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-tx-cream text-xs focus:outline-none focus:border-tx-gold"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">Android Channel</label>
              <select
                value={channel}
                onChange={(e) => setChannel(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-tx-cream text-xs font-medium focus:outline-none focus:border-tx-gold"
              >
                <option value="GENERAL">tx_general (Announcements)</option>
                <option value="BROWSER_UPDATE">tx_updates (Browser Updates)</option>
                <option value="PROMOTION">tx_promotions (Promotions & Perks)</option>
                <option value="SECURITY">tx_security (Security Alerts)</option>
              </select>
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">Message Body</label>
            <textarea
              required
              rows={2}
              value={body}
              onChange={(e) => setBody(e.target.value)}
              className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-tx-cream text-xs placeholder:text-tx-textSubtle resize-none focus:outline-none focus:border-tx-gold"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-tx-textMuted mb-1.5">
              Optional Web Destination URL (HTTPS)
            </label>
            <input
              type="url"
              placeholder="https://txbrowser.com/news"
              value={destinationUrl}
              onChange={(e) => setDestinationUrl(e.target.value)}
              className="w-full px-3.5 py-2.5 rounded-xl bg-tx-surface border border-tx-border text-tx-cream text-xs font-mono placeholder:text-tx-textSubtle focus:outline-none focus:border-tx-gold"
            />
          </div>

          {/* Optional Hero Image */}
          <div className="pt-1">
            <ImageUploadWithUrl
              value={imageUrl}
              onChange={setImageUrl}
              label="Notification Hero Image (Optional)"
              helperText="Upload or enter an image link to test expandable banner notifications on your phone."
            />
          </div>

          {/* Status Message */}
          {result && (
            <div
              className={`p-4 rounded-xl border flex items-start gap-3 text-xs shadow-card animate-fade-in ${
                result.success
                  ? 'bg-emerald-950/40 border-emerald-700/60 text-emerald-300'
                  : 'bg-rose-950/40 border-rose-700/60 text-rose-300'
              }`}
            >
              {result.success ? (
                <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
              ) : (
                <AlertCircle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
              )}
              <div className="flex-1 break-words">
                <p className="font-bold">{result.success ? 'Delivered to FCM Gateway' : 'Delivery Refused'}</p>
                <p className="mt-0.5 text-[11px] leading-relaxed opacity-90">{result.message}</p>
              </div>
            </div>
          )}

          {/* Action Footer */}
          <div className="flex items-center justify-end gap-3 pt-3 border-t border-tx-border">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2.5 rounded-xl bg-tx-card hover:bg-tx-elevated text-tx-cream text-xs font-semibold transition-colors active:scale-95"
            >
              Close
            </button>
            <button
              type="submit"
              disabled={sending || !token.trim()}
              className="px-5 py-2.5 rounded-xl bg-tx-gold hover:bg-tx-goldLight disabled:opacity-50 text-black text-xs font-bold flex items-center gap-2 shadow-glow transition-all active:scale-95"
            >
              {sending ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Send className="w-3.5 h-3.5" />}
              <span>{sending ? 'Dispatching...' : 'Dispatch Test Push'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
