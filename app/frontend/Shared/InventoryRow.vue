<script setup lang="ts">
import type { InventoryGridSlot } from "@/types/index.ts";
import InventoryItemSlot from "@/Shared/InventoryItemSlot.vue";

defineProps<{ slots: Array<InventoryGridSlot> }>();
</script>

<template>
  <div class="border-s-slate-900 border-2 flex w-161 bg-slate-300">
    <InventoryItemSlot
      v-for="gridSlot in slots"
      :key="gridSlot.slot.slot"
      :grid-slot="gridSlot"
    />
  </div>
</template>
