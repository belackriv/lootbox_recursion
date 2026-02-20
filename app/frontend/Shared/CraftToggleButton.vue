<script setup lang="ts">
import type { PlayerAction } from "@/types/index.ts";

defineProps<{
  action: PlayerAction | undefined;
  showCraftingTray: boolean;
}>();
const emit = defineEmits<{
  (e: "toggleCraftTray"): void;
}>();
</script>

<template>
  <button
    :disabled="action?.disabled"
    @click="$emit('toggleCraftTray')"
    class="fac-btn"
    style="min-width: 80px; gap: 6px"
  >
    <span style="position: relative; z-index: 1">Craft</span>
    <span
      style="
        position: relative;
        z-index: 1;
        font-size: 0.7rem;
        color: var(--color-fac-orange);
      "
    >
      {{ showCraftingTray ? "▲" : "▼" }}
    </span>
  </button>
</template>
