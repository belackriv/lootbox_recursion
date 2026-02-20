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

watch(
  () => props.actions,
  (actions) => {
    playerStore.updateAvailableActions(actions ?? []);
  },
  { immediate: true, deep: true }
);

const renderedActions = computed(() => availableActions.value ?? []);
</script>

<template>
  <div
    style="display: flex; flex-wrap: wrap; align-items: flex-start; gap: 8px"
  >
    <!-- Actions Panel -->
    <div
      class="fac-panel"
      style="min-width: 220px; flex: 1 1 220px; max-width: 420px"
    >
      <div class="fac-title-bar">⚡ Actions</div>
      <div style="padding: 8px">
        <ActionBar :actions="renderedActions" />
      </div>
    </div>

    <!-- Inventory Panel -->
    <div class="fac-panel" style="flex: 0 0 auto">
      <div class="fac-title-bar">🎒 Inventory</div>
      <div style="padding: 8px">
        <InventoryGrid :inventory="inventory" />
      </div>
    </div>
  </div>
</template>
