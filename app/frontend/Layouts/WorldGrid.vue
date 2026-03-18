<script setup lang="ts">
import { computed, ref, nextTick, onMounted } from "vue";
import { storeToRefs } from "pinia";
import type { WorldCell } from "@/types/index.ts";
import { usePlayerStore } from "@/store/player.ts";
import WorldCellSlot from "@/Shared/WorldCellSlot.vue";
import PlayerActionsChannel from "@/channels/playerActions.ts";

const props = defineProps<{
  channel: PlayerActionsChannel | undefined;
}>();

const store = usePlayerStore();
const { sortedWorldCells, windowStart, windowSize } = storeToRefs(store);

// How many cells to add each time the user scrolls to an edge.
const PAGE_SIZE = 16;
// Each cell is 48px tall with a 2px gap below it.
const CELL_HEIGHT = 50;
// How many pixels from the edge triggers an expansion.
const SCROLL_THRESHOLD = CELL_HEIGHT * 4;

const scrollEl = ref<HTMLElement | null>(null);

// Height of the sentinel buffer prepended on mount so the user can scroll
// upward immediately. Equals exactly one page worth of cells.
const SENTINEL_HEIGHT = PAGE_SIZE * CELL_HEIGHT;

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
  });

  windowStart.value -= PAGE_SIZE;
  await nextTick();
  if (scrollEl.value) {
    scrollEl.value.scrollTop = SENTINEL_HEIGHT;
  }
});

async function onScroll() {
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
