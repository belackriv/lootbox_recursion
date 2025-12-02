<script setup lang="ts">
import ActionButton from "@/Shared/ActionButton.vue";
import type { PlayerAction } from "@/types/index.ts";

defineProps<{
    availableActions: Array<PlayerAction>;
}>();
</script>

<template>
    <ActionButton
        v-for="action in availableActions"
        v-bind="action"
        :key="action.name"
    />
</template>
