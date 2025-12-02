<script setup lang="ts">
import ActionBar from "@/Layouts/ActionBar.vue";
import InventoryGrid from "@/Layouts/InventoryGrid.vue";
import { PlayerAction, InventoryItem } from "@/types/index.ts";

defineProps<{
    availableActions: Array<PlayerAction>;
    inventoryItems: Array<InventoryItem>;
}>();
</script>

<template>
    <div>
        <div>
            <h1>Actions</h1>
            <ActionBar :availableActions="availableActions" />
        </div>
        <div>
            <h1>Inventory</h1>
            <InventoryGrid :inventoryItems="inventoryItems" />
        </div>
    </div>
</template>
