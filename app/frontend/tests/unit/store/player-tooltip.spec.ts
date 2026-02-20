import { describe, it, expect, beforeEach } from "vitest";
import { createPinia, setActivePinia } from "pinia";
import { usePlayerStore } from "../../../store/player";

describe("player store - tooltip", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  // ─── Initial state ────────────────────────────────────────────────────────

  it("hoveredTooltip starts as null", () => {
    const store = usePlayerStore();
    expect(store.hoveredTooltip).toBeNull();
  });

  // ─── setTooltip ───────────────────────────────────────────────────────────

  it("setTooltip sets hoveredTooltip with the provided title and body", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "Scavenge", body: "Search the area for raw materials." });
    expect(store.hoveredTooltip).toEqual({
      title: "Scavenge",
      body: "Search the area for raw materials.",
    });
  });

  it("setTooltip sets the title correctly", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "Sort", body: "Organise your inventory." });
    expect(store.hoveredTooltip?.title).toBe("Sort");
  });

  it("setTooltip sets the body correctly", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "Sort", body: "Organise your inventory." });
    expect(store.hoveredTooltip?.body).toBe("Organise your inventory.");
  });

  it("setTooltip replaces an existing tooltip with the new one", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "First", body: "First body." });
    store.setTooltip({ title: "Second", body: "Second body." });
    expect(store.hoveredTooltip).toEqual({ title: "Second", body: "Second body." });
  });

  it("setTooltip overwrites the previous title", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "Old title", body: "Body." });
    store.setTooltip({ title: "New title", body: "Body." });
    expect(store.hoveredTooltip?.title).toBe("New title");
  });

  it("setTooltip overwrites the previous body", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "Title", body: "Old body." });
    store.setTooltip({ title: "Title", body: "New body." });
    expect(store.hoveredTooltip?.body).toBe("New body.");
  });

  it("setTooltip can be called with an empty string body", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "Title", body: "" });
    expect(store.hoveredTooltip?.body).toBe("");
  });

  it("setTooltip can be called with an empty string title", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "", body: "Some body text." });
    expect(store.hoveredTooltip?.title).toBe("");
  });

  // ─── clearTooltip ─────────────────────────────────────────────────────────

  it("clearTooltip resets hoveredTooltip to null", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "Scavenge", body: "Search the area for raw materials." });
    store.clearTooltip();
    expect(store.hoveredTooltip).toBeNull();
  });

  it("clearTooltip is a no-op when hoveredTooltip is already null", () => {
    const store = usePlayerStore();
    expect(store.hoveredTooltip).toBeNull();
    store.clearTooltip();
    expect(store.hoveredTooltip).toBeNull();
  });

  it("clearTooltip can be called multiple times without error", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "Craft", body: "Craft items." });
    store.clearTooltip();
    store.clearTooltip();
    expect(store.hoveredTooltip).toBeNull();
  });

  // ─── set → clear → set cycle ─────────────────────────────────────────────

  it("hoveredTooltip can be set again after being cleared", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "First", body: "First body." });
    store.clearTooltip();
    store.setTooltip({ title: "Second", body: "Second body." });
    expect(store.hoveredTooltip).toEqual({ title: "Second", body: "Second body." });
  });

  it("multiple set/clear cycles leave hoveredTooltip null at the end", () => {
    const store = usePlayerStore();
    store.setTooltip({ title: "A", body: "A body." });
    store.clearTooltip();
    store.setTooltip({ title: "B", body: "B body." });
    store.clearTooltip();
    expect(store.hoveredTooltip).toBeNull();
  });

  // ─── Isolation between store instances ───────────────────────────────────

  it("tooltip state is isolated between separate pinia instances", () => {
    const pinia1 = createPinia();
    const pinia2 = createPinia();

    setActivePinia(pinia1);
    const store1 = usePlayerStore();
    store1.setTooltip({ title: "From store 1", body: "Body 1." });

    setActivePinia(pinia2);
    const store2 = usePlayerStore();

    expect(store2.hoveredTooltip).toBeNull();
    expect(store1.hoveredTooltip?.title).toBe("From store 1");
  });
});
