import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwind from "@tailwindcss/vite";

export default defineConfig(({ isSsrBuild }) => ({
  plugins: [react(), tailwind()],
  build: {
    sourcemap: false,
    cssCodeSplit: false,
    manifest: !isSsrBuild,
    outDir: isSsrBuild ? "dist/server" : "dist/client",
    rollupOptions: isSsrBuild
      ? undefined
      : {
          input: {
            "entry-client": "./src/entry-client.tsx",
          },
          output: {
            entryFileNames: "assets/[name]-[hash].js",
            chunkFileNames: "assets/[name]-[hash].js",
            assetFileNames: "assets/[name]-[hash].[ext]",
          },
        },
  },
  ssr: {
    // Bundle all dependencies for Lambda (no node_modules)
    noExternal: true,
  },
  server: {
    port: 3000,
  },
}));
