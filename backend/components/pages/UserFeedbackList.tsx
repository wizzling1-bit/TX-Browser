'use client';

import React, { useState, useEffect } from 'react';
import {
  MessageSquare,
  Globe,
  ExternalLink,
  Smartphone,
  Shield,
  CheckCircle2,
  Clock,
  XCircle,
  Filter,
  Search,
  RefreshCw,
  Copy,
  Check,
  Trash2,
  PlusCircle,
  X,
  FileText,
  AlertTriangle,
  Send,
  Layers,
} from 'lucide-react';
import { api } from '@/lib/api-client';

interface FeedbackItem {
  id: string;
  category: 'BROKEN_WEBSITE' | 'AD_BLOCKER_ISSUE' | 'CRASH_BUG' | 'PERFORMANCE' | 'FEATURE_REQUEST' | 'OTHER';
  targetUrl: string | null;
  description: string;
  deviceModel: string | null;
  androidVersion: string | null;
  appVersion: string | null;
  shieldEnabled: boolean;
  status: 'NEW' | 'IN_REVIEW' | 'RESOLVED' | 'DISMISSED';
  adminNotes: string | null;
  createdAt: string;
}

interface FeedbackApiResponse {
  success: boolean;
  feedbacks: FeedbackItem[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
  counts: Record<string, number>;
}

export const UserFeedbackList: React.FC = () => {
  const [feedbacks, setFeedbacks] = useState<FeedbackItem[]>([]);
  const [counts, setCounts] = useState<Record<string, number>>({ NEW: 0, IN_REVIEW: 0, RESOLVED: 0, DISMISSED: 0 });
  const [loading, setLoading] = useState(true);
  const [selectedStatus, setSelectedStatus] = useState('ALL');
  const [selectedCategory, setSelectedCategory] = useState('ALL');
  const [search, setSearch] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Note editing state
  const [editingNoteId, setEditingNoteId] = useState<string | null>(null);
  const [noteText, setNoteText] = useState('');
  const [savingNote, setSavingNote] = useState(false);

  // Test report modal
  const [showTestModal, setShowTestModal] = useState(false);
  const [testCategory, setTestCategory] = useState<'BROKEN_WEBSITE' | 'AD_BLOCKER_ISSUE' | 'CRASH_BUG' | 'PERFORMANCE' | 'FEATURE_REQUEST' | 'OTHER'>('BROKEN_WEBSITE');
  const [testUrl, setTestUrl] = useState('https://example.com/broken-page');
  const [testDesc, setTestDesc] = useState('Sample issue: video playback controls blocked by aggressive ad-shield script.');
  const [testModel, setTestModel] = useState('Pixel 8 Pro');
  const [testShield, setTestShield] = useState(true);
  const [submittingTest, setSubmittingTest] = useState(false);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  useEffect(() => {
    fetchFeedback();
  }, [selectedStatus, selectedCategory]);

  const fetchFeedback = async (searchQuery = search) => {
    try {
      setLoading(true);
      setErrorMessage(null);
      const params = new URLSearchParams({
        status: selectedStatus,
        category: selectedCategory,
        search: searchQuery,
      });

      const data = await api.get<FeedbackApiResponse>(`/admin/feedback?${params.toString()}`);
      if (data?.success) {
        setFeedbacks(data.feedbacks || []);
        setCounts(data.counts || { NEW: 0, IN_REVIEW: 0, RESOLVED: 0, DISMISSED: 0 });
      } else {
        setFeedbacks([]);
      }
    } catch (err: any) {
      console.error('Failed to load feedback:', err);
      setErrorMessage(err?.message || 'Failed to load user feedback from server');
    } finally {
      setLoading(false);
    }
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    fetchFeedback(search);
  };

  const updateStatus = async (id: string, newStatus: string) => {
    try {
      await api.patch(`/admin/feedback/${id}`, { status: newStatus });
      setFeedbacks((prev) =>
        prev.map((f) => (f.id === id ? { ...f, status: newStatus as any } : f))
      );
      showToast(`Status updated to ${newStatus.replace('_', ' ')}`);
      // Update local counts
      setCounts((prev) => {
        const item = feedbacks.find((f) => f.id === id);
        if (!item || item.status === newStatus) return prev;
        return {
          ...prev,
          [item.status]: Math.max(0, (prev[item.status] || 1) - 1),
          [newStatus]: (prev[newStatus] || 0) + 1,
        };
      });
    } catch (err: any) {
      showToast(`Failed to update status: ${err?.message || 'Network error'}`);
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to permanently delete this feedback report?')) return;
    try {
      await api.delete(`/admin/feedback/${id}`);
      setFeedbacks((prev) => prev.filter((f) => f.id !== id));
      showToast('Feedback report deleted successfully');
      fetchFeedback();
    } catch (err: any) {
      showToast(`Delete failed: ${err?.message || 'Error deleting feedback'}`);
    }
  };

  const startEditNote = (item: FeedbackItem) => {
    setEditingNoteId(item.id);
    setNoteText(item.adminNotes || '');
  };

  const saveAdminNote = async (id: string) => {
    try {
      setSavingNote(true);
      await api.patch(`/admin/feedback/${id}`, { adminNotes: noteText.trim() });
      setFeedbacks((prev) =>
        prev.map((f) => (f.id === id ? { ...f, adminNotes: noteText.trim() || null } : f))
      );
      setEditingNoteId(null);
      showToast('Admin note saved');
    } catch (err: any) {
      showToast(`Failed to save note: ${err?.message || 'Error'}`);
    } finally {
      setSavingNote(false);
    }
  };

  const handleCreateTestFeedback = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!testDesc.trim()) return;

    try {
      setSubmittingTest(true);
      await api.post('/feedback', {
        category: testCategory,
        targetUrl: testUrl.trim() || null,
        description: testDesc.trim(),
        deviceModel: testModel.trim() || 'Admin Simulator',
        androidVersion: 'Android 14 (API 34)',
        appVersion: '1.0.6',
        shieldEnabled: testShield,
      });

      setShowTestModal(false);
      showToast('Test report submitted to Supabase Cloud database!');
      fetchFeedback();
    } catch (err: any) {
      alert(`Submission error: ${err?.message || 'Failed'}`);
    } finally {
      setSubmittingTest(false);
    }
  };

