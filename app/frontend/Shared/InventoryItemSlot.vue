<script setup lang="ts">
import { ref, watch } from "vue";
import type { InventoryGridSlot } from "@/types/index.ts";

const updated = ref(false);
const props = defineProps<{ gridSlot: InventoryGridSlot }>();

watch(props.gridSlot, () => {
  updated.value = true;
  setTimeout(() => {
    updated.value = false;
  }, 1000);
});
</script>

<template>
  <div
    class="w-16 h-16 flex-none border-2 border-slate-500 transition-border-color duration-500 hover:border-slate-300 relative"
  >
    <div>
      {{
        gridSlot.slot.inventoryItem && gridSlot.slot.inventoryItem.type
          ? gridSlot.slot.inventoryItem.type.slice(0, 1).toUpperCase()
          : ""
      }}
    </div>
    <div>{{ gridSlot.slot.inventoryItem?.count }}</div>
    <Transition name="fade">
      <div
        v-if="updated"
        class="bg-slate-50 absolute top-0 left-0 w-15 h-15 opacity-50"
      ></div>
    </Transition>
  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.5s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
