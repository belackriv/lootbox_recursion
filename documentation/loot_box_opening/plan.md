# Loot Box Opening — Implementation Plan

> **Status:** Fully implemented. All checklist items below are complete.

## Overview

When a player "uses" a loot box, `LootBox#open!` is called on the specific `LootBox`
record. The method generates loot by:

1. Loading a **base loot table** from a system-wide YAML file (analogous to `player_actions.yml`)
2. Collecting and applying any **loot box modifiers** (new AR model — no concrete
   implementations yet, just the scaffolding)
3. Rolling loot **one or more times** from the resulting weighted table
4. Writing the results to the database and inventory, then broadcasting mutations

---

## Execution Flow

```
LootBox#open!
  │
  ├─ Guard: already opened?  →  return { success: false, reason: "already_opened" }
  │
  ├─ Load base loot table
  │     LootTable.for(loot_box)         # reads app/data/loot_tables.yml
  │                                     # selects table keyed by STI type, falls back to "default"
  │
  ├─ Collect modifiers
  │     loot_box.loot_box_modifiers     # AR association — empty for now
  │
  ├─ Apply modifiers (chain)
  │     modifiers.reduce(table_config) { |cfg, mod| mod.apply(cfg) }
  │
  ├─ Roll loot (multi-roll)
  │     LootTable#roll                  # picks roll count from config range, then for each roll:
  │                                     # weighted random selection → [{ item_type:, count: }, ...]
  │
  ├─ Inside a transaction:
  │     ├─ Remove LootBoxInventoryItem (count -= 1) via InventoryItemMutation
  │     ├─ For each rolled item:
  │     │     ├─ user.add_inventory(item_type, count) → mutations
  │     │     └─ create LootBoxLoot(loot_box:, inventory_item:, count:, claimed: true)
  │     └─ loot_box.update!(opened_at: Time.current)
  │
  ├─ Broadcast all inventory mutations via PlayerInventoryChannel
  ├─ Trigger action state update
  │
  └─ Return { success: true, mutations: [...], loot: [...], reason: nil }
```

---

## New Files

### 1. `app/data/loot_tables.yml`

System-wide loot table definitions. Keyed by loot box STI class name with a `default`
fallback if no type-specific key is found.

Each table has two sections:
- `rolls` — `min`/`max` range; a random value in this range is drawn per open to
  determine how many items are generated
- `entries` — the weighted item pool; each entry has:
  - `item_type`  — `InventoryItem` subclass name
  - `weight`     — relative probability (integer; higher = more likely)
  - `min_count`  — minimum quantity for this item when selected
  - `max_count`  — maximum quantity for this item when selected

```yaml
loot_tables:
  default:
    rolls:
      min: 2
      max: 4
    entries:
      - item_type: "WoodInventoryItem"
        weight: 60
        min_count: 5
        max_count: 20
      - item_type: "IronInventoryItem"
        weight: 40
        min_count: 3
        max_count: 10

  WoodLootBox:
    rolls:
      min: 2
      max: 5
    entries:
      - item_type: "WoodInventoryItem"
        weight: 80
        min_count: 10
        max_count: 30
      - item_type: "IronInventoryItem"
        weight: 20
        min_count: 1
        max_count: 5

  IronLootBox:
    rolls:
      min: 2
      max: 5
    entries:
      - item_type: "IronInventoryItem"
        weight: 80
        min_count: 10
        max_count: 30
      - item_type: "WoodInventoryItem"
        weight: 20
        min_count: 1
        max_count: 5
```

---

### 2. `app/models/loot_table.rb`

Plain Ruby class (PORO). Responsible for:
- Loading and caching the YAML config (`app/data/loot_tables.yml`)
- Selecting the correct sub-table for a given `LootBox` instance (by STI class name,
  falling back to `"default"`)
- Performing a multi-roll via `roll` → `[{ item_type:, count: }, ...]`

**Key interface:**

