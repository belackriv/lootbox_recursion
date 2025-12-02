<script setup lang="ts">
import type { InventorySlot } from "@/types/index.ts";
import InventoryItemSlot from "@/Shared/InventoryItemSlot.vue";

defineProps<{ slots: Array<InventorySlot> }>();
</script>

<template>
    <div class="border-s-slate-900 border-2 flex w-161 bg-slate-300">
        <InventoryItemSlot
            v-for="(slot, index) in slots"
            :key="index"
            :slot="slot"
        />
    </div>
</template>
