<script setup lang="ts">
import type {
  PlayerAction,
  PlayerActionChoice,
  PlayerActionData,
} from "@/types/index.ts";
import { inject, ref } from "vue";
import { usePlayerStore } from "@/store/player.ts";
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

const performAction = (actionData: PlayerActionData | null) => {
  if (!props.action) {
    return false;
  }
  const store = usePlayerStore();
  store.performPlayerAction(
    { ...props.action },
    actionData,
    playerActionsChannel
  );

  onCooldown.value = true;

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
    }
  }
  requestAnimationFrame(animationLoop);
};

const onClick = () => {
  if (onCooldown.value || castTimeProgress.value > 0) {
    return false;
  }
  performAction(props.choice);
};
</script>

<template>
  <button
    :disabled="action?.disabled"
    @click="onClick"
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
