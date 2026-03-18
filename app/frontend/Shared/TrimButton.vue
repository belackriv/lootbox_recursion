<script setup lang="ts">
import { ref } from "vue";
import { usePlayerStore } from "@/store/player.ts";

const store = usePlayerStore();
const onCooldown = ref<boolean>(false);

const onClick = () => {
  if (onCooldown.value) return;
  store.trimWorldCells();
  onCooldown.value = true;
  setTimeout(() => {
    onCooldown.value = false;
  }, 500);
};

const onMouseEnter = () => {
  store.setTooltip({
    title: "Trim",
    body: "Reset the deployed panel to its default view, removing off-screen empty cells.",
  });
};

const onMouseLeave = () => {
  store.clearTooltip();
};
</script>

<template>
  <button
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
    <span style="position: relative; z-index: 1">Trim</span>
  </button>
</template>
