/// <reference types="vitest" />
import { describe, it, expect, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import { nextTick } from "vue";
import CraftToggleButton from "../../../Shared/CraftToggleButton.vue";
import { usePlayerStore } from "../../../store/player";
import type { PlayerAction } from "../../../types/index";

// ─── Fixtures ────────────────────────────────────────────────────────────────

const CRAFT_ACTION_WITH_TOOLTIP: PlayerAction = {
  name: "craft",
  label: "Craft",
  disabled: false,
  revealed: true,
  cooldown: 5,
  castTime: 5,
  choices: [],
  requirements: [],
  revealRequirements: [],
  tooltip: "Craft items from your gathered materials.",
};

const CRAFT_ACTION_WITHOUT_TOOLTIP: PlayerAction = {
  ...CRAFT_ACTION_WITH_TOOLTIP,
  tooltip: undefined,
};

const CRAFT_ACTION_NULL_TOOLTIP: PlayerAction = {
  ...CRAFT_ACTION_WITH_TOOLTIP,
  tooltip: null,
};

const CRAFT_ACTION_DISABLED: PlayerAction = {
  ...CRAFT_ACTION_WITH_TOOLTIP,
  disabled: true,
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

function mountButton(
  pinia: ReturnType<typeof createPinia>,
  action: PlayerAction | undefined,
  showCraftingTray = false
) {
  return mount(CraftToggleButton, {
    global: {
      plugins: [pinia],
    },
    props: { action, showCraftingTray },
  });
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe("CraftToggleButton - tooltip store integration", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  // ─── mouseenter ────────────────────────────────────────────────────────────

  it("mouseenter sets hoveredTooltip in the store when the action has a tooltip", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip).not.toBeNull();
  });

  it("mouseenter always uses 'Craft' as the tooltip title", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip?.title).toBe("Craft");
  });

  it("mouseenter sets the tooltip body to the action's tooltip text", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip?.body).toBe(
      "Craft items from your gathered materials."
    );
  });

  it("mouseenter sets the full tooltip object correctly", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip).toEqual({
      title: "Craft",
      body: "Craft items from your gathered materials.",
    });
  });

  it("mouseenter uses the action's own tooltip string as the body", async () => {
    const action: PlayerAction = {
      ...CRAFT_ACTION_WITH_TOOLTIP,
      tooltip: "A custom tooltip body for this test.",
    };
    const wrapper = mountButton(pinia, action);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip?.body).toBe(
      "A custom tooltip body for this test."
    );
  });

  it("mouseenter is a no-op when the action has no tooltip (undefined)", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITHOUT_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip).toBeNull();
  });

  it("mouseenter is a no-op when the action tooltip is null", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_NULL_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip).toBeNull();
  });

  it("mouseenter is a no-op when action prop is undefined", async () => {
    const wrapper = mountButton(pinia, undefined);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip).toBeNull();
  });

  // ─── mouseleave ────────────────────────────────────────────────────────────

  it("mouseleave clears hoveredTooltip in the store", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");
    await wrapper.trigger("mouseleave");

    expect(store.hoveredTooltip).toBeNull();
  });

  it("mouseleave clears a tooltip set by a prior mouseenter", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");
    expect(store.hoveredTooltip).not.toBeNull();

    await wrapper.trigger("mouseleave");
    expect(store.hoveredTooltip).toBeNull();
  });

  it("mouseleave is a no-op when no tooltip was ever set (no tooltip prop)", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITHOUT_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseleave");

    expect(store.hoveredTooltip).toBeNull();
  });

  it("mouseleave is a no-op when action is undefined", async () => {
    const wrapper = mountButton(pinia, undefined);
    const store = usePlayerStore();

    await wrapper.trigger("mouseleave");

    expect(store.hoveredTooltip).toBeNull();
  });

  // ─── Repeated enter / leave cycles ────────────────────────────────────────

  it("tooltip is set again after a second mouseenter following a mouseleave", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");
    await wrapper.trigger("mouseleave");
    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip).toEqual({
      title: "Craft",
      body: "Craft items from your gathered materials.",
    });
  });

  it("tooltip is null after two full enter/leave cycles", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");
    await wrapper.trigger("mouseleave");
    await wrapper.trigger("mouseenter");
    await wrapper.trigger("mouseleave");

    expect(store.hoveredTooltip).toBeNull();
  });

  // ─── showCraftingTray state doesn't affect tooltip ─────────────────────────

  it("tooltip is set correctly when the crafting tray is open", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITH_TOOLTIP, true);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip?.title).toBe("Craft");
  });

  it("tooltip is cleared correctly when the crafting tray is open", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITH_TOOLTIP, true);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");
    await wrapper.trigger("mouseleave");

    expect(store.hoveredTooltip).toBeNull();
  });

  // ─── Reactivity ───────────────────────────────────────────────────────────

  it("hoveredTooltip is reactive — store reflects the change on the next tick", async () => {
    const wrapper = mountButton(pinia, CRAFT_ACTION_WITH_TOOLTIP);
    const store = usePlayerStore();

    wrapper.trigger("mouseenter"); // intentionally not awaited
    await nextTick();

    expect(store.hoveredTooltip).not.toBeNull();
  });
});
