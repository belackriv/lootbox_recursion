# Quick Reference: Craft Button State Reflection Implementation

## What Was Changed

### Backend Changes

#### 1. `app/models/entity.rb`
- Added `trigger_action_state_update()` calls in `remove_inventory()` method (after item removal)
- Added `trigger_action_state_update()` calls in `add_inventory()` method (after item addition)
- Added new `trigger_action_state_update()` method that delegates to user

#### 2. `app/models/user.rb`
- Added `trigger_action_state_update()` method that:
  - Calls `update_player_actions()` to recalculate all action states
  - Broadcasts updated actions via `PlayerActionsChannel.broadcast_to()`

#### 3. `app/models/loot_box.rb`
- Added `user.trigger_action_state_update()` call in the `ensure` block
- Ensures action states update after crafting completes (success or failure)

### Frontend Changes
**NONE** - Frontend already supports this feature through existing infrastructure

## How It Works (Simple Version)

```
Inventory changes (craft/scavenge)
  → trigger_action_state_update() called
  → PlayerAction.update_disabled() checks requirements against inventory
  → If insufficient materials: action.disabled = true
  → If sufficient materials: action.disabled = false
  → PlayerActionsChannel broadcasts updated actions to client
  → Frontend store updates
  → Vue reactivity updates button :disabled attribute
  → Button appears enabled/disabled in UI
```

## Craft Requirements

The craft action is **ENABLED** when:
- Player has **> 50 wood** AND **> 50 iron**

The craft action is **DISABLED** when:
- Player has **≤ 50 wood** OR **≤ 50 iron**

## Key Files

| File | Changes | Lines |
|------|---------|-------|
| `app/models/entity.rb` | Added trigger calls + new method | ~60-101 |
| `app/models/user.rb` | Added trigger_action_state_update method | ~113-124 |
| `app/models/loot_box.rb` | Added trigger call in ensure block | ~95-98 |
| `test/models/loot_box_test.rb` | Added 2 new tests | ~238-300 |

## Testing

### Run Tests
```bash
bundle exec rails test test/models/loot_box_test.rb
```

### Expected Results
```
6 runs, 40 assertions, 0 failures, 0 errors, 0 skips
```

### What's Being Tested
1. ✅ Action state updates after craft (materials become insufficient)
2. ✅ Action state updates after inventory add (scavenge)
3. ✅ All original 4 craft tests still pass

## How to Verify in Production

1. **Start server**: `bin/dev`
2. **Open browser**: Navigate to game
3. **Initial state**: Craft button should be disabled (no materials)
4. **Click scavenge**: Gather wood and iron
5. **Watch button**: Button becomes enabled when materials exceed threshold
6. **Click craft**: Button works and crafts lootbox
7. **After craft**: Button becomes disabled again (materials consumed)

## Architecture

### ActionCable Flow
```
Entity.add_inventory()
  ↓
trigger_action_state_update()
  ↓
User.trigger_action_state_update()
  ↓
update_player_actions() [recalculates states]
  ↓
PlayerActionsChannel.broadcast_to(user, actions)
  ↓
Client receives actions
  ↓
store.updateAvailableActions(actions)
  ↓
Vue detects change in availableActions
  ↓
CraftActionButton sees :disabled binding change
  ↓
Button CSS classes update
```

## Code Locations

### Where to Add Similar Features
If you want to add this feature to other actions:

1. **Check action requirements**: `app/data/player_actions.yml`
2. **Action state logic**: `app/models/player_action.rb` (already handles requirements)
3. **Trigger calls**: Already in Entity, so other actions benefit automatically
4. **Button components**: Already reactive, no changes needed

### Where State is Persisted
- **Database**: `player_action_states` table
- **Query**: `PlayerActionState.where(user: user, player_action_name: 'craft')`
- **Format**: `action_state` column (JSON serialized attributes)

## Common Questions

### Q: Why is the button update real-time?
A: ActionCable broadcasts changes immediately after inventory mutations, and Vue reactivity updates the DOM automatically.

### Q: What if the button becomes out of sync?
A: Reload the page - initial page load fetches correct action states via `IndexController`.

### Q: Does this work for other actions too?
A: Yes! The system works for any action with requirements defined in `player_actions.yml`. Currently handles: craft, use, (scavenge has no requirements).

### Q: What about performance?
A: Minimal impact. Action state update happens after inventory mutation (unavoidable). Query cost is low (checking 2-3 requirements per action).

### Q: Can broadcasts be reduced?
A: Yes, future enhancement could batch broadcasts or only broadcast changed actions.

## Related Files to Understand

- `app/models/player_action.rb` - Logic for checking requirements
- `app/channels/player_actions_channel.rb` - Server-side ActionCable channel
- `app/frontend/channels/playerActions.ts` - Client-side ActionCable subscription
- `app/frontend/Shared/CraftActionButton.vue` - Button component
- `app/frontend/store/player.ts` - Pinia store with availableActions

## Debugging Tips

### Check Backend Logs
```ruby
# In Rails console
user.get_available_actions.find { |a| a.name == 'craft' }.disabled  # true/false
user.entity.inventory_items.sum(:count)  # Check inventory totals
```

### Check Frontend Logs
```javascript
// In browser console
store.availableActions  // Should have craft with correct disabled state
```

### Force Action Update
```ruby
# In Rails console
user = User.find(1)
user.trigger_action_state_update  # Manually trigger broadcast
```

### Check Database State
```ruby
# In Rails console
PlayerActionState.where(player_action_name: 'craft').first.action_state
# => {"disabled"=>true, "name"=>"craft", ...}
```

## Deployment Notes

- ✅ No migrations required
- ✅ Backward compatible
- ✅ No changes to existing API contracts
- ✅ Safe to deploy without special considerations
- ✅ All existing tests pass

## Summary

**What**: Craft button now shows whether crafting is possible based on inventory
**How**: Action state updates triggered on inventory mutations, broadcast via ActionCable
**Why**: Better UX - players see instant feedback about action availability
**Impact**: Small, focused change that leverages existing infrastructure
**Testing**: 6 tests pass including 2 new tests verifying the feature
