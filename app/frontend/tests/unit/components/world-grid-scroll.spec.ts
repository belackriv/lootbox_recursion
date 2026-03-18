import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import { nextTick } from "vue";
import WorldGrid from "../../../Layouts/WorldGrid.vue";
import { usePlayerStore } from "../../../store/player";

// ── Stubs ─────────────────────────────────────────────────────────────────────

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

// ── Scroll geometry constants (must mirror WorldGrid.vue) ─────────────────────

// CELL_HEIGHT (48px) + gap (2px) = 50px per row
const CELL_HEIGHT = 50;
const PAGE_SIZE = 16;
const SENTINEL_HEIGHT = PAGE_SIZE * CELL_HEIGHT; // 800px
const SCROLL_THRESHOLD = CELL_HEIGHT * 4; // 200px

// ── Scroll element helper ─────────────────────────────────────────────────────

/**
 * Patches scrollHeight, clientHeight, and scrollTop onto a real DOM element
 * using configurable get/set descriptors so:
 *   - The component can read and write scrollTop without throwing.
 *   - Tests can inspect the final scrollTop value via getScrollTop().
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

// ── Tests ─────────────────────────────────────────────────────────────────────

describe("WorldGrid – onMounted sentinel buffer", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("shifts windowStart down by PAGE_SIZE on mount", async () => {
    const store = usePlayerStore();
    expect(store.windowStart).toBe(0);

    mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    expect(store.windowStart).toBe(-PAGE_SIZE);
  });

  it("sets scrollTop to SENTINEL_HEIGHT on mount so coordinate 0 is at the top of the viewport", async () => {
    const store = usePlayerStore();

    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });

    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    const { getScrollTop } = patchScrollEl(el, {
      scrollTop: 0,
      scrollHeight: 4000,
      clientHeight: 400,
    });

    // Re-mount so onMounted fires against our patched element
    wrapper.unmount();
    const wrapper2 = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    const el2 = wrapper2.find(".world-grid__body").element as HTMLElement;
    const { getScrollTop: getScrollTop2 } = patchScrollEl(el2, {
      scrollTop: 0,
      scrollHeight: 4000,
      clientHeight: 400,
    });

    await flushPromises();

    // scrollTop should be set to SENTINEL_HEIGHT by onMounted
    expect(getScrollTop2()).toBe(SENTINEL_HEIGHT);
  });

  it("negative coordinates are immediately present in sortedWorldCells after mount", async () => {
    const store = usePlayerStore();

    mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    expect(coords).toContain(-1);
    expect(coords).toContain(-PAGE_SIZE);
  });

  it("coordinate 0 is still present in sortedWorldCells after mount", async () => {
    const store = usePlayerStore();

    mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    expect(coords).toContain(0);
  });

  it("sentinel cells above 0 are all empty (placedEntity null)", async () => {
    const store = usePlayerStore();

    mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const sentinel = store.sortedWorldCells.filter(
      (c) => c.coordinate >= -PAGE_SIZE && c.coordinate < 0
    );
    expect(sentinel.length).toBe(PAGE_SIZE);
    for (const cell of sentinel) {
      expect(cell.placedEntity).toBeNull();
    }
  });
});

// ─────────────────────────────────────────────────────────────────────────────

describe("WorldGrid – scroll-driven window expansion", () => {
  let pinia: ReturnType<typeof createPinia>;

  beforeEach(() => {
    pinia = createPinia();
    setActivePinia(pinia);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  // ── Downward expansion ───────────────────────────────────────────────────

  it("increases windowSize by PAGE_SIZE when scrolled near the bottom", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialSize = store.windowSize;

    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    // distanceFromBottom = 2000 - 1700 - 400 = -100 (< SCROLL_THRESHOLD)
    patchScrollEl(el, {
      scrollTop: 1700,
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.windowSize).toBe(initialSize + PAGE_SIZE);
  });

  it("does not increase windowSize when scrolled far from the bottom", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialSize = store.windowSize;

    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    // distanceFromBottom = 2000 - 0 - 400 = 1600 (well above threshold)
    patchScrollEl(el, {
      scrollTop: 800,
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.windowSize).toBe(initialSize);
  });

  it("accumulates windowSize across multiple bottom-scroll events", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialSize = store.windowSize;
    const el = wrapper.find(".world-grid__body").element as HTMLElement;

    for (let i = 0; i < 2; i++) {
      patchScrollEl(el, {
        scrollTop: 1700,
        scrollHeight: 2000,
        clientHeight: 400,
      });
      await wrapper.find(".world-grid__body").trigger("scroll");
      await flushPromises();
    }

    expect(store.windowSize).toBe(initialSize + PAGE_SIZE * 2);
  });

  it("expanding windowSize adds the correct number of cells to sortedWorldCells", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialCount = store.sortedWorldCells.length;
    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    patchScrollEl(el, {
      scrollTop: 1700,
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.sortedWorldCells.length).toBe(initialCount + PAGE_SIZE);
  });

  it("new cells added by downward scroll start at the old window end coordinate", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    // Record after mount (sentinel already shifted windowStart)
    const initialEnd = store.windowStart + store.windowSize;

    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    patchScrollEl(el, {
      scrollTop: 1700,
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    expect(coords).toContain(initialEnd);
    expect(coords).toContain(initialEnd + PAGE_SIZE - 1);
  });

  // ── Upward expansion ─────────────────────────────────────────────────────

  it("decreases windowStart by PAGE_SIZE when scrolled near the top", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialStart = store.windowStart;
    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    // scrollTop = 100 < SCROLL_THRESHOLD (200)
    patchScrollEl(el, {
      scrollTop: 100,
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.windowStart).toBe(initialStart - PAGE_SIZE);
  });

  it("can scroll upward immediately on page load without needing to scroll down first", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    // After mount the sentinel gives us scroll range above coordinate 0.
    // Simulating a scroll up toward scrollTop=0 should expand the window
    // without any prior downward scroll.
    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    patchScrollEl(el, {
      scrollTop: 50,
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.windowStart).toBe(-PAGE_SIZE * 2);
  });

  it("does not decrease windowStart when scrollTop is far from the top", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialStart = store.windowStart;
    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    // scrollTop = 500 > SCROLL_THRESHOLD (200)
    patchScrollEl(el, {
      scrollTop: 500,
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.windowStart).toBe(initialStart);
  });

  it("accumulates windowStart shifts across multiple top-scroll events", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialStart = store.windowStart;
    const el = wrapper.find(".world-grid__body").element as HTMLElement;

    for (let i = 0; i < 3; i++) {
      patchScrollEl(el, {
        scrollTop: 50,
        scrollHeight: 2000,
        clientHeight: 400,
      });
      await wrapper.find(".world-grid__body").trigger("scroll");
      await flushPromises();
    }

    expect(store.windowStart).toBe(initialStart - PAGE_SIZE * 3);
  });

  it("prepended cells have placedEntity null", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const startBefore = store.windowStart;
    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    patchScrollEl(el, { scrollTop: 50, scrollHeight: 2000, clientHeight: 400 });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    const prepended = store.sortedWorldCells.filter(
      (c) => c.coordinate >= store.windowStart && c.coordinate < startBefore
    );
    expect(prepended.length).toBeGreaterThan(0);
    for (const cell of prepended) {
      expect(cell.placedEntity).toBeNull();
    }
  });

  // ── Scroll-position compensation on upward expansion ────────────────────

  it("compensates scrollTop by PAGE_SIZE * CELL_HEIGHT after upward expansion", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    const scrollTopBefore = 100;
    const expectedCompensation = PAGE_SIZE * CELL_HEIGHT; // 16 * 50 = 800

    const { getScrollTop } = patchScrollEl(el, {
      scrollTop: scrollTopBefore,
      scrollHeight: 3000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(getScrollTop()).toBe(scrollTopBefore + expectedCompensation);
  });

  it("does not modify scrollTop when expanding downward only", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    // Near bottom, far from top — only downward expansion triggers
    const { getScrollTop } = patchScrollEl(el, {
      scrollTop: 1700,
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    // scrollTop must not have been adjusted by the component
    expect(getScrollTop()).toBe(1700);
  });

  // ── Upper bound guard ────────────────────────────────────────────────────

  it("stops expanding upward once windowStart reaches the lower bound", async () => {
    const store = usePlayerStore();
    store.windowStart = 0 - PAGE_SIZE * 100;

    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    patchScrollEl(el, { scrollTop: 50, scrollHeight: 2000, clientHeight: 400 });

    const startBefore = store.windowStart;
    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.windowStart).toBe(startBefore);
  });

  // ── Both edges simultaneously ────────────────────────────────────────────

  it("expands both downward and upward when near both edges at once", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialStart = store.windowStart;
    const initialSize = store.windowSize;

    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    // scrollTop=50 (near top), distanceFromBottom = 500-50-400 = 50 (near bottom)
    patchScrollEl(el, { scrollTop: 50, scrollHeight: 500, clientHeight: 400 });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.windowStart).toBe(initialStart - PAGE_SIZE);
    expect(store.windowSize).toBe(initialSize + PAGE_SIZE);
  });

  // ── Threshold boundary ───────────────────────────────────────────────────

  it("expands downward when distanceFromBottom is exactly one below threshold", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialSize = store.windowSize;
    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    // distanceFromBottom = SCROLL_THRESHOLD - 1 = 199
    patchScrollEl(el, {
      scrollTop: 2000 - 400 - (SCROLL_THRESHOLD - 1),
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.windowSize).toBe(initialSize + PAGE_SIZE);
  });

  it("does not expand downward when distanceFromBottom equals threshold exactly", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialSize = store.windowSize;
    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    // distanceFromBottom = exactly SCROLL_THRESHOLD = 200 (not < threshold)
    patchScrollEl(el, {
      scrollTop: 2000 - 400 - SCROLL_THRESHOLD,
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.windowSize).toBe(initialSize);
  });

  it("expands upward when scrollTop is exactly one below threshold", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialStart = store.windowStart;
    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    // scrollTop = SCROLL_THRESHOLD - 1 = 199 (< threshold)
    patchScrollEl(el, {
      scrollTop: SCROLL_THRESHOLD - 1,
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.windowStart).toBe(initialStart - PAGE_SIZE);
  });

  it("does not expand upward when scrollTop equals threshold exactly", async () => {
    const store = usePlayerStore();
    const wrapper = mount(WorldGrid, {
      global: globalConfig(pinia),
      props: { channel: undefined },
    });
    await flushPromises();

    const initialStart = store.windowStart;
    const el = wrapper.find(".world-grid__body").element as HTMLElement;
    // scrollTop = exactly SCROLL_THRESHOLD = 200 (not < threshold)
    patchScrollEl(el, {
      scrollTop: SCROLL_THRESHOLD,
      scrollHeight: 2000,
      clientHeight: 400,
    });

    await wrapper.find(".world-grid__body").trigger("scroll");
    await flushPromises();

    expect(store.windowStart).toBe(initialStart);
  });
});
