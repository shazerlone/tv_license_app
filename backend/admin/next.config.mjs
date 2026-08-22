/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // No ESLint config is shipped with this lean admin; TypeScript still
  // type-checks the build. Add eslint-config-next later if desired.
  eslint: { ignoreDuringBuilds: true },
  // Fully static export → deployable as a free Render Static Site (or Vercel,
  // GitHub Pages, any static host). The admin is 100% client-rendered
  // (client-side auth + fetch), so no server runtime is needed.
  output: 'export',
  trailingSlash: true, // emit /users/index.html so deep links resolve on static hosts
  images: { unoptimized: true },
};

export default nextConfig;
