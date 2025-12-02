<script setup lang="ts">
import { onMounted } from "vue";
import { usePlayerStore, inventoryRowLength } from "@/store/player.ts";
import type { InventoryItem } from "@/types/index.ts";
import InventoryRow from "@/Shared/InventoryRow.vue";

const props = defineProps<{ inventoryItems: Array<InventoryItem> }>();
const store = usePlayerStore();

onMounted(() => {
    for (let i = 0; i < props.inventoryItems.length; i++) {
        const slotNumber = props.inventoryItems[i].slot;
        const rowIndex = Math.floor(slotNumber / inventoryRowLength);
        const columnIndex = slotNumber % inventoryRowLength;
        store.inventory.rows[rowIndex][columnIndex].item =
            props.inventoryItems[i];
    }
});
</script>

<template>
    <InventoryRow
        v-for="(row, index) in store.inventory.rows"
        :slots="row"
        :key="index"
    />
</template>
