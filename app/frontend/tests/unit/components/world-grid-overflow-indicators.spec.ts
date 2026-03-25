/// <reference types="vitest" />
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import WorldGrid from "../../../Layouts/WorldGrid.vue";
import {
  PAGE_SIZE,
  CELL_HEIGHT,
  SENTINEL_HEIGHT,
} from "../../../Layouts/worldGridConstants";
import { usePlayerStore } from "../../../store/player";

// ── Stubs ──────────────────────────────────────────────────────────────────────

const WorldCellSlotStub = {
  template: '<div class="world-cell-slot" :data-coord="cell.coordinate"></div>',
  props: ["cell", "channel"],
};

function globalConfig(pinia: ReturnType<typeof createPinia>) {
  return {
    plugins: [pinia],
    stubs: { WorldCellSlot: WorldCellSlotStub },
  };
}

// ── Scroll geometry constants (imported from worldGridConstants.ts) ───────────

// ── Helpers ────────────────────────────────────────────────────────────────────

/**
 * Patches scrollHeight, clientHeight, and scrollTop onto a real DOM element
 * using configurable get/set descriptors so the component can read/write
 * scrollTop without throwing, and tests can inspect the final value.
 */
function patchScrollEl(
  el: HTMLElement,
  opts: { scrollTop: number; scrollHeight: number; clientHeight: number }
): { getScrollTop: () => number } {
  let _scrollTop = opts.scrollTop;

  Object.defineProperty(el, "scrollHeight", {
    configurable: true,
    get() {
      return opts.scrollHeight;
    },
  });
  Object.defineProperty(el, "clientHeight", {
    configurable: true,
    get() {
      return opts.clientHeight;
    },
  });
  Object.defineProperty(el, "scrollTop", {
    configurable: true,
    get() {
      return _scrollTop;
    },
    set(v: number) {
      _scrollTop = v;
    },
  });

  return { getScrollTop: () => _scrollTop };
}

/**
 * Mounts WorldGrid, flushes all async work from onMounted, patches the scroll
 * element, and returns both for use in tests.
 */
async function mountWorldGrid(pinia: ReturnType<typeof createPinia>) {
  const wrapper = mount(WorldGrid, {
    global: globalConfig(pinia),
    props: { channel: undefined },
  });
  await flushPromises();

  const el = wrapper.find(".world-grid__body").element as HTMLElement;

  return { wrapper, el };
}

/**
 * Triggers a scroll event on the world-grid__body with the given scroll
 * geometry, then waits for Vue to settle.
 */
async function triggerScroll(
  wrapper: ReturnType<typeof mount>,
  el: HTMLElement,
  opts: { scrollTop: number; scrollHeight: number; clientHeight: number }
) {
  patchScrollEl(el, opts);
  await wrapper.find(".world-grid__body").trigger("scroll");
  await flushPromises();
}

/**
 * Seeds a deployed entity directly into the store's worldCells map,
 * replacing it with a new Map to trigger Vue reactivity.
 */
function seedDeployedCell(
  store: ReturnType<typeof usePlayerStore>,
  coordinate: number
) {
  store.worldCells.set(coordinate, {
    coordinate,
    placedEntity: {
      type: "IrradiationEnclosureInventoryItem",
      displayName: "Enclosure",
      tooltip: null,
    },
  });
  // Replace with new Map to trigger reactivity
  (store.worldCells as any) = new Map(store.worldCells);
}

// ── Indicator element selectors ────────────────────────────────────────────────

const ABOVE_SEL = ".ruler__overflow-indicator--above";
const BELOW_SEL = ".ruler__overflow-indicator--below";
const ACTIVE_CLASS = "ruler__overflow-indicator--active";

// ── Tests ──────────────────────────────────────────────────────────────────────

describe("WorldGrid – overflow indicators: initial state", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("renders the above indicator element", async () => {
    const { wrapper } = await mountWorldGrid(pinia);
    expect(wrapper.find(ABOVE_SEL).exists()).toBe(true);
  });

  it("renders the below indicator element", async () => {
    const { wrapper } = await mountWorldGrid(pinia);
    expect(wrapper.find(BELOW_SEL).exists()).toBe(true);
  });

  it("above indicator is inactive when no entities are deployed", async () => {
    const { wrapper } = await mountWorldGrid(pinia);
    expect(wrapper.find(ABOVE_SEL).classes()).not.toContain(ACTIVE_CLASS);
  });

  it("below indicator is inactive when no entities are deployed", async () => {
    const { wrapper } = await mountWorldGrid(pinia);
    expect(wrapper.find(BELOW_SEL).classes()).not.toContain(ACTIVE_CLASS);
  });

  it("both indicators are inactive when an entity is deployed in the visible centre", async () => {
    const store = usePlayerStore();
    const { wrapper, el } = await mountWorldGrid(pinia);

    // Place entity at coordinate 10 — well within the default window.
    // After mount, windowStart = -16, so coordinate 10 is at index 26.
    // We need a viewport tall enough to include index 26:
    // clientHeight must be > (26 + 1) * CELL_HEIGHT = 1350px, so use 1500px.
    seedDeployedCell(store, 10);

    await triggerScroll(wrapper, el, {
      scrollTop: 0,
      scrollHeight: 10000,
      clientHeight: 1500,
    });

    expect(wrapper.find(ABOVE_SEL).classes()).not.toContain(ACTIVE_CLASS);
    expect(wrapper.find(BELOW_SEL).classes()).not.toContain(ACTIVE_CLASS);
  });
});

