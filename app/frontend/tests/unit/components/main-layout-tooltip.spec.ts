/// <reference types="vitest" />
import { describe, it, expect, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import { nextTick } from "vue";
import MainLayout from "../../../Layouts/MainLayout.vue";
import { usePlayerStore } from "../../../store/player";

// ─── Helpers ─────────────────────────────────────────────────────────────────

function mountLayout(pinia: ReturnType<typeof createPinia>) {
  return mount(MainLayout, {
    global: {
      plugins: [pinia],
      stubs: {
        // NavLink uses @inertiajs/vue3 Link — stub it out so we don't need
        // a full Inertia app context in unit tests.
        NavLink: { template: "<a><slot /></a>" },
      },
    },
    props: { currentUser: { emailAddress: "test@example.com" } },
    slots: { default: "<div>page content</div>" },
  });
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe("MainLayout - tooltip sidebar panel", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  // ─── Initial / empty state ────────────────────────────────────────────────

  it("renders the Info panel title bar", () => {
    const wrapper = mountLayout(pinia);
    expect(wrapper.text()).toContain("Info");
  });

  it("shows the placeholder text when no tooltip is active", () => {
    const wrapper = mountLayout(pinia);
    expect(wrapper.text()).toContain("Hover an action to see details.");
  });

  it("does not show any action title when no tooltip is active", () => {
    const wrapper = mountLayout(pinia);
    // The only orange-title text visible should be the panel/header chrome, not
    // an action name.  We simply assert no stray action text is present.
    expect(wrapper.text()).not.toContain("Scavenge");
    expect(wrapper.text()).not.toContain("Craft");
    expect(wrapper.text()).not.toContain("Sort");
  });

  // ─── setTooltip → panel updates ───────────────────────────────────────────

  it("shows the tooltip title after setTooltip is called", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
    await nextTick();

    expect(wrapper.text()).toContain("Scavenge");
  });

  it("shows the tooltip body after setTooltip is called", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
    await nextTick();

    expect(wrapper.text()).toContain("Search the area for raw materials.");
  });

  it("shows both title and body at the same time", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({
      title: "Craft",
      body: "Craft items from your gathered materials.",
    });
    await nextTick();

    expect(wrapper.text()).toContain("Craft");
    expect(wrapper.text()).toContain(
      "Craft items from your gathered materials."
    );
  });

  it("hides the placeholder text once a tooltip is active", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
    await nextTick();

    expect(wrapper.text()).not.toContain("Hover an action to see details.");
  });

  // ─── clearTooltip → panel reverts ─────────────────────────────────────────

  it("returns to the placeholder after clearTooltip is called", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
    await nextTick();

    store.clearTooltip();
    await nextTick();

    expect(wrapper.text()).toContain("Hover an action to see details.");
  });

  it("hides the tooltip title after clearTooltip is called", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
    await nextTick();

    store.clearTooltip();
    await nextTick();

    expect(wrapper.text()).not.toContain("Scavenge");
  });

  it("hides the tooltip body after clearTooltip is called", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
    await nextTick();

    store.clearTooltip();
    await nextTick();

    expect(wrapper.text()).not.toContain("Search the area for raw materials.");
  });

  // ─── Switching between tooltips ───────────────────────────────────────────

  it("shows the new title when the tooltip is replaced", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
    await nextTick();

    store.setTooltip({
      title: "Sort",
      body: "Automatically sort your inventory.",
    });
    await nextTick();

    expect(wrapper.text()).toContain("Sort");
  });

  it("shows the new body when the tooltip is replaced", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
    await nextTick();

    store.setTooltip({
      title: "Sort",
      body: "Automatically sort your inventory.",
    });
    await nextTick();

    expect(wrapper.text()).toContain("Automatically sort your inventory.");
  });

  it("hides the old title when the tooltip is replaced", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
    await nextTick();

    store.setTooltip({
      title: "Sort",
      body: "Automatically sort your inventory.",
    });
    await nextTick();

    expect(wrapper.text()).not.toContain("Scavenge");
  });

  it("hides the old body when the tooltip is replaced", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
    await nextTick();

    store.setTooltip({
      title: "Sort",
      body: "Automatically sort your inventory.",
    });
    await nextTick();

    expect(wrapper.text()).not.toContain("Search the area for raw materials.");
  });

  it("does not show the placeholder when switching between tooltips", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({ title: "Scavenge", body: "First description." });
    await nextTick();

    store.setTooltip({ title: "Use", body: "Second description." });
    await nextTick();

    expect(wrapper.text()).not.toContain("Hover an action to see details.");
  });

  // ─── Multiple set/clear cycles ────────────────────────────────────────────

  it("placeholder is restored after a second set/clear cycle", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    store.setTooltip({ title: "Scavenge", body: "First." });
    await nextTick();
    store.clearTooltip();
    await nextTick();

    store.setTooltip({ title: "Craft", body: "Second." });
    await nextTick();
    store.clearTooltip();
    await nextTick();

    expect(wrapper.text()).toContain("Hover an action to see details.");
    expect(wrapper.text()).not.toContain("Scavenge");
    expect(wrapper.text()).not.toContain("Craft");
  });

  // ─── Page slot content is unaffected ─────────────────────────────────────

  it("still renders the slotted page content regardless of tooltip state", async () => {
    const wrapper = mountLayout(pinia);
    const store = usePlayerStore();

    expect(wrapper.text()).toContain("page content");

    store.setTooltip({ title: "Scavenge", body: "Search the area." });
    await nextTick();

    expect(wrapper.text()).toContain("page content");
  });
});
