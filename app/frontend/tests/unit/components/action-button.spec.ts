/// <reference types="vitest" />
import { describe, it, expect, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import { nextTick } from "vue";
import ActionButton from "../../../Shared/ActionButton.vue";
import { usePlayerStore, inventoryRowLength } from "../../../store/player";
import { LOOTBOX_ITEM_TYPE } from "../../../types/index";
import type { PlayerAction } from "../../../types/index";

const USE_ACTION: PlayerAction = {
  name: "use",
  label: "Use",
  disabled: true,
  revealed: true,
  cooldown: 5,
  castTime: 5,
  choices: [],
  requirements: [],
  revealRequirements: [],
};

const SCAVENGE_ACTION: PlayerAction = {
  name: "scavenge",
  label: "Scavenge",
  disabled: false,
  revealed: true,
  cooldown: 5,
  castTime: 5,
  choices: [],
  requirements: [],
  revealRequirements: [],
};

const CRAFT_ACTION: PlayerAction = {
  name: "craft",
  label: "Craft",
  disabled: true,
  revealed: true,
  cooldown: 5,
  castTime: 5,
  choices: [],
  requirements: [],
  revealRequirements: [],
};

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

function isButtonDisabled(wrapper: ReturnType<typeof mount>): boolean {
  return (wrapper.find("button").element as HTMLButtonElement).disabled;
}

const globalConfig = (pinia: ReturnType<typeof createPinia>) => ({
  plugins: [pinia],
  provide: {
    playerActionsChannel: undefined,
  },
});

describe("ActionButton - use action disabled state", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  // ─── No selection ─────────────────────────────────────────────────────────

  it("use button is disabled when no slot is selected", () => {
    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: USE_ACTION,
    });

    expect(isButtonDisabled(wrapper)).toBe(true);
  });

  // ─── Empty slot selected ──────────────────────────────────────────────────

  it("use button is disabled when the selected slot is empty", () => {
    const store = usePlayerStore();
    store.selectSlot(0); // slot 0 starts empty

    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: USE_ACTION,
    });

    expect(isButtonDisabled(wrapper)).toBe(true);
  });

  // ─── Non-lootbox item selected ────────────────────────────────────────────

  it("use button is disabled when selected slot contains IronInventoryItem", () => {
    const store = usePlayerStore();
    seedSlot(store, 0, "IronInventoryItem", 5);
    store.selectSlot(0);

    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: USE_ACTION,
    });

    expect(isButtonDisabled(wrapper)).toBe(true);
  });

  it("use button is disabled when selected slot contains WoodInventoryItem", () => {
    const store = usePlayerStore();
    seedSlot(store, 2, "WoodInventoryItem", 10);
    store.selectSlot(2);

    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: USE_ACTION,
    });

    expect(isButtonDisabled(wrapper)).toBe(true);
  });

  // ─── Lootbox selected ─────────────────────────────────────────────────────

  it("use button is enabled when selected slot contains a LootBoxInventoryItem", () => {
    const store = usePlayerStore();
    seedSlot(store, 0, LOOTBOX_ITEM_TYPE, 1);
    store.selectSlot(0);

    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: USE_ACTION,
    });

    expect(isButtonDisabled(wrapper)).toBe(false);
  });

  it("use button is enabled for a lootbox on a non-zero row", () => {
    const store = usePlayerStore();
    // slot 15 sits on row 1, column 5
    seedSlot(store, 15, LOOTBOX_ITEM_TYPE, 1);
    store.selectSlot(15);

    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: USE_ACTION,
    });

    expect(isButtonDisabled(wrapper)).toBe(false);
  });

  // ─── Reactivity ───────────────────────────────────────────────────────────

  it("use button becomes enabled reactively when a lootbox slot is selected", async () => {
    const store = usePlayerStore();
    seedSlot(store, 3, LOOTBOX_ITEM_TYPE, 1);

    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: USE_ACTION,
    });

    // no selection yet — should be disabled
    expect(isButtonDisabled(wrapper)).toBe(true);

    store.selectSlot(3);
    await nextTick();

    expect(isButtonDisabled(wrapper)).toBe(false);
  });

  it("use button becomes disabled reactively when the lootbox slot is deselected", async () => {
    const store = usePlayerStore();
    seedSlot(store, 3, LOOTBOX_ITEM_TYPE, 1);
    store.selectSlot(3);

    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: USE_ACTION,
    });

    expect(isButtonDisabled(wrapper)).toBe(false);

    store.selectSlot(3); // toggle off
    await nextTick();

    expect(isButtonDisabled(wrapper)).toBe(true);
  });

  it("use button becomes disabled reactively when selection moves to a non-lootbox slot", async () => {
    const store = usePlayerStore();
    seedSlot(store, 0, LOOTBOX_ITEM_TYPE, 1);
    seedSlot(store, 1, "IronInventoryItem", 3);
    store.selectSlot(0);

    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: USE_ACTION,
    });

    expect(isButtonDisabled(wrapper)).toBe(false);

    store.selectSlot(1);
    await nextTick();

    expect(isButtonDisabled(wrapper)).toBe(true);
  });

  it("use button becomes disabled reactively when the item is removed from the selected slot", async () => {
    const store = usePlayerStore();
    seedSlot(store, 5, LOOTBOX_ITEM_TYPE, 1);
    store.selectSlot(5);

    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: USE_ACTION,
    });

    expect(isButtonDisabled(wrapper)).toBe(false);

    // simulate the item being consumed / removed from the slot
    const rowIndex = Math.floor(5 / inventoryRowLength);
    const columnIndex = 5 % inventoryRowLength;
    store.inventory.rows[rowIndex][columnIndex].slot.inventoryItem = null;
    await nextTick();

    expect(isButtonDisabled(wrapper)).toBe(true);
  });

  // ─── Non-use actions unaffected ───────────────────────────────────────────

  it("non-use button respects props.disabled=false regardless of slot selection", () => {
    // no selection, but scavenge should still be enabled
    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: { ...SCAVENGE_ACTION, disabled: false },
    });

    expect(isButtonDisabled(wrapper)).toBe(false);
  });

  it("non-use button respects props.disabled=true regardless of lootbox selection", () => {
    const store = usePlayerStore();
    seedSlot(store, 0, LOOTBOX_ITEM_TYPE, 1);
    store.selectSlot(0);

    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: { ...CRAFT_ACTION, disabled: true },
    });

    expect(isButtonDisabled(wrapper)).toBe(true);
  });

  it("non-use button is not affected when a lootbox slot becomes selected", async () => {
    const store = usePlayerStore();
    seedSlot(store, 0, LOOTBOX_ITEM_TYPE, 1);

    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: { ...SCAVENGE_ACTION, disabled: false },
    });

    expect(isButtonDisabled(wrapper)).toBe(false);

    store.selectSlot(0);
    await nextTick();

    // scavenge button should still be enabled — slot selection is irrelevant to it
    expect(isButtonDisabled(wrapper)).toBe(false);
  });

  // ─── Button label ─────────────────────────────────────────────────────────

  it("renders the correct label for the use action", () => {
    const wrapper = mount(ActionButton, {
      global: globalConfig(pinia),
      props: USE_ACTION,
    });

    expect(wrapper.find("button").text()).toContain("Use");
  });
});
