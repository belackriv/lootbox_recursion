<script setup lang="ts">
import type { PlayerAction, PlayerActionData } from "@/types/index.ts";
import { inject, ref, computed } from "vue";
import { usePlayerStore } from "@/store/player.ts";
import PlayerActionsChannel from "@/channels/playerActions.ts";

const props = defineProps<{
  action: PlayerAction;
  entityId: number;
}>();

const playerActionsChannel = inject<PlayerActionsChannel>(
  "playerActionsChannel"
);

const onCooldown = ref<boolean>(false);
const store = usePlayerStore();

const isDisabled = computed(() => props.action.disabled);

const onClick = () => {
  if (isDisabled.value || onCooldown.value) return;

  const actionData: PlayerActionData = { entityId: props.entityId };
  store.performPlayerAction({ ...props.action }, actionData, playerActionsChannel);

  onCooldown.value = true;
  setTimeout(() => {
    onCooldown.value = false;
  }, props.action.cooldown * 1000);
};

const onMouseEnter = () => {
  if (props.action.tooltip) {
    store.setTooltip({ title: props.action.label, body: props.action.tooltip });
  }
};

const onMouseLeave = () => {
  store.clearTooltip();
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
    style="
      font-size: 0.65rem;
      padding: 1px 7px;
      min-width: unset;
      letter-spacing: 0.08em;
      line-height: 1.6;
    "
  >
    <span style="position: relative; z-index: 1">{{ action.label }}</span>
  </button>
</template>
