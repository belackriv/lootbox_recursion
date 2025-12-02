<script setup lang="ts">
import type { PlayerAction } from "@/types/index.ts";
import { inject, ref } from "vue";
import { usePlayerStore } from "@/store/player.ts";
import PlayerActionsChannel from "@/channels/playerActions.ts";

const props = defineProps<PlayerAction>();
const playerActionsChannel = inject<PlayerActionsChannel>(
    "playerActionsChannel",
);
const castTimeWidth = ref(0);
const isOnCooldown = ref(false);

const onClick = () => {
    if (isOnCooldown.value || castTimeWidth.value > 0) {
        return false;
    }
    const store = usePlayerStore();
    store.performPlayerAction({ ...props }, null, playerActionsChannel);

    isOnCooldown.value = true;
    setTimeout(() => {
        isOnCooldown.value = false;
    }, props.cooldown * 1000);

    let intervalId: ReturnType<typeof setInterval>;
    const castTimeIncrementTick = 100 / (props.castTime * 60);

    intervalId = setInterval(() => {
        castTimeWidth.value += castTimeIncrementTick;
        if (castTimeWidth.value >= 100) {
            clearInterval(intervalId);
            castTimeWidth.value = 0;
        }
    }, 16);
};
</script>

<template>
    <button
        :disabled="disabled"
        @click="onClick"
        class="bg-gray-400 hover:bg-gray-500 disabled:bg-gray-600 border-gray-300 border-2 rounded-lg underline p-1 pl-2 pr-2 m-1 cursor-pointer disabled:cursor-not-allowed relative"
    >
        <span>{{ label }}</span>

        <span
            class="bg-gray-900 opacity-50 absolute top-0 left-0 h-full"
            :style="{ width: castTimeWidth + '%' }"
        ></span>
    </button>
</template>
