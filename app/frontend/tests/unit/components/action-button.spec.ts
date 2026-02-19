/// <reference types="vitest" />
import { describe, it, expect, beforeEach, vi } from "vitest";
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

// ---------------------------------------------------------------------------
// ActionButton - click sends correct actionData
// ---------------------------------------------------------------------------

describe("ActionButton - onClick actionData payload", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
    // Stub requestAnimationFrame so cast-time animation loop doesn't interfere
    vi.stubGlobal("requestAnimationFrame", vi.fn());
  });

  function mountWithMockChannel(
    props: PlayerAction,
    mockSend: ReturnType<typeof vi.fn>
  ) {
    return mount(ActionButton, {
      global: {
        plugins: [pinia],
        provide: {
          playerActionsChannel: { send: mockSend },
        },
      },
      props,
    });
  }

  // ─── use action passes slotNumber ──────────────────────────────────────────

  it("passes { slotNumber } in actionData when clicking use with a loot box slot selected", async () => {
    const store = usePlayerStore();
    seedSlot(store, 4, LOOTBOX_ITEM_TYPE, 1);
    store.selectSlot(4);

    const mockSend = vi.fn();
    const wrapper = mountWithMockChannel(USE_ACTION, mockSend);

    await wrapper.find("button").trigger("click");

    expect(mockSend).toHaveBeenCalledOnce();
    const [_action, data] = mockSend.mock.calls[0];
    expect(data).toEqual({ slotNumber: 4 });
  });

  it("passes { slotNumber } matching the selected slot number", async () => {
    const store = usePlayerStore();
    seedSlot(store, 17, LOOTBOX_ITEM_TYPE, 1);
    store.selectSlot(17);

    const mockSend = vi.fn();
    const wrapper = mountWithMockChannel(USE_ACTION, mockSend);

    await wrapper.find("button").trigger("click");

    expect(mockSend).toHaveBeenCalledOnce();
    const [_action, data] = mockSend.mock.calls[0];
    expect(data).toEqual({ slotNumber: 17 });
  });

  it("passes the action name 'use' alongside the slot data", async () => {
    const store = usePlayerStore();
    seedSlot(store, 2, LOOTBOX_ITEM_TYPE, 1);
    store.selectSlot(2);

    const mockSend = vi.fn();
    const wrapper = mountWithMockChannel(USE_ACTION, mockSend);

    await wrapper.find("button").trigger("click");

    expect(mockSend).toHaveBeenCalledOnce();
    const [action, _data] = mockSend.mock.calls[0];
    expect(action.name).toBe("use");
  });

  it("does not fire when use button is disabled (no loot box selected)", async () => {
    // No slot selected → isDisabled = true → onClick returns early
    const mockSend = vi.fn();
    const wrapper = mountWithMockChannel(USE_ACTION, mockSend);

    await wrapper.find("button").trigger("click");

    expect(mockSend).not.toHaveBeenCalled();
  });

  // ─── non-use actions pass null ────────────────────────────────────────────

  it("passes null actionData when clicking scavenge", async () => {
    const mockSend = vi.fn();
    const wrapper = mountWithMockChannel(
      { ...SCAVENGE_ACTION, disabled: false },
      mockSend
    );

    await wrapper.find("button").trigger("click");

    expect(mockSend).toHaveBeenCalledOnce();
    const [action, data] = mockSend.mock.calls[0];
    expect(action.name).toBe("scavenge");
    expect(data).toBeNull();
  });

  it("does not fire when a non-use action is disabled", async () => {
    const mockSend = vi.fn();
    const wrapper = mountWithMockChannel(
      { ...CRAFT_ACTION, disabled: true },
      mockSend
    );

    await wrapper.find("button").trigger("click");

    expect(mockSend).not.toHaveBeenCalled();
  });

  it("use action sends slotNumber 0 when slot 0 is selected", async () => {
    const store = usePlayerStore();
    seedSlot(store, 0, LOOTBOX_ITEM_TYPE, 1);
    store.selectSlot(0);

    const mockSend = vi.fn();
    const wrapper = mountWithMockChannel(USE_ACTION, mockSend);

    await wrapper.find("button").trigger("click");

    expect(mockSend).toHaveBeenCalledOnce();
    const [_action, data] = mockSend.mock.calls[0];
    // slotNumber 0 is a valid value and must be sent, not treated as falsy null
    expect(data).toEqual({ slotNumber: 0 });
  });
});
