<script setup lang="ts">
import { computed, defineAsyncComponent } from "vue";

const props = defineProps<{ itemType: string | null | undefined }>();

const spriteMap: Record<string, ReturnType<typeof defineAsyncComponent>> = {
  WoodInventoryItem: defineAsyncComponent(
    () => import("@/Sprites/WoodInventoryItem.vue")
  ),
  IronInventoryItem: defineAsyncComponent(
    () => import("@/Sprites/IronInventoryItem.vue")
  ),
  LootBoxInventoryItem: defineAsyncComponent(
    () => import("@/Sprites/LootBoxInventoryItem.vue")
  ),
  IrradiationEnclosureInventoryItem: defineAsyncComponent(
    () => import("@/Sprites/IrradiationEnclosureInventoryItem.vue")
  ),
  IrradiationEnclosure: defineAsyncComponent(
    () => import("@/Sprites/IrradiationEnclosureInventoryItem.vue")
  ),
  UnknownInventoryItem: defineAsyncComponent(
    () => import("@/Sprites/UnknownInventoryItem.vue")
  ),
};

const spriteComponent = computed(() => {
  if (!props.itemType) return null;
  return spriteMap[props.itemType] ?? spriteMap["UnknownInventoryItem"];
});
</script>

<template>
  <component v-if="spriteComponent" :is="spriteComponent" />
</template>
