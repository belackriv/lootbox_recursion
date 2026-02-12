require "test_helper"

class LootBoxTest < ActiveSupport::TestCase
  test 'craft creates loot box record and adds LootBoxInventoryItem and consumes materials' do
    user = User.create!(email_address: "test1@example.com", password: "password")
    entity = Entity.create!(user: user)

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

    assert_equal 50, entity.inventory_items.where(type: 'WoodInventoryItem').sum(:count)
    assert_equal 50, entity.inventory_items.where(type: 'IronInventoryItem').sum(:count)

    # Perform the craft which should consume materials and create a LootBox + inventory item
    result = LootBox.craft(user, {})

    assert result[:success], "Expected craft to succeed"

    # A LootBox record should have been created and associated with the user's entity
    assert LootBox.where(user: user).exists?, 'Expected a LootBox record to be created for the user'
    loot_box = LootBox.where(user: user).order(:created_at).last
    assert_equal entity.id, loot_box.entity_id

    # A LootBoxInventoryItem should exist in the entity's inventory referencing the loot_box
    loot_item = InventoryItem.where(entity: entity, type: 'LootBoxInventoryItem').first
    assert_not_nil loot_item, 'Expected a LootBoxInventoryItem to be present in the inventory'
    assert_equal 1, loot_item.count
    assert_equal loot_box.id, loot_item.loot_box_id

    # The required materials should have been consumed (counts reduced to 0)
    assert_equal 0, entity.inventory_items.where(type: 'WoodInventoryItem').sum(:count)
    assert_equal 0, entity.inventory_items.where(type: 'IronInventoryItem').sum(:count)
  end

  test 'craft rolls back when no inventory slot is available' do
    user = User.create!(email_address: "test2@example.com", password: "password")
    entity = Entity.create!(user: user)

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
    wood_before = entity.inventory_items.where(type: 'WoodInventoryItem').sum(:count)
    iron_before = entity.inventory_items.where(type: 'IronInventoryItem').sum(:count)

    # Attempt to craft; since there is no available slot the transaction should rollback
    result = LootBox.craft(user, {})

    # Debugging: inspect the returned structure and inventory state when failure occurs
    puts "craft result: #{result.inspect}"
    puts "inventory items summary: Wood=#{entity.inventory_items.where(type: 'WoodInventoryItem').sum(:count)} Iron=#{entity.inventory_items.where(type: 'IronInventoryItem').sum(:count)} LootBoxItems=#{entity.inventory_items.where(type: 'LootBoxInventoryItem').count}"

    assert result.is_a?(Hash)
    assert_equal false, result[:success], 'Expected craft to fail due to no available slot'

    # Ensure reason is provided and mutations is present (should be empty on rollback)
    assert_not_nil result[:reason], 'Expected a failure reason when craft fails'
    assert_kind_of Array, result[:mutations], 'Expected mutations key to be an Array even on failure'
    assert_empty result[:mutations], 'Expected no applied mutations on rollback'

    # Ensure no LootBox was created
    assert_not LootBox.where(user: user).exists?, 'Expected no LootBox record to be created on failure'

    # Ensure materials were not consumed (transaction rolled back)
    wood_after = entity.inventory_items.where(type: 'WoodInventoryItem').sum(:count)
    iron_after = entity.inventory_items.where(type: 'IronInventoryItem').sum(:count)
    assert_equal wood_before, wood_after
    assert_equal iron_before, iron_after

    # Ensure no LootBoxInventoryItem was created
    assert_not InventoryItem.where(entity: entity, type: 'LootBoxInventoryItem').exists?
  end

  test 'craft fails when materials are insufficient' do
    user = User.create!(email_address: "insufficient@example.com", password: "password")
    entity = Entity.create!(user: user)

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

    wood_before = entity.inventory_items.where(type: 'WoodInventoryItem').sum(:count)
    iron_before = entity.inventory_items.where(type: 'IronInventoryItem').sum(:count)

    result = LootBox.craft(user, {})

    # Debugging info for failed craft due to insufficient materials
    puts "craft result (insufficient materials test): #{result.inspect}"
    puts "inventory items after attempt: Wood=#{entity.inventory_items.where(type: 'WoodInventoryItem').sum(:count)}, Iron=#{entity.inventory_items.where(type: 'IronInventoryItem').sum(:count)}"

    assert result.is_a?(Hash)
    assert_equal false, result[:success], 'Expected craft to fail due to insufficient materials'

    # Ensure reason and mutations keys exist and are consistent with a rollback
    assert_equal 'insufficient_materials', result[:reason], 'Expected reason to indicate insufficient materials'
    assert_kind_of Array, result[:mutations]
    assert_empty result[:mutations], 'Expected no applied mutations on insufficient-materials rollback'

    # Ensure materials were not consumed (transaction rolled back)
    assert_equal wood_before, entity.inventory_items.where(type: 'WoodInventoryItem').sum(:count)
    assert_equal iron_before, entity.inventory_items.where(type: 'IronInventoryItem').sum(:count)

    # Ensure no LootBox or LootBoxInventoryItem was created
    assert_not LootBox.where(user: user).exists?
    assert_not InventoryItem.where(entity: entity, type: 'LootBoxInventoryItem').exists?
  end

  test 'craft uses next available slot if first slot contains a full LootBoxInventoryItem' do
    user = User.create!(email_address: "nextslot@example.com", password: "password")
    entity = Entity.create!(user: user)

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

    assert result[:success], 'Expected craft to succeed when another slot is available'

    # The LootBoxInventoryItem may be placed into any available slot except the first_slot
    # (which we intentionally pre-filled). Search for a LootBoxInventoryItem in any other slot.
    lootbox_slot = nil
    entity.inventory_slots.order(slot: :asc).each do |s|
      if s.inventory_item && s.inventory_item.type == 'LootBoxInventoryItem' && s.slot != first_slot.slot
        lootbox_slot = s
        break
      end
    end

    assert_not_nil lootbox_slot, 'Expected a LootBoxInventoryItem to be placed in some slot other than the first slot'

    # Verify the materials were consumed as part of a successful craft
    assert_equal 0, entity.inventory_items.where(type: 'WoodInventoryItem').sum(:count)
    assert_equal 0, entity.inventory_items.where(type: 'IronInventoryItem').sum(:count)
  end
end
