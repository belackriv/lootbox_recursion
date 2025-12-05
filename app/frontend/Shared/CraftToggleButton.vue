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
    class="bg-gray-400 hover:bg-gray-500 disabled:bg-gray-600 border-gray-300 border-2 rounded-lg underline p-1 pl-2 pr-2 m-1 cursor-pointer disabled:cursor-not-allowed relative"
  >
    <div style="width: 44px; text-align: left">Craft</div>
    <div style="position: absolute; top: 6px; left: 40px">
      <unicon
        v-if="!showCraftingTray"
        width="16"
        height="16"
        name="angle-double-down"
        fill="black"
      ></unicon>
    </div>
    <div style="position: absolute; top: 6px; left: 40px">
      <unicon
        v-if="showCraftingTray"
        width="16"
        height="16"
        name="angle-double-up"
        fill="black"
      ></unicon>
    </div>
  </button>
</template>
