'use client';

import React, { useEffect, useState } from 'react';
import { PlusCircle, CheckCircle2, XCircle, Trash2, Loader2, UserCog, X } from 'lucide-react';
import { api } from '@/lib/api-client';
import { AdminUser, AdminRole } from '@/types';
import { useAuth } from '@/context/AuthContext';
import { Skeleton } from '@/components/ui/Skeleton';
import { EmptyState } from '@/components/ui/EmptyState';

export const AdminUsers: React.FC = () => {
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateModal, setShowCreateModal] = useState(false);

  // Create form state
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<AdminRole>('ADMIN');
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadUsers = async () => {
    try {
      setLoading(true);
      const data = await api.get<AdminUser[]>('/admins');
      setUsers(data);
    } catch (err) {
      console.error('Failed to load admin users:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadUsers();
  }, []);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    try {
      setCreating(true);
      await api.post('/admins', { name, email, password, role });
      setShowCreateModal(false);
      setName('');
      setEmail('');
      setPassword('');
      await loadUsers();
    } catch (err: any) {
      setError(err?.message || 'Failed to create admin user');
    } finally {
      setCreating(false);
    }
  };

  const handleToggleActive = async (user: AdminUser) => {
    if (user.id === currentUser?.id) {
      alert('You cannot deactivate your own account.');
      return;
    }
    try {
      await api.patch(`/admins/${user.id}`, { isActive: !user.isActive });
      await loadUsers();
    } catch (err: any) {
      alert(err?.message || 'Failed to update user status');
    }
  };

  const handleDelete = async (user: AdminUser) => {
    if (user.id === currentUser?.id) {
      alert('You cannot delete your own account.');
      return;
    }
    if (!confirm(`Are you sure you want to delete admin account for ${user.email}?`)) return;
    try {
      await api.delete(`/admins/${user.id}`);
      await loadUsers();
    } catch (err: any) {
      alert(err?.message || 'Failed to delete user');
    }
  };

  return (
    <div className="space-y-6 sm:space-y-8 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-2 border-b border-tx-border/60">
        <div>
          <div className="flex items-center gap-2.5">
            <h2 className="text-xl sm:text-2xl font-bold text-tx-cream tracking-tight">
              Admin User Management
            </h2>
            <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-tx-card border border-tx-border text-tx-sage">
              RBAC
            </span>
          </div>
          <p className="text-xs text-tx-textMuted mt-1">
            Role-Based Access Control with Argon2id cryptographic hashing
          </p>
        </div>

        <button
          onClick={() => setShowCreateModal(true)}
          className="px-4 py-2.5 rounded-xl bg-tx-primary hover:bg-tx-primaryHover text-white text-xs font-bold flex items-center gap-2 transition-all shadow-glow-primary hover:-translate-y-0.5 active:scale-95 w-fit"
        >
          <PlusCircle className="w-4 h-4" />
          <span>New Admin User</span>
        </button>
      </div>

      {/* Users Table */}
      <div className="p-5 sm:p-6 rounded-2xl bg-tx-surface border border-tx-border shadow-card-elevated overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-tx-border text-tx-textMuted font-semibold uppercase tracking-wider text-[11px]">
                <th className="pb-3.5 pl-2">Name</th>
                <th className="pb-3.5">Email</th>
                <th className="pb-3.5">Assigned Role</th>
                <th className="pb-3.5">Account Status</th>
                <th className="pb-3.5">Last Login</th>
                <th className="pb-3.5 text-right pr-2">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-tx-border/40">
              {loading ? (
                Array.from({ length: 3 }).map((_, i) => (
                  <tr key={i}>
                    <td className="py-4 pl-2"><Skeleton className="h-5 w-32" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-40" /></td>
                    <td className="py-4"><Skeleton className="h-5 w-20" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-16" /></td>
                    <td className="py-4"><Skeleton className="h-4 w-28" /></td>
                    <td className="py-4 pr-2 text-right"><Skeleton className="h-6 w-24 ml-auto" /></td>
                  </tr>
                ))
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <EmptyState
                      icon={UserCog}
                      title="No admin users found"
                      description="Click below to add your first administrator."
                      action={{
                        label: 'New Admin User',
                        onClick: () => setShowCreateModal(true),
                        icon: PlusCircle,
                      }}
                    />
                  </td>
                </tr>
              ) : (
                users.map((u) => (
                  <tr key={u.id} className="hover:bg-tx-card/70 transition-colors">
                    <td className="py-4 pl-2 font-semibold text-tx-cream">
                      {u.name} {u.id === currentUser?.id && (
                        <span className="text-[10px] text-tx-sage font-mono ml-1 font-bold">(You)</span>
                      )}
                    </td>
                    <td className="py-4 text-tx-textMuted font-mono text-xs">{u.email}</td>
                    <td className="py-4">
                      <span
                        className={`text-[10px] font-bold tracking-wider uppercase px-2.5 py-0.5 rounded-full border ${
                          u.role === 'SUPER_ADMIN'
                            ? 'bg-amber-950/70 text-amber-300 border-amber-700/60'
                            : u.role === 'ADMIN'
                            ? 'bg-emerald-950/70 text-emerald-300 border-emerald-700/60'
                            : 'bg-sky-950/70 text-sky-300 border-sky-700/60'
                        }`}
                      >
                        {u.role.replace('_', ' ')}
                      </span>
                    </td>
                    <td className="py-4">
                      {u.isActive ? (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-950/60 text-emerald-300 border border-emerald-700/50 text-[11px] font-semibold">
                          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
                          <span>Active</span>
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-rose-950/60 text-rose-300 border border-rose-700/50 text-[11px] font-semibold">
                          <XCircle className="w-3.5 h-3.5 text-rose-400" />
                          <span>Deactivated</span>
                        </span>
                      )}
                    </td>
                    <td className="py-4 text-tx-textDim font-mono">
                      {u.lastLoginAt ? new Date(u.lastLoginAt).toLocaleString() : 'Never'}
                    </td>
                    <td className="py-4 text-right pr-2">
                      {u.id !== currentUser?.id && (
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => handleToggleActive(u)}
                            className="text-xs text-tx-textMuted hover:text-tx-cream px-2.5 py-1 rounded-lg bg-tx-card hover:bg-tx-cardHover border border-tx-border transition-colors font-medium active:scale-95"
                          >
                            {u.isActive ? 'Deactivate' : 'Activate'}
                          </button>
                          <button
                            onClick={() => handleDelete(u)}
                            title="Delete Admin"
                            className="p-1.5 rounded-lg bg-tx-card hover:bg-rose-950/60 text-tx-textDim hover:text-rose-400 border border-tx-border transition-colors active:scale-95"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Create Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-md animate-fade-in">
          <div className="w-full max-w-md bg-tx-surface border border-tx-borderLight rounded-2xl p-6 shadow-2xl space-y-4 animate-slide-up">
            <div className="flex items-center justify-between border-b border-tx-border pb-3">
              <h3 className="text-base font-bold text-tx-cream tracking-tight">Create Admin User</h3>
              <button
                onClick={() => setShowCreateModal(false)}
                className="p-1.5 rounded-lg text-tx-textMuted hover:text-tx-cream bg-tx-card"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {error && (
              <p className="p-3.5 rounded-xl bg-rose-950/40 border border-rose-800/50 text-rose-300 text-xs font-medium">
                {error}
              </p>
            )}

            <form onSubmit={handleCreate} className="space-y-4 text-xs">
              <div>
                <label className="block text-tx-textMuted mb-1.5 font-semibold">Full Name</label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. Sarah Jenkins"
                  className="w-full px-3.5 py-2.5 rounded-xl saas-input text-xs"
                />
              </div>

              <div>
                <label className="block text-tx-textMuted mb-1.5 font-semibold">Email Address</label>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="sarah@txbrowser.com"
                  className="w-full px-3.5 py-2.5 rounded-xl saas-input text-xs font-mono"
                />
              </div>

              <div>
                <label className="block text-tx-textMuted mb-1.5 font-semibold">Password (Min 8 chars)</label>
                <input
                  type="password"
                  required
                  minLength={8}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••••"
                  className="w-full px-3.5 py-2.5 rounded-xl saas-input text-xs font-mono"
                />
              </div>

              <div>
                <label className="block text-tx-textMuted mb-1.5 font-semibold">Role</label>
                <select
                  value={role}
                  onChange={(e) => setRole(e.target.value as AdminRole)}
                  className="w-full px-3.5 py-2.5 rounded-xl saas-input text-xs font-medium"
                >
                  <option value="ADMIN">ADMIN (Full campaign & device permissions)</option>
                  <option value="EDITOR">EDITOR (Draft and create campaigns only)</option>
                  <option value="SUPER_ADMIN">SUPER_ADMIN (All permissions + user management)</option>
                </select>
              </div>

              <div className="flex justify-end gap-2.5 pt-3 border-t border-tx-border">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  disabled={creating}
                  className="px-4 py-2.5 rounded-xl bg-tx-card hover:bg-tx-cardHover border border-tx-border text-tx-cream text-xs font-semibold transition-colors active:scale-95"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={creating}
                  className="px-4 py-2.5 rounded-xl bg-tx-primary hover:bg-tx-primaryHover text-white text-xs font-bold flex items-center gap-2 shadow-glow-primary transition-all active:scale-95"
                >
                  {creating && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
                  <span>Create Account</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
