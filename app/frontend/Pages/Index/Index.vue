<script setup lang="ts">
import { computed, watch } from "vue";
import { storeToRefs } from "pinia";
import ActionBar from "@/Layouts/ActionBar.vue";
import InventoryGrid from "@/Layouts/InventoryGrid.vue";
import { PlayerAction, InventorySlot } from "@/types/index.ts";
import { usePlayerStore } from "@/store/player.ts";

const props = defineProps<{
  actions: Array<PlayerAction>;
  inventory: Array<InventorySlot>;
}>();

const playerStore = usePlayerStore();
const { availableActions } = storeToRefs(playerStore);

// Keep store in sync with server-provided page props.
// immediate: true ensures initial page render uses these props as baseline.
watch(
  () => props.actions,
  (actions) => {
    playerStore.updateAvailableActions(actions ?? []);
  },
  { immediate: true, deep: true }
);

// Render actions from store so ActionCable updates are reflected in UI.
const renderedActions = computed(() => availableActions.value ?? []);
</script>

<template>
  <div>
    <div>
      <h1>Actions</h1>
      <ActionBar :actions="renderedActions" />
    </div>
    <div>
      <h1>Inventory</h1>
      <InventoryGrid :inventory="inventory" />
    </div>
  </div>
</template>
