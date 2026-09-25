'use client';

import React, { useState, useEffect } from 'react';
import { X, RefreshCw, Database, Cloud, ShieldCheck, Smartphone, Zap } from 'lucide-react';
import { api } from '@/lib/api-client';
import { SystemHealth } from '@/types';

interface SystemHealthModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SystemHealthModal: React.FC<SystemHealthModalProps> = ({ isOpen, onClose }) => {
  const [health, setHealth] = useState<SystemHealth | null>(null);
  const [loading, setLoading] = useState(false);

  const fetchHealth = async () => {
    setLoading(true);
    try {
      const data = await api.get<SystemHealth>('/analytics/system-health');
      setHealth(data);
    } catch (err) {
      console.error('Failed to query system health:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen) {
      fetchHealth();
    }
  }, [isOpen]);

  // Esc key listener
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-md animate-fade-in">
      <div className="w-full max-w-xl rounded-3xl bg-tx-card border border-tx-border shadow-2xl overflow-hidden flex flex-col max-h-[90vh] animate-slide-up">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-tx-border bg-tx-surface/80">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-emerald-950/80 border border-emerald-700/50 flex items-center justify-center text-emerald-400 shadow-sm">
              <Zap className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-tx-cream tracking-tight">Cloud Sync & Gateway Diagnostics</h3>
              <p className="text-[11px] text-tx-textMuted">Live latency and connectivity of Supabase DB, Firebase FCM, and Client Fleet</p>
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
        <div className="p-6 space-y-4 overflow-y-auto">
          {/* Card 1: Supabase Cloud Database */}
          <div className="p-4 sm:p-5 rounded-2xl bg-tx-surface border border-tx-border shadow-card space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5 text-xs font-bold text-tx-cream">
                <Database className="w-4 h-4 text-emerald-400" />
                <span>Supabase PostgreSQL Cloud Database</span>
              </div>
              <span className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-950/80 border border-emerald-700/60 text-emerald-300 text-[10px] font-bold">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                {health?.database.status.toUpperCase() || 'ONLINE'}
              </span>
            </div>
            <div className="grid grid-cols-2 gap-3 text-[11px] text-tx-textMuted pt-1">
              <div>
                <span className="text-tx-textSubtle">Region:</span>{' '}
                <span className="text-tx-cream font-mono font-medium">{health?.database.region || 'ap-south-1'}</span>
              </div>
              <div>
                <span className="text-tx-textSubtle">Round-trip Ping:</span>{' '}
                <span className="text-emerald-400 font-mono font-bold">{health?.database.latencyMs ?? '—'} ms</span>
              </div>
              <div>
                <span className="text-tx-textSubtle">Registered Fleet:</span>{' '}
                <span className="text-tx-cream font-bold font-mono">{health?.database.registeredDevices ?? 0} devices</span>
              </div>
              <div>
                <span className="text-tx-textSubtle">Pooler Protocol:</span> Transaction Pooler (6543)
              </div>
            </div>
          </div>

          {/* Card 2: Firebase Cloud Messaging */}
          <div className="p-4 sm:p-5 rounded-2xl bg-tx-surface border border-tx-border shadow-card space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5 text-xs font-bold text-tx-cream">
                <Cloud className="w-4 h-4 text-sky-400" />
                <span>Firebase Cloud Messaging (FCM HTTP v1)</span>
              </div>
              <span className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-sky-950/80 border border-sky-700/60 text-sky-300 text-[10px] font-bold">
                <span className="w-1.5 h-1.5 rounded-full bg-sky-400 animate-pulse" />
                {health?.firebase.status.toUpperCase() || 'ONLINE'}
              </span>
            </div>
            <div className="space-y-1.5 text-[11px] text-tx-textMuted pt-1">
              <div className="flex justify-between">
                <span className="text-tx-textSubtle">Project ID:</span>
                <span className="text-tx-cream font-mono font-medium">{health?.firebase.projectId || 'tx-browser'}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-tx-textSubtle">Service Account:</span>
                <span className="text-tx-cream font-mono text-[10px] truncate max-w-[280px]">
                  {health?.firebase.clientEmail || 'firebase-adminsdk@tx-browser.iam.gserviceaccount.com'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-tx-textSubtle">Protocol:</span>
                <span className="text-tx-cream font-medium">FCM HTTP v1 (OAuth2 Bearer Token)</span>
              </div>
            </div>
          </div>

          {/* Card 3: Mobile Client Anonymous Privacy & Sync Topology */}
          <div className="p-4 sm:p-5 rounded-2xl bg-tx-surface border border-tx-border shadow-card space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5 text-xs font-bold text-tx-cream">
                <Smartphone className="w-4 h-4 text-purple-400" />
                <span>Client Architecture & Security</span>
              </div>
              <span className="flex items-center gap-1 px-2.5 py-0.5 rounded-full bg-purple-950/80 border border-purple-700/60 text-purple-300 text-[10px] font-bold">
                <ShieldCheck className="w-3 h-3 text-purple-400" />
                ANONYMOUS
              </span>
            </div>
            <div className="space-y-2 text-[11px] text-tx-textMuted pt-1">
              <div className="flex items-center justify-between">
                <span className="text-tx-textSubtle">User Authentication:</span>
                <span className="text-emerald-400 font-semibold">100% Anonymous (No Login)</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-tx-textSubtle">Device Identity:</span>
                <span className="text-tx-cream font-mono">Drift SQLite UUID</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-tx-textSubtle">Direct Cloud Sync:</span>
                <span className="text-emerald-400 font-medium">Next.js Serverless Route Handlers</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-tx-textSubtle">Target Android SDK:</span>
                <span className="text-tx-cream font-mono font-bold">SDK 36 (Android 14+)</span>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-6 py-4 border-t border-tx-border bg-tx-surface/60">
          <p className="text-[11px] text-tx-textSubtle font-mono">
            {health?.timestamp ? `Pinged at ${new Date(health.timestamp).toLocaleTimeString()}` : 'Live Gateway Active'}
          </p>
          <div className="flex items-center gap-3">
            <button
              onClick={fetchHealth}
              disabled={loading}
              className="px-3.5 py-2 rounded-xl bg-tx-card hover:bg-tx-elevated text-tx-cream text-xs font-semibold flex items-center gap-1.5 transition-all border border-tx-border active:scale-95 shadow-sm"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-tx-gold' : ''}`} />
              <span>Ping Now</span>
            </button>
            <button
              onClick={onClose}
              className="px-4 py-2 rounded-xl bg-tx-gold hover:bg-tx-goldLight text-black text-xs font-bold transition-all shadow-glow active:scale-95"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
