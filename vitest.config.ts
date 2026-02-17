import { defineConfig } from "vitest/config";
import vue from "@vitejs/plugin-vue";
import path from "path";

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      // Match the frontend tsconfig alias so imports like "@/..." work in tests
      "@": path.resolve(__dirname, "app/frontend"),
      "~": path.resolve(__dirname, "app/frontend"),
    },
  },
  test: {
    // Use a DOM-like environment for component testing
    environment: "jsdom",

    // Allow using globals like `describe`, `it`, `expect` without importing
    globals: true,

    // Pick up unit tests under the frontend tests directory
    include: ["app/frontend/tests/**/*.spec.ts", "app/frontend/tests/**/*.test.ts"],

    // Inline certain dependencies to avoid ESM transforms issues
    deps: {
      inline: ["@vue", "vue", "@vue/test-utils", "pinia"],
    },

    // Increase the test timeout slightly for slower CI environments
    testTimeout: 5000,
  },
});
