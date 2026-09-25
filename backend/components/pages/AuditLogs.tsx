'use client';

import React, { useEffect, useState } from 'react';
import { RefreshCw, History, ChevronLeft, ChevronRight } from 'lucide-react';
import { api } from '@/lib/api-client';
import { AuditLogItem, PaginatedResult } from '@/types';
import { Skeleton } from '@/components/ui/Skeleton';
import { EmptyState } from '@/components/ui/EmptyState';

export const AuditLogs: React.FC = () => {
  const [logs, setLogs] = useState<AuditLogItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);

  const loadLogs = async () => {
    try {
      setLoading(true);
      const data = await api.get<PaginatedResult<AuditLogItem>>(
        `/audit?page=${page}&limit=20`
      );
      setLogs(data.items);
      setTotalPages(data.pagination.totalPages);
    } catch (err) {
      console.error('Failed to load audit logs:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadLogs();
  }, [page]);

  return (
    <div className="space-y-6 sm:space-y-8 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-2 border-b border-tx-border/60">
        <div>
          <div className="flex items-center gap-2.5">
            <h2 className="text-xl sm:text-2xl font-bold text-tx-cream tracking-tight">
              Audit Trail & Security Logs
            </h2>
            <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-tx-card border border-tx-border text-tx-sage">
              Immutable
            </span>
          </div>
          <p className="text-xs text-tx-textMuted mt-1">
            Chronological log of administrative actions, authentication attempts, and notification broadcasts
          </p>
        </div>

        <button
          onClick={loadLogs}
          disabled={loading}
          className="px-3.5 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-textMuted hover:text-tx-cream text-xs font-semibold flex items-center gap-2 transition-all active:scale-95 shadow-card-elevated w-fit"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-tx-primary' : ''}`} />
          <span>Refresh Logs</span>
        </button>
      </div>

      {/* Logs Table */}
      <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-tx-border text-tx-textMuted font-semibold uppercase tracking-wider text-[11px]">
                <th className="pb-3.5 pl-2">Timestamp</th>
                <th className="pb-3.5">Action</th>
                <th className="pb-3.5">Resource</th>
                <th className="pb-3.5">Admin Operator</th>
                <th className="pb-3.5">Client IP</th>
                <th className="pb-3.5 text-right pr-2">Metadata Details</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-tx-border/40">
              {loading ? (
                Array.from({ length: 6 }).map((_, i) => (
                  <tr key={i}>
                    <td className="py-4 pl-2"><Skeleton className="h-4 w-32" /></td>
                    <td className="py-4"><Skeleton className="h-5 w-24" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-28" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-36" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-24" /></td>
                    <td className="py-4 pr-2 text-right"><Skeleton className="h-4 w-28 ml-auto" /></td>
                  </tr>
                ))
              ) : logs.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <EmptyState
                      icon={History}
                      title="No audit entries"
                      description="No administrative actions or events recorded in this range."
                    />
                  </td>
                </tr>
              ) : (
                logs.map((log) => {
                  return (
                    <tr key={log.id} className="hover:bg-tx-card/70 transition-colors">
                      <td className="py-4 pl-2 font-mono text-[11px] text-tx-textDim">
                        {new Date(log.createdAt).toLocaleString()}
                      </td>
                      <td className="py-4">
                        <span className="font-mono text-[11px] font-bold text-tx-sage bg-tx-card px-2 py-0.5 rounded-md border border-tx-border">
                          {log.action}
                        </span>
                      </td>
                      <td className="py-4 text-tx-cream font-medium">
                        {log.resourceType}
                        {log.resourceId && (
                          <span className="font-mono text-[10px] text-tx-textDim ml-1 truncate">
                            ({log.resourceId.slice(0, 8)}...)
                          </span>
                        )}
                      </td>
                      <td className="py-4 text-tx-textMuted">
                        <span className="font-medium text-tx-cream block">
                          {log.adminUser?.name || 'System Daemon'}
                        </span>
                        {log.adminUser && (
                          <span className="text-[10px] text-tx-textDim block font-mono">
                            {log.adminUser.email}
                          </span>
                        )}
                      </td>
                      <td className="py-4 font-mono text-[11px] text-tx-textMuted">
                        {log.ipAddress || '127.0.0.1'}
                      </td>
                      <td className="py-4 text-right pr-2 font-mono text-[10px] text-tx-textDim max-w-[200px] truncate">
                        {log.metadata ? JSON.stringify(log.metadata) : '—'}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="mt-5 pt-4 border-t border-tx-border flex items-center justify-between text-xs text-tx-textMuted">
            <span className="font-mono">
              Page {page} of {totalPages}
            </span>
            <div className="flex gap-2">
              <button
                disabled={page <= 1}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                className="px-3 py-1.5 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-cream disabled:opacity-40 flex items-center gap-1 transition-all active:scale-95"
              >
                <ChevronLeft className="w-3.5 h-3.5" />
                <span>Previous</span>
              </button>
              <button
                disabled={page >= totalPages}
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                className="px-3 py-1.5 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-cream disabled:opacity-40 flex items-center gap-1 transition-all active:scale-95"
              >
                <span>Next</span>
                <ChevronRight className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
