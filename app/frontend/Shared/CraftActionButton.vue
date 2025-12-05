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
    class="bg-gray-400 hover:bg-gray-500 disabled:bg-gray-600 border-gray-300 border-2 rounded-lg underline p-1 pl-2 pr-2 m-1 cursor-pointer disabled:cursor-not-allowed relative"
  >
    <span>{{ choice.label }}</span>
    <span
      class="border-2 rounded-lg border-red-900 absolute"
      :style="{
        top: '-2.5%',
        left: '-2.5%',
        width: '105%',
        height: '105%',
        display: onCooldown ? 'block' : 'none',
      }"
    ></span>
    <span
      class="bg-gray-900 opacity-50 absolute top-0 left-0 h-full"
      :style="{ width: castTimeProgress + '%' }"
    ></span>
  </button>
</template>
