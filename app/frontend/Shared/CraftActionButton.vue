<script setup lang="ts">
import type {
  PlayerAction,
  PlayerActionChoice,
  PlayerActionData,
} from "@/types/index.ts";
import { inject, ref, computed } from "vue";
import { usePlayerStore } from "@/store/player.ts";
import type { TooltipCostRow } from "@/store/player.ts";
import PlayerActionsChannel from "@/channels/playerActions.ts";

const props = defineProps<{
  action?: PlayerAction;
  choice: PlayerActionChoice;
}>();

const playerActionsChannel = inject<PlayerActionsChannel>(
  "playerActionsChannel"
);
const castTimeProgress = ref<number>(0);
const onCooldown = ref<boolean>(false);

const store = usePlayerStore();

const tooltipCosts = computed<Array<TooltipCostRow>>(() => {
  if (!props.choice.cost) return [];
  const wood = props.choice.cost.wood;
  const iron = props.choice.cost.iron;
  return [
    {
      label: "Wood",
      amount: wood,
      canAfford: (store.inventoryTotals["WoodInventoryItem"] ?? 0) >= wood,
    },
    {
      label: "Iron",
      amount: iron,
      canAfford: (store.inventoryTotals["IronInventoryItem"] ?? 0) >= iron,
    },
  ];
});

const onMouseEnter = () => {
  store.setTooltip({
    title: props.choice.label,
    body: "",
    costs: tooltipCosts.value,
  });
};

const onMouseLeave = () => {
  store.clearTooltip();
};

const isDisabled = computed(() => {
  if (onCooldown.value || castTimeProgress.value > 0) return true;
  if (store.craftingInProgress) return true;
  if (props.action?.disabled) return true;
  return !store.canAfford(props.choice.cost);
});

const performAction = (actionData: PlayerActionData | null) => {
  if (!props.action) {
    return false;
  }
  store.performPlayerAction(
    { ...props.action },
    actionData,
    playerActionsChannel
  );

  onCooldown.value = true;
  store.startCrafting();

  const clickedAt = performance.now();
  const onCooldownUntil = clickedAt + props.action.cooldown * 1000;
  function animationLoop() {
    if (!props.action) {
      return false;
    }
    const currentTime = performance.now();

    onCooldown.value = currentTime <= onCooldownUntil;
    castTimeProgress.value =
      ((currentTime - clickedAt) / (props.action.castTime * 1000)) * 100;

    if (castTimeProgress.value <= 100) {
      requestAnimationFrame(animationLoop);
    } else {
      castTimeProgress.value = 0;
      store.finishCrafting();
    }
  }
  requestAnimationFrame(animationLoop);
};

const onClick = () => {
  if (isDisabled.value) {
    return false;
  }
  performAction(props.choice as PlayerActionData);
};
</script>

<template>
  <button
    :disabled="isDisabled"
    @click="onClick"
    @mouseenter="onMouseEnter"
    @mouseleave="onMouseLeave"
    class="fac-btn"
    :class="{ 'fac-btn--cooldown': onCooldown }"
    style="min-width: 96px; margin: 2px"
  >
    <!-- Label -->
    <span style="position: relative; z-index: 1">{{ choice.label }}</span>

    <!-- Cast-time overlay (sweeps from left) -->
    <span class="fac-castbar" :style="{ width: castTimeProgress + '%' }"></span>
  </button>
</template>
