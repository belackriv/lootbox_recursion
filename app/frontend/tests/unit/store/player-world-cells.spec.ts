import { describe, it, expect, beforeEach } from "vitest";
import { createPinia, setActivePinia } from "pinia";
import { usePlayerStore } from "../../../store/player";
import type { WorldCell, PlacedEntity } from "../../../types/index";

const ENCLOSURE_TYPE = "IrradiationEnclosureInventoryItem";

function makePlacedEntity(type = ENCLOSURE_TYPE): PlacedEntity {
  return { type, displayName: "Irradiation Enclosure", tooltip: null };
}

function seedCell(
  store: ReturnType<typeof usePlayerStore>,
  coordinate: number,
  placedEntity: PlacedEntity | null = null
) {
  store.worldCells.set(coordinate, { coordinate, placedEntity });
  // mirror the reactivity trigger used in the store itself
  store.worldCells = new Map(store.worldCells);
}

describe("player store – sortedWorldCells", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  // ── Default window ────────────────────────────────────────────────────────

  it("contains exactly windowSize cells when the map is empty", () => {
    const store = usePlayerStore();
    expect(store.sortedWorldCells.length).toBe(store.windowSize);
  });

  it("starts at coordinate 0 by default", () => {
    const store = usePlayerStore();
    expect(store.sortedWorldCells[0].coordinate).toBe(0);
  });

  it("ends at coordinate windowSize - 1 by default", () => {
    const store = usePlayerStore();
    const cells = store.sortedWorldCells;
    expect(cells[cells.length - 1].coordinate).toBe(store.windowSize - 1);
  });

  it("all default cells have placedEntity null", () => {
    const store = usePlayerStore();
    for (const cell of store.sortedWorldCells) {
      expect(cell.placedEntity).toBeNull();
    }
  });

  it("cells are sorted ascending by coordinate", () => {
    const store = usePlayerStore();
    seedCell(store, 5, makePlacedEntity());
    seedCell(store, 99, makePlacedEntity());
    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    for (let i = 1; i < coords.length; i++) {
      expect(coords[i]).toBeGreaterThan(coords[i - 1]);
    }
  });

  // ── Entity inside the window ──────────────────────────────────────────────

  it("shows a placed entity at a coordinate within the window", () => {
    const store = usePlayerStore();
    const entity = makePlacedEntity();
    seedCell(store, 5, entity);
    const cell = store.sortedWorldCells.find((c) => c.coordinate === 5);
    expect(cell).toBeDefined();
    expect(cell!.placedEntity).toMatchObject({ type: ENCLOSURE_TYPE });
  });

  // ── Entity beyond window end fills gap ───────────────────────────────────

  it("extends the list to include a placed entity beyond the default window", () => {
    const store = usePlayerStore();
    seedCell(store, 99, makePlacedEntity());
    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    expect(coords).toContain(99);
  });

  it("fills every coordinate between window end and a far placed entity", () => {
    const store = usePlayerStore();
    // Default window is [0, 32). Place entity at 35 — coords 32, 33, 34
    // must be generated as empty cells.
    seedCell(store, 35, makePlacedEntity());
    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    expect(coords).toContain(32);
    expect(coords).toContain(33);
    expect(coords).toContain(34);
    expect(coords).toContain(35);
  });

  it("cells between window end and far entity are empty", () => {
    const store = usePlayerStore();
    seedCell(store, 40, makePlacedEntity());
    const cells = store.sortedWorldCells;
    for (const cell of cells) {
      if (cell.coordinate >= store.windowSize && cell.coordinate < 40) {
        expect(cell.placedEntity).toBeNull();
      }
    }
  });

  it("does not add cells beyond the far placed entity", () => {
    const store = usePlayerStore();
    seedCell(store, 40, makePlacedEntity());
    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    expect(coords).not.toContain(41);
  });

  it("handles two placed entities at different far coordinates", () => {
    const store = usePlayerStore();
    seedCell(store, 50, makePlacedEntity());
    seedCell(store, 99, makePlacedEntity());
    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    // Gap between window end and first entity
    expect(coords).toContain(32);
    // Gap between the two entities
    expect(coords).toContain(51);
    expect(coords).toContain(98);
    // Both entities
    expect(coords).toContain(50);
    expect(coords).toContain(99);
    // Nothing beyond the far one
    expect(coords).not.toContain(100);
  });

  // ── windowStart and windowSize changes ───────────────────────────────────

  it("reflects an enlarged windowSize immediately", () => {
    const store = usePlayerStore();
    store.windowSize += 16;
    expect(store.sortedWorldCells.length).toBe(48);
  });

  it("reflects a shifted windowStart immediately", () => {
    const store = usePlayerStore();
    store.windowStart = 10;
    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    expect(coords[0]).toBe(10);
    expect(coords[coords.length - 1]).toBe(10 + store.windowSize - 1);
  });

  it("supports negative windowStart", () => {
    const store = usePlayerStore();
    store.windowStart = -16;
    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    expect(coords[0]).toBe(-16);
    expect(coords).toContain(0);
  });

  it("window-only cells outside the new window are not shown after windowStart increases", () => {
    const store = usePlayerStore();
    // Default starts at 0. Shift window to start at 10 — coord 0–9 should
    // not appear unless they hold a placed entity.
    store.windowStart = 10;
    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    expect(coords).not.toContain(0);
    expect(coords).not.toContain(9);
  });

  // ── snapshotWorldCells integration ───────────────────────────────────────

  it("snapshotWorldCells merges server cells and they appear in sortedWorldCells", () => {
    const store = usePlayerStore();
    store.snapshotWorldCells([
      {
        coordinate: 5,
        placedEntity: {
          type: ENCLOSURE_TYPE,
          display_name: "IE",
          tooltip: null,
        },
      },
    ]);
    const cell = store.sortedWorldCells.find((c) => c.coordinate === 5);
    expect(cell?.placedEntity?.type).toBe(ENCLOSURE_TYPE);
  });
});

