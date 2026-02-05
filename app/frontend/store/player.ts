import { ref } from "vue";
import { defineStore } from "pinia";
import {
  PlayerAction,
  PlayerActionData,
  //  InventoryItem,
  InventoryMutation,
  //  InventorySlot,
  InventoryGridSlot,
} from "../types/index.ts";
import PlayerActionsChannel from "@/channels/playerActions.ts";

export const inventoryRowCount = 5;
export const inventoryRowLength = 10;
const inventoryRows: Array<Array<InventoryGridSlot>> = [];

for (let row = 0; row < inventoryRowCount; row++) {
  const inventoryRow: Array<InventoryGridSlot> = [];
  for (let col = 0; col < inventoryRowLength; col++) {
    inventoryRow.push({
      slot: {
        slot: row * inventoryRowLength + col,
        inventoryItem: null,
      },
      row: row,
      column: col,
    });
  }
  inventoryRows.push(inventoryRow);
}

const defaultActions: Array<PlayerAction> = [];

export const usePlayerStore = defineStore("player", () => {
  const inventory = ref({ rows: inventoryRows });
  const availableActions = ref(defaultActions);

  const updateAvailableActions = (
    updatedAvailableActions: Array<PlayerAction>
  ) => {
    availableActions.value = updatedAvailableActions;
  };

  const updateInventory = (
    updatedInventoryRows: Array<Array<InventoryGridSlot>>
  ) => {
    inventory.value.rows = updatedInventoryRows;
  };

  const mutateInventory = (inventoryMutations: Array<InventoryMutation>) => {
    for (let i = 0; i < inventoryMutations.length; i++) {
      const { delta, inventorySlot, itemType, applied } = inventoryMutations[i];
      if (!applied) {
        continue;
      }
    }
  };

  const performPlayerAction = (
    action: PlayerAction,
    data: PlayerActionData | null | undefined,
    channel: PlayerActionsChannel | undefined
  ) => {
    if (channel) {
      channel.send(action, data);
    }
  };

  return {
    inventory,
    availableActions,
    updateAvailableActions,
    updateInventory,
    mutateInventory,
    performPlayerAction,
  };
});
