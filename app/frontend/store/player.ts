import { ref, computed } from "vue";
import { defineStore } from "pinia";
import {
  PlayerAction,
  PlayerActionData,
  //  InventoryItem,
  InventoryMutation,
  InventorySlot,
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

export type TooltipContent = {
  title: string;
  body: string;
};

export const usePlayerStore = defineStore("player", () => {
  const inventory = ref({ rows: inventoryRows });
  const availableActions = ref(defaultActions);
  const selectedSlotIndex = ref<number | null>(null);
  const hoveredTooltip = ref<TooltipContent | null>(null);

  const selectSlot = (slotNumber: number) => {
    selectedSlotIndex.value =
      selectedSlotIndex.value === slotNumber ? null : slotNumber;
  };

  const selectedSlotItem = computed(() => {
    if (selectedSlotIndex.value === null) return null;
    const slotNumber = selectedSlotIndex.value;
    const rowIndex = Math.floor(slotNumber / inventoryRowLength);
    const columnIndex = slotNumber % inventoryRowLength;
    return (
      inventory.value.rows[rowIndex]?.[columnIndex]?.slot?.inventoryItem ?? null
    );
  });

  const setTooltip = (content: TooltipContent) => {
    hoveredTooltip.value = content;
  };

  const clearTooltip = () => {
    hoveredTooltip.value = null;
  };

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
    for (let i = 0; i < (inventoryMutations ?? []).length; i++) {
      const mutation = inventoryMutations[i] as any;

      // skip unapplied mutations
      const applied =
        mutation.applied ?? mutation.applied === undefined
          ? true
          : mutation.applied;
      if (!applied) {
        continue;
      }

      // Support both camelCase and snake_case payloads from the server
      const invSlot = mutation.inventorySlot ?? mutation.inventory_slot ?? null;
      const slotNumber =
        invSlot?.slot ??
        mutation.slot ??
        (invSlot?.id ? invSlot?.slot : undefined);

      if (slotNumber === undefined || slotNumber === null) {
        // nothing we can do without a slot number
        continue;
      }

      const rowIndex = Math.floor(slotNumber / inventoryRowLength);
      const columnIndex = slotNumber % inventoryRowLength;

      // Defensive: ensure row/col exist
      if (
        !inventory.value.rows[rowIndex] ||
        !inventory.value.rows[rowIndex][columnIndex]
      ) {
        continue;
      }

      const gridSlot = inventory.value.rows[rowIndex][columnIndex];

      // Prefer the server-sent inventory item payload if present
      const serverItem =
        invSlot?.inventoryItem ?? invSlot?.inventory_item ?? null;

      if (serverItem === null) {
        // If server didn't include the nested item, fallback to itemType/delta
        const itemType = mutation.itemType ?? mutation.item_type ?? null;
        const delta = mutation.delta ?? 0;

        if (itemType && delta) {
          // If there is already an item of this type in the slot, update its count
          const existing = gridSlot.slot.inventoryItem;
          if (existing && existing.type === itemType) {
            const newCount = (existing.count ?? 0) + delta;
            if (newCount <= 0) {
              // replace reference with null so watchers/reactivity see the change
              gridSlot.slot.inventoryItem = null;
            } else {
              // replace the object reference with a new object so Vue reactivity
              // and reference-based watchers are triggered
              gridSlot.slot.inventoryItem = {
                type: existing.type,
                count: newCount,
              };
            }
          } else if (delta > 0) {
            // create new inventory item representation (new object reference)
            gridSlot.slot.inventoryItem = { type: itemType, count: delta };
          } else {
            // negative delta but no existing item -> nothing to do
          }
        } else {
          // If no more details, and delta indicates removal, clear the slot
          if ((mutation.delta ?? 0) < 0) {
            gridSlot.slot.inventoryItem = null;
          }
        }
      } else {
        // server provided full item; normalize keys and assign
        const normalized = {
          type:
            serverItem.type ??
            serverItem["type"] ??
            serverItem["_type"] ??
            null,
          count: serverItem.count ?? serverItem["count"] ?? 0,
          displayName:
            serverItem.displayName ?? serverItem["display_name"] ?? null,
          tooltip: serverItem.tooltip ?? null,
        } as any;

        // If count is zero or null, clear the slot
        if (!normalized.type || !normalized.count) {
          gridSlot.slot.inventoryItem = null;
        } else {
          // assign normalized (new object) to ensure watchers/reactivity pick up change
          gridSlot.slot.inventoryItem = normalized;
        }
      }

      // Ensure slot metadata is in sync
      gridSlot.slot.slot = slotNumber;
    }
  };

  const snapshotInventory = (slots: Array<InventorySlot>) => {
    for (const serverSlot of slots) {
      // Support both camelCase and snake_case keys from server
      const slotNumber = (serverSlot as any).slot;
      if (slotNumber === undefined || slotNumber === null) continue;

      const rowIndex = Math.floor(slotNumber / inventoryRowLength);
      const columnIndex = slotNumber % inventoryRowLength;

      if (
        !inventory.value.rows[rowIndex] ||
        !inventory.value.rows[rowIndex][columnIndex]
      ) {
        continue;
      }

      const gridSlot = inventory.value.rows[rowIndex][columnIndex];
      const serverItem =
        (serverSlot as any).inventoryItem ??
        (serverSlot as any).inventory_item ??
        null;

      if (serverItem && serverItem.type && serverItem.count > 0) {
        gridSlot.slot.inventoryItem = {
          type: serverItem.type,
          count: serverItem.count,
          displayName:
            serverItem.displayName ?? serverItem["display_name"] ?? null,
          tooltip: serverItem.tooltip ?? null,
        };
      } else {
        gridSlot.slot.inventoryItem = null;
      }

      gridSlot.slot.slot = slotNumber;
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
    selectedSlotIndex,
    hoveredTooltip,
    selectSlot,
    selectedSlotItem,
    setTooltip,
    clearTooltip,
    updateAvailableActions,
    updateInventory,
    mutateInventory,
    snapshotInventory,
    performPlayerAction,
  };
});
