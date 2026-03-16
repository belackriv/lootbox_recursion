<script setup lang="ts">
import { computed } from "vue";
import { storeToRefs } from "pinia";
import { usePlayerStore } from "@/store/player.ts";
import WorldCellSlot from "@/Shared/WorldCellSlot.vue";

const CELL_HEIGHT = 48;
const CELL_GAP = 2;

const store = usePlayerStore();
const { worldCells } = storeToRefs(store);

type TickKind = "major" | "minor" | "normal";

function tickKind(index: number): TickKind {
  if (index % 16 === 0) return "major";
  if (index % 4 === 0) return "minor";
  return "normal";
}

const ticks = computed(() =>
  worldCells.value.map((cell) => ({
    cell,
    kind: tickKind(cell.index),
  }))
);
</script>

<template>
  <div class="world-grid">
    <!-- Scroll viewport -->
    <div class="world-grid__body">
      <!-- Scroll content: ruler + cell list side by side -->
      <div class="world-grid__inner">
        <!-- Ruler -->
        <div class="ruler" aria-hidden="true">
          <div
            v-for="{ cell, kind } in ticks"
            :key="cell.index"
            class="ruler__row"
          >
            <div :class="['ruler__tick', `ruler__tick--${kind}`]" />
          </div>
        </div>

        <!-- Cell list -->
        <div class="world-grid__list">
          <WorldCellSlot
            v-for="{ cell } in ticks"
            :key="cell.index"
            :cell="cell"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* ---------- layout shell ---------- */
.world-grid {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.world-grid__body {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
}

.world-grid__inner {
  display: flex;
  min-height: 100%;
}

/* ---------- scrollbar (hidden) ---------- */
.world-grid__body::-webkit-scrollbar {
  display: none;
}
.world-grid__body {
  -ms-overflow-style: none;
  scrollbar-width: none;
}

/* ---------- ruler ---------- */
.ruler {
  flex-shrink: 0;
  width: 14px;
  display: flex;
  flex-direction: column;
  align-self: flex-start;
  background: var(--color-fac-bg, #111108);
  border-right: 1px solid var(--color-fac-border, #3a3a2a);
}

.ruler__row {
  /* matches the cell height */
  height: 48px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  /* gap between rows matches world-grid__list gap */
  margin-bottom: 2px;
}

.ruler__row:last-child {
  margin-bottom: 0;
}

/* Base tick — a short, thin horizontal bar that grows left from the border */
.ruler__tick {
  background: var(--color-fac-text-dark, #444433);
  height: 1px;
}

/* Normal: short and thin */
.ruler__tick--normal {
  width: 4px;
}

/* Minor: longer and slightly thicker (every 4th) */
.ruler__tick--minor {
  width: 8px;
  height: 2px;
  background: var(--color-fac-text-dim, #888866);
}

/* Major: longest and widest (every 16th) */
.ruler__tick--major {
  width: 12px;
  height: 3px;
  background: var(--color-fac-orange, #e8a020);
}

/* ---------- cell list ---------- */
.world-grid__list {
  flex: 1;
  align-self: flex-start;
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 0 4px 4px 4px;
}
</style>
