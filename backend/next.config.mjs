/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '**',
      },
    ],
  },
  // Ensure serverless routes have sufficient execution time on Vercel
  experimental: {
    serverComponentsExternalPackages: ['argon2', 'firebase-admin', '@prisma/client', 'prisma'],
  },
};

export default nextConfig;
