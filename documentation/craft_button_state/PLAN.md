# Plan: Make Lootbox Craft Button Reflect Player Action States

## Overview
Currently, the craft button appears pressable even when a player lacks the required materials (50 wood + 50 iron). This plan ensures the button's visual state and interactivity reflect actual crafting eligibility.

## Current Architecture

### Backend (Rails)
1. **PlayerAction Model** (`app/models/player_action.rb`)
   - Defines action metadata (name, label, disabled, revealed, etc.)
   - Has `update_disabled()` method that checks requirements against inventory
   - Requirements are checked against `user.send(req['check'])` (e.g., `user.inventory_items`)

2. **Player Action State** (`app/models/player_action_state.rb`)
   - Stores the user's action state in the database
   - Persists the disabled/revealed status per user

3. **User Model** (`app/models/user.rb`)
   - `get_player_actions()` - retrieves actions and applies stored states
   - `update_player_actions()` - updates action states and saves them
   - `craft()` - calls `LootBox.craft()`

4. **LootBox Model** (`app/models/loot_box.rb`)
   - `craft()` method performs the actual crafting
   - Returns `{ success, mutations, reason }`
   - Broadcasts mutations to `PlayerInventoryChannel`

5. **Entity Model** (`app/models/entity.rb`)
   - `remove_inventory()` - removes items from inventory
   - `add_inventory()` - adds items to inventory
   - Both methods return mutations

### Frontend (Vue/TypeScript)
1. **Player Store** (`app/frontend/store/player.ts`)
   - Stores `availableActions` (array of PlayerAction)
   - `mutateInventory()` - applies inventory mutations from server
   - `updateAvailableActions()` - receives updated actions from server

2. **CraftActionButton Component** (`app/frontend/Shared/CraftActionButton.vue`)
   - Uses `action?.disabled` to determine if button is disabled
   - Has cooldown and cast time animations
   - Sends action via `playerActionsChannel.send()`

3. **PlayerActionsChannel** (`app/frontend/channels/playerActions.ts`)
   - Receives updated PlayerActions from server
   - Calls `store.updateAvailableActions()`

4. **PlayerInventoryChannel** (`app/frontend/channels/playerInventory.ts`)
   - Receives inventory mutations from server
   - Calls `store.mutateInventory()`

## Problem Statement
1. **Current Issue**: Button `disabled` state is only set during initial page load via `get_available_actions`
2. **Missing**: When inventory changes (items removed/added), the craft action's `disabled` state is NOT updated
3. **Result**: Player sees a disabled button that suddenly becomes clickable (or vice versa) without visual feedback

## Solution: Update Action States on Inventory Mutation

### Phase 1: Backend - Update Actions After Inventory Changes

#### Step 1.1: Modify Entity Model
- After `remove_inventory()` or `add_inventory()`, update the user's action states
- Call a new method: `trigger_action_state_update()`

```ruby
# In Entity.remove_inventory()
def remove_inventory(class_name, count)
  # ... existing code ...
  mutations = []
  # ... apply mutations ...
  
  # NEW: Trigger action state updates after inventory changes
  user.trigger_action_state_update
  
  return mutations
end

# In Entity.add_inventory()
def add_inventory(class_name, count)
  # ... existing code ...
  mutations = []
  # ... apply mutations ...
  
  # NEW: Trigger action state updates after inventory changes
  user.trigger_action_state_update
  
  return mutations
end
```

#### Step 1.2: Add Trigger Method to User Model
- Create a new method that updates all action states and broadcasts them
- This ensures frontend gets the latest action states

```ruby
# In User model
def trigger_action_state_update
  # Recalculate all action states based on current inventory
  update_player_actions
  
  # Broadcast updated actions to the user's PlayerActionsChannel
  updated_actions = get_available_actions.map do |action|
    action.to_jbuilder.attributes!
  end
  PlayerActionsChannel.broadcast_to(self, updated_actions)
end
```

#### Step 1.3: Integrate into Craft Method
- Ensure that after crafting (success or failure), the craft action state is updated
- The mutation broadcast in the `ensure` block should trigger this

