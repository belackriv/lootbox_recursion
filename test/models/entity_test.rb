require "test_helper"

class EntityTest < ActiveSupport::TestCase
  test "sort_and_compress_inventory! compresses stacks and sorts by display name" do
    user = User.create!(email_address: "entity_sort_1@example.com", password: "password")
    entity = user.entity
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
    entity = user.entity
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
    entity = user.entity
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
    entity = user.entity
    entity.ensure_inventory_slots

    # Clear all slots to deterministic empty state
    entity.inventory_slots.order(slot: :asc).each do |slot|
      slot.update!(inventory_item: nil)
    end

    assert_not entity.inventory_sort_needed?, "Empty inventory should not need sorting"
  end

  test "inventory_sort_needed? returns false when already sorted and compressed" do
    user = User.create!(email_address: "sort_needed_sorted@example.com", password: "password")
    entity = user.entity
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
    entity = user.entity
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
    entity = user.entity
    entity.ensure_inventory_slots

    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each { |s| s.update!(inventory_item: nil) }

    # Two partial Iron stacks that could be compressed into one
    slots[0].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 40))
    slots[1].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 30))

    assert entity.inventory_sort_needed?, "Split stacks that can be compressed should need sorting"
  end

  # ── cleanup_orphaned_inventory_items! tests ──

  test "cleanup_orphaned_inventory_items! destroys items not referenced by any slot" do
    user = User.create!(email_address: "cleanup_orphan@example.com", password: "password")
    entity = user.entity
    entity.ensure_inventory_slots

    # Create an orphaned InventoryItem (belongs to entity but no slot points to it)
    orphan = WoodInventoryItem.create!(entity: entity, count: 10)

    assert_equal 1, entity.inventory_items.left_joins(:inventory_slot).where(inventory_slots: { id: nil }).count,
      "Expected one orphaned InventoryItem before cleanup"

    removed = entity.cleanup_orphaned_inventory_items!

    assert_equal 1, removed, "Expected cleanup to report 1 removed orphan"
    assert_not InventoryItem.exists?(orphan.id), "Orphaned InventoryItem should have been destroyed"
  end

  test "cleanup_orphaned_inventory_items! does not destroy items that are referenced by a slot" do
    user = User.create!(email_address: "cleanup_safe@example.com", password: "password")
    entity = user.entity
    entity.ensure_inventory_slots

    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each { |s| s.update!(inventory_item: nil) }

    item = IronInventoryItem.create!(entity: entity, count: 50)
    slots[0].update!(inventory_item: item)

    removed = entity.cleanup_orphaned_inventory_items!

    assert_equal 0, removed, "Expected no items removed when all are slotted"
    assert InventoryItem.exists?(item.id), "Slotted InventoryItem should still exist"
  end

  test "cleanup_orphaned_inventory_items! returns 0 when there are no orphans" do
    user = User.create!(email_address: "cleanup_none@example.com", password: "password")
    entity = user.entity
    entity.ensure_inventory_slots

    removed = entity.cleanup_orphaned_inventory_items!

    assert_equal 0, removed
  end

  test "cleanup_orphaned_inventory_items! only affects its own entity" do
    user_a = User.create!(email_address: "cleanup_a@example.com", password: "password")
    entity_a = user_a.entity
    entity_a.ensure_inventory_slots

    user_b = User.create!(email_address: "cleanup_b@example.com", password: "password")
    entity_b = user_b.entity
    entity_b.ensure_inventory_slots

    # Create orphans on both entities
    orphan_a = WoodInventoryItem.create!(entity: entity_a, count: 5)
    orphan_b = IronInventoryItem.create!(entity: entity_b, count: 5)

    removed = entity_a.cleanup_orphaned_inventory_items!

    assert_equal 1, removed
    assert_not InventoryItem.exists?(orphan_a.id), "Entity A's orphan should be destroyed"
    assert InventoryItem.exists?(orphan_b.id), "Entity B's orphan should be untouched"
  end

  test "cleanup_all_orphaned_inventory_items! cleans up across all entities" do
    user_a = User.create!(email_address: "cleanup_all_a@example.com", password: "password")
    entity_a = user_a.entity
    entity_a.ensure_inventory_slots

    user_b = User.create!(email_address: "cleanup_all_b@example.com", password: "password")
    entity_b = user_b.entity
    entity_b.ensure_inventory_slots

    orphan_a = WoodInventoryItem.create!(entity: entity_a, count: 5)
    orphan_b = IronInventoryItem.create!(entity: entity_b, count: 10)

    total = Entity.cleanup_all_orphaned_inventory_items!

    assert_operator total, :>=, 2, "Expected at least 2 orphans destroyed across all entities"
    assert_not InventoryItem.exists?(orphan_a.id), "Entity A's orphan should be destroyed"
    assert_not InventoryItem.exists?(orphan_b.id), "Entity B's orphan should be destroyed"
  end
end
