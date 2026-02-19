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

  const clickedAt = performance.now();
  const onCooldownUntil = clickedAt + props.cooldown * 1000;
  function animationLoop() {
    const currentTime = performance.now();

    onCooldown.value = currentTime <= onCooldownUntil;
    castTimeProgress.value =
      ((currentTime - clickedAt) / (props.castTime * 1000)) * 100;

    if (castTimeProgress.value <= 100) {
      requestAnimationFrame(animationLoop);
    } else {
      castTimeProgress.value = 0;
    }
  }
  requestAnimationFrame(animationLoop);
};

const onClick = () => {
  if (isDisabled.value) {
    return false;
  }
  if (onCooldown.value || castTimeProgress.value > 0) {
    return false;
  }
  performAction(null);
};
</script>

<template>
  <button
    :disabled="isDisabled"
    @click="onClick"
    class="bg-gray-400 hover:bg-gray-500 disabled:bg-gray-700 disabled:opacity-60 border-gray-300 border-2 rounded-lg underline p-1 pl-2 pr-2 m-1 disabled:cursor-not-allowed cursor-pointer relative"
  >
    <span>{{ label }}</span>
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
