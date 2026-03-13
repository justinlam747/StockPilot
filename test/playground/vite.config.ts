import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "path";

const ROOT = path.resolve(__dirname, "../..");

export default defineConfig({
  plugins: [react(), tailwindcss()],
  root: __dirname,
  resolve: {
    alias: [
      {
        // Intercept the real auth hook and replace with our mock.
        // Match any import path ending with hooks/useAuthenticatedFetch
        find: /.*hooks\/useAuthenticatedFetch$/,
        replacement: path.resolve(__dirname, "mock-fetch.ts"),
      },
      {
        // Support @/ path alias for components
        find: /^@\//,
        replacement: path.resolve(ROOT, "frontend/src") + "/",
      },
    ],
  },
  server: {
    port: 3100,
    open: true,
  },
});
