<script setup lang="ts">
import { ref, watch, computed } from "vue";
import type { InventoryGridSlot } from "@/types/index.ts";
import { usePlayerStore } from "@/store/player.ts";
import ItemSprite from "@/Sprites/ItemSprite.vue";

const updated = ref(false);
const props = defineProps<{ gridSlot: InventoryGridSlot }>();
const store = usePlayerStore();

const isSelected = computed(
  () => store.selectedSlotIndex === props.gridSlot.slot.slot
);

const hasItem = computed(() => !!props.gridSlot.slot.inventoryItem?.type);

const itemCount = computed(
  () => props.gridSlot.slot.inventoryItem?.count ?? null
);

watch(props.gridSlot, () => {
  updated.value = true;
  setTimeout(() => {
    updated.value = false;
  }, 500);
});
</script>

<template>
  <div
    class="fac-slot"
    :class="{ selected: isSelected }"
    @click="store.selectSlot(props.gridSlot.slot.slot)"
    :title="gridSlot.slot.inventoryItem?.type ?? ''"
  >
    <!-- Item sprite -->
    <div
      v-if="hasItem"
      style="position: absolute; inset: 2px; pointer-events: none"
    >
      <ItemSprite :item-type="gridSlot.slot.inventoryItem?.type" />
    </div>

    <!-- Item count badge -->
    <span v-if="hasItem && itemCount !== null" class="fac-slot-count">
      {{ itemCount }}
    </span>

    <!-- Updated flash overlay -->
    <Transition name="fade">
      <div v-if="updated" class="fac-slot-flash"></div>
    </Transition>
  </div>
</template>