  const copyUrl = (id: string, url: string) => {
    navigator.clipboard.writeText(url);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const getCategoryBadge = (cat: string) => {
    switch (cat) {
      case 'BROKEN_WEBSITE':
        return 'bg-rose-500/15 text-rose-300 border-rose-500/30';
      case 'AD_BLOCKER_ISSUE':
        return 'bg-amber-500/15 text-amber-300 border-amber-500/30';
      case 'CRASH_BUG':
        return 'bg-red-500/15 text-red-300 border-red-500/30';
      case 'PERFORMANCE':
        return 'bg-sky-500/15 text-sky-300 border-sky-500/30';
      case 'FEATURE_REQUEST':
        return 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30';
      default:
        return 'bg-purple-500/15 text-purple-300 border-purple-500/30';
    }
  };

  const totalReportsCount =
    (counts.NEW || 0) + (counts.IN_REVIEW || 0) + (counts.RESOLVED || 0) + (counts.DISMISSED || 0);

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 px-4 py-3 rounded-2xl bg-tx-surface border border-tx-gold/40 text-tx-cream shadow-2xl text-xs font-semibold flex items-center gap-2 animate-slide-up">
          <CheckCircle2 className="w-4 h-4 text-tx-gold" />
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-tx-border pb-5">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center">
              <MessageSquare className="w-5 h-5 text-emerald-400" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-xl font-bold text-tx-cream tracking-tight">
                  User Feedback & Broken Websites
                </h1>
                <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded-full bg-emerald-950/80 border border-emerald-700/60 text-emerald-400">
                  {totalReportsCount} Total
                </span>
              </div>
              <p className="text-xs text-tx-textMuted mt-0.5">
                Direct client bug reports, site compatibility logs, and user experience tickets from Android devices.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2.5 self-start sm:self-auto flex-wrap">
          <button
            onClick={() => setShowTestModal(true)}
            className="px-3.5 py-2 rounded-xl bg-tx-card hover:bg-tx-surface border border-tx-border text-tx-cream text-xs font-semibold flex items-center gap-2 transition-all shadow-sm active:scale-95"
          >
            <PlusCircle className="w-4 h-4 text-emerald-400" />
            <span>Test Report</span>
          </button>

          <button
            onClick={() => fetchFeedback()}
            disabled={loading}
            className="p-2 text-tx-textMuted hover:text-tx-cream bg-tx-card border border-tx-border rounded-xl transition-all shadow-sm active:scale-95"
            title="Refresh inbox"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin text-tx-gold' : ''}`} />
          </button>
        </div>
      </div>

      {/* Error Alert if request failed */}
      {errorMessage && (
        <div className="p-4 rounded-2xl bg-rose-950/40 border border-rose-800/60 text-rose-300 text-xs flex items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0" />
            <span>{errorMessage}</span>
          </div>
          <button
            onClick={() => fetchFeedback()}
            className="px-2.5 py-1 rounded-lg bg-rose-900/60 hover:bg-rose-800 text-rose-200 text-xs font-semibold"
          >
            Retry
          </button>
        </div>
      )}

      {/* Filter and Search Bar */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-3">
        {/* Search */}
        <div className="md:col-span-8">
          <form onSubmit={handleSearchSubmit} className="relative">
            <Search className="w-4 h-4 text-tx-textMuted absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search by URL, description, or device model..."
              className="w-full pl-10 pr-24 py-2.5 rounded-xl bg-tx-card border border-tx-border text-xs text-tx-cream placeholder:text-tx-textMuted focus:outline-none focus:border-tx-gold/60 transition-all"
            />
            {search && (
              <button
                type="button"
                onClick={() => {
                  setSearch('');
                  fetchFeedback('');
                }}
                className="absolute right-16 top-1/2 -translate-y-1/2 p-1 text-tx-textMuted hover:text-tx-cream"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            )}
            <button
              type="submit"
              className="absolute right-2 top-1/2 -translate-y-1/2 px-2.5 py-1 rounded-lg bg-tx-surface hover:bg-tx-elevated border border-tx-border text-tx-cream text-[11px] font-semibold transition-all"
            >
              Search
            </button>
          </form>
        </div>

        {/* Category Dropdown */}
        <div className="md:col-span-4">
          <select
            value={selectedCategory}
            onChange={(e) => setSelectedCategory(e.target.value)}
            className="w-full px-3 py-2.5 rounded-xl bg-tx-card border border-tx-border text-xs text-tx-cream focus:outline-none focus:border-tx-gold/60 transition-all"
          >
            <option value="ALL">All Categories</option>
            <option value="BROKEN_WEBSITE">Broken Website</option>
            <option value="AD_BLOCKER_ISSUE">Ad-Blocker Issue</option>
            <option value="CRASH_BUG">Crash / Bug</option>
            <option value="PERFORMANCE">Performance / Lag</option>
            <option value="FEATURE_REQUEST">Feature Request</option>
            <option value="OTHER">Other Feedback</option>
          </select>
        </div>
      </div>

      {/* Status Segment Tabs */}
      <div className="flex flex-wrap items-center gap-2 p-1.5 rounded-2xl bg-tx-card border border-tx-border">
        {[
          { id: 'ALL', label: 'All Reports', count: totalReportsCount },
          { id: 'NEW', label: 'New / Unread', count: counts.NEW || 0, color: 'text-amber-400' },
          { id: 'IN_REVIEW', label: 'In Review', count: counts.IN_REVIEW || 0, color: 'text-sky-400' },
          { id: 'RESOLVED', label: 'Resolved', count: counts.RESOLVED || 0, color: 'text-emerald-400' },
          { id: 'DISMISSED', label: 'Dismissed', count: counts.DISMISSED || 0, color: 'text-tx-textMuted' },
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setSelectedStatus(tab.id)}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-2 transition-all ${
              selectedStatus === tab.id
                ? 'bg-tx-surface text-tx-cream shadow-sm border border-tx-borderHover'
                : 'text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface/50 border border-transparent'
            }`}
          >
            <span>{tab.label}</span>
            <span
              className={`px-1.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-tx-bg ${
                tab.color || 'text-tx-cream'
              }`}
            >
              {tab.count}
            </span>
          </button>
        ))}
      </div>

      {/* Reports List */}
      <div className="space-y-3.5">
        {loading ? (
          <div className="p-12 text-center text-tx-textMuted rounded-2xl bg-tx-card border border-tx-border">
            <div className="w-7 h-7 border-2 border-tx-gold/20 border-t-tx-gold rounded-full animate-spin mx-auto mb-3" />
            <p className="text-xs font-medium text-tx-cream">Loading live reports from Supabase...</p>
          </div>
        ) : feedbacks.length === 0 ? (
          <div className="p-12 text-center text-tx-textMuted rounded-2xl bg-tx-card border border-tx-border space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-tx-surface flex items-center justify-center mx-auto text-tx-textMuted">
              <MessageSquare className="w-6 h-6" />
            </div>
            <div>
              <p className="text-sm font-semibold text-tx-cream">No feedback reports found</p>
              <p className="text-xs text-tx-textMuted mt-1">
                {search || selectedStatus !== 'ALL' || selectedCategory !== 'ALL'
                  ? 'No submissions match your current filter settings.'
                  : 'Zero user complaints recorded. The mobile client is reporting clean browsing!'}
              </p>
            </div>
            <button
              onClick={() => setShowTestModal(true)}
              className="px-4 py-2 rounded-xl bg-tx-gold hover:bg-tx-goldLight text-black text-xs font-semibold inline-flex items-center gap-2 shadow-glow transition-all"
            >
              <PlusCircle className="w-3.5 h-3.5" />
              <span>Submit A Test Report</span>
            </button>
          </div>
        ) : (
          feedbacks.map((item) => (
            <div
              key={item.id}
              className="p-5 rounded-2xl bg-tx-card border border-tx-border hover:border-tx-gold/40 transition-all space-y-3 shadow-card"
            >
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div className="flex items-center gap-2 flex-wrap">
                  <span
                    className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${getCategoryBadge(
                      item.category
                    )}`}
                  >
                    {item.category.replace(/_/g, ' ')}
                  </span>
                  <span className="text-[11px] text-tx-textMuted">
                    {new Date(item.createdAt).toLocaleDateString()} at{' '}
                    {new Date(item.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </span>
                </div>

                {/* Status Switcher & Delete */}
                <div className="flex items-center gap-1.5 flex-wrap">
                  {(['NEW', 'IN_REVIEW', 'RESOLVED', 'DISMISSED'] as const).map((st) => (
                    <button
                      key={st}
                      onClick={() => updateStatus(item.id, st)}
                      className={`px-2.5 py-1 rounded-lg text-[10px] font-bold transition-all border ${
                        item.status === st
                          ? st === 'RESOLVED'
                            ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40 shadow-sm'
                            : st === 'IN_REVIEW'
                            ? 'bg-sky-500/20 text-sky-300 border-sky-500/40 shadow-sm'
                            : st === 'NEW'
                            ? 'bg-amber-500/20 text-amber-300 border-amber-500/40 shadow-sm'
                            : 'bg-tx-surface text-tx-textMuted border-tx-border'
                          : 'bg-tx-surface/40 text-tx-textMuted border-transparent hover:border-tx-border hover:text-tx-cream'
                      }`}
                    >
                      {st.replace(/_/g, ' ')}
                    </button>
                  ))}

                  <button
                    onClick={() => handleDelete(item.id)}
                    className="p-1.5 rounded-lg text-tx-textMuted hover:text-rose-400 hover:bg-rose-950/30 transition-colors ml-1"
                    title="Delete report"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>

              {/* Target Website URL if attached */}
              {item.targetUrl && (
                <div className="flex items-center justify-between p-2.5 rounded-xl bg-tx-surface border border-tx-border text-xs font-mono">
                  <div className="flex items-center gap-2 truncate text-tx-cream">
                    <Globe className="w-3.5 h-3.5 text-tx-gold shrink-0" />
                    <span className="truncate">{item.targetUrl}</span>
                  </div>
                  <div className="flex items-center gap-1 shrink-0 ml-2">
                    <button
                      onClick={() => copyUrl(item.id, item.targetUrl!)}
                      className="p-1.5 rounded-lg text-tx-textMuted hover:text-tx-cream hover:bg-tx-card transition-colors"
                      title="Copy URL"
                    >
                      {copiedId === item.id ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                    </button>
                    <a
                      href={item.targetUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="p-1.5 rounded-lg text-tx-textMuted hover:text-tx-cream hover:bg-tx-card transition-colors"
                      title="Open URL"
                    >
                      <ExternalLink className="w-3.5 h-3.5" />
                    </a>
                  </div>
                </div>
              )}

              {/* Description */}
              <p className="text-xs text-tx-cream font-normal leading-relaxed whitespace-pre-wrap">
                {item.description}
              </p>

              {/* Admin Note Box */}
              {editingNoteId === item.id ? (
                <div className="p-3 rounded-xl bg-tx-surface border border-tx-border space-y-2">
                  <label className="text-[11px] font-semibold text-tx-gold flex items-center gap-1">
                    <FileText className="w-3 h-3" />
                    <span>Admin Resolution Note:</span>
                  </label>
                  <textarea
                    value={noteText}
                    onChange={(e) => setNoteText(e.target.value)}
                    placeholder="Enter diagnostic notes, fix details, or whitelist updates..."
                    rows={2}
                    className="w-full p-2 text-xs rounded-lg bg-tx-card border border-tx-border text-tx-cream focus:outline-none focus:border-tx-gold"
                  />
                  <div className="flex justify-end gap-2">
                    <button
                      onClick={() => setEditingNoteId(null)}
                      className="px-2.5 py-1 text-xs text-tx-textMuted hover:text-tx-cream"
                    >
                      Cancel
                    </button>
                    <button
                      onClick={() => saveAdminNote(item.id)}
                      disabled={savingNote}
                      className="px-3 py-1 rounded-lg bg-tx-gold hover:bg-tx-goldLight text-black text-xs font-semibold"
                    >
                      {savingNote ? 'Saving...' : 'Save Note'}
                    </button>
                  </div>
                </div>
              ) : item.adminNotes ? (
                <div className="p-2.5 rounded-xl bg-tx-surface/80 border border-tx-border/80 flex items-start justify-between gap-2 text-xs">
                  <div>
                    <span className="text-[10px] font-bold text-tx-gold uppercase tracking-wider block">
                      Admin Note:
                    </span>
                    <p className="text-tx-cream/90 mt-0.5">{item.adminNotes}</p>
                  </div>
                  <button
                    onClick={() => startEditNote(item)}
                    className="text-[11px] text-tx-textMuted hover:text-tx-gold font-medium shrink-0"
                  >
                    Edit
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => startEditNote(item)}
                  className="text-[11px] text-tx-textMuted hover:text-tx-gold flex items-center gap-1 transition-colors"
                >
                  <FileText className="w-3 h-3" />
                  <span>+ Add resolution note</span>
                </button>
              )}

              {/* Diagnostics telemetry chips */}
              <div className="flex items-center gap-2 pt-1 text-[11px] text-tx-textMuted flex-wrap border-t border-tx-border/40">
                {item.deviceModel && (
                  <span className="flex items-center gap-1 px-2 py-0.5 rounded-md bg-tx-surface border border-tx-border">
                    <Smartphone className="w-3 h-3 text-tx-textMuted" />
                    {item.deviceModel}
                  </span>
                )}
                {item.androidVersion && (
                  <span className="px-2 py-0.5 rounded-md bg-tx-surface border border-tx-border">
                    {item.androidVersion}
                  </span>
                )}
                {item.appVersion && (
                  <span className="px-2 py-0.5 rounded-md bg-tx-surface border border-tx-border font-mono">
                    v{item.appVersion}
                  </span>
                )}
                <span className="flex items-center gap-1 px-2 py-0.5 rounded-md bg-tx-surface border border-tx-border">
                  <Shield className="w-3 h-3 text-emerald-400" />
                  Shield {item.shieldEnabled ? 'ON' : 'OFF'}
                </span>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Test Report Modal */}
      {showTestModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fade-in">
          <div className="w-full max-w-lg rounded-2xl bg-tx-card border border-tx-border shadow-2xl p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-tx-border pb-3">
              <div className="flex items-center gap-2">
                <MessageSquare className="w-5 h-5 text-emerald-400" />
                <h3 className="text-sm font-bold text-tx-cream">Submit Test User Feedback</h3>
              </div>
              <button
                onClick={() => setShowTestModal(false)}
                className="p-1 rounded-lg text-tx-textMuted hover:text-tx-cream"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleCreateTestFeedback} className="space-y-3.5">
              <div>
                <label className="text-xs font-semibold text-tx-cream block mb-1">Issue Category</label>
                <select
                  value={testCategory}
                  onChange={(e) => setTestCategory(e.target.value as any)}
                  className="w-full px-3 py-2 rounded-xl bg-tx-surface border border-tx-border text-xs text-tx-cream focus:outline-none focus:border-tx-gold"
                >
                  <option value="BROKEN_WEBSITE">Broken Website</option>
                  <option value="AD_BLOCKER_ISSUE">Ad-Blocker Issue</option>
                  <option value="CRASH_BUG">Crash / Bug</option>
                  <option value="PERFORMANCE">Performance / Lag</option>
                  <option value="FEATURE_REQUEST">Feature Request</option>
                  <option value="OTHER">Other</option>
                </select>
              </div>

              <div>
                <label className="text-xs font-semibold text-tx-cream block mb-1">Target Website URL (Optional)</label>
                <input
                  type="url"
                  value={testUrl}
                  onChange={(e) => setTestUrl(e.target.value)}
                  placeholder="https://example.com"
                  className="w-full px-3 py-2 rounded-xl bg-tx-surface border border-tx-border text-xs text-tx-cream focus:outline-none focus:border-tx-gold"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-tx-cream block mb-1">Description / Issue Log</label>
                <textarea
                  rows={3}
                  required
                  value={testDesc}
                  onChange={(e) => setTestDesc(e.target.value)}
                  placeholder="Describe the issue reported by the mobile browser user..."
                  className="w-full px-3 py-2 rounded-xl bg-tx-surface border border-tx-border text-xs text-tx-cream focus:outline-none focus:border-tx-gold"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-tx-cream block mb-1">Device Model</label>
                  <input
                    type="text"
                    value={testModel}
                    onChange={(e) => setTestModel(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl bg-tx-surface border border-tx-border text-xs text-tx-cream focus:outline-none focus:border-tx-gold"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-tx-cream block mb-1">Ad-Shield Active</label>
                  <button
                    type="button"
                    onClick={() => setTestShield(!testShield)}
                    className={`w-full py-2 rounded-xl border text-xs font-semibold transition-all ${
                      testShield
                        ? 'bg-emerald-950/60 border-emerald-700/60 text-emerald-300'
                        : 'bg-tx-surface border-tx-border text-tx-textMuted'
                    }`}
                  >
                    Shield {testShield ? 'ENABLED' : 'DISABLED'}
                  </button>
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-2 border-t border-tx-border">
                <button
                  type="button"
                  onClick={() => setShowTestModal(false)}
                  className="px-4 py-2 rounded-xl bg-tx-surface text-tx-textMuted hover:text-tx-cream text-xs font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submittingTest}
                  className="px-4 py-2 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-black text-xs font-bold transition-all shadow-glow flex items-center gap-1.5"
                >
                  <Send className="w-3.5 h-3.5" />
                  <span>{submittingTest ? 'Submitting...' : 'Save & Publish'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
