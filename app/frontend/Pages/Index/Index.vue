<script setup lang="ts">
import { computed, watch } from "vue";
import { storeToRefs } from "pinia";
import ActionBar from "@/Layouts/ActionBar.vue";
import InventoryGrid from "@/Layouts/InventoryGrid.vue";
import WorldGrid from "@/Layouts/WorldGrid.vue";
import SortButton from "@/Shared/SortButton.vue";
import TrimButton from "@/Shared/TrimButton.vue";
import { PlayerAction, InventorySlot, WorldCell } from "@/types/index.ts";
import { usePlayerStore } from "@/store/player.ts";
import PlayerActionsChannel from "@/channels/playerActions.ts";
import { inject } from "vue";

const ACTION_PANEL_WHITELIST = ["scavenge", "craft", "use", "sort_inventory"];

const props = defineProps<{
  actions: Array<PlayerAction>;
  inventory: Array<InventorySlot>;
  userEntityId: number;
  worldCells: Array<WorldCell>;
}>();

const playerActionsChannel = inject<PlayerActionsChannel>(
  "playerActionsChannel"
);

const playerStore = usePlayerStore();
const { availableActions } = storeToRefs(playerStore);

watch(
  () => props.actions,
  (actions) => {
    playerStore.updateAvailableActions(actions ?? []);
  },
  { immediate: true, deep: true }
);

watch(
  () => props.worldCells,
  (cells) => {
    playerStore.snapshotWorldCells(cells ?? []);
  },
  { immediate: true, deep: true }
);

const renderedActions = computed(() =>
  (availableActions.value ?? []).filter((a) =>
    ACTION_PANEL_WHITELIST.includes(a.name)
  )
);

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
    <div class="fac-panel" style="align-self: flex-start; width: 420px">
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
        flex: 0 0 240px;
        display: flex;
        flex-direction: column;
        align-self: stretch;
      "
    >
      <div
        class="fac-title-bar"
        style="
          display: flex;
          align-items: center;
          justify-content: space-between;
        "
      >
        <span>⬡ Deployed</span>
        <TrimButton />
      </div>
      <WorldGrid
        style="flex: 1; min-height: 0"
        :channel="playerActionsChannel"
      />
    </div>
  </div>
</template>
