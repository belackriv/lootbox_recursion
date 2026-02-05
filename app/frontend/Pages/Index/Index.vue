<script setup lang="ts">
import ActionBar from "@/Layouts/ActionBar.vue";
import InventoryGrid from "@/Layouts/InventoryGrid.vue";
import { PlayerAction, InventorySlot } from "@/types/index.ts";

defineProps<{
  actions: Array<PlayerAction>;
  inventory: Array<InventorySlot>;
}>();
</script>

<template>
  <div>
    <div>
      <h1>Actions</h1>
      <ActionBar :actions="actions" />
    </div>
    <div>
      <h1>Inventory</h1>
      <InventoryGrid :inventory="inventory" />
    </div>
  </div>
</template>
