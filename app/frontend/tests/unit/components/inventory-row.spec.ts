/// <reference types="vitest" />
import { describe, it, expect, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import { nextTick } from "vue";
import InventoryRow from "../../../Shared/InventoryRow.vue";
import { usePlayerStore } from "../../../store/player";

// Stub ItemSprite so async component loading doesn't interfere with DOM checks.
// Renders a simple span with a data attribute so tests can assert on item type
// if needed, without depending on SVG sprite internals.
const ItemSpriteStub = {
  template: '<span class="item-sprite" :data-item-type="itemType"></span>',
  props: ["itemType"],
};

function globalConfig(pinia: ReturnType<typeof createPinia>) {
  return {
    plugins: [pinia],
    stubs: { ItemSprite: ItemSpriteStub },
  };
}

describe("InventoryRow / InventoryItemSlot integration (DOM updates)", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  it("renders one fac-slot element per grid slot in the row", () => {
    const store = usePlayerStore();
    const row = store.inventory.rows[0];

    const wrapper = mount(InventoryRow, {
      global: globalConfig(pinia),
      props: { slots: row },
    });

    const slotEls = wrapper.findAll(".fac-slot");
    expect(slotEls.length).toBe(row.length);
  });

  it("renders empty slots with no count badge initially", () => {
    const store = usePlayerStore();
    const row = store.inventory.rows[0];

    const wrapper = mount(InventoryRow, {
      global: globalConfig(pinia),
      props: { slots: row },
    });

    // No count badges should be visible when all slots are empty
    expect(wrapper.findAll(".fac-slot-count").length).toBe(0);
  });

  it("updates DOM when a store slot is updated directly (replace object reference)", async () => {
    const store = usePlayerStore();
    const row = store.inventory.rows[0];

    const wrapper = mount(InventoryRow, {
      global: globalConfig(pinia),
      props: { slots: row },
    });

    const slotEls = wrapper.findAll(".fac-slot");
    expect(slotEls.length).toBeGreaterThan(0);

    // First slot starts empty — no count badge
    expect(slotEls[0].find(".fac-slot-count").exists()).toBe(false);

    // Update the store by replacing the inventoryItem with a new object reference
    store.inventory.rows[0][0].slot.inventoryItem = {
      type: "IronInventoryItem",
      count: 3,
    };

    await nextTick();

    // Count badge should now be visible with the correct value
    const countBadge = slotEls[0].find(".fac-slot-count");
    expect(countBadge.exists()).toBe(true);
    expect(countBadge.text()).toBe("3");
  });

  it("shows the item sprite element after a slot is populated", async () => {
    const store = usePlayerStore();
    const row = store.inventory.rows[0];

    const wrapper = mount(InventoryRow, {
      global: globalConfig(pinia),
      props: { slots: row },
    });

    const slotEls = wrapper.findAll(".fac-slot");

    // Explicitly clear the slot in case a previous test left it populated
    store.inventory.rows[0][0].slot.inventoryItem = null;
    await nextTick();

    // No sprite initially
    expect(slotEls[0].find(".item-sprite").exists()).toBe(false);

    store.inventory.rows[0][0].slot.inventoryItem = {
      type: "IronInventoryItem",
      count: 3,
    };

    await nextTick();

    // Sprite stub should now be rendered
    const sprite = slotEls[0].find(".item-sprite");
    expect(sprite.exists()).toBe(true);
    expect(sprite.attributes("data-item-type")).toBe("IronInventoryItem");
  });

  it("updates DOM when mutateInventory applies a mutation (server-like payload)", async () => {
    const store = usePlayerStore();
    const row = store.inventory.rows[0];

    const wrapper = mount(InventoryRow, {
      global: globalConfig(pinia),
      props: { slots: row },
    });

    const slotEls = wrapper.findAll(".fac-slot");
    expect(slotEls.length).toBeGreaterThan(1);

    // Use slot index 1 for this test
    const slotIndex = 1;
    const slotNumber = store.inventory.rows[0][slotIndex].slot.slot;

    // Starts empty
    expect(slotEls[slotIndex].find(".fac-slot-count").exists()).toBe(false);

    // Simulate a server-sent inventory mutation
    const mutationsPayload = [
      {
        inventory_slot: {
          slot: slotNumber,
          inventory_item: { type: "WoodInventoryItem", count: 2 },
        },
        applied: true,
      },
    ];

    store.mutateInventory(mutationsPayload as any);

    await nextTick();

    // Count badge should reflect the new item
    const countBadge = slotEls[slotIndex].find(".fac-slot-count");
    expect(countBadge.exists()).toBe(true);
    expect(countBadge.text()).toBe("2");
  });

  it("shows the correct item type in the sprite after a mutation", async () => {
    const store = usePlayerStore();
    const row = store.inventory.rows[0];

    const wrapper = mount(InventoryRow, {
      global: globalConfig(pinia),
      props: { slots: row },
    });

    const slotEls = wrapper.findAll(".fac-slot");
    const slotNumber = store.inventory.rows[0][2].slot.slot;

    store.mutateInventory([
      {
        inventory_slot: {
          slot: slotNumber,
          inventory_item: { type: "WoodInventoryItem", count: 5 },
        },
        applied: true,
      },
    ] as any);

    await nextTick();

    const sprite = slotEls[2].find(".item-sprite");
    expect(sprite.exists()).toBe(true);
    expect(sprite.attributes("data-item-type")).toBe("WoodInventoryItem");
  });

  it("clears the count badge when an item is removed from a slot", async () => {
    const store = usePlayerStore();
    const row = store.inventory.rows[0];

    // Pre-seed a slot with an item
    store.inventory.rows[0][0].slot.inventoryItem = {
      type: "IronInventoryItem",
      count: 5,
    };

    const wrapper = mount(InventoryRow, {
      global: globalConfig(pinia),
      props: { slots: row },
    });

    await nextTick();

    const slotEls = wrapper.findAll(".fac-slot");
    expect(slotEls[0].find(".fac-slot-count").exists()).toBe(true);

    // Remove the item
    store.inventory.rows[0][0].slot.inventoryItem = null;
    await nextTick();

    expect(slotEls[0].find(".fac-slot-count").exists()).toBe(false);
  });

  it("updates the count badge when the item count changes", async () => {
    const store = usePlayerStore();
    const row = store.inventory.rows[0];

    store.inventory.rows[0][0].slot.inventoryItem = {
      type: "IronInventoryItem",
      count: 1,
    };

    const wrapper = mount(InventoryRow, {
      global: globalConfig(pinia),
      props: { slots: row },
    });

    await nextTick();

    const slotEls = wrapper.findAll(".fac-slot");
    expect(slotEls[0].find(".fac-slot-count").text()).toBe("1");

    // Replace with updated count
    store.inventory.rows[0][0].slot.inventoryItem = {
      type: "IronInventoryItem",
      count: 10,
    };
    await nextTick();

    expect(slotEls[0].find(".fac-slot-count").text()).toBe("10");
  });
});
