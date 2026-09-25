import React, { useEffect, useState } from 'react';
import { Search, CheckCircle2, XCircle, HelpCircle, Loader2 } from 'lucide-react';
import { api } from '../lib/api.js';
import { DeviceItem, PaginatedResult } from '../types/index.js';

export const Devices: React.FC = () => {
  const [devices, setDevices] = useState<DeviceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [permissionFilter, setPermissionFilter] = useState('ALL');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  const [selectedDevice, setSelectedDevice] = useState<DeviceItem | null>(null);

  const loadDevices = async () => {
    try {
      setLoading(true);
      const params = new URLSearchParams();
      if (search) params.set('search', search);
      if (permissionFilter !== 'ALL') params.set('permission', permissionFilter);
      params.set('page', String(page));
      params.set('limit', '15');

      const data = await api.get<PaginatedResult<DeviceItem>>(`/admin/devices?${params.toString()}`);
      setDevices(data.items);
      setTotalPages(data.pagination.totalPages);
      setTotalCount(data.pagination.total);
    } catch (err) {
      console.error('Failed to load devices:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDevices();
  }, [permissionFilter, page]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    loadDevices();
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-tx-cream tracking-tight">Device Registry</h2>
          <p className="text-xs text-tx-textMuted mt-0.5">
            Active client installations with token health and topic bindings ({totalCount} devices)
          </p>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="p-4 rounded-2xl bg-tx-surface border border-tx-border flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0">
          {['ALL', 'granted', 'denied', 'unknown'].map((p) => (
            <button
              key={p}
              onClick={() => {
                setPermissionFilter(p);
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all shrink-0 capitalize ${
                permissionFilter === p
                  ? 'bg-tx-primary text-white shadow-sm'
                  : 'bg-tx-card text-tx-textMuted hover:text-tx-text hover:bg-tx-cardHover'
              }`}
            >
              {p === 'ALL' ? 'All Permissions' : p}
            </button>
          ))}
        </div>

        <form onSubmit={handleSearch} className="flex items-center gap-2 w-full md:w-80">
          <div className="relative flex-1">
            <Search className="w-3.5 h-3.5 text-tx-textDim absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search installation ID, model..."
              className="w-full pl-9 pr-3 py-1.5 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-xs placeholder-tx-textDim focus:outline-none focus:border-tx-primary transition-colors"
            />
          </div>
          <button
            type="submit"
            className="px-3 py-1.5 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-cream text-xs font-medium"
          >
            Filter
          </button>
        </form>
      </div>

      {/* Device Table */}
      <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-tx-border text-tx-textDim font-medium">
                <th className="pb-3 pl-1">Device Model</th>
                <th className="pb-3">Installation ID</th>
                <th className="pb-3">Android OS</th>
                <th className="pb-3">App Version</th>
                <th className="pb-3">Push Opt-in</th>
                <th className="pb-3">Subscribed Topics</th>
                <th className="pb-3 text-right pr-1">Last Seen</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-tx-border/50">
              {loading ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-tx-textDim">
                    <Loader2 className="w-6 h-6 animate-spin mx-auto mb-2 text-tx-primary" />
                    Loading registered devices...
                  </td>
                </tr>
              ) : devices.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-tx-textDim">
                    No devices found matching criteria.
                  </td>
                </tr>
              ) : (
                devices.map((device) => {
                  return (
                    <tr
                      key={device.id}
                      onClick={() => setSelectedDevice(device)}
                      className="hover:bg-tx-card/60 transition-colors cursor-pointer group"
                    >
                      <td className="py-3.5 pl-1 font-semibold text-tx-cream">
                        {device.deviceModel || 'Unknown Device'}
                      </td>
                      <td className="py-3.5 font-mono text-[11px] text-tx-textDim max-w-[140px] truncate">
                        {device.installationId}
                      </td>
                      <td className="py-3.5 text-tx-textMuted">{device.androidVersion}</td>
                      <td className="py-3.5 font-mono text-tx-sage">{device.appVersion}</td>
                      <td className="py-3.5">
                        {device.notificationPermission === 'granted' ? (
                          <span className="inline-flex items-center gap-1 text-[11px] font-medium text-emerald-400">
                            <CheckCircle2 className="w-3.5 h-3.5" />
                            <span>Granted</span>
                          </span>
                        ) : device.notificationPermission === 'denied' ? (
                          <span className="inline-flex items-center gap-1 text-[11px] font-medium text-rose-400">
                            <XCircle className="w-3.5 h-3.5" />
                            <span>Denied</span>
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 text-[11px] font-medium text-amber-400">
                            <HelpCircle className="w-3.5 h-3.5" />
                            <span>Pending</span>
                          </span>
                        )}
                      </td>
                      <td className="py-3.5 text-tx-textDim max-w-[160px] truncate">
                        {device.topics.length > 0 ? device.topics.join(', ') : 'none'}
                      </td>
                      <td className="py-3.5 text-right pr-1 text-tx-textDim">
                        {new Date(device.lastSeenAt).toLocaleString()}
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

      {/* Inspect Drawer */}
      {selectedDevice && (
        <div className="fixed inset-0 z-50 flex justify-end bg-black/60 backdrop-blur-xs">
          <div className="w-full max-w-lg bg-tx-surface border-l border-tx-border h-full p-6 overflow-y-auto space-y-6 shadow-2xl">
            <div className="flex items-center justify-between border-b border-tx-border pb-4">
              <div>
                <span className="text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded bg-tx-card border border-tx-border text-tx-sage">
                  {selectedDevice.platform}
                </span>
                <h3 className="text-base font-bold text-tx-cream mt-1.5">
                  {selectedDevice.deviceModel}
                </h3>
              </div>
              <button
                onClick={() => setSelectedDevice(null)}
                className="p-1.5 rounded-lg text-tx-textDim hover:text-tx-cream bg-tx-card"
              >
                &times;
              </button>
            </div>

            <div className="space-y-3 text-xs">
              <div className="flex justify-between py-2 border-b border-tx-border/60">
                <span className="text-tx-textDim">Installation ID:</span>
                <span className="font-mono text-tx-cream select-all">{selectedDevice.installationId}</span>
              </div>
              <div className="flex justify-between py-2 border-b border-tx-border/60">
                <span className="text-tx-textDim">Android OS:</span>
                <span className="text-tx-cream">{selectedDevice.androidVersion}</span>
              </div>
              <div className="flex justify-between py-2 border-b border-tx-border/60">
                <span className="text-tx-textDim">App Version:</span>
                <span className="font-mono text-tx-sage">{selectedDevice.appVersion} (build {selectedDevice.buildNumber})</span>
              </div>
              <div className="flex justify-between py-2 border-b border-tx-border/60">
                <span className="text-tx-textDim">Permission Status:</span>
                <span className="capitalize font-semibold text-tx-cream">{selectedDevice.notificationPermission}</span>
              </div>
              <div className="flex justify-between py-2 border-b border-tx-border/60">
                <span className="text-tx-textDim">First Registered:</span>
                <span className="text-tx-cream">{new Date(selectedDevice.createdAt).toLocaleString()}</span>
              </div>
              <div className="flex justify-between py-2 border-b border-tx-border/60">
                <span className="text-tx-textDim">Last Heartbeat Seen:</span>
                <span className="text-tx-cream">{new Date(selectedDevice.lastSeenAt).toLocaleString()}</span>
              </div>
            </div>

            {/* Subscribed Topics */}
            <div>
              <span className="text-xs font-semibold text-tx-cream block mb-2">Subscribed Topics</span>
              <div className="flex flex-wrap gap-2">
                {selectedDevice.topics.length === 0 ? (
                  <span className="text-xs text-tx-textDim">No topic subscriptions</span>
                ) : (
                  selectedDevice.topics.map((t) => (
                    <span key={t} className="px-2.5 py-1 rounded-lg bg-tx-card border border-tx-border text-xs text-tx-sage font-mono">
                      #{t}
                    </span>
                  ))
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
