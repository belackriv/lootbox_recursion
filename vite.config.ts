import vue from "@vitejs/plugin-vue";

import { defineConfig } from "vite";
import path from "path";
import RubyPlugin from "vite-plugin-ruby";

export default defineConfig({
  plugins: [vue(), RubyPlugin()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./app/frontend"),
    },
  },
  server: {
    watch: {
      usePolling: true, // Enables file polling
    },
  },
});
