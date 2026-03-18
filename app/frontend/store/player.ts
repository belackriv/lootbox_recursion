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
  WorldCellUpdatePayload,
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
  const selectedWorldCellCoordinate = ref<number | null>(null);
  const hoveredTooltip = ref<TooltipContent | null>(null);
  const craftingInProgress = ref<boolean>(false);

  // World cells are keyed by their signed integer coordinate.
  // This supports negative coordinates and sparse/scrollable windows —
  // entries are added/removed as the player scrolls.
  const worldCells = ref<Map<number, WorldCell>>(new Map());

  // The visible window defines which coordinates are always shown, empty or
  // not. windowStart is the first coordinate; windowSize is how many cells
  // are in the window. Both can be updated as the player scrolls.
  const windowStart = ref<number>(0);
  const windowSize = ref<number>(32);
  const DEFAULT_WINDOW_START = 0;
  const DEFAULT_WINDOW_SIZE = 32;
  const TRIM_LEAD_CELLS = 4; // empty cells to show above the first placed entity

  // Callback registered by WorldGrid so the store can imperatively scroll it.
  // TrimButton calls scrollToCoordinate without needing access to the DOM ref.
  let _scrollToCoordinate: ((coordinate: number) => void) | null = null;

  const registerScrollTo = (fn: (coordinate: number) => void) => {
    _scrollToCoordinate = fn;
  };

  const scrollToCoordinate = (coordinate: number) => {
    _scrollToCoordinate?.(coordinate);
  };

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

  const selectWorldCell = (coordinate: number) => {
    selectedWorldCellCoordinate.value =
      selectedWorldCellCoordinate.value === coordinate ? null : coordinate;
  };

  // Returns true when the currently selected inventory item is placeable.
  const selectedItemIsPlaceable = computed(() => {
    const item = selectedSlotItem.value;
    if (!item?.type) return false;
    return PLACEABLE_ITEM_TYPES.includes(item.type);
  });

  // Returns the WorldCell for the currently selected coordinate, or null.
  // Useful for inspecting what's at the selected cell (e.g. showing details,
  // future interactions) — not used for deploy flow.
  const selectedWorldCell = computed((): WorldCell | null => {
    if (selectedWorldCellCoordinate.value === null) return null;
    return worldCells.value.get(selectedWorldCellCoordinate.value) ?? null;
  });

  // Optimistically places the selected entity into the selected world cell,
  // then fires the deploy action over the channel. The server will confirm
  // (or correct) via a world_cell_update broadcast.
  const placeSelectedEntity = (
    coordinate: number,
    channel: PlayerActionsChannel | undefined
  ) => {
    if (!selectedItemIsPlaceable.value) return;
    const item = selectedSlotItem.value!;
    const cellCoordinate = coordinate;
    const slotNumber = selectedSlotIndex.value!;

    // Optimistic update — place entity in world cell
    worldCells.value.set(cellCoordinate, {
      coordinate: cellCoordinate,
      placedEntity: {
        type: item.type,
        displayName: item.displayName ?? null,
        tooltip: item.tooltip ?? null,
      } as PlacedEntity,
    });
    // Trigger Map reactivity — replace the ref value with a new Map instance
    worldCells.value = new Map(worldCells.value);

    // Optimistic update — immediately clear the inventory slot.
    // The server will broadcast an inventory_mutation confirming the removal;
    // if the deploy fails the server broadcast will restore the item.
    const rowIndex = Math.floor(slotNumber / inventoryRowLength);
    const columnIndex = slotNumber % inventoryRowLength;
    if (
      inventory.value.rows[rowIndex] &&
      inventory.value.rows[rowIndex][columnIndex]
    ) {
      inventory.value.rows[rowIndex][columnIndex].slot.inventoryItem = null;
    }

    // Deselect inventory slot
    selectedSlotIndex.value = null;

    // Fire over the channel — send only the action name, not the full action object
    if (channel) {
      channel.send({ name: "deploy" } as PlayerAction, {
        slotNumber,
        cellCoordinate,
      });
    }
  };

  const removeEntityFromCell = (
    coordinate: number,
    channel: PlayerActionsChannel | undefined
  ) => {
    const existing = worldCells.value.get(coordinate);
    if (existing) {
      // Optimistic update — clear the world cell immediately.
      // The server will confirm (or rollback) via a world_cell_update broadcast.
      worldCells.value.set(coordinate, { coordinate, placedEntity: null });
      worldCells.value = new Map(worldCells.value);

      // Optimistic update — restore the item to the first empty inventory slot.
      // The server will confirm (or correct) via an inventory_mutations broadcast.
      const placedEntity = existing.placedEntity;
      if (placedEntity) {
        // Find the first empty slot across all rows
        let placed = false;
        outer: for (const row of inventory.value.rows) {
          for (const gridSlot of row) {
            if (gridSlot.slot.inventoryItem === null) {
              gridSlot.slot.inventoryItem = {
                type: placedEntity.type,
                count: 1,
                displayName: placedEntity.displayName ?? null,
                tooltip: placedEntity.tooltip ?? null,
              };
              placed = true;
              break outer;
            }
          }
        }
        if (!placed) {
          // No empty slot found — the server broadcast will handle it.
          // This is an edge case; the server enforces inventory space too.
        }
      }
    }

    if (selectedWorldCellCoordinate.value === coordinate) {
      selectedWorldCellCoordinate.value = null;
    }

    // Fire recall over the channel
    if (channel) {
      channel.send({ name: "recall" } as PlayerAction, {
        cellCoordinate: coordinate,
      });
    }
  };

  // Update a single world cell from a server broadcast.
  const updateWorldCell = (payload: WorldCellUpdatePayload) => {
    const coordinate =
      (payload as any).coordinate ?? (payload as any).world_coordinate ?? null;
    if (coordinate === null) return;

    const rawEntity =
      (payload as any).placedEntity ?? (payload as any).placed_entity ?? null;

    const placedEntity: PlacedEntity | null = rawEntity
      ? {
          type: rawEntity.type ?? null,
          displayName: rawEntity.displayName ?? rawEntity.display_name ?? null,
          tooltip: rawEntity.tooltip ?? null,
        }
      : null;

    worldCells.value.set(coordinate, { coordinate, placedEntity });
    worldCells.value = new Map(worldCells.value);
  };

  // Hydrate the world cell map from the server's initial props or a bulk snapshot.
  // Each entry should have { coordinate, placedEntity } (or snake_case equivalents).
  const snapshotWorldCells = (cells: Array<any>) => {
    const next = new Map<number, WorldCell>(worldCells.value);
    for (const raw of cells) {
      const coordinate = raw.coordinate ?? raw.world_coordinate ?? null;
      if (coordinate === null) continue;

      const rawEntity = raw.placedEntity ?? raw.placed_entity ?? null;
      const placedEntity: PlacedEntity | null = rawEntity
        ? {
            type: rawEntity.type ?? null,
            displayName:
              rawEntity.displayName ?? rawEntity.display_name ?? null,
            tooltip: rawEntity.tooltip ?? null,
          }
        : null;

      next.set(coordinate, { coordinate, placedEntity });
    }
    worldCells.value = next;
  };

  // Returns all currently known world cells sorted by coordinate ascending.
  // Always includes every coordinate in the visible window (as empty cells
  // if nothing is placed there). If any placed entity lies beyond the window
  // end, the filled range is extended to that coordinate so there are no gaps
  // in the rendered list. Components should use this for rendering.
  const sortedWorldCells = computed((): Array<WorldCell> => {
    const merged = new Map<number, WorldCell>(worldCells.value);

    // Find the furthest coordinate that has a placed entity, if any.
    let maxPlacedCoord = windowStart.value + windowSize.value - 1;
    for (const cell of worldCells.value.values()) {
      if (cell.placedEntity !== null && cell.coordinate > maxPlacedCoord) {
        maxPlacedCoord = cell.coordinate;
      }
    }

    // Fill every coordinate from windowStart up to and including the furthest
    // relevant coordinate (window end or a placed entity beyond it).
    const end = Math.max(
      windowStart.value + windowSize.value,
      maxPlacedCoord + 1
    );
    for (let coord = windowStart.value; coord < end; coord++) {
      if (!merged.has(coord)) {
        merged.set(coord, { coordinate: coord, placedEntity: null });
      }
    }

    return Array.from(merged.values()).sort(
      (a, b) => a.coordinate - b.coordinate
    );
  });

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

  // Scrolls to the first placed entity (with TRIM_LEAD_CELLS empty cells above
  // it), then trims excess empty cells that were generated by scrolling.
  // If no placed entities exist, falls back to the default window at coordinate 0.
  const trimWorldCells = () => {
    // Find the coordinate of the first (lowest) placed entity.
    let firstPlacedCoord: number | null = null;
    for (const cell of worldCells.value.values()) {
      if (cell.placedEntity !== null) {
        if (firstPlacedCoord === null || cell.coordinate < firstPlacedCoord) {
          firstPlacedCoord = cell.coordinate;
        }
      }
    }

    // New window starts TRIM_LEAD_CELLS above the first entity (or default).
    const newStart =
      firstPlacedCoord !== null
        ? firstPlacedCoord - TRIM_LEAD_CELLS
        : DEFAULT_WINDOW_START;

    windowStart.value = newStart;
    windowSize.value = DEFAULT_WINDOW_SIZE;

    // Drop map entries that are both outside the new window AND have no
    // placed entity — they were generated purely by scrolling.
    const next = new Map<number, WorldCell>();
    for (const [coord, cell] of worldCells.value) {
      const inWindow =
        coord >= newStart && coord < newStart + DEFAULT_WINDOW_SIZE;
      if (inWindow || cell.placedEntity !== null) {
        next.set(coord, cell);
      }
    }
    worldCells.value = next;

    // Scroll the WorldGrid viewport so windowStart is at the top.
    scrollToCoordinate(newStart);
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
    selectedWorldCellCoordinate,
    hoveredTooltip,
    craftingInProgress,
    worldCells,
    windowStart,
    windowSize,
    sortedWorldCells,
    selectSlot,
    selectWorldCell,
    selectedSlotItem,
    selectedWorldCell,
    selectedItemIsPlaceable,
    placeSelectedEntity,
    removeEntityFromCell,
    updateWorldCell,
    snapshotWorldCells,
    trimWorldCells,
    registerScrollTo,
    scrollToCoordinate,
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
