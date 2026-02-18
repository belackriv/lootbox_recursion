# Exact Edit Checklist: Sort Inventory Backend

This checklist captures the concrete backend edits needed to add a `Sort` player action, support sort-disabled rules, and migrate inventory channel payloads to an action/data envelope.

## A) Add new player action config

### File: `lootbox_recursion/app/data/player_actions.yml`

- Add a new action entry:

  - `name: "sort_inventory"`
  - `label: "Sort"`
  - `disabled: true` (initial default; runtime updates will compute actual state)
  - `revealed: true`
  - `cooldown: 1`
  - `on_cooldown_until: null`
  - `cast_time: 0` (recommended so cooldown handles throttling; no artificial cast delay)
  - `choices: []`
  - `requirements: []`
  - `reveal_requirements: []`

Why: action definitions are loaded from YAML into `PlayerAction` instances via `APP_DATA`.

---

## B) Add user method to execute sort action

### File: `lootbox_recursion/app/models/user.rb`

- Add method:

  - `def sort_inventory(action_data)`
    - call `entity.sort_and_compress_inventory!`
    - build payload:
      - `inventory_payload = entity.inventory_slots.order(:slot).limit(100).map { |slot| slot.to_jbuilder.attributes! }`
    - broadcast to inventory channel with envelope:
      - `{ action: "inventory_snapshot", data: inventory_payload }`

- Keep existing action-state update flow:
  - `sort_and_compress_inventory!` already triggers action-state refresh through entity/user path.
  - avoid duplicate state broadcasts unless needed.

Why: the action job dispatches with `user.send(action_name, action_data)`, so this is the execution handler for `sort_inventory`.

---

## C) Add disabled logic for Sort action (cooldown + sort-needed)

### File: `lootbox_recursion/app/models/player_action.rb`

- In `update_disabled(user)`, add a special-case branch for `name == "sort_inventory"` before generic requirements logic.

Suggested behavior:

1. `on_cooldown = on_cooldown_until && on_cooldown_until > Time.current`
2. `sort_needed = user.entity.present? && user.entity.inventory_sort_needed?`
3. `self.disabled = on_cooldown || !sort_needed`
4. return from method (skip generic requirement loop for this action)

Notes on “disabled while sort is being performed”:

- Current architecture sets cooldown immediately in `perform_action` before enqueuing execution.
- With `cooldown: 1` and `cast_time: 0`, button disables immediately during execution window and for the cooldown period.

---

## D) Add sort-needed predicate on entity

### File: `lootbox_recursion/app/models/entity.rb`

- Add `inventory_sort_needed?`:

  1. ensure slots exist (`ensure_inventory_slots`)
  2. load slots in ascending slot order with `inventory_item`
  3. build current non-empty sequence:
     - `[{ type: "...", count: n }, ...]`
  4. build expected organized sequence using same logic as `sort_and_compress_inventory!`:
     - aggregate totals by `type`
     - sort types by `Object.const_get(type).display_name.downcase`, tie-break on `type`
     - split totals into stacks using `STACK_SIZE`
  5. return whether current sequence differs from expected sequence

- Keep `sort_and_compress_inventory!` as the actual mutating operation.

Why: this drives action disabled state so `Sort` is only enabled when it would change inventory.

---

## E) Refactor inventory channel payload protocol to envelope

Target envelope format:

- `{ action: string, data: [] | {} }`

### File: `lootbox_recursion/app/models/inventory_item.rb`

- In `self.scavenge_item`, change broadcast payload:
  - from raw mutation array
  - to:
    - `{ action: "inventory_mutations", data: mutations_payload }`

### File: `lootbox_recursion/app/models/loot_box.rb`

- In craft broadcast path (`ensure` block), change payload to:
  - `{ action: "inventory_mutations", data: mutations_payload }`

### File: `lootbox_recursion/app/jobs/apply_inventory_item_mutations_job.rb`

- Wrap final broadcast payload:
  - `{ action: "inventory_mutations", data: mutations_payload }`

Why: keeps existing mutation transport while introducing a stable, extensible message contract.

---

## F) Tests to add/update

### File: `lootbox_recursion/test/models/entity_test.rb`

Add tests for `inventory_sort_needed?`:

- empty inventory => `false`
- already sorted/compressed => `false`
- unsorted types => `true`
- compressible split stacks => `true`

### File: `lootbox_recursion/test/models/player_action_state_test.rb`

Add tests:

- available actions include `sort_inventory` with label `Sort`
- disabled when empty/already-organized inventory
- enabled when organization needed
- after performing sort action, disabled during cooldown
- cooldown is set and approximately 1 second in future

### File: `lootbox_recursion/test/models/inventory_item_test.rb` (or create/add targeted test)

- verify scavenge inventory channel payload uses envelope:
  - includes `action`
  - includes `data`
  - `action == "inventory_mutations"`

### File: `lootbox_recursion/test/models/loot_box_test.rb`

- update/add assertions for inventory channel payload envelope format where applicable.

---

## G) Files likely unchanged

- `lootbox_recursion/app/channels/player_inventory_channel.rb` (transport/subscription only)
- `lootbox_recursion/app/channels/player_actions_channel.rb` (already routes incoming action requests)
- `lootbox_recursion/app/jobs/perform_player_action_job.rb` (generic action dispatcher remains valid)

---

## H) Recommended verification run order

1. `bin/rails test test/models/entity_test.rb`
2. `bin/rails test test/models/player_action_state_test.rb`
3. `bin/rails test test/models/loot_box_test.rb`
4. run any new/updated inventory item or job tests
5. full suite if desired