```ruby
# In LootBox.craft()
begin
  # ... crafting logic ...
  success = true
rescue => e
  # ... error handling ...
ensure
  # Broadcast mutations
  mutations_payload = mutations.map { |mutation| mutation.to_jbuilder.attributes! }
  PlayerInventoryChannel.broadcast_to(user, mutations_payload)
  
  # NEW: Trigger action state update so disabled state reflects new inventory
  user.trigger_action_state_update
end
```

### Phase 2: Frontend - React to Action State Updates

#### Step 2.1: Enhance PlayerActionsChannel
- Already implemented! The channel receives actions and calls `store.updateAvailableActions()`
- No changes needed - it already broadcasts updated actions

#### Step 2.2: Store Updates
- The store already has `updateAvailableActions()` that replaces the action array
- This will update the `disabled` property for all actions
- Vue reactivity will automatically update the button appearance

#### Step 2.3: CraftActionButton Component
- Component already respects `action?.disabled`
- No changes needed - it will reactively disable/enable based on store updates

## Implementation Steps

### Backend Implementation
1. **Update Entity Model** - Add `trigger_action_state_update()` calls in `remove_inventory()` and `add_inventory()`
2. **Update User Model** - Add `trigger_action_state_update()` method
3. **Update LootBox Model** - Call `user.trigger_action_state_update()` after crafting

### Frontend Implementation
- No changes needed! The frontend already supports this via reactive updates

## Testing Strategy

### Unit Tests
1. **Entity Tests**
   - Verify `remove_inventory()` calls `trigger_action_state_update()`
   - Verify `add_inventory()` calls `trigger_action_state_update()`

2. **User Tests**
   - Test `trigger_action_state_update()` updates action states correctly
   - Test craft action becomes disabled when materials are insufficient
   - Test craft action becomes enabled when materials are sufficient

### Integration Tests
1. **Full Craft Flow**
   - Player starts with 100 wood, 100 iron
   - Craft button should be enabled
   - Player crafts lootbox (removes 50 wood, 50 iron)
   - Craft button should remain enabled (still have 50 of each)
   - Player crafts another lootbox (removes 50 wood, 50 iron)
   - Craft button should be disabled (insufficient materials)
   - Player scavenges and gets 50 wood
   - Craft button should remain disabled (still need iron)
   - Player scavenges and gets 50 iron
   - Craft button should be enabled (sufficient materials again)

2. **Frontend Tests**
   - Mock PlayerActionsChannel to send updated actions
   - Verify button disabled attribute updates reactively
   - Verify button appearance changes (CSS classes) based on disabled state

## Benefits
1. **Real-time Feedback**: Players see immediate visual feedback when their material count changes
2. **Prevents Errors**: Button accurately reflects whether craft is possible
3. **Better UX**: No confusion about why a button looks clickable but doesn't work
4. **Maintainable**: Centralized action state update logic in User model
5. **Extensible**: Other actions can use the same pattern

## Edge Cases to Consider
1. **Concurrent Actions**: If two inventory mutations happen rapidly, ensure action states are correctly recalculated
2. **Network Latency**: Frontend might see action before state update arrives - this is okay as state update will correct it
3. **Multiple Actions**: Ensure all actions' states are updated, not just craft
4. **Cooldowns**: Craft action can be disabled for two reasons (no materials OR on cooldown) - ensure both are respected

## Database Considerations
- No new migrations needed
- Existing `PlayerActionState` table already stores action states
- Inventory mutations already trigger broadcasts

## Performance Considerations
- `trigger_action_state_update()` will call `update_player_actions()` which:
  - Loads all player actions
  - Queries inventory for each action's requirements
  - Saves action states to database
- This is acceptable for craft/scavenge actions (typically 1-2 per action)
- Could optimize in future by only updating affected actions, not all actions

## Future Enhancements
1. Batch action state updates if multiple inventory changes occur within a time window
2. Add logging to track when craft button becomes enabled/disabled
3. Show tooltip with reason craft is disabled (e.g., "Need 23 more iron")
4. Add progress indicator showing materials toward craft requirement