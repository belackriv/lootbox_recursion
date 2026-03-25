<script setup lang="ts">
import { computed, ref, nextTick, onMounted, watch } from "vue";
import { storeToRefs } from "pinia";
import type { WorldCell } from "@/types/index.ts";
import { usePlayerStore } from "@/store/player.ts";
import WorldCellSlot from "@/Shared/WorldCellSlot.vue";
import PlayerActionsChannel from "@/channels/playerActions.ts";
import {
  PAGE_SIZE,
  CELL_HEIGHT,
  SCROLL_THRESHOLD,
  SENTINEL_HEIGHT,
} from "@/Layouts/worldGridConstants.ts";

const props = defineProps<{
  channel: PlayerActionsChannel | undefined;
}>();

const store = usePlayerStore();
const { sortedWorldCells, windowStart, windowSize, worldCells } =
  storeToRefs(store);

const scrollEl = ref<HTMLElement | null>(null);

// Tracks the first and last coordinate indices visible in the scroll viewport.
// Updated on every scroll event and whenever sortedWorldCells changes (e.g.
// after a deploy/remove that shifts the list).
const firstVisibleIndex = ref<number>(0);
const lastVisibleIndex = ref<number>(0);

function updateVisibleRange() {
  const el = scrollEl.value;
  if (!el) return;
  const { scrollTop, clientHeight } = el;
  firstVisibleIndex.value = Math.floor(scrollTop / CELL_HEIGHT);
  lastVisibleIndex.value = Math.floor(
    (scrollTop + clientHeight - 1) / CELL_HEIGHT
  );
}

// Recompute the visible range whenever sortedWorldCells changes so indicators
// update immediately after a deploy/remove without needing a scroll event.
watch(sortedWorldCells, () => {
  nextTick(updateVisibleRange);
});

const hasDeployedAboveWindow = computed((): boolean => {
  const cells = sortedWorldCells.value;
  const firstIdx = firstVisibleIndex.value;
  for (const cell of worldCells.value.values()) {
    if (cell.placedEntity === null) continue;
    const idx = cells.findIndex((c) => c.coordinate === cell.coordinate);
    if (idx !== -1 && idx < firstIdx) return true;
  }
  return false;
});

const hasDeployedBelowWindow = computed((): boolean => {
  const cells = sortedWorldCells.value;
  const lastIdx = lastVisibleIndex.value;
  for (const cell of worldCells.value.values()) {
    if (cell.placedEntity === null) continue;
    const idx = cells.findIndex((c) => c.coordinate === cell.coordinate);
    if (idx !== -1 && idx > lastIdx) return true;
  }
  return false;
});

type TickKind = "major" | "minor" | "normal";

function tickKind(coordinate: number): TickKind {
  if (coordinate % 16 === 0) return "major";
  if (coordinate % 4 === 0) return "minor";
  return "normal";
}

const ticks = computed(() =>
  sortedWorldCells.value.map((cell: WorldCell) => ({
    cell,
    kind: tickKind(cell.coordinate),
  }))
);

// Converts a world coordinate to the pixel offset from the top of the scroll
// content. Used by scrollToCoordinate to position the viewport.
function coordinateToScrollTop(coordinate: number): number {
  // The coordinate's row index within sortedWorldCells (0-based).
  const cells = sortedWorldCells.value;
  const index = cells.findIndex((c) => c.coordinate === coordinate);
  if (index === -1) return 0;
  return index * CELL_HEIGHT;
}

