import { describe, it, expect, vi, beforeEach } from 'vitest';
import { AuthService } from '../src/services/auth.service.js';
import { loginSchema } from '../src/schemas/auth.schema.js';
import argon2 from 'argon2';

describe('Admin Authentication & RBAC Unit Tests', () => {
  let mockPrisma: any;
  let authService: AuthService;

  beforeEach(() => {
    mockPrisma = {
      adminUser: {
        findUnique: vi.fn(),
        update: vi.fn(),
      },
      adminAuditLog: {
        create: vi.fn(),
      },
    };
    authService = new AuthService(mockPrisma);
  });

  describe('Zod Validation for Auth', () => {
    it('validates a valid login payload', () => {
      const payload = {
        email: 'admin@txbrowser.com',
        password: 'ValidPassword123!',
      };
      const res = loginSchema.safeParse(payload);
      expect(res.success).toBe(true);
    });

    it('rejects invalid email or empty password', () => {
      const payload = {
        email: 'not-an-email',
        password: '',
      };
      const res = loginSchema.safeParse(payload);
      expect(res.success).toBe(false);
    });
  });

  describe('Argon2id Password Hashing & Verification', () => {
    it('hashes and successfully verifies a secure password', async () => {
      const password = 'CorrectPassword123#';
      const hash = await authService.hashPassword(password);

      expect(hash).toContain('$argon2id$');
      const isMatch = await authService.verifyPassword(hash, password);
      expect(isMatch).toBe(true);

      const isWrongMatch = await authService.verifyPassword(hash, 'WrongPassword456!');
      expect(isWrongMatch).toBe(false);
    });
  });

  describe('Login & Account Lockout Flow', () => {
    it('successfully logs in active user and clears failed attempts', async () => {
      const password = 'SecretPassword123!';
      const hash = await argon2.hash(password, { type: argon2.argon2id });

      mockPrisma.adminUser.findUnique.mockResolvedValue({
        id: 'admin-uuid-1',
        email: 'admin@txbrowser.com',
        name: 'Lead Admin',
        passwordHash: hash,
        role: 'SUPER_ADMIN',
        isActive: true,
        failedAttempts: 2,
        lockedUntil: null,
      });

      mockPrisma.adminUser.update.mockResolvedValue({});
      mockPrisma.adminAuditLog.create.mockResolvedValue({});

      const user = await authService.login(
        'admin@txbrowser.com',
        password,
        '127.0.0.1',
        'Mozilla/5.0'
      );

      expect(user.email).toBe('admin@txbrowser.com');
      expect(mockPrisma.adminUser.update).toHaveBeenCalledWith({
        where: { id: 'admin-uuid-1' },
        data: expect.objectContaining({
          failedAttempts: 0,
          lockedUntil: null,
        }),
      });
      expect(mockPrisma.adminAuditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          action: 'LOGIN',
          adminUserId: 'admin-uuid-1',
        }),
      });
    });

    it('locks account after 5 failed attempts', async () => {
      const password = 'CorrectPassword123!';
      const hash = await argon2.hash(password, { type: argon2.argon2id });

      mockPrisma.adminUser.findUnique.mockResolvedValue({
        id: 'admin-uuid-2',
        email: 'target@txbrowser.com',
        name: 'Target Admin',
        passwordHash: hash,
        role: 'ADMIN',
        isActive: true,
        failedAttempts: 4, // 5th attempt will lock
        lockedUntil: null,
      });

      mockPrisma.adminUser.update.mockResolvedValue({});
      mockPrisma.adminAuditLog.create.mockResolvedValue({});

      await expect(
        authService.login('target@txbrowser.com', 'BadPassword', '127.0.0.1', 'Mozilla/5.0')
      ).rejects.toThrow('Invalid credentials or account locked');

      expect(mockPrisma.adminUser.update).toHaveBeenCalledWith({
        where: { id: 'admin-uuid-2' },
        data: expect.objectContaining({
          failedAttempts: 5,
          lockedUntil: expect.any(Date),
        }),
      });
    });

    it('rejects login when account is locked', async () => {
      const futureDate = new Date(Date.now() + 10 * 60 * 1000); // Locked for 10 more minutes
      mockPrisma.adminUser.findUnique.mockResolvedValue({
        id: 'admin-uuid-3',
        email: 'locked@txbrowser.com',
        isActive: true,
        failedAttempts: 5,
        lockedUntil: futureDate,
      });

      await expect(
        authService.login('locked@txbrowser.com', 'AnyPassword', '127.0.0.1', 'Mozilla/5.0')
      ).rejects.toThrow('Account is temporarily locked');
    });
  });
});