// ─────────────────────────────────────────────────────────────────────────────

describe("WorldGrid – overflow indicators: below indicator", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("below indicator becomes active when a deployed entity is below the viewport", async () => {
    const store = usePlayerStore();
    const { wrapper, el } = await mountWorldGrid(pinia);

    // Deploy an entity far down — beyond what a 400px viewport shows at scrollTop 0
    // sortedWorldCells after mount starts at windowStart (-PAGE_SIZE = -16)
    // A 400px viewport shows 8 cells. Coordinate 50 will be well off the bottom.
    seedDeployedCell(store, 50);

    await triggerScroll(wrapper, el, {
      scrollTop: 0,
      scrollHeight: 5000,
      clientHeight: 400,
    });

    expect(wrapper.find(BELOW_SEL).classes()).toContain(ACTIVE_CLASS);
  });

  it("below indicator is inactive when the viewport is scrolled down to show the deployed entity", async () => {
    const store = usePlayerStore();
    const { wrapper, el } = await mountWorldGrid(pinia);

    seedDeployedCell(store, 50);

    // After mount, windowStart = -PAGE_SIZE = -16.
    // Coordinate 50 is at index (50 - (-16)) = 66 in sortedWorldCells.
    // To bring index 66 into view, scrollTop must be at least 66 * CELL_HEIGHT.
    const entityScrollTop = 66 * CELL_HEIGHT;

    await triggerScroll(wrapper, el, {
      scrollTop: entityScrollTop,
      scrollHeight: 10000,
      clientHeight: 400,
    });

    expect(wrapper.find(BELOW_SEL).classes()).not.toContain(ACTIVE_CLASS);
  });

  it("below indicator becomes inactive when the entity below is removed", async () => {
    const store = usePlayerStore();
    const { wrapper, el } = await mountWorldGrid(pinia);

    seedDeployedCell(store, 50);

    await triggerScroll(wrapper, el, {
      scrollTop: 0,
      scrollHeight: 5000,
      clientHeight: 400,
    });

    // Confirm it is active first
    expect(wrapper.find(BELOW_SEL).classes()).toContain(ACTIVE_CLASS);

    // Remove the entity
    store.worldCells.set(50, { coordinate: 50, placedEntity: null });
    (store as any).worldCells = new Map(store.worldCells);
    await flushPromises();

    expect(wrapper.find(BELOW_SEL).classes()).not.toContain(ACTIVE_CLASS);
  });

  it("below indicator does not activate when only empty cells are below the viewport", async () => {
    const { wrapper, el } = await mountWorldGrid(pinia);

    // No entities seeded — all cells are empty
    await triggerScroll(wrapper, el, {
      scrollTop: 0,
      scrollHeight: 5000,
      clientHeight: 400,
    });

    expect(wrapper.find(BELOW_SEL).classes()).not.toContain(ACTIVE_CLASS);
  });

  it("below indicator activates with multiple entities, at least one below viewport", async () => {
    const store = usePlayerStore();
    const { wrapper, el } = await mountWorldGrid(pinia);

    // One entity visible, one entity far below
    seedDeployedCell(store, 2);
    seedDeployedCell(store, 80);

    await triggerScroll(wrapper, el, {
      scrollTop: 0,
      scrollHeight: 8000,
      clientHeight: 400,
    });

    expect(wrapper.find(BELOW_SEL).classes()).toContain(ACTIVE_CLASS);
  });
});

// ─────────────────────────────────────────────────────────────────────────────

