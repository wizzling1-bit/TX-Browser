import React, { useState } from 'react';
import { Send, Lock, Mail, AlertCircle, Loader2 } from 'lucide-react';
import { useAuth } from '../context/AuthContext.js';

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
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-tx-primary/10 rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-md bg-tx-surface/90 backdrop-blur-xl border border-tx-border rounded-2xl p-8 shadow-2xl relative z-10 glow-border">
        {/* Logo and Header */}
        <div className="text-center mb-8">
          <div className="inline-flex w-14 h-14 rounded-2xl bg-gradient-to-br from-tx-primary to-emerald-700 items-center justify-center shadow-xl shadow-tx-primary/20 mb-4">
            <Send className="w-7 h-7 text-white" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight text-tx-cream">TX Browser Console</h1>
          <p className="text-sm text-tx-textMuted mt-1">
            Production Push Notification Management
          </p>
        </div>

        {/* Error notification */}
        {error && (
          <div className="mb-6 p-3.5 rounded-xl bg-rose-950/40 border border-rose-800/50 flex items-start gap-3 text-rose-300 text-xs">
            <AlertCircle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
            <p className="flex-1">{error}</p>
          </div>
        )}

        {/* Login Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-tx-textMuted mb-1.5">
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
                className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream placeholder-tx-textDim text-sm focus:outline-none focus:border-tx-primary transition-colors"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-tx-textMuted mb-1.5">
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
                className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream placeholder-tx-textDim text-sm focus:outline-none focus:border-tx-primary transition-colors"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full mt-2 py-3 rounded-xl bg-tx-primary hover:bg-tx-primaryHover text-white font-medium text-sm transition-all shadow-lg shadow-tx-primary/20 flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Authenticating...</span>
              </>
            ) : (
              <span>Sign In to Dashboard</span>
            )}
          </button>
        </form>

        <div className="mt-8 pt-6 border-t border-tx-border text-center">
          <p className="text-[11px] text-tx-textDim">
            Protected by Argon2id & Rate Limiting &bull; Authorized Personnel Only
          </p>
        </div>
      </div>
    </div>
  );
};
