import React, { useState, useEffect } from 'react';
import {
  Search,
  Send,
  XCircle,
  Copy,
  Trash2,
  RefreshCw,
  PlusCircle,
  Loader2,
  Calendar,
} from 'lucide-react';
import { api } from '../lib/api.js';
import { NotificationItem, PaginatedResult } from '../types/index.js';

interface NotificationsListProps {
  onNavigate: (tab: string, meta?: any) => void;
  selectedId?: string;
}

export const NotificationsList: React.FC<NotificationsListProps> = ({
  onNavigate,
  selectedId,
}) => {
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  const [activeItem, setActiveItem] = useState<NotificationItem | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const loadNotifications = async () => {
    try {
      setLoading(true);
      const params = new URLSearchParams();
      if (statusFilter !== 'ALL') params.set('status', statusFilter);
      if (search) params.set('search', search);
      params.set('page', String(page));
      params.set('limit', '15');

      const data = await api.get<PaginatedResult<NotificationItem>>(
        `/notifications?${params.toString()}`
      );
      setNotifications(data.items);
      setTotalPages(data.pagination.totalPages);
      setTotalCount(data.pagination.total);

      if (selectedId) {
        const found = data.items.find((n) => n.id === selectedId);
        if (found) setActiveItem(found);
      }
    } catch (err) {
      console.error('Failed to load notifications:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadNotifications();
  }, [statusFilter, page]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    loadNotifications();
  };

  const handleSendNow = async (id: string) => {
    try {
      setActionLoading(id);
      await api.post(`/notifications/${id}/send`);
      await loadNotifications();
    } catch (err: any) {
      alert(err?.message || 'Failed to send notification');
    } finally {
      setActionLoading(null);
    }
  };

  const handleCancel = async (id: string) => {
    if (!confirm('Are you sure you want to cancel this scheduled notification?')) return;
    try {
      setActionLoading(id);
      await api.post(`/notifications/${id}/cancel`);
      await loadNotifications();
    } catch (err: any) {
      alert(err?.message || 'Failed to cancel notification');
    } finally {
      setActionLoading(null);
    }
  };

  const handleDuplicate = async (id: string) => {
    try {
      setActionLoading(id);
      await api.post(`/notifications/${id}/duplicate`);
      await loadNotifications();
    } catch (err: any) {
      alert(err?.message || 'Failed to duplicate notification');
    } finally {
      setActionLoading(null);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this draft?')) return;
    try {
      setActionLoading(id);
      await api.delete(`/notifications/${id}`);
      await loadNotifications();
      if (activeItem?.id === id) setActiveItem(null);
    } catch (err: any) {
      alert(err?.message || 'Failed to delete notification');
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-tx-cream tracking-tight">Notification Campaigns</h2>
          <p className="text-xs text-tx-textMuted mt-0.5">
            Manage history, view performance metrics, and trigger broadcasts ({totalCount} total)
          </p>
        </div>

        <button
          onClick={() => onNavigate('composer')}
          className="px-4 py-2 rounded-xl bg-tx-primary hover:bg-tx-primaryHover text-white text-xs font-semibold flex items-center gap-2 transition-all shadow-md shadow-tx-primary/20 w-fit"
        >
          <PlusCircle className="w-4 h-4" />
          <span>New Campaign</span>
        </button>
      </div>

      {/* Filter and Search Bar */}
      <div className="p-4 rounded-2xl bg-tx-surface border border-tx-border flex flex-col md:flex-row md:items-center justify-between gap-4">
        {/* Status Filters */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0">
          {['ALL', 'SENT', 'SCHEDULED', 'DRAFT', 'QUEUED', 'CANCELLED'].map((st) => (
            <button
              key={st}
              onClick={() => {
                setStatusFilter(st);
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all shrink-0 ${
                statusFilter === st
                  ? 'bg-tx-primary text-white shadow-sm'
                  : 'bg-tx-card text-tx-textMuted hover:text-tx-text hover:bg-tx-cardHover'
              }`}
            >
              {st}
            </button>
          ))}
        </div>

        {/* Search */}
        <form onSubmit={handleSearchSubmit} className="flex items-center gap-2 w-full md:w-72">
          <div className="relative flex-1">
            <Search className="w-3.5 h-3.5 text-tx-textDim absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search title, body..."
              className="w-full pl-9 pr-3 py-1.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-xs placeholder-tx-textDim focus:outline-none focus:border-tx-primary transition-colors"
            />
          </div>
          <button
            type="submit"
            className="p-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-textMuted hover:text-tx-cream"
          >
            <RefreshCw className="w-3.5 h-3.5" />
          </button>
        </form>
      </div>

      {/* Table Container */}
      <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-tx-border text-tx-textDim font-medium">
                <th className="pb-3 pl-1">Campaign</th>
                <th className="pb-3">Type</th>
                <th className="pb-3">Audience</th>
                <th className="pb-3">Status</th>
                <th className="pb-3">Delivery & Opens</th>
                <th className="pb-3">Date</th>
                <th className="pb-3 text-right pr-1">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-tx-border/50">
              {loading ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-tx-textDim">
                    <Loader2 className="w-6 h-6 animate-spin mx-auto mb-2 text-tx-primary" />
                    Loading campaigns...
                  </td>
                </tr>
              ) : notifications.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-tx-textDim">
                    No campaigns found matching criteria.
                  </td>
                </tr>
              ) : (
                notifications.map((notif) => {
                  const statusColor =
                    notif.status === 'SENT'
                      ? 'bg-emerald-950/50 text-emerald-400 border-emerald-800/40'
                      : notif.status === 'SCHEDULED'
                      ? 'bg-amber-950/50 text-amber-400 border-amber-800/40'
                      : notif.status === 'QUEUED' || notif.status === 'SENDING'
                      ? 'bg-blue-950/50 text-blue-400 border-blue-800/40'
                      : notif.status === 'CANCELLED'
                      ? 'bg-zinc-900 text-zinc-500 border-zinc-700'
                      : 'bg-zinc-900 text-zinc-300 border-zinc-700';

                  const isBusy = actionLoading === notif.id;

                  return (
                    <tr
                      key={notif.id}
                      className="hover:bg-tx-card/60 transition-colors group cursor-pointer"
                      onClick={() => setActiveItem(notif)}
                    >
                      <td className="py-3.5 pl-1 max-w-[240px]">
                        <p className="font-semibold text-tx-cream truncate">{notif.title}</p>
                        <p className="text-[11px] text-tx-textDim truncate mt-0.5">{notif.body}</p>
                      </td>
                      <td className="py-3.5">
                        <span className="text-[10px] font-medium px-2 py-0.5 rounded bg-tx-card text-tx-sage border border-tx-border">
                          {notif.notificationType}
                        </span>
                      </td>
                      <td className="py-3.5 text-tx-textMuted">
                        <span className="text-xs">
                          {notif.audienceType === 'ALL_USERS'
                            ? 'All Users'
                            : notif.audienceType === 'TOPIC'
                            ? notif.audienceConfig?.topic || 'Topic'
                            : 'Segment'}
                        </span>
                      </td>
                      <td className="py-3.5">
                        <span
                          className={`text-[10px] font-semibold tracking-wider uppercase px-2 py-0.5 rounded border ${statusColor}`}
                        >
                          {notif.status}
                        </span>
                      </td>
                      <td className="py-3.5 text-tx-textMuted">
                        {notif.stats?.sent ?? 0} sent
                        <span className="text-tx-sage ml-1 font-semibold">
                          ({notif.stats?.openRate ?? 0}% opened)
                        </span>
                      </td>
                      <td className="py-3.5 text-tx-textDim">
                        {notif.scheduledAt ? (
                          <div className="flex items-center gap-1 text-amber-400">
                            <Calendar className="w-3 h-3" />
                            <span>{new Date(notif.scheduledAt).toLocaleDateString()}</span>
                          </div>
                        ) : (
                          new Date(notif.createdAt).toLocaleDateString()
                        )}
                      </td>
                      <td
                        className="py-3.5 text-right pr-1"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <div className="flex items-center justify-end gap-1.5">
                          {notif.status === 'DRAFT' && (
                            <button
                              onClick={() => handleSendNow(notif.id)}
                              disabled={isBusy}
                              title="Send Immediately"
                              className="p-1.5 rounded-lg bg-tx-card hover:bg-tx-primary hover:text-white text-tx-sage border border-tx-border transition-colors"
                            >
                              <Send className="w-3.5 h-3.5" />
                            </button>
                          )}

                          {notif.status === 'SCHEDULED' && (
                            <button
                              onClick={() => handleCancel(notif.id)}
                              disabled={isBusy}
                              title="Cancel Scheduled Send"
                              className="p-1.5 rounded-lg bg-tx-card hover:bg-rose-950/60 text-rose-400 border border-tx-border transition-colors"
                            >
                              <XCircle className="w-3.5 h-3.5" />
                            </button>
                          )}

                          <button
                            onClick={() => handleDuplicate(notif.id)}
                            disabled={isBusy}
                            title="Duplicate as Draft"
                            className="p-1.5 rounded-lg bg-tx-card hover:bg-tx-cardHover text-tx-textMuted hover:text-tx-cream border border-tx-border transition-colors"
                          >
                            <Copy className="w-3.5 h-3.5" />
                          </button>

                          {['DRAFT', 'CANCELLED'].includes(notif.status) && (
                            <button
                              onClick={() => handleDelete(notif.id)}
                              disabled={isBusy}
                              title="Delete Draft"
                              className="p-1.5 rounded-lg bg-tx-card hover:bg-rose-950/60 text-tx-textDim hover:text-rose-400 border border-tx-border transition-colors"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Bar */}
        {totalPages > 1 && (
          <div className="mt-4 pt-4 border-t border-tx-border flex items-center justify-between text-xs text-tx-textDim">
            <span>
              Page {page} of {totalPages}
            </span>
            <div className="flex gap-2">
              <button
                disabled={page <= 1}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                className="px-3 py-1.5 rounded-lg bg-tx-card border border-tx-border text-tx-cream disabled:opacity-40"
              >
                Previous
              </button>
              <button
                disabled={page >= totalPages}
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                className="px-3 py-1.5 rounded-lg bg-tx-card border border-tx-border text-tx-cream disabled:opacity-40"
              >
                Next
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Slide-in Detail Drawer */}
      {activeItem && (
        <div className="fixed inset-0 z-50 flex justify-end bg-black/60 backdrop-blur-xs">
          <div className="w-full max-w-lg bg-tx-surface border-l border-tx-border h-full p-6 overflow-y-auto space-y-6 shadow-2xl">
            <div className="flex items-center justify-between border-b border-tx-border pb-4">
              <div>
                <span className="text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded bg-tx-card border border-tx-border text-tx-sage">
                  {activeItem.notificationType}
                </span>
                <h3 className="text-base font-bold text-tx-cream mt-1.5">{activeItem.title}</h3>
              </div>
              <button
                onClick={() => setActiveItem(null)}
                className="p-1.5 rounded-lg text-tx-textDim hover:text-tx-cream bg-tx-card"
              >
                &times;
              </button>
            </div>

            {/* Message Body */}
            <div>
              <span className="text-xs text-tx-textDim block mb-1">Message Content</span>
              <p className="text-sm text-tx-textMuted bg-tx-card p-3.5 rounded-xl border border-tx-border leading-relaxed">
                {activeItem.body}
              </p>
            </div>

            {/* Image Preview */}
            {activeItem.imageUrl && (
              <div>
                <span className="text-xs text-tx-textDim block mb-1">Banner Image</span>
                <div className="rounded-xl overflow-hidden bg-black aspect-video border border-tx-border">
                  <img
                    src={activeItem.imageUrl}
                    alt="Banner"
                    className="w-full h-full object-cover"
                  />
                </div>
              </div>
            )}

            {/* Performance Stats */}
            <div className="grid grid-cols-3 gap-3">
              <div className="p-3.5 rounded-xl bg-tx-card border border-tx-border text-center">
                <span className="text-[10px] text-tx-textDim block">Total Sent</span>
                <span className="text-base font-bold text-tx-cream">
                  {activeItem.stats?.sent ?? 0}
                </span>
              </div>
              <div className="p-3.5 rounded-xl bg-tx-card border border-tx-border text-center">
                <span className="text-[10px] text-tx-textDim block">Opens</span>
                <span className="text-base font-bold text-emerald-400">
                  {activeItem.stats?.opened ?? 0}
                </span>
              </div>
              <div className="p-3.5 rounded-xl bg-tx-card border border-tx-border text-center">
                <span className="text-[10px] text-tx-textDim block">Open Rate</span>
                <span className="text-base font-bold text-tx-sage">
                  {activeItem.stats?.openRate ?? 0}%
                </span>
              </div>
            </div>

            {/* Destination & Action Details */}
            <div className="space-y-2 text-xs">
              <div className="flex justify-between py-2 border-b border-tx-border/60">
                <span className="text-tx-textDim">Destination Type:</span>
                <span className="font-semibold text-tx-cream">{activeItem.destinationType}</span>
              </div>
              {activeItem.destinationValue && (
                <div className="flex justify-between py-2 border-b border-tx-border/60">
                  <span className="text-tx-textDim">Target Value:</span>
                  <span className="font-mono text-tx-sage truncate max-w-[200px]">
                    {activeItem.destinationValue}
                  </span>
                </div>
              )}
              <div className="flex justify-between py-2 border-b border-tx-border/60">
                <span className="text-tx-textDim">Created By:</span>
                <span className="text-tx-cream">{activeItem.createdBy?.name || 'System'}</span>
              </div>
              <div className="flex justify-between py-2 border-b border-tx-border/60">
                <span className="text-tx-textDim">Created At:</span>
                <span className="text-tx-cream">
                  {new Date(activeItem.createdAt).toLocaleString()}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
