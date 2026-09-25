'use client';

import React, { useState } from 'react';
import { Send, Lock, Mail, AlertCircle, Loader2, ShieldCheck } from 'lucide-react';
import { useAuth } from '@/context/AuthContext';

export const Login: React.FC = () => {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setError('Please provide email and password');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      await login(email, password);
    } catch (err: any) {
      setError(err?.message || 'Login failed. Please check your credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-tx-bg p-4 relative overflow-hidden">
      {/* Background ambient lighting */}
      <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-tx-primary/10 rounded-full blur-[100px] pointer-events-none -z-10" />
      <div className="absolute bottom-10 right-10 w-80 h-80 bg-emerald-900/10 rounded-full blur-3xl pointer-events-none -z-10" />

      <div className="w-full max-w-md bg-tx-surface/95 backdrop-blur-2xl border border-tx-borderLight rounded-3xl p-8 sm:p-10 shadow-2xl relative z-10 animate-slide-up">
        {/* Logo and Header */}
        <div className="text-center mb-8">
          <div className="inline-flex w-16 h-16 rounded-2xl bg-gradient-to-br from-tx-primary via-emerald-600 to-emerald-800 items-center justify-center shadow-glow-primary mb-5">
            <Send className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight text-tx-cream">TX Browser Console</h1>
          <p className="text-xs text-tx-textMuted mt-1.5 font-medium">
            Production Push Notification Management
          </p>
        </div>

        {/* Error notification */}
        {error && (
          <div className="mb-6 p-4 rounded-xl bg-rose-950/40 border border-rose-800/50 flex items-start gap-3 text-rose-300 text-xs shadow-card-elevated animate-fade-in">
            <AlertCircle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
            <p className="flex-1 font-medium">{error}</p>
          </div>
        )}

        {/* Login Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-semibold text-tx-textMuted mb-2">
              Admin Email
            </label>
            <div className="relative">
              <Mail className="w-4 h-4 text-tx-textDim absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@txbrowser.com"
                className="w-full pl-10 pr-4 py-2.5 rounded-xl saas-input text-xs font-mono placeholder-tx-textDim"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-tx-textMuted mb-2">
              Password
            </label>
            <div className="relative">
              <Lock className="w-4 h-4 text-tx-textDim absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••••••"
                className="w-full pl-10 pr-4 py-2.5 rounded-xl saas-input text-xs font-mono placeholder-tx-textDim"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full mt-2 py-3 rounded-xl bg-tx-primary hover:bg-tx-primaryHover text-white font-bold text-xs transition-all shadow-glow-primary flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed active:scale-95"
          >
            {loading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Authenticating...</span>
              </>
            ) : (
              <span>Sign In to Console</span>
            )}
          </button>
        </form>

        <div className="mt-8 pt-6 border-t border-tx-border/60 text-center">
          <div className="flex items-center justify-center gap-1.5 text-[11px] text-tx-textDim">
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
            <span>Protected by Argon2id & Rate Limiting</span>
          </div>
        </div>
      </div>
    </div>
  );
};
