<script setup lang="ts">
import { computed } from "vue";
import type { WorldCell } from "@/types/index.ts";
import { usePlayerStore } from "@/store/player.ts";
import ItemSprite from "@/Sprites/ItemSprite.vue";

const props = defineProps<{ cell: WorldCell }>();
const store = usePlayerStore();

const isSelected = computed(
  () => store.selectedWorldCellIndex === props.cell.index
);

const isEmpty = computed(() => props.cell.placedEntity === null);

const isPlacementTarget = computed(
  () => isEmpty.value && store.selectedItemIsPlaceable
);

const onMouseEnter = () => {
  const entity = props.cell.placedEntity;
  store.setTooltip({
    title: `Cell ${props.cell.index}`,
    body: entity
      ? (entity.displayName ?? entity.type) +
        (entity.tooltip ? `\n${entity.tooltip}` : "")
      : "Empty",
  });
};

const onMouseLeave = () => {
  store.clearTooltip();
};

const onClick = () => {
  // If a deployable item is selected and this cell is empty → deploy it immediately
  if (store.canPlaceSelected && isEmpty.value) {
    store.placeSelectedEntity();
    return;
  }
  store.selectWorldCell(props.cell.index);
};

const onRemove = (e: MouseEvent) => {
  e.stopPropagation();
  store.removeEntityFromCell(props.cell.index);
};
</script>

<template>
  <div
    class="world-cell"
    :class="{
      'world-cell--selected': isSelected,
      'world-cell--placement-target': isPlacementTarget && !isSelected,
      'world-cell--occupied': !isEmpty,
    }"
    @click="onClick"
    @mouseenter="onMouseEnter"
    @mouseleave="onMouseLeave"
  >
    <!-- Placed entity sprite -->
    <div v-if="!isEmpty" class="world-cell__sprite">
      <ItemSprite :item-type="cell.placedEntity!.type" />
    </div>

    <!-- Entity label -->
    <span v-if="!isEmpty" class="world-cell__label">
      {{ cell.placedEntity!.displayName ?? cell.placedEntity!.type }}
    </span>

    <!-- Empty slot hint when a placeable item is selected -->
    <span v-else-if="isPlacementTarget" class="world-cell__hint">
      ▸ deploy
    </span>

    <!-- Remove button (occupied cells only) -->
    <button
      v-if="!isEmpty"
      class="world-cell__remove"
      title="Remove deployed entity"
      @click="onRemove"
    >
      x
    </button>
  </div>
</template>

<style scoped>
.world-cell {
  position: relative;
  display: flex;
  align-items: center;
  gap: 6px;
  height: 48px;
  padding: 0 8px;
  border: 1px solid var(--color-fac-border, #3a3a2a);
  background: var(--color-fac-slot-bg, #1a1a12);
  cursor: pointer;
  transition: border-color 0.12s ease, background 0.12s ease;
  user-select: none;
}

.world-cell:hover {
  border-color: var(--color-fac-orange, #e8a020);
  background: var(--color-fac-slot-hover, #222218);
}

.world-cell--selected {
  border-color: var(--color-fac-orange, #e8a020);
  background: var(--color-fac-slot-selected, #2a2210);
  box-shadow: inset 0 0 6px rgba(232, 160, 32, 0.25);
}

.world-cell--placement-target {
  border-color: #4caf50;
  animation: pulse-green 1.2s ease-in-out infinite;
}

.world-cell--occupied {
  border-color: var(--color-fac-border-active, #5a5a3a);
}

@keyframes pulse-green {
  0%,
  100% {
    box-shadow: inset 0 0 0px rgba(76, 175, 80, 0);
  }
  50% {
    box-shadow: inset 0 0 8px rgba(76, 175, 80, 0.35);
  }
}

.world-cell__sprite {
  width: 48px;
  height: 48px;
  flex-shrink: 0;
  position: relative;
}

.world-cell__label {
  font-size: 0.72rem;
  color: var(--color-fac-text, #c8c8a0);
  letter-spacing: 0.04em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex: 1;
}

.world-cell__hint {
  font-size: 0.68rem;
  color: #4caf50;
  letter-spacing: 0.06em;
  font-style: italic;
  flex: 1;
}

.world-cell__remove {
  flex-shrink: 0;
  background: none;
  border: none;
  color: var(--color-fac-text-dark, #555544);
  font-size: 0.6rem;
  cursor: pointer;
  padding: 2px 4px;
  line-height: 1;
  border-radius: 2px;
  transition: color 0.1s ease, background 0.1s ease;
}

.world-cell__remove:hover {
  color: #ff6b6b;
  background: rgba(255, 107, 107, 0.12);
}
</style>
