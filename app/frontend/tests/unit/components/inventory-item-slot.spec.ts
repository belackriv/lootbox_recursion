/// <reference types="vitest" />
import { describe, it, expect, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import { nextTick } from "vue";
import InventoryItemSlot from "../../../Shared/InventoryItemSlot.vue";
import { usePlayerStore } from "../../../store/player";
import type { InventoryGridSlot } from "../../../types/index";

function makeGridSlot(slotNumber: number, type?: string, count?: number): InventoryGridSlot {
  return {
    slot: {
      slot: slotNumber,
      inventoryItem: type && count != null ? { type, count } : null,
    },
    row: Math.floor(slotNumber / 10),
    column: slotNumber % 10,
  };
}

describe("InventoryItemSlot - selection", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  // ─── Border class ─────────────────────────────────────────────────────────

  it("has the default slate border when no slot is selected", () => {
    const gridSlot = makeGridSlot(0);

    const wrapper = mount(InventoryItemSlot, {
      global: { plugins: [pinia] },
      props: { gridSlot },
    });

    expect(wrapper.classes()).toContain("border-slate-500");
    expect(wrapper.classes()).not.toContain("border-yellow-400");
  });

  it("has the construction yellow border when its slot is selected", async () => {
    const store = usePlayerStore();
    store.selectSlot(0);

    const gridSlot = makeGridSlot(0);

    const wrapper = mount(InventoryItemSlot, {
      global: { plugins: [pinia] },
      props: { gridSlot },
    });

    await nextTick();

    expect(wrapper.classes()).toContain("border-yellow-400");
    expect(wrapper.classes()).not.toContain("border-slate-500");
  });

  it("keeps the default slate border when a different slot is selected", async () => {
    const store = usePlayerStore();
    store.selectSlot(1); // select slot 1, not slot 0

    const gridSlot = makeGridSlot(0);

    const wrapper = mount(InventoryItemSlot, {
      global: { plugins: [pinia] },
      props: { gridSlot },
    });

    await nextTick();

    expect(wrapper.classes()).toContain("border-slate-500");
    expect(wrapper.classes()).not.toContain("border-yellow-400");
  });

  it("updates to yellow border reactively when its slot becomes selected", async () => {
    const store = usePlayerStore();
    const gridSlot = makeGridSlot(3);

    const wrapper = mount(InventoryItemSlot, {
      global: { plugins: [pinia] },
      props: { gridSlot },
    });

    // initially not selected
    expect(wrapper.classes()).toContain("border-slate-500");

    store.selectSlot(3);
    await nextTick();

    expect(wrapper.classes()).toContain("border-yellow-400");
    expect(wrapper.classes()).not.toContain("border-slate-500");
  });

  it("reverts to slate border reactively when its slot becomes deselected", async () => {
    const store = usePlayerStore();
    store.selectSlot(3);

    const gridSlot = makeGridSlot(3);

    const wrapper = mount(InventoryItemSlot, {
      global: { plugins: [pinia] },
      props: { gridSlot },
    });

    await nextTick();
    expect(wrapper.classes()).toContain("border-yellow-400");

    // deselect by clicking again (toggle)
    store.selectSlot(3);
    await nextTick();

    expect(wrapper.classes()).toContain("border-slate-500");
    expect(wrapper.classes()).not.toContain("border-yellow-400");
  });

  it("loses yellow border when selection moves to a different slot", async () => {
    const store = usePlayerStore();
    store.selectSlot(5);

    const gridSlot = makeGridSlot(5);

    const wrapper = mount(InventoryItemSlot, {
      global: { plugins: [pinia] },
      props: { gridSlot },
    });

    await nextTick();
    expect(wrapper.classes()).toContain("border-yellow-400");

    // select a different slot
    store.selectSlot(9);
    await nextTick();

    expect(wrapper.classes()).toContain("border-slate-500");
    expect(wrapper.classes()).not.toContain("border-yellow-400");
  });

  // ─── Click behaviour ──────────────────────────────────────────────────────

  it("clicking an unselected slot selects it in the store", async () => {
    const store = usePlayerStore();
    const gridSlot = makeGridSlot(4);

    const wrapper = mount(InventoryItemSlot, {
      global: { plugins: [pinia] },
      props: { gridSlot },
    });

    await wrapper.trigger("click");

    expect(store.selectedSlotIndex).toBe(4);
  });

  it("clicking the selected slot deselects it (toggle)", async () => {
    const store = usePlayerStore();
    store.selectSlot(4);

    const gridSlot = makeGridSlot(4);

    const wrapper = mount(InventoryItemSlot, {
      global: { plugins: [pinia] },
      props: { gridSlot },
    });

    await wrapper.trigger("click");

    expect(store.selectedSlotIndex).toBeNull();
  });

  it("clicking a slot replaces a previously selected slot", async () => {
    const store = usePlayerStore();
    store.selectSlot(2);
    expect(store.selectedSlotIndex).toBe(2);

    const gridSlot = makeGridSlot(7);

    const wrapper = mount(InventoryItemSlot, {
      global: { plugins: [pinia] },
      props: { gridSlot },
    });

    await wrapper.trigger("click");

    expect(store.selectedSlotIndex).toBe(7);
  });

  it("clicking a slot with an item still selects it", async () => {
    const store = usePlayerStore();
    const gridSlot = makeGridSlot(6, "LootBoxInventoryItem", 1);

    const wrapper = mount(InventoryItemSlot, {
      global: { plugins: [pinia] },
      props: { gridSlot },
    });

    await wrapper.trigger("click");

    expect(store.selectedSlotIndex).toBe(6);
  });

  // ─── cursor style ─────────────────────────────────────────────────────────

  it("has cursor-pointer class to indicate the slot is interactive", () => {
    const gridSlot = makeGridSlot(0);

    const wrapper = mount(InventoryItemSlot, {
      global: { plugins: [pinia] },
      props: { gridSlot },
    });

    expect(wrapper.classes()).toContain("cursor-pointer");
  });
});
