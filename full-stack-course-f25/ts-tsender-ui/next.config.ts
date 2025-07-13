import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  output: "export", // build as static site
  distDir: "out", // compile location
  images: {
    unoptimized: true,
  },
  basePath: "",
  assetPrefix: "",
  trailingSlash: true
};

export default nextConfig;

// pnpm next build -> build as static site for deployment 
