'use client';

import React, { useState, useEffect } from 'react';
import {
  ShieldAlert,
  Search,
  Plus,
  Trash2,
  AlertTriangle,
  CheckCircle,
  ExternalLink,
  Filter,
  RefreshCw,
  Globe,
  Radio,
  Lock,
  ChevronRight,
  ShieldCheck,
  Info,
} from 'lucide-react';
import { api } from '@/lib/api-client';

interface ThreatItem {
  id: string;
  domain: string;
  category: 'PHISHING' | 'SCAM' | 'MALWARE' | 'CRYPTO_DRAINER' | 'SUSPICIOUS';
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  reason: string;
  reportedCount: number;
  isActive: boolean;
  source: string;
  createdAt: string;
}

export const SecurityThreats: React.FC = () => {
  const [threats, setThreats] = useState<ThreatItem[]>([]);
  const [stats, setStats] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('ALL');
  const [selectedSeverity, setSelectedSeverity] = useState('ALL');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);

  // New threat form
  const [newDomain, setNewDomain] = useState('');
  const [newCategory, setNewCategory] = useState<'PHISHING' | 'SCAM' | 'MALWARE' | 'CRYPTO_DRAINER' | 'SUSPICIOUS'>('PHISHING');
  const [newSeverity, setNewSeverity] = useState<'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'>('HIGH');
  const [newReason, setNewReason] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [actionMsg, setActionMsg] = useState('');

  // Test URL simulation state
  const [testInput, setTestInput] = useState('');
  const [testResult, setTestResult] = useState<{ checked: boolean; isBlocked: boolean; threat?: ThreatItem } | null>(null);

  useEffect(() => {
    fetchThreats();
  }, [page, selectedCategory, selectedSeverity]);

  const fetchThreats = async () => {
    try {
      setLoading(true);
      const params = new URLSearchParams({
        page: page.toString(),
        limit: '20',
        search,
        category: selectedCategory,
        severity: selectedSeverity,
      });

      const data = await api.get<any>(`/admin/threats?${params.toString()}`);
      if (data?.success) {
        setThreats(data.threats);
        setStats(data.stats || {});
        setTotalPages(data.pagination.totalPages || 1);
      }
    } catch (err: any) {
      console.error('Failed to load threats:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    fetchThreats();
  };

  const handleAddThreat = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newDomain || !newReason) return;

    try {
      setIsSubmitting(true);
      const data = await api.post<any>('/admin/threats', {
        domain: newDomain,
        category: newCategory,
        severity: newSeverity,
        reason: newReason,
      });

      if (data?.success) {
        setIsAddModalOpen(false);
        setNewDomain('');
        setNewReason('');
        setActionMsg(`Successfully added threat domain to cloud database.`);
        setTimeout(() => setActionMsg(''), 3500);
        fetchThreats();
      } else {
        alert(data?.error || 'Failed to add threat');
      }
    } catch (err: any) {
      alert(err?.message || 'Error adding threat domain');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggleActive = async (id: string, currentActive: boolean) => {
    try {
      const data = await api.put<any>(`/admin/threats/${id}`, {
        isActive: !currentActive,
      });
      if (data?.success) {
        setThreats(threats.map((t) => (t.id === id ? { ...t, isActive: !currentActive } : t)));
      }
    } catch (err) {
      console.error('Error toggling active state:', err);
    }
  };

  const handleDelete = async (id: string, domain: string) => {
    if (!confirm(`Are you sure you want to remove "${domain}" from the threat registry?`)) return;

    try {
      const data = await api.delete<any>(`/admin/threats/${id}`);
      if (data?.success) {
        setThreats(threats.filter((t) => t.id !== id));
      }
    } catch (err) {
      console.error('Error deleting threat:', err);
    }
  };

  const runTestDomainSimulation = (e: React.FormEvent) => {
    e.preventDefault();
    if (!testInput.trim()) return;

    const normalized = testInput.toLowerCase().trim().replace(/^https?:\/\//, '').replace(/\/.*$/, '');
    const matched = threats.find((t) => t.isActive && (t.domain === normalized || normalized.endsWith(`.${t.domain}`)));

    setTestResult({
      checked: true,
      isBlocked: !!matched,
      threat: matched,
    });
  };

  const getSeverityBadge = (sev: string) => {
    switch (sev) {
      case 'CRITICAL':
        return 'bg-red-500/15 text-red-400 border-red-500/30';
      case 'HIGH':
        return 'bg-amber-500/15 text-amber-400 border-amber-500/30';
      case 'MEDIUM':
        return 'bg-yellow-500/15 text-yellow-400 border-yellow-500/30';
      default:
        return 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30';
    }
  };

  const getCategoryBadge = (cat: string) => {
    switch (cat) {
      case 'PHISHING':
        return 'bg-rose-500/15 text-rose-300 border-rose-500/30';
      case 'SCAM':
        return 'bg-orange-500/15 text-orange-300 border-orange-500/30';
      case 'CRYPTO_DRAINER':
        return 'bg-purple-500/15 text-purple-300 border-purple-500/30';
      case 'MALWARE':
        return 'bg-red-500/15 text-red-300 border-red-500/30';
      default:
        return 'bg-amber-500/15 text-amber-300 border-amber-500/30';
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-tx-border pb-5">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-red-500/10 border border-red-500/30 flex items-center justify-center">
              <ShieldAlert className="w-5 h-5 text-red-400" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-tx-cream tracking-tight">Phishing & Scam Threat Database</h1>
              <p className="text-xs text-tx-textMuted mt-0.5">
                Real-time threat intelligence protecting users from deceptive credential harvesters, scams, and wallet drainers.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => fetchThreats()}
            className="p-2 text-tx-textMuted hover:text-tx-cream bg-tx-card border border-tx-border rounded-xl transition-all shadow-sm"
            title="Refresh database"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
          <button
            onClick={() => setIsAddModalOpen(true)}
            className="px-4 py-2 text-xs font-semibold text-black bg-gradient-to-r from-tx-gold to-amber-500 hover:from-amber-400 hover:to-amber-500 rounded-xl flex items-center gap-2 transition-all shadow-glow font-medium"
          >
            <Plus className="w-4 h-4" />
            Add Threat Domain
          </button>
        </div>
      </div>

      {actionMsg && (
        <div className="flex items-center gap-2.5 p-3.5 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs">
          <CheckCircle className="w-4 h-4 flex-shrink-0" />
          <span>{actionMsg}</span>
        </div>
      )}

      {/* Metrics Banner */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="p-4 rounded-xl bg-tx-card border border-tx-border">
          <p className="text-[11px] font-medium text-tx-textMuted">Phishing Domains</p>
          <p className="text-xl font-bold text-rose-400 mt-1 font-mono">{stats.PHISHING || 0}</p>
        </div>
        <div className="p-4 rounded-xl bg-tx-card border border-tx-border">
          <p className="text-[11px] font-medium text-tx-textMuted">Financial Scams</p>
          <p className="text-xl font-bold text-amber-400 mt-1 font-mono">{stats.SCAM || 0}</p>
        </div>
        <div className="p-4 rounded-xl bg-tx-card border border-tx-border">
          <p className="text-[11px] font-medium text-tx-textMuted">Crypto Drainers</p>
          <p className="text-xl font-bold text-purple-400 mt-1 font-mono">{stats.CRYPTO_DRAINER || 0}</p>
        </div>
        <div className="p-4 rounded-xl bg-tx-card border border-tx-border">
          <p className="text-[11px] font-medium text-tx-textMuted">Malware Droppers</p>
          <p className="text-xl font-bold text-red-400 mt-1 font-mono">{stats.MALWARE || 0}</p>
        </div>
      </div>

      {/* Domain Safety Simulator */}
      <div className="p-4 rounded-2xl bg-tx-card border border-tx-border space-y-3">
        <div className="flex items-center gap-2">
          <Lock className="w-4 h-4 text-tx-gold" />
          <h3 className="text-xs font-bold text-tx-cream uppercase tracking-wider">
            Test Domain Interception Simulator
          </h3>
        </div>
        <form onSubmit={runTestDomainSimulation} className="flex gap-2.5">
          <div className="relative flex-1">
            <Globe className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-tx-textMuted" />
            <input
              type="text"
              placeholder="Enter domain to test (e.g. metamask-restore-wallet.xyz or google.com)..."
              value={testInput}
              onChange={(e) => setTestInput(e.target.value)}
              className="w-full pl-9 pr-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream focus:outline-none focus:border-tx-gold font-mono"
            />
          </div>
          <button
            type="submit"
            className="px-4 py-2 text-xs font-semibold text-tx-cream bg-tx-surface border border-tx-border hover:border-tx-gold rounded-xl transition-all"
          >
            Simulate Check
          </button>
        </form>

        {testResult && testResult.checked && (
          <div
            className={`p-3.5 rounded-xl border flex items-center justify-between text-xs ${
              testResult.isBlocked
                ? 'bg-red-500/10 border-red-500/30 text-red-400'
                : 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400'
            }`}
          >
            <div className="flex items-center gap-2.5">
              {testResult.isBlocked ? (
                <AlertTriangle className="w-4 h-4 flex-shrink-0" />
              ) : (
                <ShieldCheck className="w-4 h-4 flex-shrink-0" />
              )}
              <div>
                <p className="font-semibold">
                  {testResult.isBlocked
                    ? `THREAT INTERCEPTED: ${testResult.threat?.category} (${testResult.threat?.severity})`
                    : 'SAFE DOMAIN: Not listed in threat intelligence registry.'}
                </p>
                {testResult.threat && (
                  <p className="text-[11px] text-red-300/80 mt-0.5">{testResult.threat.reason}</p>
                )}
              </div>
            </div>
            <span className="text-[10px] uppercase font-mono px-2 py-0.5 rounded bg-black/20">
              {testResult.isBlocked ? 'Blocked in TX Browser' : 'Allowed'}
            </span>
          </div>
        )}
      </div>

      {/* Filters & Search */}
      <div className="p-4 rounded-2xl bg-tx-card border border-tx-border space-y-3">
        <div className="flex flex-col sm:flex-row gap-3">
          <form onSubmit={handleSearch} className="relative flex-1">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-tx-textMuted" />
            <input
              type="text"
              placeholder="Search threat domains or reason..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-9 pr-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream focus:outline-none focus:border-tx-gold"
            />
          </form>

          <div className="flex items-center gap-2">
            <select
              value={selectedCategory}
              onChange={(e) => {
                setSelectedCategory(e.target.value);
                setPage(1);
              }}
              className="px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream focus:outline-none focus:border-tx-gold"
            >
              <option value="ALL">All Threat Categories</option>
              <option value="PHISHING">Phishing</option>
              <option value="SCAM">Scam</option>
              <option value="CRYPTO_DRAINER">Crypto Drainer</option>
              <option value="MALWARE">Malware</option>
              <option value="SUSPICIOUS">Suspicious</option>
            </select>

            <select
              value={selectedSeverity}
              onChange={(e) => {
                setSelectedSeverity(e.target.value);
                setPage(1);
              }}
              className="px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream focus:outline-none focus:border-tx-gold"
            >
              <option value="ALL">All Severities</option>
              <option value="CRITICAL">Critical</option>
              <option value="HIGH">High</option>
              <option value="MEDIUM">Medium</option>
              <option value="LOW">Low</option>
            </select>
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="rounded-2xl bg-tx-card border border-tx-border overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs text-tx-textMuted">
            <thead className="bg-tx-surface text-tx-cream border-b border-tx-border uppercase text-[10px] tracking-wider font-semibold">
              <tr>
                <th className="px-5 py-3.5">Threat Domain</th>
                <th className="px-5 py-3.5">Category</th>
                <th className="px-5 py-3.5">Severity</th>
                <th className="px-5 py-3.5">Threat Details</th>
                <th className="px-5 py-3.5 text-center">Active Status</th>
                <th className="px-5 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-tx-border/60">
              {loading ? (
                <tr>
                  <td colSpan={6} className="px-5 py-10 text-center text-tx-textMuted">
                    <div className="w-6 h-6 border-2 border-tx-gold/20 border-t-tx-gold rounded-full animate-spin mx-auto mb-2" />
                    Loading threat intelligence data...
                  </td>
                </tr>
              ) : threats.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-5 py-10 text-center text-tx-textMuted">
                    No threat domains matching filters found.
                  </td>
                </tr>
              ) : (
                threats.map((threat) => (
                  <tr key={threat.id} className="hover:bg-tx-surface/50 transition-colors">
                    <td className="px-5 py-3.5 font-mono text-tx-cream font-medium">
                      <div className="flex items-center gap-1.5">
                        <span>{threat.domain}</span>
                      </div>
                    </td>
                    <td className="px-5 py-3.5">
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${getCategoryBadge(threat.category)}`}>
                        {threat.category}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${getSeverityBadge(threat.severity)}`}>
                        {threat.severity}
                      </span>
                    </td>
                    <td className="px-5 py-3.5 max-w-xs truncate text-tx-textDim" title={threat.reason}>
                      {threat.reason}
                    </td>
                    <td className="px-5 py-3.5 text-center">
                      <button
                        onClick={() => handleToggleActive(threat.id, threat.isActive)}
                        className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold border transition-all ${
                          threat.isActive
                            ? 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30'
                            : 'bg-tx-surface text-tx-textMuted border-tx-border'
                        }`}
                      >
                        {threat.isActive ? 'Active Block' : 'Muted'}
                      </button>
                    </td>
                    <td className="px-5 py-3.5 text-right">
                      <button
                        onClick={() => handleDelete(threat.id, threat.domain)}
                        className="p-1.5 text-tx-textMuted hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-all"
                        title="Delete threat"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add Modal */}
      {isAddModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="w-full max-w-md p-6 rounded-2xl bg-tx-card border border-tx-border space-y-4 shadow-2xl">
            <div className="flex items-center justify-between border-b border-tx-border pb-3">
              <h3 className="text-sm font-bold text-tx-cream">Add Threat Domain</h3>
              <button
                onClick={() => setIsAddModalOpen(false)}
                className="text-tx-textMuted hover:text-tx-cream text-sm"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleAddThreat} className="space-y-4">
              <div>
                <label className="text-xs font-medium text-tx-textMuted block mb-1">
                  Domain Name (e.g. evil-phishing.com)
                </label>
                <input
                  type="text"
                  required
                  placeholder="domain-name.xyz"
                  value={newDomain}
                  onChange={(e) => setNewDomain(e.target.value)}
                  className="w-full px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream focus:outline-none focus:border-tx-gold font-mono"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-tx-textMuted block mb-1">Category</label>
                  <select
                    value={newCategory}
                    onChange={(e: any) => setNewCategory(e.target.value)}
                    className="w-full px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream focus:outline-none focus:border-tx-gold"
                  >
                    <option value="PHISHING">Phishing</option>
                    <option value="SCAM">Scam</option>
                    <option value="CRYPTO_DRAINER">Crypto Drainer</option>
                    <option value="MALWARE">Malware</option>
                    <option value="SUSPICIOUS">Suspicious</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-medium text-tx-textMuted block mb-1">Severity</label>
                  <select
                    value={newSeverity}
                    onChange={(e: any) => setNewSeverity(e.target.value)}
                    className="w-full px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream focus:outline-none focus:border-tx-gold"
                  >
                    <option value="CRITICAL">Critical</option>
                    <option value="HIGH">High</option>
                    <option value="MEDIUM">Medium</option>
                    <option value="LOW">Low</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="text-xs font-medium text-tx-textMuted block mb-1">
                  Reason & Behavior Details
                </label>
                <textarea
                  required
                  rows={3}
                  placeholder="e.g. Credential harvesting form impersonating banking portal with deceptive SSL..."
                  value={newReason}
                  onChange={(e) => setNewReason(e.target.value)}
                  className="w-full px-3 py-2 text-xs bg-tx-surface border border-tx-border rounded-xl text-tx-cream focus:outline-none focus:border-tx-gold"
                />
              </div>

              <div className="flex justify-end gap-2.5 pt-2">
                <button
                  type="button"
                  onClick={() => setIsAddModalOpen(false)}
                  className="px-4 py-2 text-xs font-semibold text-tx-textMuted bg-tx-surface border border-tx-border rounded-xl hover:text-tx-cream"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-4 py-2 text-xs font-semibold text-black bg-gradient-to-r from-tx-gold to-amber-500 hover:from-amber-400 rounded-xl"
                >
                  {isSubmitting ? 'Registering...' : 'Add Threat'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
