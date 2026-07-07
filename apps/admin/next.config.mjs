/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // The admin console is a standalone Next app; it is intentionally NOT part of
  // the pnpm workspace's strict TS build. It talks to the Fastify API over HTTP.
};

export default nextConfig;