// ─────────────────────────────────────────────────────────────────────────────

describe("player store – trimWorldCells", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  // ── Window reset ─────────────────────────────────────────────────────────

  it("resets windowStart to firstPlacedCoord - 4 when a placed entity exists", () => {
    const store = usePlayerStore();
    store.windowStart = -48;
    seedCell(store, 20, makePlacedEntity());
    store.trimWorldCells();
    expect(store.windowStart).toBe(20 - 4);
  });

  it("resets windowStart to 0 when no placed entities exist", () => {
    const store = usePlayerStore();
    store.windowStart = -48;
    store.trimWorldCells();
    expect(store.windowStart).toBe(0);
  });

  it("resets windowSize to 32", () => {
    const store = usePlayerStore();
    store.windowSize = 128;
    store.trimWorldCells();
    expect(store.windowSize).toBe(32);
  });

  it("after trim with no placed entities, sortedWorldCells has exactly 32 entries", () => {
    const store = usePlayerStore();
    store.windowSize = 128;
    store.trimWorldCells();
    expect(store.sortedWorldCells.length).toBe(32);
  });

  it("anchors window to the lowest-coordinate placed entity when multiple exist", () => {
    const store = usePlayerStore();
    seedCell(store, 50, makePlacedEntity());
    seedCell(store, 10, makePlacedEntity());
    seedCell(store, 80, makePlacedEntity());
    store.trimWorldCells();
    expect(store.windowStart).toBe(10 - 4);
  });

  it("windowStart can be negative when first placed entity is within 4 of coordinate 0", () => {
    const store = usePlayerStore();
    seedCell(store, 2, makePlacedEntity());
    store.trimWorldCells();
    expect(store.windowStart).toBe(2 - 4); // -2
  });

  // ── Empty cells outside window are dropped ───────────────────────────────

  it("removes empty cells that were scrolled in beyond the new window", () => {
    const store = usePlayerStore();
    // No placed entities → newStart = 0, window = [0, 32)
    store.windowSize = 64;
    seedCell(store, 50, null); // empty, outside [0, 32) → drop
    store.trimWorldCells();
    expect(store.worldCells.has(50)).toBe(false);
  });

  it("removes empty cells scrolled in above the new window", () => {
    const store = usePlayerStore();
    // No placed entities → newStart = 0; coord -10 is outside [0, 32) → drop
    store.windowStart = -32;
    seedCell(store, -10, null);
    store.trimWorldCells();
    expect(store.worldCells.has(-10)).toBe(false);
  });

  it("removes multiple out-of-window empty cells in one trim", () => {
    const store = usePlayerStore();
    store.windowSize = 96;
    for (let c = 32; c < 96; c++) {
      seedCell(store, c, null);
    }
    store.trimWorldCells();
    for (let c = 32; c < 96; c++) {
      expect(store.worldCells.has(c)).toBe(false);
    }
  });

  // ── Placed entities are always kept ─────────────────────────────────────

  it("retains a placed entity outside the default window", () => {
    const store = usePlayerStore();
    seedCell(store, 99, makePlacedEntity());
    store.trimWorldCells();
    expect(store.worldCells.has(99)).toBe(true);
    expect(store.worldCells.get(99)!.placedEntity).not.toBeNull();
  });

  it("retains multiple placed entities beyond the default window", () => {
    const store = usePlayerStore();
    seedCell(store, 50, makePlacedEntity());
    seedCell(store, 99, makePlacedEntity());
    store.trimWorldCells();
    expect(store.worldCells.has(50)).toBe(true);
    expect(store.worldCells.has(99)).toBe(true);
  });

  it("retains a placed entity at a negative coordinate", () => {
    const store = usePlayerStore();
    seedCell(store, -5, makePlacedEntity());
    store.trimWorldCells();
    expect(store.worldCells.has(-5)).toBe(true);
  });

  it("retains placed entities inside the default window", () => {
    const store = usePlayerStore();
    seedCell(store, 10, makePlacedEntity());
    store.trimWorldCells();
    expect(store.worldCells.has(10)).toBe(true);
  });

  // ── Mixed: some kept, some dropped ──────────────────────────────────────

  it("drops out-of-window empty cells but keeps out-of-window placed entities simultaneously", () => {
    const store = usePlayerStore();
    store.windowSize = 64;
    // First placed entity is at coord 50, so newStart = 50 - 4 = 46.
    // Window after trim: [46, 78). Coord 40 is outside → drop. Coord 60 is inside → kept as empty.
    seedCell(store, 40, null); // empty, outside [46,78) → drop
    seedCell(store, 50, makePlacedEntity()); // placed → always kept
    seedCell(store, 70, null); // empty, outside [46,78)? 70 < 78 → inside, kept

    // Use a coord clearly outside the new window for the "drop" assertion
    seedCell(store, 90, null); // empty, outside [46,78) → drop

    store.trimWorldCells();

    expect(store.worldCells.has(40)).toBe(false);
    expect(store.worldCells.has(50)).toBe(true);
    expect(store.worldCells.has(90)).toBe(false);
  });

  // ── sortedWorldCells after trim still fills gap to placed entity ──────────

  it("sortedWorldCells after trim still fills gap between window end and far placed entity", () => {
    const store = usePlayerStore();
    // Place two entities: one near (coord 5) and one far (coord 99).
    // Trim anchors to the first placed entity at coord 5.
    // newStart = 5 - 4 = 1. Window = [1, 33). Far entity at 99 is outside
    // the window but has a placedEntity so sortedWorldCells must bridge to it.
    seedCell(store, 5, makePlacedEntity());
    seedCell(store, 99, makePlacedEntity());
    store.windowSize = 64; // expand via scroll simulation
    store.trimWorldCells();

    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    // Window starts at 1, entity at 5 is inside
    expect(coords).toContain(1);
    expect(coords).toContain(5);
    // Gap from window end (33) up to the far entity must be filled
    expect(coords).toContain(33);
    expect(coords).toContain(98);
    expect(coords).toContain(99);
    expect(coords).not.toContain(100);
  });

  // ── Idempotence ──────────────────────────────────────────────────────────

  it("is idempotent — trimming twice produces the same result as trimming once", () => {
    const store = usePlayerStore();
    store.windowSize = 64;
    seedCell(store, 99, makePlacedEntity());

    store.trimWorldCells();
    const afterFirst = store.sortedWorldCells.map((c) => c.coordinate);

    store.trimWorldCells();
    const afterSecond = store.sortedWorldCells.map((c) => c.coordinate);

    expect(afterFirst).toEqual(afterSecond);
  });
});

