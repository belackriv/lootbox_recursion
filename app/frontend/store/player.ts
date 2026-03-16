import { ref, computed } from "vue";
import { defineStore } from "pinia";
import {
  PlayerAction,
  PlayerActionData,
  //  InventoryItem,
  InventoryMutation,
  InventorySlot,
  InventoryGridSlot,
  CraftingCost,
  WorldCell,
  PlacedEntity,
  WORLD_GRID_SIZE,
  PLACEABLE_ITEM_TYPES,
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

const defaultWorldCells: Array<WorldCell> = Array.from(
  { length: WORLD_GRID_SIZE },
  (_, i) => ({ index: i, placedEntity: null })
);

export type TooltipCostRow = {
  label: string;
  amount: number;
  canAfford: boolean;
};

export type TooltipContent = {
  title: string;
  body: string;
  costs?: Array<TooltipCostRow>;
};

export const usePlayerStore = defineStore("player", () => {
  const inventory = ref({ rows: inventoryRows });
  const availableActions = ref(defaultActions);
  const selectedSlotIndex = ref<number | null>(null);
  const selectedWorldCellIndex = ref<number | null>(null);
  const hoveredTooltip = ref<TooltipContent | null>(null);
  const craftingInProgress = ref<boolean>(false);
  const worldCells = ref<Array<WorldCell>>(
    defaultWorldCells.map((c) => ({ ...c }))
  );

  // Reactive map of item type → total count across all inventory slots.
  const inventoryTotals = computed<Record<string, number>>(() => {
    const totals: Record<string, number> = {};
    for (const row of inventory.value.rows) {
      for (const gridSlot of row) {
        const item = gridSlot.slot.inventoryItem;
        if (item?.type && item.count > 0) {
          totals[item.type] = (totals[item.type] ?? 0) + item.count;
        }
      }
    }
    return totals;
  });

  // Returns true when the player has enough of every material in the given cost.
  const canAfford = (cost: CraftingCost | null | undefined): boolean => {
    if (!cost) return true;
    return (
      (inventoryTotals.value["WoodInventoryItem"] ?? 0) >= cost.wood &&
      (inventoryTotals.value["IronInventoryItem"] ?? 0) >= cost.iron
    );
  };

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

  const selectWorldCell = (index: number) => {
    selectedWorldCellIndex.value =
      selectedWorldCellIndex.value === index ? null : index;
  };

  // Returns true when the currently selected inventory item is placeable
  const selectedItemIsPlaceable = computed(() => {
    const item = selectedSlotItem.value;
    if (!item?.type) return false;
    return PLACEABLE_ITEM_TYPES.includes(item.type);
  });

  // Returns true when placing is possible: a placeable item AND an empty world cell are both selected
  const canPlaceSelected = computed(() => {
    if (!selectedItemIsPlaceable.value) return false;
    if (selectedWorldCellIndex.value === null) return false;
    const cell = worldCells.value[selectedWorldCellIndex.value];
    return cell !== undefined && cell.placedEntity === null;
  });

  const placeSelectedEntity = () => {
    if (!canPlaceSelected.value) return;
    const item = selectedSlotItem.value!;
    const cellIndex = selectedWorldCellIndex.value!;

    worldCells.value[cellIndex] = {
      index: cellIndex,
      placedEntity: {
        type: item.type,
        displayName: item.displayName ?? null,
        tooltip: item.tooltip ?? null,
      } as PlacedEntity,
    };

    // Deselect both after placement
    selectedSlotIndex.value = null;
    selectedWorldCellIndex.value = null;
  };

  const removeEntityFromCell = (index: number) => {
    if (worldCells.value[index]) {
      worldCells.value[index] = { index, placedEntity: null };
    }
    if (selectedWorldCellIndex.value === index) {
      selectedWorldCellIndex.value = null;
    }
  };

  const setTooltip = (content: TooltipContent) => {
    hoveredTooltip.value = content;
  };

  const clearTooltip = () => {
    hoveredTooltip.value = null;
  };

  const startCrafting = () => {
    craftingInProgress.value = true;
  };

  const finishCrafting = () => {
    craftingInProgress.value = false;
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
    selectedWorldCellIndex,
    hoveredTooltip,
    craftingInProgress,
    worldCells,
    selectSlot,
    selectWorldCell,
    selectedSlotItem,
    selectedItemIsPlaceable,
    canPlaceSelected,
    placeSelectedEntity,
    removeEntityFromCell,
    inventoryTotals,
    canAfford,
    setTooltip,
    clearTooltip,
    startCrafting,
    finishCrafting,
    updateAvailableActions,
    updateInventory,
    mutateInventory,
    snapshotInventory,
    performPlayerAction,
  };
});
