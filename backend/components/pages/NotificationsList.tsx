'use client';

import React, { useState, useEffect } from 'react';
import {
  Search,
  Send,
  XCircle,
  Copy,
  Trash2,
  RefreshCw,
  PlusCircle,
  X,
  BellRing,
  ChevronLeft,
  ChevronRight,
  Clock,
} from 'lucide-react';
import { api } from '@/lib/api-client';
import { NotificationItem, PaginatedResult } from '@/types';
import { Skeleton } from '../ui/Skeleton';
import { EmptyState } from '../ui/EmptyState';

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

      const data: any = await api.get(`/notifications?${params.toString()}`);
      const items = data?.data || data?.items || [];
      const pagination = data?.pagination || { total: items.length, totalPages: 1 };

      setNotifications(items);
      setTotalPages(pagination.totalPages || 1);
      setTotalCount(pagination.total || items.length);

      if (selectedId) {
        const found = items.find((n: any) => n.id === selectedId);
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
    <div className="space-y-6 sm:space-y-8 animate-fade-in">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-2 border-b border-tx-border/60">
        <div>
          <div className="flex items-center gap-2.5">
            <h2 className="text-xl sm:text-2xl font-bold text-tx-cream tracking-tight">
              Notification Campaigns
            </h2>
            <span className="text-[11px] font-mono font-bold px-2 py-0.5 rounded-full bg-tx-surface border border-tx-border text-tx-gold">
              {totalCount} Total
            </span>
          </div>
          <p className="text-xs text-tx-textMuted mt-1">
            Complete history of dispatched, scheduled, and draft notification broadcasts
          </p>
        </div>

        <button
          onClick={() => onNavigate('composer')}
          className="px-4 py-2.5 rounded-xl bg-tx-gold hover:bg-tx-goldLight text-black text-xs font-bold flex items-center gap-2 transition-all shadow-glow hover:-translate-y-0.5 active:scale-95 w-fit"
        >
          <PlusCircle className="w-4 h-4" />
          <span>New Campaign</span>
        </button>
      </div>

      {/* Filter and Search Bar */}
      <div className="p-4 rounded-2xl bg-tx-card border border-tx-border shadow-card flex flex-col md:flex-row md:items-center justify-between gap-4">
        {/* Status Filters */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0">
          {['ALL', 'SENT', 'SCHEDULED', 'DRAFT', 'QUEUED', 'CANCELLED'].map((st) => (
            <button
              key={st}
              onClick={() => {
                setStatusFilter(st);
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 active:scale-95 ${
                statusFilter === st
                  ? 'bg-tx-gold text-black shadow-glow'
                  : 'bg-tx-surface text-tx-textMuted hover:text-tx-cream hover:bg-tx-elevated border border-tx-border'
              }`}
            >
              {st}
            </button>
          ))}
        </div>

        {/* Search */}
        <form onSubmit={handleSearchSubmit} className="flex items-center gap-2 w-full md:w-80">
          <div className="relative flex-1">
            <Search className="w-3.5 h-3.5 text-tx-textSubtle absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search title, message body..."
              className="w-full pl-9 pr-3.5 py-2 rounded-xl bg-tx-surface border border-tx-border text-xs text-tx-cream placeholder-tx-textSubtle focus:outline-none focus:border-tx-gold"
            />
          </div>
          <button
            type="submit"
            className="p-2 rounded-xl bg-tx-surface hover:bg-tx-elevated border border-tx-border text-tx-textMuted hover:text-tx-cream transition-colors active:scale-95"
            title="Search"
          >
            <RefreshCw className="w-3.5 h-3.5" />
          </button>
        </form>
      </div>

      {/* Table Container */}
      <div className="rounded-2xl bg-tx-card border border-tx-border shadow-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-tx-border text-tx-textMuted font-semibold uppercase tracking-wider text-[11px] bg-tx-surface/40">
                <th className="py-3.5 pl-5">Campaign Title</th>
                <th className="py-3.5">Category</th>
                <th className="py-3.5">Destination</th>
                <th className="py-3.5">Audience</th>
                <th className="py-3.5">Status</th>
                <th className="py-3.5">Performance</th>
                <th className="py-3.5">Created Date</th>
                <th className="py-3.5 pr-5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-tx-border/40">
              {loading ? (
                Array.from({ length: 6 }).map((_, i) => (
                  <tr key={i}>
                    <td className="py-4 pl-5"><Skeleton className="h-4 w-44" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-20" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-20" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-24" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-16" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-28" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-20" /></td>
                    <td className="py-4 pr-5 text-right"><Skeleton className="h-4 w-16 ml-auto" /></td>
                  </tr>
                ))
              ) : notifications.length === 0 ? (
                <tr>
                  <td colSpan={8}>
                    <EmptyState
                      icon={BellRing}
                      title="No campaigns found"
                      description={
                        search || statusFilter !== 'ALL'
                          ? 'No notification campaigns matched your current filters. Try resetting the search or filter.'
                          : 'You haven’t created any notification campaigns yet. Create your first campaign to engage with users.'
                      }
                      action={{
                        label: 'Create Campaign',
                        onClick: () => onNavigate('composer'),
                        icon: PlusCircle,
                      }}
                    />
                  </td>
                </tr>
              ) : (
                notifications.map((notif) => {
                  const statusColor =
                    notif.status === 'SENT'
                      ? 'bg-emerald-950/70 text-emerald-300 border-emerald-700/60'
                      : notif.status === 'SCHEDULED'
                      ? 'bg-amber-950/70 text-amber-300 border-amber-700/60'
                      : notif.status === 'QUEUED' || notif.status === 'SENDING'
                      ? 'bg-sky-950/70 text-sky-300 border-sky-700/60'
                      : notif.status === 'CANCELLED'
                      ? 'bg-rose-950/70 text-rose-300 border-rose-700/60'
                      : 'bg-zinc-900 text-zinc-400 border-zinc-700';

                  return (
                    <tr
                      key={notif.id}
                      className="hover:bg-tx-surface/70 transition-colors group cursor-pointer"
                      onClick={() => setActiveItem(notif)}
                    >
                      {/* Title & Preview Body */}
                      <td className="py-4 pl-5 max-w-[240px]">
                        <div className="font-semibold text-tx-cream truncate group-hover:text-tx-gold transition-colors">
                          {notif.title}
                        </div>
                        <div className="text-[11px] text-tx-textSubtle truncate mt-0.5">
                          {notif.body}
                        </div>
                      </td>

                      {/* Type */}
                      <td className="py-4">
                        <span className="text-[11px] px-2 py-0.5 rounded-md bg-tx-surface text-tx-textMuted border border-tx-border font-medium">
                          {notif.notificationType}
                        </span>
                      </td>

                      {/* Destination */}
                      <td className="py-4 text-[11px] text-tx-textMuted">
                        <span className="font-medium text-tx-cream block">{notif.destinationType}</span>
                        {notif.destinationValue && (
                          <span className="text-[10px] text-tx-textSubtle font-mono truncate block max-w-[120px]">
                            {notif.destinationValue}
                          </span>
                        )}
                      </td>

                      {/* Audience */}
                      <td className="py-4 text-[11px] text-tx-textMuted">
                        <span className="font-medium text-tx-cream block">{notif.audienceType}</span>
                        {notif.audienceConfig?.topic && (
                          <span className="text-[10px] text-tx-gold font-mono">
                            {notif.audienceConfig.topic}
                          </span>
                        )}
                      </td>

                      {/* Status */}
                      <td className="py-4">
                        <span
                          className={`text-[10px] font-bold tracking-wider uppercase px-2.5 py-0.5 rounded-full border ${statusColor}`}
                        >
                          {notif.status}
                        </span>
                      </td>

                      {/* Performance / Stats */}
                      <td className="py-4 text-tx-textMuted font-mono text-[11px]">
                        {notif.status === 'SENT' ? (
                          <div>
                            <span className="text-tx-cream font-bold">
                              {notif.stats?.sent ?? (notif._count?.deliveries ?? 0)}
                            </span>{' '}
                            sent
                            <div className="text-[10px] text-emerald-400 font-semibold">
                              {notif.stats?.openRate ?? 0}% opened
                            </div>
                          </div>
                        ) : notif.status === 'SCHEDULED' && notif.scheduledAt ? (
                          <div className="flex items-center gap-1 text-amber-400">
                            <Clock className="w-3 h-3" />
                            <span>{new Date(notif.scheduledAt).toLocaleDateString()}</span>
                          </div>
                        ) : (
                          <span className="text-tx-textSubtle">—</span>
                        )}
                      </td>

                      {/* Date */}
                      <td className="py-4 text-tx-textSubtle font-mono text-[11px]">
                        {new Date(notif.createdAt).toLocaleDateString()}
                      </td>

                      {/* Actions */}
                      <td className="py-4 pr-5 text-right" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center justify-end gap-1">
                          {/* Send Now Button (Draft/Scheduled) */}
                          {(notif.status === 'DRAFT' || notif.status === 'SCHEDULED') && (
                            <button
                              onClick={() => handleSendNow(notif.id)}
                              disabled={actionLoading === notif.id}
                              className="p-1.5 rounded-lg text-emerald-400 hover:bg-emerald-950/40 hover:text-emerald-300 transition-colors"
                              title="Send Immediately"
                            >
                              <Send className="w-3.5 h-3.5" />
                            </button>
                          )}

                          {/* Cancel Button (Scheduled) */}
                          {notif.status === 'SCHEDULED' && (
                            <button
                              onClick={() => handleCancel(notif.id)}
                              disabled={actionLoading === notif.id}
                              className="p-1.5 rounded-lg text-amber-400 hover:bg-amber-950/40 hover:text-amber-300 transition-colors"
                              title="Cancel Scheduled Send"
                            >
                              <XCircle className="w-3.5 h-3.5" />
                            </button>
                          )}

                          {/* Duplicate */}
                          <button
                            onClick={() => handleDuplicate(notif.id)}
                            disabled={actionLoading === notif.id}
                            className="p-1.5 rounded-lg text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface transition-colors"
                            title="Duplicate Campaign"
                          >
                            <Copy className="w-3.5 h-3.5" />
                          </button>

                          {/* Delete (Drafts/Cancelled) */}
                          {(notif.status === 'DRAFT' || notif.status === 'CANCELLED') && (
                            <button
                              onClick={() => handleDelete(notif.id)}
                              disabled={actionLoading === notif.id}
                              className="p-1.5 rounded-lg text-tx-textSubtle hover:text-rose-400 hover:bg-rose-950/30 transition-colors"
                              title="Delete Draft"
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

        {/* Pagination Footer */}
        {totalPages > 1 && (
          <div className="p-4 border-t border-tx-border bg-tx-surface/40 flex items-center justify-between text-xs text-tx-textMuted">
            <span>
              Showing Page {page} of {totalPages} ({totalCount} items)
            </span>
            <div className="flex items-center gap-1.5">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page === 1}
                className="p-1.5 rounded-lg bg-tx-card hover:bg-tx-elevated border border-tx-border text-tx-cream disabled:opacity-40 transition-colors"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <button
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                disabled={page === totalPages}
                className="p-1.5 rounded-lg bg-tx-card hover:bg-tx-elevated border border-tx-border text-tx-cream disabled:opacity-40 transition-colors"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Inspect Modal */}
      {activeItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-md animate-fade-in">
          <div className="w-full max-w-lg rounded-3xl bg-tx-card border border-tx-border shadow-2xl overflow-hidden flex flex-col max-h-[90vh] animate-slide-up">
            <div className="flex items-center justify-between px-6 py-4 border-b border-tx-border bg-tx-surface/80">
              <h3 className="text-sm font-bold text-tx-cream tracking-tight">
                Campaign Inspection: {activeItem.title}
              </h3>
              <button
                onClick={() => setActiveItem(null)}
                className="p-1.5 rounded-xl text-tx-textMuted hover:text-tx-cream hover:bg-tx-surface transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="p-6 space-y-4 overflow-y-auto text-xs">
              <div className="p-4 rounded-xl bg-tx-surface border border-tx-border space-y-2">
                <p className="text-[11px] text-tx-textSubtle uppercase font-semibold">Message Body</p>
                <p className="text-tx-cream leading-relaxed">{activeItem.body}</p>
                {activeItem.imageUrl && (
                  <div className="mt-3 rounded-lg overflow-hidden border border-tx-border aspect-video bg-black/40">
                    <img src={activeItem.imageUrl} alt="Banner" className="w-full h-full object-cover" />
                  </div>
                )}
              </div>

              <div className="grid grid-cols-2 gap-3 text-[11px]">
                <div className="p-3 rounded-xl bg-tx-surface border border-tx-border">
                  <span className="text-tx-textSubtle block mb-1">Status</span>
                  <span className="font-bold text-tx-cream">{activeItem.status}</span>
                </div>
                <div className="p-3 rounded-xl bg-tx-surface border border-tx-border">
                  <span className="text-tx-textSubtle block mb-1">Category</span>
                  <span className="font-bold text-tx-cream">{activeItem.notificationType}</span>
                </div>
                <div className="p-3 rounded-xl bg-tx-surface border border-tx-border">
                  <span className="text-tx-textSubtle block mb-1">Destination</span>
                  <span className="font-bold text-tx-cream">{activeItem.destinationType}</span>
                  {activeItem.destinationValue && (
                    <span className="text-[10px] text-tx-gold font-mono block truncate mt-0.5">
                      {activeItem.destinationValue}
                    </span>
                  )}
                </div>
                <div className="p-3 rounded-xl bg-tx-surface border border-tx-border">
                  <span className="text-tx-textSubtle block mb-1">Audience</span>
                  <span className="font-bold text-tx-cream">{activeItem.audienceType}</span>
                </div>
              </div>
            </div>

            <div className="flex items-center justify-end px-6 py-4 border-t border-tx-border bg-tx-surface/60">
              <button
                onClick={() => setActiveItem(null)}
                className="px-4 py-2 rounded-xl bg-tx-surface hover:bg-tx-elevated border border-tx-border text-tx-cream text-xs font-semibold"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