describe("WorldGrid – overflow indicators: above indicator", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("above indicator becomes active when a deployed entity is above the viewport", async () => {
    const store = usePlayerStore();
    const { wrapper, el } = await mountWorldGrid(pinia);

    // After mount, windowStart = -16, so coordinate 0 is at index 16.
    // Deploy at coordinate 0 (index 16 in the list).
    // With a 400px viewport (8 visible cells), scrolling to index 30+ pushes coord 0 above.
    seedDeployedCell(store, 0);

    // Scroll far enough down that coordinate 0 (index 16) is above the top of the viewport.
    // lastFirstVisible = floor(scrollTop / CELL_HEIGHT). We need firstVisible > 16.
    const scrollTop = 20 * CELL_HEIGHT; // firstVisibleIndex = 20, entity at index 16 → above

    await triggerScroll(wrapper, el, {
      scrollTop,
      scrollHeight: 10000,
      clientHeight: 400,
    });

    expect(wrapper.find(ABOVE_SEL).classes()).toContain(ACTIVE_CLASS);
  });

  it("above indicator is inactive when the viewport is scrolled back up to show the entity", async () => {
    const store = usePlayerStore();
    const { wrapper, el } = await mountWorldGrid(pinia);

    seedDeployedCell(store, 0);

    // First scroll down past the entity
    await triggerScroll(wrapper, el, {
      scrollTop: 20 * CELL_HEIGHT,
      scrollHeight: 10000,
      clientHeight: 400,
    });
    expect(wrapper.find(ABOVE_SEL).classes()).toContain(ACTIVE_CLASS);

    // Now scroll back up so coordinate 0 (index 16) is visible
    // firstVisibleIndex = floor(0 / 50) = 0 — entity at index 16 is not above index 0
    // We need scrollTop such that firstVisibleIndex <= 16. scrollTop = 10 * 50 = 500 → firstVisible = 10 ≤ 16.
    await triggerScroll(wrapper, el, {
      scrollTop: 10 * CELL_HEIGHT,
      scrollHeight: 10000,
      clientHeight: 400,
    });

    expect(wrapper.find(ABOVE_SEL).classes()).not.toContain(ACTIVE_CLASS);
  });

  it("above indicator becomes inactive when the entity above is removed", async () => {
    const store = usePlayerStore();
    const { wrapper, el } = await mountWorldGrid(pinia);

    seedDeployedCell(store, 0);

    await triggerScroll(wrapper, el, {
      scrollTop: 20 * CELL_HEIGHT,
      scrollHeight: 10000,
      clientHeight: 400,
    });

    expect(wrapper.find(ABOVE_SEL).classes()).toContain(ACTIVE_CLASS);

    // Remove the entity
    store.worldCells.set(0, { coordinate: 0, placedEntity: null });
    (store as any).worldCells = new Map(store.worldCells);
    await flushPromises();

    expect(wrapper.find(ABOVE_SEL).classes()).not.toContain(ACTIVE_CLASS);
  });

  it("above indicator does not activate when only empty cells are above the viewport", async () => {
    const { wrapper, el } = await mountWorldGrid(pinia);

    // No entities — just scroll down into empty territory
    await triggerScroll(wrapper, el, {
      scrollTop: 20 * CELL_HEIGHT,
      scrollHeight: 10000,
      clientHeight: 400,
    });

    expect(wrapper.find(ABOVE_SEL).classes()).not.toContain(ACTIVE_CLASS);
  });

  it("above indicator activates with multiple entities, at least one above viewport", async () => {
    const store = usePlayerStore();
    const { wrapper, el } = await mountWorldGrid(pinia);

    // One entity above viewport, one entity in view
    seedDeployedCell(store, 0); // index 16 after mount (windowStart = -16)
    seedDeployedCell(store, 25); // well below, stays in view when scrolled to 20

    const scrollTop = 20 * CELL_HEIGHT; // firstVisible = 20 → coord 0 at index 16 is above

    await triggerScroll(wrapper, el, {
      scrollTop,
      scrollHeight: 10000,
      clientHeight: 400,
    });

    expect(wrapper.find(ABOVE_SEL).classes()).toContain(ACTIVE_CLASS);
  });
});

// ─────────────────────────────────────────────────────────────────────────────

describe("WorldGrid – overflow indicators: both active simultaneously", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("both indicators are active when entities exist above and below the viewport", async () => {
    const store = usePlayerStore();
    const { wrapper, el } = await mountWorldGrid(pinia);

    // After mount: windowStart = -16.
    // Coordinate 0 → index 16. Coordinate 80 → index 96.
    // With a 400px (8 cell) viewport at scrollTop = 20 * CELL_HEIGHT:
    //   firstVisibleIndex = 20 → coord 0 (idx 16) is above
    //   lastVisibleIndex  = 27 → coord 80 (idx 96) is below
    seedDeployedCell(store, 0);
    seedDeployedCell(store, 80);

    await triggerScroll(wrapper, el, {
      scrollTop: 20 * CELL_HEIGHT,
      scrollHeight: 15000,
      clientHeight: 400,
    });

    expect(wrapper.find(ABOVE_SEL).classes()).toContain(ACTIVE_CLASS);
    expect(wrapper.find(BELOW_SEL).classes()).toContain(ACTIVE_CLASS);
  });

  it("both indicators become inactive when viewport is scrolled to show all entities", async () => {
    const store = usePlayerStore();
    const { wrapper, el } = await mountWorldGrid(pinia);

    seedDeployedCell(store, 0); // index 16
    seedDeployedCell(store, 5); // index 21

    // A 1000px viewport (20 cells) at scrollTop 0:
    //   firstVisibleIndex = 0, lastVisibleIndex = 19
    //   coord 0 (idx 16) → 16 >= 0, not above
    //   coord 5 (idx 21) → 21 > 19, below!
    // Use a 1500px viewport instead to fit both (indices 16 and 21)
    await triggerScroll(wrapper, el, {
      scrollTop: 0,
      scrollHeight: 10000,
      clientHeight: 1500,
    });

    expect(wrapper.find(ABOVE_SEL).classes()).not.toContain(ACTIVE_CLASS);
    expect(wrapper.find(BELOW_SEL).classes()).not.toContain(ACTIVE_CLASS);
  });
});
