# Inventory Slot Selection

## Overview

This feature allows the player to select a single inventory slot at a time by left-clicking it. The selected slot is highlighted with a construction yellow border (`border-yellow-400`). Clicking the same slot again deselects it. Only one slot can be selected at a time.

---

## Changed Files

| File | Change Type | Description |
|---|---|---|
| `app/frontend/store/player.ts` | Modified | Added `selectedSlotIndex` state and `selectSlot` action |
| `app/frontend/Shared/InventoryItemSlot.vue` | Modified | Added click handler, `isSelected` computed, dynamic border class |

---

## Implementation Details

### `app/frontend/store/player.ts`

Two additions were made inside the `usePlayerStore` Pinia store:

**State:**
```ts
const selectedSlotIndex = ref<number | null>(null);
```
Holds the slot number of the currently selected slot, or `null` if nothing is selected.

**Action:**
```ts
const selectSlot = (slotNumber: number) => {
  selectedSlotIndex.value =
    selectedSlotIndex.value === slotNumber ? null : slotNumber;
};
```
Selects the given slot. If that slot is already selected, it deselects it (toggle). Both `selectedSlotIndex` and `selectSlot` are exposed in the store's return object.

---

### `app/frontend/Shared/InventoryItemSlot.vue`

Three additions were made:

**Store access:**
```ts
const store = usePlayerStore();
```

**Computed selection state:**
```ts
const isSelected = computed(
  () => store.selectedSlotIndex === props.gridSlot.slot.slot
);
```

**Template — click handler and dynamic border class:**
```html
<div
  class="w-16 h-16 flex-none border-2 transition-colors duration-150 relative cursor-pointer"
  :class="
    isSelected
      ? 'border-yellow-400'
      : 'border-slate-500 hover:border-slate-300'
  "
  @click="store.selectSlot(props.gridSlot.slot.slot)"
>
```

Notable changes from the original `div`:
- `transition-border-color duration-500` replaced with `transition-colors duration-150` (faster, covers all color transitions)
- `border-slate-500 hover:border-slate-300` moved into the dynamic `:class` binding so they are mutually exclusive with the selected state
- `cursor-pointer` added to signal the slot is interactive
- `border-yellow-400` applied when `isSelected` is true

---

## Behaviour

| User Action | Result |
|---|---|
| Left-click an unselected slot | That slot becomes selected (yellow border). Any previously selected slot is deselected. |
| Left-click the currently selected slot | The slot is deselected. No slot is selected. |
| Inventory updates (items added/removed) | Selection state is unaffected. |

---

## Design Decisions

- **Selection state lives in the Pinia store** rather than local component state so that other systems (crafting, actions, equipment) can read `selectedSlotIndex` without prop drilling or event buses.
- **Toggle on re-click** provides a natural way to dismiss a selection without requiring an explicit "deselect" mechanism.
- **Construction yellow (`border-yellow-400`)** matches the Tailwind yellow-400 value (`#facc15`), which is close to the standard caution/construction yellow used in the game's UI vocabulary.
- **No changes to `InventoryRow.vue` or `InventoryGrid.vue`** — selection is fully self-contained between the store and the individual slot component.

---

## Accessing Selected Slot from Other Components

Any component can read or act on the current selection by importing the player store:

```ts
import { usePlayerStore } from "@/store/player.ts";

const store = usePlayerStore();

// Reactive reference to the selected slot number (or null)
store.selectedSlotIndex;

// Programmatically select or deselect a slot
store.selectSlot(slotNumber);

// Reactive reference to the InventoryItem in the selected slot (or null)
store.selectedSlotItem;
```

---

## Use Button — Disabled Unless a Lootbox Slot is Selected

### Overview

The **Use** action button is disabled unless the currently selected inventory slot contains a `LootBoxInventoryItem`. This is enforced entirely on the frontend — no server round-trip is needed.

---

### Additional Changed Files

| File | Change Type | Description |
|---|---|---|
| `app/frontend/types/index.ts` | Modified | Added `LOOTBOX_ITEM_TYPE` constant |
| `app/frontend/store/player.ts` | Modified | Added `selectedSlotItem` computed |
| `app/frontend/Shared/ActionButton.vue` | Modified | Added `isDisabled` computed, updated `:disabled` binding and `onClick` guard |

---

### `app/frontend/types/index.ts`

A named constant was added to avoid repeating the item type string:

```ts
export const LOOTBOX_ITEM_TYPE = "LootBoxInventoryItem";
```

---

### `app/frontend/store/player.ts`

A `computed` was added that derives the `InventoryItem` (or `null`) sitting in the currently selected slot. It is reactive — it updates automatically when either `selectedSlotIndex` or the inventory contents change.

```ts
const selectedSlotItem = computed(() => {
  if (selectedSlotIndex.value === null) return null;
  const slotNumber = selectedSlotIndex.value;
  const rowIndex = Math.floor(slotNumber / inventoryRowLength);
  const columnIndex = slotNumber % inventoryRowLength;
  return (
    inventory.value.rows[rowIndex]?.[columnIndex]?.slot?.inventoryItem ?? null
  );
});
```

Exposed on the store's return object as `selectedSlotItem`.

---

### `app/frontend/Shared/ActionButton.vue`

**`isDisabled` computed** replaces the raw `props.disabled` binding for the `"use"` action:

```ts
const isDisabled = computed(() => {
  if (props.name === "use") {
    return store.selectedSlotItem?.type !== LOOTBOX_ITEM_TYPE;
  }
  return props.disabled;
});
```

The `"use"` action is disabled when:
- No slot is selected (`selectedSlotItem` is `null`), or
- The selected slot's item type is not `LootBoxInventoryItem`

All other actions continue to use the `disabled` flag provided by the server via `PlayerAction`.

**`:disabled` binding** updated in the template:
```html
<button :disabled="isDisabled" ...>
```

**`onClick` guard** simplified — the old `"use"` stub (`//todo: implement use`) was replaced with a single early-return on `isDisabled`, which covers all actions uniformly:

```ts
const onClick = () => {
  if (isDisabled.value) {
    return false;
  }
  ...
};
```

---

### Behaviour

| State | Use Button |
|---|---|
| No slot selected | Disabled |
| Slot selected, slot is empty | Disabled |
| Slot selected, contains Wood or Iron | Disabled |
| Slot selected, contains `LootBoxInventoryItem` | **Enabled** |

---

### Design Decisions

- **`selectedSlotItem` lives in the store** so any future component (tooltip, context menu, equipment panel) can consume it without re-deriving the lookup logic.
- **`LOOTBOX_ITEM_TYPE` constant in `types/index.ts`** ensures the string `"LootBoxInventoryItem"` is defined in one place, consistent with the backend class name.
- **`isDisabled` keeps all other actions unchanged** — only the `"use"` branch introduces new logic; every other action still respects the server-driven `disabled` prop.
