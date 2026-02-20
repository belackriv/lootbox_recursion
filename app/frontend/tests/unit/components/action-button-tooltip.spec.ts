/// <reference types="vitest" />
import { describe, it, expect, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import { nextTick } from "vue";
import ActionButton from "../../../Shared/ActionButton.vue";
import { usePlayerStore } from "../../../store/player";
import type { PlayerAction } from "../../../types/index";

// ─── Fixtures ────────────────────────────────────────────────────────────────

const BASE_ACTION: PlayerAction = {
  name: "scavenge",
  label: "Scavenge",
  disabled: false,
  revealed: true,
  cooldown: 5,
  castTime: 0,
  choices: [],
  requirements: [],
  revealRequirements: [],
};

const WITH_TOOLTIP: PlayerAction = {
  ...BASE_ACTION,
  tooltip: "Search the area for raw materials.",
};

const WITHOUT_TOOLTIP: PlayerAction = {
  ...BASE_ACTION,
  tooltip: undefined,
};

const WITH_NULL_TOOLTIP: PlayerAction = {
  ...BASE_ACTION,
  tooltip: null,
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

function mountButton(
  pinia: ReturnType<typeof createPinia>,
  action: PlayerAction
) {
  return mount(ActionButton, {
    global: {
      plugins: [pinia],
      provide: { playerActionsChannel: undefined },
    },
    props: action,
  });
}

// ─── Tests ────────────────────────────────────────────────────────────────────

describe("ActionButton - tooltip store integration", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  // ─── mouseenter ────────────────────────────────────────────────────────────

  it("mouseenter sets hoveredTooltip in the store when a tooltip is provided", async () => {
    const wrapper = mountButton(pinia, WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip).not.toBeNull();
  });

  it("mouseenter sets hoveredTooltip title to the action label", async () => {
    const wrapper = mountButton(pinia, WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip?.title).toBe("Scavenge");
  });

  it("mouseenter sets hoveredTooltip body to the action tooltip text", async () => {
    const wrapper = mountButton(pinia, WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip?.body).toBe(
      "Search the area for raw materials."
    );
  });

  it("mouseenter sets the full tooltip object correctly", async () => {
    const wrapper = mountButton(pinia, WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip).toEqual({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
  });

  it("mouseenter uses the action's own label as the tooltip title", async () => {
    const action: PlayerAction = {
      ...WITH_TOOLTIP,
      name: "sort_inventory",
      label: "Sort",
      tooltip: "Automatically sort your inventory.",
    };
    const wrapper = mountButton(pinia, action);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip?.title).toBe("Sort");
  });

  it("mouseenter uses the action's own tooltip text as the body", async () => {
    const action: PlayerAction = {
      ...WITH_TOOLTIP,
      tooltip: "A completely different tooltip body.",
    };
    const wrapper = mountButton(pinia, action);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip?.body).toBe(
      "A completely different tooltip body."
    );
  });

  it("mouseenter is a no-op when tooltip prop is undefined", async () => {
    const wrapper = mountButton(pinia, WITHOUT_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip).toBeNull();
  });

  it("mouseenter is a no-op when tooltip prop is null", async () => {
    const wrapper = mountButton(pinia, WITH_NULL_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip).toBeNull();
  });

  // ─── mouseleave ────────────────────────────────────────────────────────────

  it("mouseleave clears hoveredTooltip in the store", async () => {
    const wrapper = mountButton(pinia, WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");
    await wrapper.trigger("mouseleave");

    expect(store.hoveredTooltip).toBeNull();
  });

  it("mouseleave is a no-op when no tooltip was set (tooltip prop absent)", async () => {
    const wrapper = mountButton(pinia, WITHOUT_TOOLTIP);
    const store = usePlayerStore();

    // never entered — store should still be null after leave
    await wrapper.trigger("mouseleave");

    expect(store.hoveredTooltip).toBeNull();
  });

  it("mouseleave clears a tooltip set by a prior mouseenter", async () => {
    const wrapper = mountButton(pinia, WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");
    expect(store.hoveredTooltip).not.toBeNull();

    await wrapper.trigger("mouseleave");
    expect(store.hoveredTooltip).toBeNull();
  });

  // ─── Repeated enter / leave cycles ────────────────────────────────────────

  it("tooltip is set again after a second mouseenter following a mouseleave", async () => {
    const wrapper = mountButton(pinia, WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");
    await wrapper.trigger("mouseleave");
    await wrapper.trigger("mouseenter");

    expect(store.hoveredTooltip).toEqual({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
  });

  it("tooltip is null after two enter/leave cycles", async () => {
    const wrapper = mountButton(pinia, WITH_TOOLTIP);
    const store = usePlayerStore();

    await wrapper.trigger("mouseenter");
    await wrapper.trigger("mouseleave");
    await wrapper.trigger("mouseenter");
    await wrapper.trigger("mouseleave");

    expect(store.hoveredTooltip).toBeNull();
  });

  // ─── Reactivity ───────────────────────────────────────────────────────────

  it("hoveredTooltip is reactive — store reflects the change on the next tick", async () => {
    const wrapper = mountButton(pinia, WITH_TOOLTIP);
    const store = usePlayerStore();

    wrapper.trigger("mouseenter"); // intentionally not awaited
    await nextTick();

    expect(store.hoveredTooltip).not.toBeNull();
  });
});
