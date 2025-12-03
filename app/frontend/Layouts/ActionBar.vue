<script setup lang="ts">
import ActionButton from "@/Shared/ActionButton.vue";
import type { PlayerAction } from "@/types/index.ts";

defineProps<{
    availableActions: Array<PlayerAction>;
}>();
// using v-bind="action" leads to a warning with onCooldownUntil
// seems like it is a taken event handler name or something
</script>
<template>
    <ActionButton
        v-for="action in availableActions"
        :name="action.name"
        :label="action.label"
        :disabled="action.disabled"
        :cooldown="action.cooldown"
        :castTime="action.castTime"
        :key="action.name"
    />
</template>