```ruby
# Returns a LootTable instance configured for the given loot box's type
LootTable.for(loot_box)   # => LootTable instance

# Accepts a raw config hash (used internally and by modifiers)
LootTable.new(config)

# Rolls loot: draws roll_count from config[:rolls] range, then picks one
# weighted entry per roll. Returns an array of { item_type:, count: } hashes.
# The same item_type may appear more than once if rolled multiple times.
loot_table.roll           # => [{ item_type: "WoodInventoryItem", count: 12 }, ...]

# Expose the raw config so modifiers can read and mutate it
loot_table.config         # => { rolls: { min:, max: }, entries: [...] }
```

**Weighted selection algorithm:** build a cumulative weight array from `entries`, draw
`rand(0...total_weight)`, find the entry whose cumulative range contains it. Repeat
`rand(min_rolls..max_rolls)` times.

---

### 3. `app/models/loot_box_modifier.rb`

ActiveRecord model. Base class for all future loot box modifier types. Uses STI (`type`
column) so concrete subclasses can be added without schema changes.

**Ownership:** a `LootBoxModifier` belongs to exactly one `LootBox`
(`loot_box_id NOT NULL`). A `LootBox` has many `loot_box_modifiers`.

**Interface:**

```ruby
class LootBoxModifier < ApplicationRecord
  belongs_to :loot_box

  # Subclasses override this method.
  # @param config [Hash]  the full loot table config ({ rolls: {...}, entries: [...] })
  # @return [Hash]        the (potentially mutated) config
  def apply(config)
    config   # base implementation is a no-op pass-through
  end
end
```

Future concrete examples might include:
- `DoubleIronModifier`      — doubles the weight of iron entries
- `BonusLootModifier`       — appends an extra guaranteed item entry
- `ExtraRollModifier`       — increments `rolls[:max]` by a fixed amount
- `CountMultiplierModifier` — scales `min_count`/`max_count` by a factor

---

## Modified Files

### `app/models/loot_box.rb` — add `open!`

The new instance method mirrors the structure of `LootBox.craft` — transaction wrapping
all writes, structured return value `{ success:, mutations:, loot:, reason: }`, and
broadcast + action state trigger in an `ensure` block.

```ruby
def open!
  mutations = []
  loot      = []
  success   = false
  reason    = nil

  begin
    ActiveRecord::Base.transaction do
      # 1. Guard against re-opening
      if opened_at.present?
        reason = "already_opened"
        raise ActiveRecord::Rollback
      end

      # 2. Locate the LootBoxInventoryItem that references this loot box
      item = LootBoxInventoryItem.find_by(loot_box: self)
      if item.nil? || item.inventory_slot.nil?
        reason = "no_inventory_item"
        raise ActiveRecord::Rollback
      end
      slot = item.inventory_slot

      # 3. Load base loot table and apply modifier chain
      base_config  = LootTable.for(self).config
      final_config = loot_box_modifiers.reduce(base_config) { |cfg, mod| mod.apply(cfg) }
      rolled       = LootTable.new(final_config).roll

      # 4. Remove the LootBoxInventoryItem from inventory
      removal = InventoryItemMutation.new(
        item_type:      "LootBoxInventoryItem",
        inventory_slot: slot,
        delta:          -1
      )
      removal.apply!
      mutations << removal

      # 5. Add each rolled item to inventory and record LootBoxLoot
      rolled.each do |roll|
        add_mutations = user.add_inventory(roll[:item_type], roll[:count])
        add_mutations.each do |m|
          loot << LootBoxLoot.create!(
            loot_box:       self,
            inventory_item: m.inventory_slot.inventory_item,
            count:          roll[:count],
            claimed:        true
          )
        end
        mutations.concat(add_mutations)
      end

      # 6. Mark the loot box as opened
      update!(opened_at: Time.current)

      success = true
    end
  rescue => e
    Rails.logger.error(
      "LootBox#open! failed for loot_box=#{id}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    )
    mutations = []
    loot      = []
    reason    = "exception" if reason.nil?
  ensure
    mutations_payload = mutations.map { |m| m.to_jbuilder.attributes! }
    PlayerInventoryChannel.broadcast_to(user, { action: "inventory_mutations", data: mutations_payload })
    user.trigger_action_state_update
  end

  result = { success: success, mutations: mutations, loot: loot, reason: reason }
  Rails.logger.info("LootBox#open! result for loot_box=#{id}: #{result.inspect}")
  result
end
```

