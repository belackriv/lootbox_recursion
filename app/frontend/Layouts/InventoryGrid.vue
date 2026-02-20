<script setup lang="ts">
import { onMounted } from "vue";
import { usePlayerStore, inventoryRowLength } from "@/store/player.ts";
import type { InventorySlot } from "@/types/index.ts";
import InventoryRow from "@/Shared/InventoryRow.vue";

const props = defineProps<{ inventory: Array<InventorySlot> }>();
const store = usePlayerStore();

onMounted(() => {
  for (let i = 0; i < props.inventory.length; i++) {
    const slotNumber = props.inventory[i].slot;
    const rowIndex = Math.floor(slotNumber / inventoryRowLength);
    const columnIndex = slotNumber % inventoryRowLength;
    store.inventory.rows[rowIndex][columnIndex].slot.slot = slotNumber;
    store.inventory.rows[rowIndex][columnIndex].slot.inventoryItem =
      props.inventory[i].inventoryItem;
  }
});
</script>

<template>
  <div class="fac-panel-inner" style="display: inline-block; padding: 6px">
    <InventoryRow
      v-for="(row, index) in store.inventory.rows"
      :slots="row"
      :key="index"
    />
  </div>
</template>
