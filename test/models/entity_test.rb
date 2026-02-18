require "test_helper"

class EntityTest < ActiveSupport::TestCase
  test "sort_and_compress_inventory! compresses stacks and sorts by display name" do
    user = User.create!(email_address: "entity_sort_1@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    slots = entity.inventory_slots.order(slot: :asc).to_a
    assert_operator slots.length, :>=, 5, "Expected at least 5 inventory slots for this test setup"

    # Clear all slots to deterministic state
    slots.each do |slot|
      slot.update!(inventory_item: nil)
    end

    # Setup unsorted + split stacks:
    # slot0: Wood 40
    # slot1: Iron 30
    # slot2: Wood 70
    # slot3: Iron 80
    # slot4: nil
    #
    # Totals => Iron 110, Wood 110
    # STACK_SIZE for both => 100
    # Expected after organize (sorted by display name: Iron, then Wood):
    # slot0: Iron 100
    # slot1: Iron 10
    # slot2: Wood 100
    # slot3: Wood 10
    # slot4: nil
    slots[0].update!(inventory_item: WoodInventoryItem.create!(entity: entity, count: 40))
    slots[1].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 30))
    slots[2].update!(inventory_item: WoodInventoryItem.create!(entity: entity, count: 70))
    slots[3].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 80))

    result = entity.sort_and_compress_inventory!

    assert_kind_of Hash, result
    assert_equal 2, result[:item_types]
    assert_equal 4, result[:slots_used]

    slots_after = entity.inventory_slots.includes(:inventory_item).order(slot: :asc).to_a

    assert_equal "IronInventoryItem", slots_after[0].inventory_item&.type
    assert_equal 100, slots_after[0].inventory_item&.count

    assert_equal "IronInventoryItem", slots_after[1].inventory_item&.type
    assert_equal 10, slots_after[1].inventory_item&.count

    assert_equal "WoodInventoryItem", slots_after[2].inventory_item&.type
    assert_equal 100, slots_after[2].inventory_item&.count

    assert_equal "WoodInventoryItem", slots_after[3].inventory_item&.type
    assert_equal 10, slots_after[3].inventory_item&.count

    assert_nil slots_after[4].inventory_item
  end

  test "sort_and_compress_inventory! preserves total count per item type" do
    user = User.create!(email_address: "entity_sort_2@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    slots = entity.inventory_slots.order(slot: :asc).to_a
    assert_operator slots.length, :>=, 4, "Expected at least 4 inventory slots for this test setup"

    # Clear all slots to deterministic state
    slots.each do |slot|
      slot.update!(inventory_item: nil)
    end

    slots[0].update!(inventory_item: WoodInventoryItem.create!(entity: entity, count: 15))
    slots[1].update!(inventory_item: WoodInventoryItem.create!(entity: entity, count: 85))
    slots[2].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 1))
    slots[3].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 99))

    before_totals = entity.inventory_slots
      .joins(:inventory_item)
      .group("inventory_item.type")
      .sum("inventory_item.count")

    entity.sort_and_compress_inventory!

    after_totals = entity.inventory_slots
      .joins(:inventory_item)
      .group("inventory_item.type")
      .sum("inventory_item.count")

    assert_equal before_totals, after_totals
    assert_equal 100, after_totals["WoodInventoryItem"]
    assert_equal 100, after_totals["IronInventoryItem"]
  end

  test "sort_and_compress_inventory! handles empty inventory" do
    user = User.create!(email_address: "entity_sort_3@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    # Clear all slots to deterministic empty state
    entity.inventory_slots.order(slot: :asc).each do |slot|
      slot.update!(inventory_item: nil)
    end

    result = entity.sort_and_compress_inventory!

    assert_kind_of Hash, result
    assert_equal 0, result[:item_types]
    assert_equal 0, result[:slots_used]

    assert_equal 0, entity.inventory_slots.joins(:inventory_item).count
  end

  # ── inventory_sort_needed? tests ──

  test "inventory_sort_needed? returns false for empty inventory" do
    user = User.create!(email_address: "sort_needed_empty@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    # Clear all slots to deterministic empty state
    entity.inventory_slots.order(slot: :asc).each do |slot|
      slot.update!(inventory_item: nil)
    end

    assert_not entity.inventory_sort_needed?, "Empty inventory should not need sorting"
  end

  test "inventory_sort_needed? returns false when already sorted and compressed" do
    user = User.create!(email_address: "sort_needed_sorted@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each { |s| s.update!(inventory_item: nil) }

    # Place items in already-sorted, compressed order (Iron before Wood by display name)
    slots[0].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 100))
    slots[1].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 10))
    slots[2].update!(inventory_item: WoodInventoryItem.create!(entity: entity, count: 100))
    slots[3].update!(inventory_item: WoodInventoryItem.create!(entity: entity, count: 10))

    assert_not entity.inventory_sort_needed?, "Already sorted and compressed inventory should not need sorting"
  end

  test "inventory_sort_needed? returns true when types are unsorted" do
    user = User.create!(email_address: "sort_needed_unsorted@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each { |s| s.update!(inventory_item: nil) }

    # Place Wood before Iron — wrong order (Iron should come first by display name)
    slots[0].update!(inventory_item: WoodInventoryItem.create!(entity: entity, count: 50))
    slots[1].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 50))

    assert entity.inventory_sort_needed?, "Unsorted inventory types should need sorting"
  end

  test "inventory_sort_needed? returns true when stacks are compressible" do
    user = User.create!(email_address: "sort_needed_compress@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each { |s| s.update!(inventory_item: nil) }

    # Two partial Iron stacks that could be compressed into one
    slots[0].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 40))
    slots[1].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 30))

    assert entity.inventory_sort_needed?, "Split stacks that can be compressed should need sorting"
  end
end