// On mount, prepend PAGE_SIZE cells above coordinate 0 and offset scrollTop
// by their total height so the viewport still shows coordinate 0 at the top
// but the user has scroll range above it immediately.
onMounted(async () => {
  // Register the imperative scroll callback with the store so TrimButton
  // (and any other component) can scroll this viewport without DOM access.
  store.registerScrollTo(async (coordinate: number) => {
    if (!scrollEl.value) return;
    // Wait for Vue to repaint after windowStart/windowSize changes before
    // converting the coordinate to a pixel offset.
    await nextTick();
    if (!scrollEl.value) return;
    scrollEl.value.scrollTop = coordinateToScrollTop(coordinate);
    updateVisibleRange();
  });

  windowStart.value -= PAGE_SIZE;
  await nextTick();
  if (scrollEl.value) {
    scrollEl.value.scrollTop = SENTINEL_HEIGHT;
  }
  updateVisibleRange();
});

async function onScroll() {
  updateVisibleRange();
  const el = scrollEl.value;
  if (!el) return;

  const { scrollTop, scrollHeight, clientHeight } = el;
  const distanceFromBottom = scrollHeight - scrollTop - clientHeight;

  // ── Scroll near bottom → expand window downward ──────────────────────────
  if (distanceFromBottom < SCROLL_THRESHOLD) {
    windowSize.value += PAGE_SIZE;
    // No scroll-position compensation needed: content grows below the current
    // view so scrollTop stays valid.
  }

  // ── Scroll near top → expand window upward ───────────────────────────────
  if (scrollTop < SCROLL_THRESHOLD && windowStart.value > 0 - PAGE_SIZE * 100) {
    const addedCells = PAGE_SIZE;
    const addedHeight = addedCells * CELL_HEIGHT;

    // Capture position before the DOM update.
    const scrollTopBefore = el.scrollTop;

    windowStart.value -= addedCells;

    // After Vue repaints, restore scrollTop + the height we prepended so the
    // viewport stays on the same cell and doesn't jump to the top.
    await nextTick();
    el.scrollTop = scrollTopBefore + addedHeight;
  }
}
</script>

<template>
  <div class="world-grid">
    <!-- Overflow indicators overlay — sits above the scroll container, pinned to the ruler strip -->
    <div class="ruler-overlay" aria-hidden="true">
      <div
        class="ruler__overflow-indicator ruler__overflow-indicator--above"
        :class="{ 'ruler__overflow-indicator--active': hasDeployedAboveWindow }"
        title="Deployed entity above visible area"
      >
        ▲
      </div>
      <div
        class="ruler__overflow-indicator ruler__overflow-indicator--below"
        :class="{ 'ruler__overflow-indicator--active': hasDeployedBelowWindow }"
        title="Deployed entity below visible area"
      >
        ▼
      </div>
    </div>

    <!-- Scroll viewport -->
    <div ref="scrollEl" class="world-grid__body" @scroll.passive="onScroll">
      <!-- Scroll content: ruler + cell list side by side -->
      <div class="world-grid__inner">
        <!-- Ruler -->
        <div class="ruler" aria-hidden="true">
          <div
            v-for="{ cell, kind } in ticks"
            :key="cell.coordinate"
            class="ruler__row"
          >
            <div :class="['ruler__tick', `ruler__tick--${kind}`]" />
          </div>
        </div>

        <!-- Cell list -->
        <div class="world-grid__list">
          <WorldCellSlot
            v-for="{ cell } in ticks"
            :key="cell.coordinate"
            :cell="cell"
            :channel="props.channel"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* ---------- layout shell ---------- */
.world-grid {
  position: relative;
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

/* ---------- ruler overflow indicators ---------- */
.ruler-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 14px;
  height: 100%;
  pointer-events: none;
  z-index: 10;
}

.ruler__overflow-indicator {
  position: absolute;
  left: 2px;
  width: 100%;
  height: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  color: transparent;
  transition: color 0.2s ease, opacity 0.2s ease;
}

.ruler__overflow-indicator--above {
  top: 0;
}

.ruler__overflow-indicator--below {
  bottom: 0;
}

.ruler__overflow-indicator--active {
  color: var(--color-fac-orange, #e8a020);
  animation: indicator-pulse 1.5s ease-in-out infinite;
}

@keyframes indicator-pulse {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.35;
  }
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
