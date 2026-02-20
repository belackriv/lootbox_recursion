<script setup lang="ts">
import type { PlayerAction, PlayerActionData } from "@/types/index.ts";
import { LOOTBOX_ITEM_TYPE } from "@/types/index.ts";
import { inject, ref, computed } from "vue";
import { usePlayerStore } from "@/store/player.ts";
import PlayerActionsChannel from "@/channels/playerActions.ts";

const props = defineProps<PlayerAction>();

const playerActionsChannel = inject<PlayerActionsChannel>(
  "playerActionsChannel"
);
const castTimeProgress = ref<number>(0);
const onCooldown = ref<boolean>(false);

const store = usePlayerStore();

const isDisabled = computed(() => {
  if (props.name === "use") {
    return store.selectedSlotItem?.type !== LOOTBOX_ITEM_TYPE;
  }
  return props.disabled;
});

const performAction = (actionData: PlayerActionData | null) => {
  store.performPlayerAction({ ...props }, actionData, playerActionsChannel);

  onCooldown.value = true;
  setTimeout(() => {
    onCooldown.value = false;
  }, props.cooldown * 1000);

  if (props.castTime > 0) {
    const clickedAt = performance.now();
    function animationLoop() {
      const currentTime = performance.now();

      castTimeProgress.value =
        ((currentTime - clickedAt) / (props.castTime * 1000)) * 100;

      if (castTimeProgress.value <= 100) {
        requestAnimationFrame(animationLoop);
      } else {
        castTimeProgress.value = 0;
      }
    }
    requestAnimationFrame(animationLoop);
  }
};

const onClick = () => {
  if (isDisabled.value) return false;
  if (onCooldown.value || castTimeProgress.value > 0) return false;

  if (props.name === "use") {
    const actionData =
      store.selectedSlotIndex !== null
        ? { slotNumber: store.selectedSlotIndex }
        : null;
    performAction(actionData);
  } else {
    performAction(null);
  }
};
</script>

<template>
  <button
    :disabled="isDisabled"
    @click="onClick"
    class="fac-btn"
    :class="{ 'fac-btn--cooldown': onCooldown }"
    style="min-width: 80px"
  >
    <!-- Label -->
    <span style="position: relative; z-index: 1">{{ label }}</span>

    <!-- Cast-time overlay (sweeps from left) -->
    <span class="fac-castbar" :style="{ width: castTimeProgress + '%' }"></span>
  </button>
</template>
