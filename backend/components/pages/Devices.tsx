'use client';

import React, { useEffect, useState } from 'react';
import {
  Search,
  CheckCircle2,
  XCircle,
  HelpCircle,
  Download,
  Send,
  ShieldCheck,
  RefreshCw,
  Smartphone,
  Copy,
  Check,
  X,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';
import { api } from '@/lib/api-client';
import { DeviceItem, PaginatedResult } from '@/types';
import { TestPushModal } from '@/components/TestPushModal';
import { Skeleton } from '@/components/ui/Skeleton';
import { EmptyState } from '@/components/ui/EmptyState';

export const Devices: React.FC = () => {
  const [devices, setDevices] = useState<DeviceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [permissionFilter, setPermissionFilter] = useState('ALL');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  const [selectedDevice, setSelectedDevice] = useState<DeviceItem | null>(null);
  const [testPushToken, setTestPushToken] = useState<string>('');
  const [showTestModal, setShowTestModal] = useState(false);
  const [copiedToken, setCopiedToken] = useState(false);

  const loadDevices = async () => {
    try {
      setLoading(true);
      const params = new URLSearchParams();
      if (search) params.set('search', search);
      if (permissionFilter !== 'ALL') params.set('permission', permissionFilter);
      params.set('page', String(page));
      params.set('limit', '15');

      const data = await api.get<PaginatedResult<DeviceItem>>(`/devices?${params.toString()}`);
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

  const exportToCsv = () => {
    if (devices.length === 0) return;
    const headers = [
      'Installation ID',
      'Model',
      'Platform',
      'Android OS',
      'App Version',
      'Build',
      'Permission',
      'Last Seen',
      'FCM Token',
    ];
    const rows = devices.map((d) => [
      d.installationId,
      `"${d.deviceModel.replace(/"/g, '""')}"`,
      d.platform,
      `"${d.androidVersion.replace(/"/g, '""')}"`,
      d.appVersion,
      d.buildNumber,
      d.notificationPermission,
      d.lastSeenAt,
      `"${d.fcmToken}"`,
    ]);
    const csvContent =
      'data:text/csv;charset=utf-8,' +
      [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `tx_devices_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleOpenTestPush = (fcmToken: string, e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    setTestPushToken(fcmToken);
    setShowTestModal(true);
  };

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopiedToken(true);
      setTimeout(() => setCopiedToken(false), 2000);
    } catch {
      // ignore
    }
  };

  return (
    <div className="space-y-6 sm:space-y-8 animate-fade-in">
      {/* Header & Export Actions */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-2 border-b border-tx-border/60">
        <div>
          <div className="flex items-center gap-2.5">
            <h2 className="text-xl sm:text-2xl font-bold text-tx-cream tracking-tight">
              Device Fleet Registry
            </h2>
            <span className="text-[11px] font-mono font-bold px-2 py-0.5 rounded-full bg-tx-card border border-tx-border text-tx-sage">
              {totalCount} Active
            </span>
          </div>
          <p className="text-xs text-tx-textMuted mt-1">
            Real-time client installations, notification token status & topic bindings
          </p>
        </div>

        <div className="flex items-center gap-2.5 self-start sm:self-auto flex-wrap">
          <button
            onClick={() => handleOpenTestPush('')}
            className="px-3.5 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-borderLight/80 text-tx-cream text-xs font-semibold flex items-center gap-2 transition-all shadow-card-elevated hover:-translate-y-0.5 active:scale-95"
          >
            <Send className="w-3.5 h-3.5 text-tx-primary" />
            <span>Test Push</span>
          </button>

          <button
            onClick={exportToCsv}
            disabled={devices.length === 0}
            className="px-3.5 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-textMuted hover:text-tx-cream disabled:opacity-40 text-xs font-semibold flex items-center gap-2 transition-all active:scale-95 shadow-sm"
          >
            <Download className="w-3.5 h-3.5 text-tx-sage" />
            <span>Export CSV</span>
          </button>

          <button
            onClick={loadDevices}
            disabled={loading}
            className="px-3 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-textMuted hover:text-tx-cream text-xs font-medium flex items-center gap-1.5 transition-all active:scale-95"
            title="Refresh fleet"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-tx-primary' : ''}`} />
            <span className="hidden sm:inline">Refresh</span>
          </button>
        </div>
      </div>

      {/* Privacy Notice Banner */}
      <div className="p-4 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated flex items-start sm:items-center gap-3 text-xs text-tx-textMuted">
        <div className="w-8 h-8 rounded-xl bg-emerald-950/80 border border-emerald-700/50 flex items-center justify-center text-emerald-400 shrink-0">
          <ShieldCheck className="w-4 h-4" />
        </div>
        <p className="flex-1 leading-relaxed">
          <strong className="text-tx-cream font-semibold">Privacy-Preserving Telemetry:</strong> Devices communicate anonymously via local Drift hardware UUIDs. No email, Google Play credentials, or personally identifiable data is stored.
        </p>
      </div>

      {/* Filter and Search Bar */}
      <div className="p-4 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0">
          {['ALL', 'granted', 'denied', 'unknown'].map((p) => (
            <button
              key={p}
              onClick={() => {
                setPermissionFilter(p);
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 active:scale-95 capitalize ${
                permissionFilter === p
                  ? 'bg-tx-primary text-white shadow-glow-subtle'
                  : 'bg-tx-surfaceInset/60 text-tx-textMuted hover:text-tx-cream hover:bg-tx-card border border-tx-border/60'
              }`}
            >
              {p === 'ALL' ? 'All Permissions' : p}
            </button>
          ))}
        </div>

        <form onSubmit={handleSearch} className="flex items-center gap-2 w-full md:w-80">
          <div className="relative flex-1">
            <Search className="w-3.5 h-3.5 text-tx-textDim absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search installation ID, model..."
              className="w-full pl-9 pr-3.5 py-2 rounded-xl saas-input text-xs placeholder-tx-textDim font-mono"
            />
          </div>
          <button
            type="submit"
            className="px-3.5 py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-cream text-xs font-semibold transition-all active:scale-95"
          >
            Filter
          </button>
        </form>
      </div>

      {/* Device Table */}
      <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-tx-border text-tx-textMuted font-semibold uppercase tracking-wider text-[11px]">
                <th className="pb-3.5 pl-2">Device Hardware</th>
                <th className="pb-3.5">OS & App Version</th>
                <th className="pb-3.5">Notification Perm</th>
                <th className="pb-3.5">Topic Bindings</th>
                <th className="pb-3.5 text-right">Last Heartbeat</th>
                <th className="pb-3.5 text-right pr-2">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-tx-border/40">
              {loading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <tr key={i}>
                    <td className="py-4 pl-2"><Skeleton className="h-5 w-40 mb-1" /><Skeleton className="h-3 w-28" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-28" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-20" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-32" /></td>
                    <td className="py-4 text-right"><Skeleton className="h-4 w-24 ml-auto" /></td>
                    <td className="py-4 pr-2 text-right"><Skeleton className="h-7 w-9 ml-auto" /></td>
                  </tr>
                ))
              ) : devices.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <EmptyState
                      icon={Smartphone}
                      title="No devices found"
                      description={
                        search
                          ? `No devices matched query "${search}". Try clearing search filter.`
                          : "No active devices registered in this category. Open TX Browser on Android to automatically connect."
                      }
                    />
                  </td>
                </tr>
              ) : (
                devices.map((device) => {
                  return (
                    <tr
                      key={device.id}
                      onClick={() => setSelectedDevice(device)}
                      className="hover:bg-tx-card/70 transition-colors cursor-pointer group"
                    >
                      <td className="py-4 pl-2">
                        <div className="font-semibold text-tx-cream group-hover:text-tx-sage transition-colors">
                          {device.deviceModel}
                        </div>
                        <div className="text-[11px] text-tx-textDim font-mono truncate max-w-[180px]">
                          {device.installationId}
                        </div>
                      </td>
                      <td className="py-4">
                        <div className="text-tx-cream font-medium">{device.androidVersion}</div>
                        <div className="text-[11px] text-tx-sage font-mono">
                          v{device.appVersion} (build {device.buildNumber})
                        </div>
                      </td>
                      <td className="py-4">
                        {device.notificationPermission === 'granted' ? (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-950/70 text-emerald-300 border border-emerald-700/60 text-[11px] font-semibold">
                            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
                            <span>Granted</span>
                          </span>
                        ) : device.notificationPermission === 'denied' ? (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-rose-950/70 text-rose-300 border border-rose-700/60 text-[11px] font-semibold">
                            <XCircle className="w-3.5 h-3.5 text-rose-400" />
                            <span>Denied</span>
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-amber-950/70 text-amber-300 border border-amber-700/60 text-[11px] font-semibold">
                            <HelpCircle className="w-3.5 h-3.5 text-amber-400" />
                            <span>Pending</span>
                          </span>
                        )}
                      </td>
                      <td className="py-4 text-tx-textMuted max-w-[180px] truncate">
                        {device.topics && device.topics.length > 0 ? (
                          <span className="font-mono text-[11px] text-tx-sage bg-tx-card px-2 py-0.5 rounded-md border border-tx-border">
                            {device.topics.join(', ')}
                          </span>
                        ) : (
                          <span className="text-[11px] text-tx-textDim">None</span>
                        )}
                      </td>
                      <td className="py-4 text-right text-tx-textDim font-mono">
                        <div>{new Date(device.lastSeenAt).toLocaleDateString()}</div>
                        <div className="text-[10px] text-tx-textDim">
                          {new Date(device.lastSeenAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </div>
                      </td>
                      <td className="py-4 text-right pr-2">
                        <button
                          onClick={(e) => handleOpenTestPush(device.fcmToken, e)}
                          title="Send test push to this device"
                          className="p-1.5 rounded-xl bg-tx-card hover:bg-tx-primary hover:text-white text-tx-sage border border-tx-border transition-all active:scale-95 shadow-sm"
                        >
                          <Send className="w-3.5 h-3.5" />
                        </button>
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
              Page {page} of {totalPages} ({totalCount} devices)
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

      {/* Inspect Drawer */}
      {selectedDevice && (
        <div className="fixed inset-0 z-50 flex justify-end bg-black/75 backdrop-blur-sm animate-fade-in">
          <div className="w-full max-w-lg bg-tx-surface border-l border-tx-borderLight/80 h-full p-6 overflow-y-auto space-y-6 shadow-2xl animate-slide-up flex flex-col justify-between">
            <div className="space-y-6">
              <div className="flex items-center justify-between border-b border-tx-border pb-4">
                <div>
                  <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-tx-card border border-tx-border text-tx-sage">
                    {selectedDevice.platform}
                  </span>
                  <h3 className="text-base font-bold text-tx-cream tracking-tight mt-1.5">
                    {selectedDevice.deviceModel}
                  </h3>
                </div>
                <button
                  onClick={() => setSelectedDevice(null)}
                  className="p-2 rounded-xl text-tx-textMuted hover:text-tx-cream bg-tx-card border border-tx-border transition-colors active:scale-95"
                  aria-label="Close"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>

              {/* Hardware & Identity */}
              <div className="p-4 rounded-xl bg-tx-surfaceInset border border-tx-border space-y-2.5 text-xs">
                <div className="flex justify-between">
                  <span className="text-tx-textMuted">Installation UUID:</span>
                  <span className="font-mono text-tx-cream select-all">{selectedDevice.installationId}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-tx-textMuted">Android OS:</span>
                  <span className="text-tx-cream font-medium">{selectedDevice.androidVersion}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-tx-textMuted">App Version:</span>
                  <span className="font-mono text-tx-sage font-bold">
                    v{selectedDevice.appVersion} (build {selectedDevice.buildNumber})
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-tx-textMuted">Permission Status:</span>
                  <span className="capitalize font-semibold text-emerald-400">
                    {selectedDevice.notificationPermission}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-tx-textMuted">First Registered:</span>
                  <span className="text-tx-cream font-mono text-[11px]">
                    {new Date(selectedDevice.createdAt).toLocaleString()}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-tx-textMuted">Last Seen:</span>
                  <span className="text-tx-cream font-mono text-[11px]">
                    {new Date(selectedDevice.lastSeenAt).toLocaleString()}
                  </span>
                </div>
              </div>

              {/* Subscribed Topics */}
              <div>
                <span className="text-xs font-semibold text-tx-textMuted block mb-2">
                  Subscribed Topics
                </span>
                <div className="flex flex-wrap gap-2">
                  {!selectedDevice.topics || selectedDevice.topics.length === 0 ? (
                    <span className="text-xs text-tx-textDim">No topic subscriptions</span>
                  ) : (
                    selectedDevice.topics.map((t) => (
                      <span
                        key={t}
                        className="px-2.5 py-1 rounded-lg bg-tx-card border border-tx-border text-xs text-tx-sage font-mono"
                      >
                        #{t}
                      </span>
                    ))
                  )}
                </div>
              </div>

              {/* Raw FCM Registration Token */}
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-xs font-semibold text-tx-textMuted">
                    FCM Registration Token
                  </span>
                  <button
                    onClick={() => copyToClipboard(selectedDevice.fcmToken)}
                    className="flex items-center gap-1 text-[11px] text-tx-sage hover:text-tx-cream transition-colors font-medium"
                  >
                    {copiedToken ? (
                      <>
                        <Check className="w-3.5 h-3.5 text-emerald-400" />
                        <span className="text-emerald-400">Copied!</span>
                      </>
                    ) : (
                      <>
                        <Copy className="w-3.5 h-3.5" />
                        <span>Copy Token</span>
                      </>
                    )}
                  </button>
                </div>
                <div className="p-3 rounded-xl bg-tx-surfaceInset border border-tx-border font-mono text-[11px] text-tx-textMuted break-all select-all max-h-28 overflow-y-auto">
                  {selectedDevice.fcmToken}
                </div>
              </div>
            </div>

            {/* Direct Push Action */}
            <div className="pt-4 border-t border-tx-border space-y-2">
              <button
                onClick={() => handleOpenTestPush(selectedDevice.fcmToken)}
                className="w-full py-2.5 rounded-xl bg-tx-primary hover:bg-tx-primaryHover text-white text-xs font-bold flex items-center justify-center gap-2 shadow-glow-primary transition-all active:scale-95"
              >
                <Send className="w-3.5 h-3.5" />
                <span>Send Direct Test Push to This Device</span>
              </button>
              <button
                onClick={() => setSelectedDevice(null)}
                className="w-full py-2 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-cream text-xs font-medium transition-colors"
              >
                Close Drawer
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Test Push Modal */}
      <TestPushModal
        isOpen={showTestModal}
        defaultToken={testPushToken}
        onClose={() => setShowTestModal(false)}
      />
    </div>
  );
};
