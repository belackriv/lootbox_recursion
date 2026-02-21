require "test_helper"

class LootBoxTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "craft broadcasts inventory channel payload with envelope format" do
    user = User.create!(email_address: "envelope_test@example.com", password: "password")
    entity = user.entity
    entity.ensure_inventory_slots

    # Clear all slots for deterministic state
    entity.inventory_slots.order(slot: :asc).each do |s|
      s.inventory_item = nil
      s.save!
    end

    # Add required materials
    wood = WoodInventoryItem.create!(entity: entity, count: 50)
    iron = IronInventoryItem.create!(entity: entity, count: 50)
    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots[0].inventory_item = wood
    slots[0].save!
    slots[1].inventory_item = iron
    slots[1].save!

    # Capture broadcasts to PlayerInventoryChannel
    inventory_broadcasts = capture_broadcasts(PlayerInventoryChannel.broadcasting_for(user)) do
      LootBox.craft(user, {})
    end

    # There should be at least one broadcast with the envelope format
    assert_not_empty inventory_broadcasts, "Expected at least one broadcast to PlayerInventoryChannel"

    # Find the craft broadcast (the last one should be the ensure-block broadcast)
    envelope = inventory_broadcasts.last

    assert envelope.key?("action"), "Broadcast payload should include 'action' key"
    assert envelope.key?("data"), "Broadcast payload should include 'data' key"
    assert_equal "inventory_mutations", envelope["action"], "Broadcast action should be 'inventory_mutations'"
    assert_kind_of Array, envelope["data"], "Broadcast data should be an Array"
  end

  test "craft creates loot box record and adds LootBoxInventoryItem and consumes materials" do
    user = User.create!(email_address: "test1@example.com", password: "password")
    entity = user.entity

    # Ensure the entity has inventory slots available
    entity.ensure_inventory_slots

    # Clear all inventory slots to make test deterministic
    entity.inventory_slots.order(slot: :asc).each do |s|
      s.inventory_item = nil
      s.save!
    end

    # Add required materials by creating inventory items and assigning them to slots
    wood = WoodInventoryItem.create!(entity: entity, count: 50)
    iron = IronInventoryItem.create!(entity: entity, count: 50)
    slots = entity.inventory_slots.order(slot: :asc).to_a
    # Place wood and iron into the first two slots
    slots[0].inventory_item = wood
    slots[0].save!
    slots[1].inventory_item = iron
    slots[1].save!

    assert_equal 50, entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    assert_equal 50, entity.inventory_items.where(type: "IronInventoryItem").sum(:count)

    # Perform the craft which should consume materials and create a LootBox + inventory item
    result = LootBox.craft(user, {})

    assert result[:success], "Expected craft to succeed"

    # A LootBox record should have been created and associated with the user's entity
    assert LootBox.where(user: user).exists?, "Expected a LootBox record to be created for the user"
    loot_box = LootBox.where(user: user).order(:created_at).last
    assert_equal entity.id, loot_box.entity_id

    # A LootBoxInventoryItem should exist in the entity's inventory referencing the loot_box
    loot_item = InventoryItem.where(entity: entity, type: "LootBoxInventoryItem").first
    assert_not_nil loot_item, "Expected a LootBoxInventoryItem to be present in the inventory"
    assert_equal 1, loot_item.count
    assert_equal loot_box.id, loot_item.loot_box_id

    # The required materials should have been consumed (counts reduced to 0)
    assert_equal 0, entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    assert_equal 0, entity.inventory_items.where(type: "IronInventoryItem").sum(:count)
  end

  test "craft rolls back when no inventory slot is available" do
    user = User.create!(email_address: "test2@example.com", password: "password")
    entity = user.entity

    # Ensure slots exist
    entity.ensure_inventory_slots
    slots = entity.inventory_slots.order(slot: :asc).to_a

    # Clear all slots to ensure deterministic state before filling
    slots.each do |slot|
      slot.inventory_item = nil
      slot.save!
    end

    # Fill every slot with items so there is no empty slot for the new lootbox item.
    # Distribute Wood and Iron across slots so both materials are available for removal.
    slots.each_with_index do |slot, i|
      if i < (slots.length / 2)
        item = WoodInventoryItem.create!(entity: entity, count: 100)
      else
        item = IronInventoryItem.create!(entity: entity, count: 100)
      end
      slot.inventory_item = item
      slot.save!
    end

    # Record current material totals
    wood_before = entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    iron_before = entity.inventory_items.where(type: "IronInventoryItem").sum(:count)

    # Attempt to craft; since there is no available slot the transaction should rollback
    result = LootBox.craft(user, {})

    # Debugging: inspect the returned structure and inventory state when failure occurs
    puts "craft result: #{result.inspect}"
    puts "inventory items summary: Wood=#{entity.inventory_items.where(type: 'WoodInventoryItem').sum(:count)} Iron=#{entity.inventory_items.where(type: 'IronInventoryItem').sum(:count)} LootBoxItems=#{entity.inventory_items.where(type: 'LootBoxInventoryItem').count}"

    assert result.is_a?(Hash)
    assert_equal false, result[:success], "Expected craft to fail due to no available slot"

    # Ensure reason is provided and mutations is present (should be empty on rollback)
    assert_not_nil result[:reason], "Expected a failure reason when craft fails"
    assert_kind_of Array, result[:mutations], "Expected mutations key to be an Array even on failure"
    assert_empty result[:mutations], "Expected no applied mutations on rollback"

    # Ensure no LootBox was created
    assert_not LootBox.where(user: user).exists?, "Expected no LootBox record to be created on failure"

    # Ensure materials were not consumed (transaction rolled back)
    wood_after = entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    iron_after = entity.inventory_items.where(type: "IronInventoryItem").sum(:count)
    assert_equal wood_before, wood_after
    assert_equal iron_before, iron_after

    # Ensure no LootBoxInventoryItem was created
    assert_not InventoryItem.where(entity: entity, type: "LootBoxInventoryItem").exists?
  end

  test "craft fails when materials are insufficient" do
    user = User.create!(email_address: "insufficient@example.com", password: "password")
    entity = user.entity

    entity.ensure_inventory_slots
    # Clear slots to deterministic state before setting up test items
    entity.inventory_slots.order(slot: :asc).each do |s|
      s.inventory_item = nil
      s.save!
    end

    # Provide insufficient wood but sufficient iron by creating items and assigning to slots
    wood = WoodInventoryItem.create!(entity: entity, count: 10)
    iron = IronInventoryItem.create!(entity: entity, count: 50)
    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots[0].inventory_item = wood
    slots[0].save!
    slots[1].inventory_item = iron
    slots[1].save!

    wood_before = entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    iron_before = entity.inventory_items.where(type: "IronInventoryItem").sum(:count)

    result = LootBox.craft(user, {})

    # Debugging info for failed craft due to insufficient materials
    puts "craft result (insufficient materials test): #{result.inspect}"
    puts "inventory items after attempt: Wood=#{entity.inventory_items.where(type: 'WoodInventoryItem').sum(:count)}, Iron=#{entity.inventory_items.where(type: 'IronInventoryItem').sum(:count)}"

    assert result.is_a?(Hash)
    assert_equal false, result[:success], "Expected craft to fail due to insufficient materials"

    # Ensure reason and mutations keys exist and are consistent with a rollback
    assert_equal "insufficient_materials", result[:reason], "Expected reason to indicate insufficient materials"
    assert_kind_of Array, result[:mutations]
    assert_empty result[:mutations], "Expected no applied mutations on insufficient-materials rollback"

    # Ensure materials were not consumed (transaction rolled back)
    assert_equal wood_before, entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    assert_equal iron_before, entity.inventory_items.where(type: "IronInventoryItem").sum(:count)

    # Ensure no LootBox or LootBoxInventoryItem was created
    assert_not LootBox.where(user: user).exists?
    assert_not InventoryItem.where(entity: entity, type: "LootBoxInventoryItem").exists?
  end

  test "craft uses next available slot if first slot contains a full LootBoxInventoryItem" do
    user = User.create!(email_address: "nextslot@example.com", password: "password")
    entity = user.entity

    # Prepare clean inventory and materials
    entity.ensure_inventory_slots
    # Clear all slots to deterministic state before placing materials
    entity.inventory_slots.order(slot: :asc).each do |s|
      s.inventory_item = nil
      s.save!
    end

    # Place materials into later slots so we don't interfere with slot 0/1 used in the test
    slots = entity.inventory_slots.order(slot: :asc).to_a
    wood = WoodInventoryItem.create!(entity: entity, count: 50)
    iron = IronInventoryItem.create!(entity: entity, count: 50)
    # Use slots[2] and slots[3] (they should exist given default inventory size)
    slots[2].inventory_item = wood
    slots[2].save!
    slots[3].inventory_item = iron
    slots[3].save!

    slots = entity.inventory_slots.order(slot: :asc).to_a
    first_slot = slots[0]
    second_slot = slots[1]

    # Put a full LootBoxInventoryItem into the first slot
    # Create without running validations to avoid association/foreign-key presence validations
    existing_item = LootBoxInventoryItem.new(entity: entity, count: LootBoxInventoryItem::STACK_SIZE)
    existing_item.save!(validate: false)
    first_slot.inventory_item = existing_item
    first_slot.save!

    # Ensure second slot is empty (force it to be empty to avoid flaky preconditions)
    if second_slot.inventory_item
      # Remove any unexpected item that might interfere with the test
      # Use save without validations in case test-only state would fail validations
      second_slot.inventory_item.destroy!
      second_slot.inventory_item = nil
      second_slot.save!
    end

    # As a defensive check, reload the slot and ensure it's actually empty
    second_slot.reload
    assert_nil second_slot.inventory_item, "Second slot must be empty before crafting; found #{second_slot.inventory_item&.inspect}"

    # Run craft and capture the result for inspection on failure
    result = LootBox.craft(user, {})

    # If craft failed unexpectedly, output detailed debug info to help identify the cause
    unless result[:success]
      puts "craft result in next-slot test: #{result.inspect}"
      puts "Mutations returned: #{result[:mutations].map { |m| { item_type: m.item_type, delta: m.delta, slot: m.inventory_slot&.slot } }.inspect}"
      puts "Slots state after craft:"
      entity.inventory_slots.order(slot: :asc).each do |s|
        puts "slot=#{s.slot} item_id=#{s.inventory_item&.id} item_type=#{s.inventory_item&.type} item_count=#{s.inventory_item&.count} loot_box_id=#{s.inventory_item&.loot_box_id}"
      end
      # Also dump top-level inventory items for clarity
      puts "Inventory items summary:"
      entity.inventory_items.order(:id).each do |it|
        puts "item id=#{it.id} type=#{it.type} count=#{it.count} slot_id=#{it.inventory_slot&.slot} loot_box_id=#{it.respond_to?(:loot_box_id) ? it.loot_box_id : nil}"
      end
    end

    assert result[:success], "Expected craft to succeed when another slot is available"

    # The LootBoxInventoryItem may be placed into any available slot except the first_slot
    # (which we intentionally pre-filled). Search for a LootBoxInventoryItem in any other slot.
    lootbox_slot = nil
    entity.inventory_slots.order(slot: :asc).each do |s|
      if s.inventory_item && s.inventory_item.type == "LootBoxInventoryItem" && s.slot != first_slot.slot
        lootbox_slot = s
        break
      end
    end

    assert_not_nil lootbox_slot, "Expected a LootBoxInventoryItem to be placed in some slot other than the first slot"

    # Verify the materials were consumed as part of a successful craft
    assert_equal 0, entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    assert_equal 0, entity.inventory_items.where(type: "IronInventoryItem").sum(:count)
  end

  test "craft action becomes disabled after crafting when materials are insufficient" do
    user = User.create!(email_address: "action_state@example.com", password: "password")
    entity = user.entity
    entity.ensure_inventory_slots

    # Clear all slots for deterministic state
    entity.inventory_slots.order(slot: :asc).each do |s|
      s.inventory_item = nil
      s.save!
    end

    # Add 51 wood and 51 iron (more than 50 required for craft requirements which use gt)
    wood = WoodInventoryItem.create!(entity: entity, count: 51)
    iron = IronInventoryItem.create!(entity: entity, count: 51)
    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots[0].inventory_item = wood
    slots[0].save!
    slots[1].inventory_item = iron
    slots[1].save!

    # Verify craft action is enabled before crafting
    user.update_player_actions
    craft_action_before = user.get_available_actions.find { |a| a.name == "craft" }
    assert_not craft_action_before.disabled, "Craft action should be enabled when materials are sufficient (> 50)"

    # Perform the craft (consumes 50, leaving 1)
    result = LootBox.craft(user, {})
    assert result[:success], "Craft should succeed with sufficient materials"

    # After crafting, reload user's action states to reflect the inventory change
    # In production, this happens via PlayerActionsChannel broadcast, but in tests we call it directly
    user.update_player_actions
    craft_action_after = user.get_available_actions.find { |a| a.name == "craft" }

    # Verify craft action is now disabled (need > 50, but only have 1 left)
    assert craft_action_after.disabled, "Craft action should be disabled when materials drop to 1 (needs > 50)"
  end

  test "scavenge triggers action state update via trigger_action_state_update" do
    user = User.create!(email_address: "scavenge_state@example.com", password: "password")
    entity = user.entity
    entity.ensure_inventory_slots

    # Clear all slots
    entity.inventory_slots.order(slot: :asc).each do |s|
      s.inventory_item = nil
      s.save!
    end

    # Verify initial state
    user.update_player_actions
    craft_action_initial = user.get_available_actions.find { |a| a.name == "craft" }
    assert craft_action_initial.disabled, "Craft should be disabled initially (no materials)"

    # Add inventory via add_inventory, which should trigger action state update
    # Need > 50 for each, so add 51 of each
    entity.add_inventory("WoodInventoryItem", 51)
    entity.add_inventory("IronInventoryItem", 51)

    # Reload and check action state was updated
    user.update_player_actions
    craft_action_after = user.get_available_actions.find { |a| a.name == "craft" }
    assert_not craft_action_after.disabled, "Craft should be enabled after adding > 50 of each material"
  end

  # ---------------------------------------------------------------------------
  # LootBox#open! tests
  # ---------------------------------------------------------------------------

  # Shared helper: create a user + entity with inventory slots, craft a loot box,
  # and return [user, entity, loot_box].
  def create_user_with_crafted_loot_box(email:)
    user   = User.create!(email_address: email, password: "password")
    entity = user.entity
    entity.ensure_inventory_slots

    entity.inventory_slots.order(slot: :asc).each { |s| s.update!(inventory_item: nil) }

    wood = WoodInventoryItem.create!(entity: entity, count: 50)
    iron = IronInventoryItem.create!(entity: entity, count: 50)
    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots[0].update!(inventory_item: wood)
    slots[1].update!(inventory_item: iron)

    result = LootBox.craft(user, {})
    assert result[:success], "Precondition: craft must succeed (got: #{result.inspect})"

    loot_box = LootBox.where(user: user).order(:created_at).last
    [ user, entity, loot_box ]
  end

  test "open! returns success with mutations and loot arrays" do
    user, entity, loot_box = create_user_with_crafted_loot_box(email: "open_success@example.com")

    result = loot_box.open!

    assert result.is_a?(Hash)
    assert_equal true,  result[:success],   "Expected open! to succeed"
    assert_nil          result[:reason],    "Expected no failure reason on success"
    assert_kind_of Array, result[:mutations]
    assert_kind_of Array, result[:loot]
    assert_not_empty result[:mutations], "Expected at least one inventory mutation"
    assert_not_empty result[:loot],      "Expected at least one LootBoxLoot record"
  end

  test "open! sets opened_at on the loot box" do
    user, entity, loot_box = create_user_with_crafted_loot_box(email: "open_opened_at@example.com")

    assert_nil loot_box.opened_at, "Precondition: loot box must not be opened yet"
    loot_box.open!
    loot_box.reload

    assert_not_nil loot_box.opened_at, "Expected opened_at to be set after open!"
  end

  test "open! removes the LootBoxInventoryItem from inventory" do
    user, entity, loot_box = create_user_with_crafted_loot_box(email: "open_removes_box@example.com")

    assert InventoryItem.where(entity: entity, type: "LootBoxInventoryItem").exists?,
           "Precondition: LootBoxInventoryItem must exist before opening"

    loot_box.open!

    assert_not InventoryItem.where(entity: entity, type: "LootBoxInventoryItem").exists?,
               "Expected LootBoxInventoryItem to be removed after open!"
  end

  test "open! adds rolled items to inventory" do
    user, entity, loot_box = create_user_with_crafted_loot_box(email: "open_adds_items@example.com")

    wood_before = entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    iron_before = entity.inventory_items.where(type: "IronInventoryItem").sum(:count)

    result = loot_box.open!
    assert result[:success], "Expected open! to succeed"

    entity.reload
    wood_after = entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    iron_after = entity.inventory_items.where(type: "IronInventoryItem").sum(:count)

    # At least one material type must have increased (loot table always grants at least some)
    assert (wood_after > wood_before) || (iron_after > iron_before),
           "Expected at least one material to increase after opening. " \
           "Wood: #{wood_before}->#{wood_after}, Iron: #{iron_before}->#{iron_after}"
  end

  test "open! creates LootBoxLoot records linked to this loot box" do
    user, entity, loot_box = create_user_with_crafted_loot_box(email: "open_loot_records@example.com")

    loot_box.open!

    loot_records = LootBoxLoot.where(loot_box: loot_box)
    assert_not_empty loot_records, "Expected LootBoxLoot records to be created"
    loot_records.each do |record|
      assert_equal loot_box.id, record.loot_box_id
      assert_not_nil record.item_snapshot, "Expected item_snapshot to be present"
      assert_not_nil record.item_snapshot["type"], "Expected item_snapshot to include item type"
      assert_equal true, record.claimed
      assert record.count.to_i > 0, "Expected loot count > 0"
    end
  end

  test "open! broadcasts to PlayerInventoryChannel" do
    user, entity, loot_box = create_user_with_crafted_loot_box(email: "open_broadcast@example.com")

    broadcasts = capture_broadcasts(PlayerInventoryChannel.broadcasting_for(user)) do
      loot_box.open!
    end

    assert_not_empty broadcasts, "Expected at least one broadcast to PlayerInventoryChannel"

    # The final ensure-block broadcast carries the mutation payload
    envelope = broadcasts.last
    assert envelope.key?("action"), "Broadcast payload must include 'action' key"
    assert_equal "inventory_mutations", envelope["action"]
    assert_kind_of Array, envelope["data"]
  end

  test "open! returns already_opened when loot box was previously opened" do
    user, entity, loot_box = create_user_with_crafted_loot_box(email: "open_already_opened@example.com")

    # First open succeeds
    first = loot_box.open!
    assert first[:success], "Expected first open! to succeed"

    # Second open must be rejected
    second = loot_box.open!
    assert_equal false,            second[:success]
    assert_equal "already_opened", second[:reason]
    assert_empty                   second[:mutations]
  end

  test "open! returns no_inventory_item when LootBoxInventoryItem is missing" do
    user   = User.create!(email_address: "open_no_item@example.com", password: "password")
    entity = user.entity
    entity.ensure_inventory_slots

    # Create a loot box without a corresponding LootBoxInventoryItem in inventory
    loot_box = LootBox.create!(user: user, entity: entity)

    result = loot_box.open!
    assert_equal false,             result[:success]
    assert_equal "no_inventory_item", result[:reason]
  end

  test "open! does not set opened_at when it fails" do
    user, entity, loot_box = create_user_with_crafted_loot_box(email: "open_no_opened_at@example.com")

    # Force failure by pre-marking as opened
    loot_box.update_columns(opened_at: 1.hour.ago)

    result = loot_box.open!
    assert_equal false,            result[:success]
    assert_equal "already_opened", result[:reason]

    # opened_at should still be the original value, not updated to now
    loot_box.reload
    assert loot_box.opened_at < Time.current - 30.minutes,
           "Expected opened_at to remain the original pre-set value"
  end

  test "open! is idempotent — second call does not create additional loot records" do
    user, entity, loot_box = create_user_with_crafted_loot_box(email: "open_idempotent@example.com")

    loot_box.open!
    loot_count_after_first = LootBoxLoot.where(loot_box: loot_box).count

    loot_box.open!
    loot_count_after_second = LootBoxLoot.where(loot_box: loot_box).count

    assert_equal loot_count_after_first, loot_count_after_second,
                 "Expected no additional LootBoxLoot records on second (rejected) open attempt"
  end

  test "open! base LootBoxModifier no-op apply does not change config" do
    user   = User.create!(email_address: "modifier_noop@example.com", password: "password")
    entity = user.entity

    loot_box = LootBox.create!(user: user, entity: entity)

    modifier = LootBoxModifier.new(loot_box: loot_box)
    original_config = { rolls: { min: 2, max: 4 }, entries: [] }

    result = modifier.apply(original_config)
    assert_equal original_config, result, "Expected base LootBoxModifier#apply to return config unchanged"
  end

  test "open! applies loot_box_modifiers to the loot table config" do
    user, entity, loot_box = create_user_with_crafted_loot_box(email: "open_modifier_apply@example.com")

    # Build a modifier subclass inline that forces exactly 1 roll
    one_roll_modifier_class = Class.new(LootBoxModifier) do
      def apply(config)
        config.merge(rolls: { min: 1, max: 1 })
      end
    end

    # Stub loot_box_modifiers to return an instance of our inline modifier
    stub_modifier = one_roll_modifier_class.new
    stub_modifier.define_singleton_method(:loot_box) { loot_box }
    loot_box.define_singleton_method(:loot_box_modifiers) do
      [ stub_modifier ]
    end

    result = loot_box.open!

    assert result[:success], "Expected open! to succeed with modifier applied"
    # With exactly 1 roll, there should be at least 1 loot record
    assert_not_empty result[:loot], "Expected at least one loot record even with 1 forced roll"
  end
end
