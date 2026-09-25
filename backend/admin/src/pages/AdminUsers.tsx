import React, { useEffect, useState } from 'react';
import { UserCog, PlusCircle, Shield, CheckCircle2, XCircle, Trash2, Loader2 } from 'lucide-react';
import { api } from '../lib/api.js';
import { AdminUser, AdminRole } from '../types/index.js';
import { useAuth } from '../context/AuthContext.js';

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
      const data = await api.get<AdminUser[]>('/admin/users');
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
      await api.post('/admin/users', { name, email, password, role });
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
      await api.patch(`/admin/users/${user.id}`, { isActive: !user.isActive });
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
      await api.delete(`/admin/users/${user.id}`);
      await loadUsers();
    } catch (err: any) {
      alert(err?.message || 'Failed to delete user');
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-tx-cream tracking-tight">Admin User Management</h2>
          <p className="text-xs text-tx-textMuted mt-0.5">
            Role-Based Access Control (RBAC) with Argon2id credential hashing
          </p>
        </div>

        <button
          onClick={() => setShowCreateModal(true)}
          className="px-4 py-2 rounded-xl bg-tx-primary hover:bg-tx-primaryHover text-white text-xs font-semibold flex items-center gap-2 transition-all shadow-md shadow-tx-primary/20 w-fit"
        >
          <PlusCircle className="w-4 h-4" />
          <span>New Admin User</span>
        </button>
      </div>

      {/* Users Table */}
      <div className="p-5 rounded-2xl bg-tx-surface border border-tx-border overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-tx-border text-tx-textDim font-medium">
                <th className="pb-3 pl-1">Name</th>
                <th className="pb-3">Email</th>
                <th className="pb-3">Role</th>
                <th className="pb-3">Status</th>
                <th className="pb-3">Last Login</th>
                <th className="pb-3 text-right pr-1">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-tx-border/50">
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-tx-textDim">
                    <Loader2 className="w-6 h-6 animate-spin mx-auto mb-2 text-tx-primary" />
                    Loading admin accounts...
                  </td>
                </tr>
              ) : (
                users.map((u) => (
                  <tr key={u.id} className="hover:bg-tx-card/60 transition-colors">
                    <td className="py-3.5 pl-1 font-semibold text-tx-cream">
                      {u.name} {u.id === currentUser?.id && '(You)'}
                    </td>
                    <td className="py-3.5 text-tx-textMuted">{u.email}</td>
                    <td className="py-3.5">
                      <span className="text-[10px] font-semibold px-2 py-0.5 rounded bg-tx-card border border-tx-border text-tx-sage">
                        {u.role}
                      </span>
                    </td>
                    <td className="py-3.5">
                      {u.isActive ? (
                        <span className="inline-flex items-center gap-1 text-[11px] text-emerald-400 font-medium">
                          <CheckCircle2 className="w-3.5 h-3.5" />
                          <span>Active</span>
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-[11px] text-rose-400 font-medium">
                          <XCircle className="w-3.5 h-3.5" />
                          <span>Deactivated</span>
                        </span>
                      )}
                    </td>
                    <td className="py-3.5 text-tx-textDim">
                      {u.lastLoginAt ? new Date(u.lastLoginAt).toLocaleString() : 'Never'}
                    </td>
                    <td className="py-3.5 text-right pr-1">
                      {u.id !== currentUser?.id && (
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => handleToggleActive(u)}
                            className="text-xs text-tx-textMuted hover:text-tx-cream px-2 py-1 rounded bg-tx-card border border-tx-border"
                          >
                            {u.isActive ? 'Deactivate' : 'Activate'}
                          </button>
                          <button
                            onClick={() => handleDelete(u)}
                            className="p-1.5 rounded bg-tx-card hover:bg-rose-950/60 text-tx-textDim hover:text-rose-400 border border-tx-border"
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
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="w-full max-w-md bg-tx-surface border border-tx-border rounded-2xl p-6 shadow-2xl space-y-4">
            <h3 className="text-base font-bold text-tx-cream">Create Admin User</h3>
            {error && (
              <p className="p-3 rounded-xl bg-rose-950/40 border border-rose-800/50 text-rose-300 text-xs">
                {error}
              </p>
            )}
            <form onSubmit={handleCreate} className="space-y-4 text-xs">
              <div>
                <label className="block text-tx-textMuted mb-1 font-medium">Full Name</label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. Sarah Jenkins"
                  className="w-full px-3 py-2 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-xs focus:outline-none focus:border-tx-primary"
                />
              </div>
              <div>
                <label className="block text-tx-textMuted mb-1 font-medium">Email Address</label>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="sarah@txbrowser.com"
                  className="w-full px-3 py-2 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-xs focus:outline-none focus:border-tx-primary"
                />
              </div>
              <div>
                <label className="block text-tx-textMuted mb-1 font-medium">Password (Min 8 chars)</label>
                <input
                  type="password"
                  required
                  minLength={8}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••••"
                  className="w-full px-3 py-2 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-xs focus:outline-none focus:border-tx-primary"
                />
              </div>
              <div>
                <label className="block text-tx-textMuted mb-1 font-medium">Role</label>
                <select
                  value={role}
                  onChange={(e) => setRole(e.target.value as AdminRole)}
                  className="w-full px-3 py-2 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-xs focus:outline-none focus:border-tx-primary"
                >
                  <option value="ADMIN">ADMIN (Full campaign & device permissions)</option>
                  <option value="EDITOR">EDITOR (Draft and create campaigns only)</option>
                  <option value="SUPER_ADMIN">SUPER_ADMIN (All permissions + user management)</option>
                </select>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  disabled={creating}
                  className="px-4 py-2 rounded-xl bg-tx-card border border-tx-border text-tx-cream text-xs font-medium"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={creating}
                  className="px-4 py-2 rounded-xl bg-tx-primary hover:bg-tx-primaryHover text-white text-xs font-semibold flex items-center gap-2"
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