// ─────────────────────────────────────────────────────────────────────────────

describe("player store – window expansion (scroll simulation)", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("increasing windowSize adds new empty cells to sortedWorldCells", () => {
    const store = usePlayerStore();
    const before = store.sortedWorldCells.length;
    store.windowSize += 16;
    const after = store.sortedWorldCells.length;
    expect(after).toBe(before + 16);
  });

  it("new cells added by expanding windowSize are empty", () => {
    const store = usePlayerStore();
    store.windowSize += 16;
    const cells = store.sortedWorldCells;
    for (const cell of cells.slice(32)) {
      expect(cell.placedEntity).toBeNull();
    }
  });

  it("decreasing windowStart prepends empty cells", () => {
    const store = usePlayerStore();
    store.windowStart = -16;
    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    for (let c = -16; c < 0; c++) {
      expect(coords).toContain(c);
    }
  });

  it("prepended cells have placedEntity null", () => {
    const store = usePlayerStore();
    store.windowStart = -16;
    const cells = store.sortedWorldCells;
    const prepended = cells.filter((c) => c.coordinate < 0);
    expect(prepended.length).toBe(16);
    for (const cell of prepended) {
      expect(cell.placedEntity).toBeNull();
    }
  });

  it("expanding windowSize multiple times accumulates correctly", () => {
    const store = usePlayerStore();
    store.windowSize += 16; // 48
    store.windowSize += 16; // 64
    expect(store.sortedWorldCells.length).toBe(64);
  });

  it("expanding windowStart downward multiple times accumulates correctly", () => {
    const store = usePlayerStore();
    store.windowStart -= 16; // -16
    store.windowStart -= 16; // -32
    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    expect(coords[0]).toBe(-32);
  });

  it("placed entity at boundary of expanded window is visible", () => {
    const store = usePlayerStore();
    store.windowSize += 16; // expand to [0, 48)
    seedCell(store, 47, makePlacedEntity());
    const cell = store.sortedWorldCells.find((c) => c.coordinate === 47);
    expect(cell?.placedEntity).not.toBeNull();
  });

  it("upward expansion includes originally-windowed cells too", () => {
    const store = usePlayerStore();
    store.windowStart = -8;
    // Window is now [-8, -8 + 32) = [-8, 24)
    const coords = store.sortedWorldCells.map((c) => c.coordinate);
    // Cells within new window are present
    expect(coords).toContain(0);
    expect(coords).toContain(23); // last coord in window
    // New cells prepended
    expect(coords).toContain(-8);
    expect(coords).toContain(-1);
    // Coord 24+ is outside the window (no placed entities) — not present
    expect(coords).not.toContain(24);
  });
});
