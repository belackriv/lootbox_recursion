<script setup lang="ts">
import type { InventoryGridSlot } from "@/types/index.ts";
import InventoryItemSlot from "@/Shared/InventoryItemSlot.vue";

defineProps<{ slots: Array<InventoryGridSlot> }>();
</script>

<template>
  <div style="display: flex; gap: 2px; margin-bottom: 2px">
    <InventoryItemSlot
      v-for="gridSlot in slots"
      :key="gridSlot.slot.slot"
      :grid-slot="gridSlot"
    />
  </div>
</template>
