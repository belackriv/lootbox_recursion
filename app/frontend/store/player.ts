import { ref } from "vue";
import { defineStore } from "pinia";
import {
  PlayerAction,
  PlayerActionData,
  InventoryItem,
  InventoryMutation,
  InventorySlot,
} from "../types/index.ts";
import PlayerActionsChannel from "@/channels/playerActions.ts";

export const inventoryRowCount = 5;
export const inventoryRowLength = 10;
const inventoryRows: Array<Array<InventorySlot>> = [];

for (let row = 0; row < inventoryRowCount; row++) {
  const inventoryRow: Array<InventorySlot> = [];
  for (let col = 0; col < inventoryRowLength; col++) {
    inventoryRow.push({
      item: null,
      slot: row * inventoryRowLength + col,
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
    updatedAvailableActions: Array<PlayerAction>,
  ) => {
    availableActions.value = updatedAvailableActions;
  };

  const updateInventory = (
    updatedInventoryRows: Array<Array<InventorySlot>>,
  ) => {
    inventory.value.rows = updatedInventoryRows;
  };

  const mutateInventory = (inventoryMutations: Array<InventoryMutation>) => {
    for (let i = 0; i < inventoryMutations.length; i++) {
      const { delta, slot, itemType, applied } = inventoryMutations[i];
      if (!applied) {
        continue;
      }
      const rowIndex = Math.floor(slot / inventoryRowLength);
      const columnIndex = slot % inventoryRowLength;

      if (!inventory.value.rows[rowIndex][columnIndex].item && itemType) {
        inventory.value.rows[rowIndex][columnIndex].item = {
          type: itemType,
          slot: slot,
          count: 0,
        };
      }
      if (inventory.value.rows[rowIndex][columnIndex].item) {
        inventory.value.rows[rowIndex][columnIndex].item.count += delta;
      }
    }
  };

  const performPlayerAction = (
    action: PlayerAction,
    data: PlayerActionData | null | undefined,
    channel: PlayerActionsChannel | undefined,
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
