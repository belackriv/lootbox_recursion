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
  <div>
    <!-- Primary action buttons row -->
    <div style="display: flex; flex-wrap: wrap; align-items: center; gap: 4px">
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
    </div>

    <!-- Crafting tray -->
    <Transition name="craft-tray">
      <div
        v-if="showCraftingTray"
        class="fac-crafting-tray"
        style="margin-top: 6px"
      >
        <div
          style="
            font-size: 0.7rem;
            font-weight: 700;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            color: var(--color-fac-text-dim);
            margin-bottom: 6px;
            padding-bottom: 4px;
            border-bottom: 1px solid var(--color-fac-border);
          "
        >
          ⚙ Crafting Recipes
        </div>
        <div style="display: flex; flex-wrap: wrap; gap: 4px">
          <CraftActionButton
            v-for="choice in craftingAction?.choices"
            :choice="choice"
            :action="craftingAction"
            :key="choice.name"
          />
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.craft-tray-enter-active,
.craft-tray-leave-active {
  transition: opacity 0.15s ease, transform 0.15s ease;
}
.craft-tray-enter-from,
.craft-tray-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}
</style>
