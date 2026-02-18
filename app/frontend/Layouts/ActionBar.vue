<script setup lang="ts">
import { ref, computed } from "vue";
import ActionButton from "@/Shared/ActionButton.vue";
import CraftToggleButton from "@/Shared/CraftToggleButton.vue";
import CraftActionButton from "@/Shared/CraftActionButton.vue";

import type { PlayerAction } from "@/types/index.ts";

const showCraftingTray = ref<boolean>(false);

const toggleCraftingTray = () => {
  showCraftingTray.value = !showCraftingTray.value;
};

const props = defineProps<{
  actions: Array<PlayerAction>;
}>();

const nonCraftingActions = computed(() => {
  return props.actions.filter((action) => {
    return action.name !== "craft";
  });
});

const craftingAction = computed(() => {
  return props.actions.find((action) => {
    return action.name === "craft";
  });
});
</script>
<template>
  <CraftToggleButton
    @toggle-craft-tray="toggleCraftingTray"
    :showCraftingTray="showCraftingTray"
    :action="craftingAction"
  />
  <ActionButton
    v-for="action in nonCraftingActions"
    v-bind="action"
    :key="action.name"
  />
  <div v-if="showCraftingTray">
    <h2>Crafting</h2>
    <div>
      <CraftActionButton
        v-for="choice in craftingAction?.choices"
        :choice="choice"
        :action="craftingAction"
        :key="choice.name"
      />
    </div>
  </div>
</template>
