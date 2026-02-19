# Player Action State Bugfix: Stale `disabled` Overwriting Fresh Computation

## The Bug

The craft button could appear enabled even when the player lacked sufficient materials (e.g., only 40 wood when 50+ is required).

The edge case was in `User#get_player_actions`. The original code had this order:

1. Load `PlayerAction` objects from `APP_DATA`
2. Call `update(self)` → correctly computes `disabled: true` (40 wood fails `40 > 50`)
3. Overwrite ALL attributes from `PlayerActionState` (DB) → **replaces `disabled` with a stale `false`** saved from when the player previously had enough materials

The DB overwrite at step 3 undoes the fresh computation from step 2.

### How the stale value gets into the database

1. Player scavenges and accumulates >50 wood + >50 iron
2. `trigger_action_state_update` → saves `disabled: false` to `PlayerActionState`
3. Player crafts → consumes 50 of each → 40 wood remains
4. The craft job calls `trigger_action_state_update` which eventually saves `disabled: true`…
5. **But** on the next page load (or any code path hitting `get_player_actions` without `update_player_actions`), the method computes the right answer (`disabled: true`) and then **immediately overwrites it** with whatever the DB has

### Why `update_player_actions` masked the issue

The `update_player_actions` method (used by `trigger_action_state_update`) worked around this by calling `update(self)` a second time *after* `get_player_actions`, but the standalone `get_player_actions` path (used by `IndexController#index` for page loads) had no such second pass.

### Original code

```ruby
def get_player_actions
  if @player_actions.nil?
    @player_actions = APP_DATA[:player_actions]
    @player_actions.each do |action|
      action.update(self)       # ← computes correct disabled state
    end
  end
  @player_actions.each do |action|
    player_action_state = PlayerActionState.where(user: self, player_action_name: action.name).first()
    if player_action_state
      action.assign_attributes(player_action_state.action_state)  # ← overwrites with stale DB value
    end
  end
  @player_actions
end
```

## The Fix

Move `update(self)` to **after** the DB overwrite, so the live inventory check always has the final word. Now `disabled` is always freshly computed from current inventory state, regardless of what's stored in the DB.

### Fixed code

```ruby
def get_player_actions
  if @player_actions.nil?
    @player_actions = APP_DATA[:player_actions]
  end
  # load the user's player action state and update player_actions
  @player_actions.each do |action|
    player_action_state = PlayerActionState.where(user: self, player_action_name: action.name).first()
    if player_action_state
      action.assign_attributes(player_action_state.action_state)
    end
  end
  # Recompute dynamic fields (disabled, revealed, choices) AFTER restoring
  # persisted state so that stale DB values never override a fresh check.
  @player_actions.each do |action|
    action.update(self)
  end
  @player_actions
end
```

## Affected files

- `app/models/user.rb` — `get_player_actions` method

## Related note: global mutable `APP_DATA` singletons

`APP_DATA[:player_actions]` holds singleton `PlayerAction` objects shared across all users and requests in the same process. `get_player_actions` assigns a reference (`@player_actions = APP_DATA[:player_actions]`) rather than a deep copy, so any call to `update(self)` or `assign_attributes` mutates these shared objects. In a multi-threaded server (Puma), this is a potential race condition where one user's state computation could momentarily affect another's. This is a pre-existing architectural concern separate from the fix above.
