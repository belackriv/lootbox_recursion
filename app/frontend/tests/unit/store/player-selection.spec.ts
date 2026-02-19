import { describe, it, expect, beforeEach } from "vitest";
import { createPinia, setActivePinia } from "pinia";
import { usePlayerStore, inventoryRowLength } from "../../../store/player";
import { LOOTBOX_ITEM_TYPE } from "../../../types/index";

function seedSlot(
  store: ReturnType<typeof usePlayerStore>,
  slotNumber: number,
  type: string,
  count: number
) {
  const rowIndex = Math.floor(slotNumber / inventoryRowLength);
  const columnIndex = slotNumber % inventoryRowLength;
  store.inventory.rows[rowIndex][columnIndex].slot.inventoryItem = {
    type,
    count,
  };
}

function clearSlot(
  store: ReturnType<typeof usePlayerStore>,
  slotNumber: number
) {
  const rowIndex = Math.floor(slotNumber / inventoryRowLength);
  const columnIndex = slotNumber % inventoryRowLength;
  store.inventory.rows[rowIndex][columnIndex].slot.inventoryItem = null;
}

describe("player store - slot selection", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  // ─── selectSlot / selectedSlotIndex ──────────────────────────────────────

  describe("selectSlot", () => {
    it("selectedSlotIndex starts as null", () => {
      const store = usePlayerStore();
      expect(store.selectedSlotIndex).toBeNull();
    });

    it("sets selectedSlotIndex to the clicked slot number", () => {
      const store = usePlayerStore();
      store.selectSlot(5);
      expect(store.selectedSlotIndex).toBe(5);
    });

    it("deselects the slot when the same slot number is clicked again (toggle)", () => {
      const store = usePlayerStore();
      store.selectSlot(5);
      store.selectSlot(5);
      expect(store.selectedSlotIndex).toBeNull();
    });

    it("replaces the previous selection when a different slot is clicked", () => {
      const store = usePlayerStore();
      store.selectSlot(3);
      store.selectSlot(7);
      expect(store.selectedSlotIndex).toBe(7);
    });

    it("only one slot is selected at a time", () => {
      const store = usePlayerStore();
      store.selectSlot(0);
      store.selectSlot(1);
      store.selectSlot(2);
      // only the last call should be reflected
      expect(store.selectedSlotIndex).toBe(2);
    });

    it("can select slot 0 (first slot)", () => {
      const store = usePlayerStore();
      store.selectSlot(0);
      expect(store.selectedSlotIndex).toBe(0);
    });

    it("can select the last slot in the grid", () => {
      const store = usePlayerStore();
      const lastSlot = 49; // 5 rows × 10 cols − 1
      store.selectSlot(lastSlot);
      expect(store.selectedSlotIndex).toBe(lastSlot);
    });
  });

  // ─── selectedSlotItem ────────────────────────────────────────────────────

  describe("selectedSlotItem", () => {
    it("returns null when no slot is selected", () => {
      const store = usePlayerStore();
      expect(store.selectedSlotItem).toBeNull();
    });

    it("returns null when the selected slot is empty", () => {
      const store = usePlayerStore();
      clearSlot(store, 0);
      store.selectSlot(0);
      expect(store.selectedSlotItem).toBeNull();
    });

    it("returns the inventory item when the selected slot contains one", () => {
      const store = usePlayerStore();
      seedSlot(store, 2, "IronInventoryItem", 3);
      store.selectSlot(2);
      expect(store.selectedSlotItem).toEqual({ type: "IronInventoryItem", count: 3 });
    });

    it("returns null after the selected slot is deselected", () => {
      const store = usePlayerStore();
      seedSlot(store, 2, "IronInventoryItem", 3);
      store.selectSlot(2);
      store.selectSlot(2); // toggle off
      expect(store.selectedSlotItem).toBeNull();
    });

    it("returns null when selection moves to a different empty slot", () => {
      const store = usePlayerStore();
      seedSlot(store, 1, "WoodInventoryItem", 10);
      store.selectSlot(1);
      expect(store.selectedSlotItem).not.toBeNull();

      clearSlot(store, 2);
      store.selectSlot(2); // move selection to empty slot 2
      expect(store.selectedSlotItem).toBeNull();
    });

    it("updates reactively when an item is placed into the selected slot after selection", () => {
      const store = usePlayerStore();
      store.selectSlot(4);
      expect(store.selectedSlotItem).toBeNull();

      // place an item into the already-selected slot
      seedSlot(store, 4, "WoodInventoryItem", 5);

      // computed should reflect the new item without re-selecting
      expect(store.selectedSlotItem).toEqual({ type: "WoodInventoryItem", count: 5 });
    });

    it("updates reactively when the item in the selected slot is removed", () => {
      const store = usePlayerStore();
      seedSlot(store, 6, "IronInventoryItem", 2);
      store.selectSlot(6);
      expect(store.selectedSlotItem).not.toBeNull();

      clearSlot(store, 6);
      expect(store.selectedSlotItem).toBeNull();
    });

    it("reflects a LootBoxInventoryItem in the selected slot", () => {
      const store = usePlayerStore();
      seedSlot(store, 8, LOOTBOX_ITEM_TYPE, 1);
      store.selectSlot(8);
      expect(store.selectedSlotItem?.type).toBe(LOOTBOX_ITEM_TYPE);
      expect(store.selectedSlotItem?.count).toBe(1);
    });

    it("correctly tracks a slot on a non-zero row", () => {
      const store = usePlayerStore();
      // slot 15 is row 1, column 5
      seedSlot(store, 15, "WoodInventoryItem", 7);
      store.selectSlot(15);
      expect(store.selectedSlotItem).toEqual({ type: "WoodInventoryItem", count: 7 });
    });

    it("returns the item of the newly selected slot after switching selection", () => {
      const store = usePlayerStore();
      seedSlot(store, 0, "IronInventoryItem", 1);
      seedSlot(store, 1, "WoodInventoryItem", 2);

      store.selectSlot(0);
      expect(store.selectedSlotItem?.type).toBe("IronInventoryItem");

      store.selectSlot(1);
      expect(store.selectedSlotItem?.type).toBe("WoodInventoryItem");
    });
  });
});
