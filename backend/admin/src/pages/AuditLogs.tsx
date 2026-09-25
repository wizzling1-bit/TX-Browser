import React, { useEffect, useState } from 'react';
import { History, Shield, Search, RefreshCw, Loader2 } from 'lucide-react';
import { api } from '../lib/api.js';
import { AuditLogItem, PaginatedResult } from '../types/index.js';

export const AuditLogs: React.FC = () => {
  const [logs, setLogs] = useState<AuditLogItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  const loadLogs = async () => {
    try {
      setLoading(true);
      const data = await api.get<PaginatedResult<AuditLogItem>>(
        `/admin/audit-logs?page=${page}&limit=20`
      );
      setLogs(data.items);
      setTotalPages(data.pagination.totalPages);
      setTotalCount(data.pagination.total);
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
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-tx-cream tracking-tight">Audit Trail & Security Logs</h2>
          <p className="text-xs text-tx-textMuted mt-0.5">
            Immutable log of administrative operations, logins, campaign dispatches, and modifications
          </p>
        </div>

        <button
          onClick={loadLogs}
          disabled={loading}
          className="px-3 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-textMuted hover:text-tx-cream text-xs font-medium flex items-center gap-2 transition-colors w-fit"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          <span>Refresh Logs</span>
        </button>
      </div>

      {/* Logs Table */}
      <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-tx-border text-tx-textDim font-medium">
                <th className="pb-3 pl-1">Timestamp</th>
                <th className="pb-3">Action</th>
                <th className="pb-3">Resource</th>
                <th className="pb-3">Admin User</th>
                <th className="pb-3">IP Address</th>
                <th className="pb-3 text-right pr-1">Metadata</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-tx-border/50">
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-tx-textDim">
                    <Loader2 className="w-6 h-6 animate-spin mx-auto mb-2 text-tx-primary" />
                    Loading audit trail...
                  </td>
                </tr>
              ) : logs.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-tx-textDim">
                    No audit records found.
                  </td>
                </tr>
              ) : (
                logs.map((log) => {
                  return (
                    <tr key={log.id} className="hover:bg-tx-card/60 transition-colors">
                      <td className="py-3 pl-1 font-mono text-[11px] text-tx-textDim">
                        {new Date(log.createdAt).toLocaleString()}
                      </td>
                      <td className="py-3">
                        <span className="font-mono text-xs font-bold text-tx-sage">
                          {log.action}
                        </span>
                      </td>
                      <td className="py-3 text-tx-cream font-medium">
                        {log.resourceType}
                        {log.resourceId && (
                          <span className="font-mono text-[10px] text-tx-textDim ml-1 truncate">
                            ({log.resourceId.slice(0, 8)}...)
                          </span>
                        )}
                      </td>
                      <td className="py-3 text-tx-textMuted">
                        {log.adminUser?.name || 'System / Unauth'}
                        {log.adminUser && (
                          <span className="text-[10px] text-tx-textDim block">
                            {log.adminUser.email}
                          </span>
                        )}
                      </td>
                      <td className="py-3 font-mono text-[11px] text-tx-textDim">
                        {log.ipAddress || '—'}
                      </td>
                      <td className="py-3 text-right pr-1 font-mono text-[10px] text-tx-textDim max-w-[200px] truncate">
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
    </div>
  );
};
