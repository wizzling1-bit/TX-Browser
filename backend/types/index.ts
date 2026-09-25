export type AdminRole = 'SUPER_ADMIN' | 'ADMIN' | 'EDITOR';

export interface AdminUser {
  id: string;
  email: string;
  name: string;
  role: AdminRole;
  isActive: boolean;
  lastLoginAt?: string | null;
  createdAt?: string;
}

export type NotificationType =
  | 'GENERAL'
  | 'BROWSER_UPDATE'
  | 'PROMOTION'
  | 'NEW_FEATURE'
  | 'SECURITY'
  | 'ANNOUNCEMENT'
  | 'MAINTENANCE';

export type DestinationType =
  | 'HOME'
  | 'WEB_URL'
  | 'PLAY_STORE'
  | 'INTERNAL_SCREEN'
  | 'NO_ACTION';

export type AudienceType = 'ALL_USERS' | 'TOPIC' | 'SEGMENT';

export type NotificationStatus =
  | 'DRAFT'
  | 'SCHEDULED'
  | 'QUEUED'
  | 'SENDING'
  | 'SENT'
  | 'PARTIALLY_FAILED'
  | 'FAILED'
  | 'CANCELLED';

export interface NotificationStats {
  total: number;
  sent: number;
  failed: number;
  opened: number;
  openRate: number;
}

export interface NotificationItem {
  id: string;
  title: string;
  body: string;
  imageUrl?: string | null;
  notificationType: NotificationType;
  destinationType: DestinationType;
  destinationValue?: string | null;
  audienceType: AudienceType;
  audienceConfig?: any;
  status: NotificationStatus;
  scheduledAt?: string | null;
  startedAt?: string | null;
  completedAt?: string | null;
  createdAt: string;
  updatedAt: string;
  createdBy?: {
    id: string;
    name: string;
    email: string;
  } | null;
  stats?: NotificationStats;
  _count?: {
    deliveries: number;
    jobs: number;
  };
}

export interface Pagination {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

export interface PaginatedResult<T> {
  items: T[];
  pagination: Pagination;
}

export interface AudienceStats {
  summary: {
    totalInstallations: number;
    activeInstallations: number;
    activeLast30Days: number;
    permissionGranted: number;
    permissionDenied: number;
    permissionUnknown: number;
    grantedPercentage: number;
  };
  topics: Record<string, number>;
  versions: {
    app: Array<{ version: string; count: number }>;
    android: Array<{ version: string; count: number }>;
  };
}

export interface DeviceItem {
  id: string;
  installationId: string;
  fcmToken: string;
  platform: string;
  appVersion: string;
  buildNumber: number;
  androidVersion: string;
  deviceModel: string;
  notificationPermission: string;
  isActive: boolean;
  lastSeenAt: string;
  createdAt: string;
  topics: string[];
  totalDeliveries: number;
}

export interface AnalyticsOverview {
  summary: {
    totalCampaigns: number;
    sentCampaigns: number;
    scheduledCampaigns: number;
    totalDeliveries: number;
    failedDeliveries: number;
    openedDeliveries: number;
    overallOpenRate: number;
  };
  dailyTrend: Array<{ date: string; sent: number; opened: number }>;
  typeDistribution: Array<{ type: string; count: number }>;
  topCampaigns: Array<{ id: string; title: string; type: string; totalDeliveries: number }>;
}

export interface AuditLogItem {
  id: string;
  adminUserId?: string | null;
  action: string;
  resourceType: string;
  resourceId?: string | null;
  metadata?: any;
  ipAddress?: string | null;
  userAgent?: string | null;
  createdAt: string;
  adminUser?: {
    id: string;
    name: string;
    email: string;
    role: AdminRole;
  } | null;
}

export interface SystemHealth {
  status: 'healthy' | 'degraded';
  timestamp: string;
  database: {
    provider: string;
    status: string;
    latencyMs: number;
    registeredDevices: number;
    region: string;
  };
  firebase: {
    projectId: string;
    status: string;
    gateway: string;
    clientEmail: string;
  };
  syncTopology: {
    appLoginRequired: boolean;
    deviceIdentity: string;
    cloudSync: string;
  };
}

export interface CampaignBacklink {
  id: string;
  title: string;
  targetUrl: string;
  campaignSlug: string;
  packageName: string;
  fullBacklink: string;
  deepLink?: string | null;
  notes?: string | null;
  isActive: boolean;
  clickCount: number;
  createdAt: string;
  updatedAt: string;
}
