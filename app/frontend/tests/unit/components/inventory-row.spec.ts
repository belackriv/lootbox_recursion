/// <reference types="vitest" />
import { describe, it, expect, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import { nextTick } from "vue";
import InventoryRow from "../../../Shared/InventoryRow.vue";
import { usePlayerStore } from "../../../store/player";

describe("InventoryRow / InventoryItemSlot integration (DOM updates)", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    // ensure a fresh Pinia instance for each test
    pinia = createPinia();
    setActivePinia(pinia);
  });

  it("updates DOM when a store slot is updated directly (replace object reference)", async () => {
    const store = usePlayerStore();

    // use the first inventory row from the store as the prop
    const row = store.inventory.rows[0];

    const wrapper = mount(InventoryRow, {
      global: {
        plugins: [pinia],
      },
      props: {
        slots: row,
      },
    });

    // find all rendered item slots by their unique slot element class
    const slotEls = wrapper.findAll(".w-16");
    expect(slotEls.length).toBeGreaterThan(0);

    // initially the first slot should be empty (no letter or count)
    const beforeText = slotEls[0].text().trim();
    expect(beforeText).toBe("");

    // update the store by replacing the inventoryItem with a new object reference
    store.inventory.rows[0][0].slot.inventoryItem = {
      type: "IronInventoryItem",
      count: 3,
    };

    // wait for DOM update
    await nextTick();

    // now the first slot should show first-letter 'I' and the count '3'
    const afterText = slotEls[0].text();
    expect(afterText).toContain("I");
    expect(afterText).toContain("3");
  });

  it("updates DOM when mutateInventory applies a mutation (server-like payload)", async () => {
    const store = usePlayerStore();
    const row = store.inventory.rows[0];

    const wrapper = mount(InventoryRow, {
      global: {
        plugins: [pinia],
      },
      props: {
        slots: row,
      },
    });

    const slotEls = wrapper.findAll(".w-16");
    expect(slotEls.length).toBeGreaterThan(1);

    // pick slot index 1 for this test
    const slotIndex = 1;
    const slotNumber = store.inventory.rows[0][slotIndex].slot.slot;

    // Ensure starting empty
    expect(slotEls[slotIndex].text().trim()).toBe("");

    // Simulate a server-sent inventory mutation that includes nested inventory_slot -> inventory_item
    const mutationsPayload = [
      {
        inventory_slot: {
          slot: slotNumber,
          inventory_item: { type: "WoodInventoryItem", count: 2 },
        },
        applied: true,
      },
    ];

    // Call the store mutation handler
    store.mutateInventory(mutationsPayload as any);

    await nextTick();

    // Expect the DOM to reflect the change
    const updatedText = slotEls[slotIndex].text();
    expect(updatedText).toContain("W"); // first letter of WoodInventoryItem
    expect(updatedText).toContain("2");
  });
});
