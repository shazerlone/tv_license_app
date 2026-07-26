/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // No ESLint config is shipped with this lean admin; TypeScript still
  // type-checks the build. Add eslint-config-next later if desired.
  eslint: { ignoreDuringBuilds: true },
};

export default nextConfig;
