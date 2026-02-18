# Sort Inventory Frontend Changes

## Inventory Channel Envelope Protocol

### `app/frontend/types/index.ts`

Added `InventoryChannelEnvelope` discriminated union type:

- `{ action: "inventory_mutations"; data: Array<InventoryMutation> }` — existing mutation-based updates
- `{ action: "inventory_snapshot"; data: Array<InventorySlot> }` — full inventory replacement (used by sort)

### `app/frontend/channels/playerInventory.ts`

Updated `receive` to unwrap the `{ action, data }` envelope and dispatch based on `action`:

- `"inventory_mutations"` → calls `store.mutateInventory(data)` (existing behavior)
- `"inventory_snapshot"` → calls `store.snapshotInventory(data)` (new)
- Unknown actions log a warning to console

### `app/frontend/store/player.ts`

Added `snapshotInventory(slots)` method:

- Takes the flat array of server inventory slots from the snapshot envelope
- Iterates each slot and overwrites the corresponding grid cell's `inventoryItem` in place
- Handles both camelCase and snake_case keys from the backend
- Clears slots where the server item is null or has zero count
- Exported from the store's return object