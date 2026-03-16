<script setup lang="ts">
import { computed, watch } from "vue";
import { storeToRefs } from "pinia";
import ActionBar from "@/Layouts/ActionBar.vue";
import InventoryGrid from "@/Layouts/InventoryGrid.vue";
import WorldGrid from "@/Layouts/WorldGrid.vue";
import SortButton from "@/Shared/SortButton.vue";
import { PlayerAction, InventorySlot } from "@/types/index.ts";
import { usePlayerStore } from "@/store/player.ts";

const props = defineProps<{
  actions: Array<PlayerAction>;
  inventory: Array<InventorySlot>;
  userEntityId: number;
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

const sortAction = computed(
  () => renderedActions.value.find((a) => a.name === "sort_inventory") ?? null
);

const nonSortActions = computed(() =>
  renderedActions.value.filter((a) => a.name !== "sort_inventory")
);
</script>

<template>
  <div style="display: flex; align-items: stretch; gap: 8px; height: 100%">
    <!-- Actions column — sized to content -->
    <div
      class="fac-panel"
      style="align-self: flex-start; min-width: 220px; max-width: 420px"
    >
      <div class="fac-title-bar">◈ Actions</div>
      <div style="padding: 8px">
        <ActionBar :actions="nonSortActions" />
      </div>
    </div>

    <!-- Inventory column — sized to content -->
    <div class="fac-panel" style="align-self: flex-start; flex: 0 0 auto">
      <div
        class="fac-title-bar"
        style="
          display: flex;
          align-items: center;
          justify-content: space-between;
        "
      >
        <span>▦ Inventory</span>
        <SortButton
          v-if="sortAction"
          :action="sortAction"
          :entity-id="props.userEntityId"
        />
      </div>
      <div style="padding: 8px">
        <InventoryGrid :inventory="inventory" />
      </div>
    </div>

    <!-- World Grid Panel — stretches full height independently -->
    <div
      class="fac-panel"
      style="
        flex: 0 0 220px;
        display: flex;
        flex-direction: column;
        align-self: stretch;
      "
    >
      <div class="fac-title-bar">⬡ Deployed</div>
      <WorldGrid style="flex: 1; min-height: 0" />
    </div>
  </div>
</template>