Also add the AR association to `LootBox`:

```ruby
has_many :loot_box_modifiers, dependent: :destroy
```

---

## Database

### New migration: `create_loot_box_modifiers`

```ruby
create_table :loot_box_modifiers do |t|
  t.string  :type,        null: false          # STI discriminator
  t.bigint  :loot_box_id, null: false
  t.timestamps
end

add_index :loot_box_modifiers, :loot_box_id
add_foreign_key :loot_box_modifiers, :loot_boxes
```

No other migrations are required. The existing schema already provides:

| Table | Relevant columns used |
|---|---|
| `loot_boxes` | `opened_at`, `type`, `user_id`, `entity_id` |
| `loot_box_loots` | `loot_box_id`, `inventory_item_id`, `count`, `claimed`, `type` |
| `inventory_items` | `loot_box_id` (FK already present for `LootBoxInventoryItem`) |
| `inventory_item_mutations` | used as-is |

---

## File Checklist

- [x] `app/data/loot_tables.yml` — base loot table config (default + WoodLootBox + IronLootBox)
- [x] `app/models/loot_table.rb` — PORO loader + multi-roll weighted roller
- [x] `app/models/loot_box_modifier.rb` — abstract AR base class with no-op `apply`
- [x] Migration: `db/migrate/20251210000001_create_loot_box_modifiers.rb`
- [x] `app/models/loot_box.rb` — add `has_many :loot_box_modifiers` + `open!` method
- [x] `app/models/user.rb` — add `User#use(action_data)` delegating to `loot_box.open!`
- [x] `app/data/player_actions.yml` — fix `use` requirement value from `1` → `0` (enable when count > 0)
- [x] `app/frontend/Shared/ActionButton.vue` — pass `{ slotIndex }` as actionData on "use" click
- [x] `test/models/loot_table_test.rb` — 18 unit tests for `LootTable` PORO
- [x] `test/models/loot_box_test.rb` — 12 new `open!` integration tests
- [x] `test/models/user_test.rb` — 10 new `User#use` integration tests
- [x] `app/frontend/tests/unit/components/action-button.spec.ts` — 7 new click/payload tests

---

---

## Frontend Wiring

The "Use" button triggers `LootBox#open!` through the existing ActionCable pipeline:

```
Player selects inventory slot (LootBoxInventoryItem)
  │
  └─ ActionButton "Use" becomes enabled
       (isDisabled computed: store.selectedSlotItem?.type === LOOTBOX_ITEM_TYPE)

Player clicks "Use"
  │
  └─ ActionButton#onClick captures store.selectedSlotIndex at click time
       → performAction({ slotIndex: N })
       → store.performPlayerAction(action, { slotIndex: N }, playerActionsChannel)
       → PlayerActionsChannel.send({ playerAction: ..., playerActionData: { slotIndex: N } })

Server (PlayerActionsChannel#receive)
  │
  └─ snake_case_keys → { "player_action" => ..., "player_action_data" => { "slot_index" => N } }
  └─ current_user.perform_action("use", { "slot_index" => N })
  └─ PerformPlayerActionJob.set(wait: cast_time.seconds).perform_later(user, "use", data)

Job fires (after 5 s cast time)
  │
  └─ user.use({ "slot_index" => N })
       ├─ Look up entity.inventory_slots.find_by(slot: N)
       ├─ Verify slot holds a LootBoxInventoryItem
       ├─ loot_box = item.loot_box
       └─ loot_box.open!  →  broadcasts mutations, triggers action state update
```

**Fallback behaviour:** if `slot_index` is absent or points to a non-loot-box slot,
`User#use` falls back to the first available `LootBoxInventoryItem` in the entity's
inventory before giving up with `{ success: false, reason: "no_loot_box" }`.

---

## Out of Scope (for now)

- Concrete `LootBoxModifier` subclasses
- Per-user or per-session modifier stacking
- A "reveal" UI step before items land in inventory (the `claimed` flag is preserved for
  this possibility — set to `true` immediately for now)
- Controller / frontend wiring (tracked separately)