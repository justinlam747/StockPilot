import { fileURLToPath } from 'node:url';

export default {
  serverExternalPackages: ['bullmq', 'ioredis'],
  turbopack: { root: fileURLToPath(new URL('../', import.meta.url)) },
  devIndicators: false,
  poweredByHeader: false,
  async redirects() {
    return ['/', '/simulation', '/retail', '/transfer', '/dashboard'].map(source => ({
      source, destination: '/forecast', permanent: true,
    }));
  },
  async headers() {
    return [{
      source: '/:path*',
      headers: [
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'Content-Security-Policy', value: "object-src 'none'; frame-ancestors 'none'; base-uri 'self'; connect-src 'self' ws://127.0.0.1:* ws://localhost:*" },
      ],
    }];
  },
};
