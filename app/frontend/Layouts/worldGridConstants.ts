// Scroll geometry constants for WorldGrid.
// Exported here so both WorldGrid.vue and test files share a single source of truth.

// How many cells to add each time the user scrolls to an edge.
export const PAGE_SIZE = 16;

// Each cell is 48px tall with a 2px gap below it.
export const CELL_HEIGHT = 50;

// How many pixels from the edge triggers an expansion.
export const SCROLL_THRESHOLD = CELL_HEIGHT * 4;

// Height of the sentinel buffer prepended on mount so the user can scroll
// upward immediately. Equals exactly one page worth of cells.
export const SENTINEL_HEIGHT = PAGE_SIZE * CELL_HEIGHT;
