import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  DATABASE_URL: z.string().url().default('postgresql://postgres:postgres@localhost:5432/tx_notifications?schema=public'),

  // Firebase Admin Credentials
  FIREBASE_PROJECT_ID: z.string().default('tx-browser-production'),
  FIREBASE_CLIENT_EMAIL: z.string().default('firebase-adminsdk@tx-browser-production.iam.gserviceaccount.com'),
  FIREBASE_PRIVATE_KEY: z.string().default(''),

  // Security & Sessions
  ADMIN_SESSION_SECRET: z.string().min(32, 'Session secret must be at least 32 characters long').default('super_secret_cookie_session_key_min_32_chars_long_12345'),
  CORS_ORIGINS: z.string().default('*'),

  // Admin Seeding Defaults
  SEED_ADMIN_EMAIL: z.string().email().default('admin@txbrowser.com'),
  SEED_ADMIN_PASSWORD: z.string().min(8).default('ChangeMeNowSecure123!'),
  SEED_ADMIN_NAME: z.string().default('TX Super Admin'),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment variables:', parsed.error.format());
  throw new Error('Environment configuration validation failed.');
}

const rawPrivateKey = parsed.data.FIREBASE_PRIVATE_KEY;
// Handle literal \n characters in multiline PEM keys passed through environment variables
const normalizedPrivateKey = rawPrivateKey
  ? rawPrivateKey.replace(/\\n/g, '\n')
  : '';

export const env = {
  ...parsed.data,
  FIREBASE_PRIVATE_KEY: normalizedPrivateKey,
  corsOriginsList: parsed.data.CORS_ORIGINS === '*'
    ? true
    : parsed.data.CORS_ORIGINS.split(',').map((o) => o.trim()),
};
