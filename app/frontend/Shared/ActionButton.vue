<script setup lang="ts">
import type { PlayerAction } from "@/types/index.ts";
import { inject, ref } from "vue";
import { usePlayerStore } from "@/store/player.ts";
import PlayerActionsChannel from "@/channels/playerActions.ts";

const props = defineProps<PlayerAction>();
const playerActionsChannel = inject<PlayerActionsChannel>(
    "playerActionsChannel",
);
const castTimeProgress = ref<number>(0);
const isOnCooldownUntil = ref<Date>(new Date());

const onClick = () => {
    const clickedAt = new Date();
    if (isOnCooldownUntil.value > clickedAt || castTimeProgress.value > 0) {
        return false;
    }
    const store = usePlayerStore();
    store.performPlayerAction({ ...props }, null, playerActionsChannel);

    isOnCooldownUntil.value = new Date(
        clickedAt.getTime() + props.cooldown * 1000,
    );
    const castStartTime = performance.now();

    function animationLoop() {
        const currentTime = performance.now();
        castTimeProgress.value =
            ((currentTime - castStartTime) / (props.castTime * 1000)) * 100;

        if (castTimeProgress.value <= 100) {
            requestAnimationFrame(animationLoop);
        } else {
            castTimeProgress.value = 0;
        }
    }
    requestAnimationFrame(animationLoop);
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
            :style="{ width: castTimeProgress + '%' }"
        ></span>
    </button>
</template>
