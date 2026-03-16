import { describe, it, expect, beforeEach, vi, afterEach } from "vitest";
import { createPinia, setActivePinia } from "pinia";
import { usePlayerStore, inventoryRowLength } from "../../../store/player";

type RawMutation = any;

function getGridSlot(
  store: ReturnType<typeof usePlayerStore>,
  slotNumber: number
) {
  const rowIndex = Math.floor(slotNumber / inventoryRowLength);
  const columnIndex = slotNumber % inventoryRowLength;
  return store.inventory.rows[rowIndex][columnIndex];
}

describe("player store - mutateInventory", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("applies a nested inventory_slot + inventory_item payload", () => {
    const store = usePlayerStore();

    const targetSlot = 3;
    const gridSlot = getGridSlot(store, targetSlot);
    // start empty
    expect(gridSlot.slot.inventoryItem).toBeNull();

    const mutations: RawMutation[] = [
      {
        inventory_slot: {
          slot: targetSlot,
          inventory_item: { type: "IronInventoryItem", count: 2 },
        },
        applied: true,
      },
    ];

    store.mutateInventory(mutations as any);

    const updated = getGridSlot(store, targetSlot).slot.inventoryItem;
    expect(updated).not.toBeNull();
    expect(updated).toMatchObject({ type: "IronInventoryItem", count: 2 });
  });

  it("applies item_type + delta to update an existing stack", () => {
    const store = usePlayerStore();

    const targetSlot = 5;
    const gridSlot = getGridSlot(store, targetSlot);

    // seed existing item
    gridSlot.slot.inventoryItem = {
      type: "IronInventoryItem",
      count: 1,
    } as any;

    const mutations: RawMutation[] = [
      {
        inventory_slot: { slot: targetSlot },
        item_type: "IronInventoryItem",
        delta: 2,
        applied: true,
      },
    ];

    store.mutateInventory(mutations as any);

    const updated = getGridSlot(store, targetSlot).slot.inventoryItem;
    expect(updated).not.toBeNull();
    expect((updated as any).type).toBe("IronInventoryItem");
    expect((updated as any).count).toBe(3);
  });

  it("removes item when delta reduces count to zero", () => {
    const store = usePlayerStore();

    const targetSlot = 7;
    const gridSlot = getGridSlot(store, targetSlot);

    // seed existing item with count 2
    gridSlot.slot.inventoryItem = {
      type: "WoodInventoryItem",
      count: 2,
    } as any;

    const mutations: RawMutation[] = [
      {
        inventory_slot: { slot: targetSlot },
        item_type: "WoodInventoryItem",
        delta: -2,
        applied: true,
      },
    ];

    store.mutateInventory(mutations as any);

    const updated = getGridSlot(store, targetSlot).slot.inventoryItem;
    expect(updated).toBeNull();
  });

  it("skips mutations marked as not applied", () => {
    const store = usePlayerStore();

    const targetSlot = 8;
    const gridSlot = getGridSlot(store, targetSlot);

    // ensure empty initially
    gridSlot.slot.inventoryItem = null;
    expect(gridSlot.slot.inventoryItem).toBeNull();

    const mutations: RawMutation[] = [
      {
        inventory_slot: {
          slot: targetSlot,
          inventory_item: { type: "IronInventoryItem", count: 5 },
        },
        applied: false,
      },
    ];

    store.mutateInventory(mutations as any);

    // still unchanged because mutation was not applied
    const after = getGridSlot(store, targetSlot).slot.inventoryItem;
    expect(after).toBeNull();
  });

  describe("player store - craftingInProgress", () => {
    beforeEach(() => {
      setActivePinia(createPinia());
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("craftingInProgress is false by default", () => {
      const store = usePlayerStore();
      expect(store.craftingInProgress).toBe(false);
    });

    it("startCrafting sets craftingInProgress to true", () => {
      const store = usePlayerStore();
      store.startCrafting();
      expect(store.craftingInProgress).toBe(true);
    });

    it("finishCrafting sets craftingInProgress back to false", () => {
      const store = usePlayerStore();
      store.startCrafting();
      store.finishCrafting();
      expect(store.craftingInProgress).toBe(false);
    });

    it("finishCrafting is a no-op when crafting was never started", () => {
      const store = usePlayerStore();
      store.finishCrafting();
      expect(store.craftingInProgress).toBe(false);
    });

    it("craftingInProgress can be toggled on and off multiple times", () => {
      const store = usePlayerStore();

      store.startCrafting();
      expect(store.craftingInProgress).toBe(true);

      store.finishCrafting();
      expect(store.craftingInProgress).toBe(false);

      store.startCrafting();
      expect(store.craftingInProgress).toBe(true);

      store.finishCrafting();
      expect(store.craftingInProgress).toBe(false);
    });
  });
});
