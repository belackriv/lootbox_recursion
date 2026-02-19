require "test_helper"

class LootBoxLootTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def build_loot_box(user: nil, entity: nil)
    user   ||= User.create!(email_address: "lbl_#{SecureRandom.hex(4)}@example.com", password: "password")
    entity ||= Entity.create!(user: user)
    LootBox.create!(user: user, entity: entity)
  end

  def build_loot(loot_box:, type: "WoodInventoryItem", count: 5)
    LootBoxLoot.create!(
      loot_box:      loot_box,
      item_snapshot: { "type" => type, "count" => count },
      count:         count,
      claimed:       true
    )
  end

  # ---------------------------------------------------------------------------
  # Persistence — item_snapshot column
  # ---------------------------------------------------------------------------

  test "can be created with an item_snapshot" do
    loot = build_loot(loot_box: build_loot_box)

    assert loot.persisted?, "Expected LootBoxLoot to be persisted"
    assert_not_nil loot.item_snapshot
  end

  test "item_snapshot is stored and reloaded correctly" do
    loot_box = build_loot_box
    loot     = build_loot(loot_box: loot_box, type: "IronInventoryItem", count: 3)

    loot.reload

    assert_equal "IronInventoryItem", loot.item_snapshot["type"]
    assert_equal 3,                   loot.item_snapshot["count"]
  end

  test "item_snapshot round-trips for WoodInventoryItem" do
    loot = build_loot(loot_box: build_loot_box, type: "WoodInventoryItem", count: 10)
    loot.reload

    assert_equal "WoodInventoryItem", loot.item_snapshot["type"]
    assert_equal 10,                  loot.item_snapshot["count"]
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  test "is invalid without item_snapshot" do
    loot = LootBoxLoot.new(
      loot_box: build_loot_box,
      count:    1,
      claimed:  true
    )

    assert_not loot.valid?, "Expected LootBoxLoot to be invalid without item_snapshot"
    assert_includes loot.errors[:item_snapshot], "can't be blank"
  end

  test "is invalid without loot_box" do
    loot = LootBoxLoot.new(
      item_snapshot: { "type" => "WoodInventoryItem", "count" => 1 },
      count:         1,
      claimed:       true
    )

    assert_not loot.valid?, "Expected LootBoxLoot to be invalid without loot_box"
    assert_includes loot.errors[:loot_box], "must exist"
  end

  # ---------------------------------------------------------------------------
  # store_accessor: item_type
  # ---------------------------------------------------------------------------

  test "item_type reader returns the type from item_snapshot" do
    loot = build_loot(loot_box: build_loot_box, type: "WoodInventoryItem", count: 7)

    assert_equal "WoodInventoryItem", loot.item_type
  end

  test "item_type reader returns IronInventoryItem when snapshot has that type" do
    loot = build_loot(loot_box: build_loot_box, type: "IronInventoryItem", count: 2)

    assert_equal "IronInventoryItem", loot.item_type
  end

  test "item_type persists through a reload" do
    loot = build_loot(loot_box: build_loot_box, type: "WoodInventoryItem", count: 4)
    loot.reload

    assert_equal "WoodInventoryItem", loot.item_type
  end

  test "item_type is nil when snapshot type key is nil" do
    loot_box = build_loot_box
    loot = LootBoxLoot.create!(
      loot_box:      loot_box,
      item_snapshot: { "type" => nil, "count" => 1 },
      count:         1,
      claimed:       true
    )

    assert_nil loot.item_type
  end

  # ---------------------------------------------------------------------------
  # item_class helper
  # ---------------------------------------------------------------------------

  test "item_class returns the Ruby constant for the snapshot type" do
    loot = build_loot(loot_box: build_loot_box, type: "WoodInventoryItem", count: 1)

    assert_equal WoodInventoryItem, loot.item_class
  end

  test "item_class returns IronInventoryItem constant when snapshot type is IronInventoryItem" do
    loot = build_loot(loot_box: build_loot_box, type: "IronInventoryItem", count: 1)

    assert_equal IronInventoryItem, loot.item_class
  end

  test "item_class returns nil when snapshot type is nil" do
    loot_box = build_loot_box
    loot = LootBoxLoot.create!(
      loot_box:      loot_box,
      item_snapshot: { "type" => nil, "count" => 1 },
      count:         1,
      claimed:       true
    )

    assert_nil loot.item_class
  end

  test "item_class returns nil for an unknown type string" do
    loot_box = build_loot_box
    loot = LootBoxLoot.create!(
      loot_box:      loot_box,
      item_snapshot: { "type" => "NonExistentItem", "count" => 1 },
      count:         1,
      claimed:       true
    )

    assert_nil loot.item_class
  end

  # ---------------------------------------------------------------------------
  # No inventory_item FK — items can be freely destroyed
  # ---------------------------------------------------------------------------

  test "destroying the corresponding InventoryItem does not affect the LootBoxLoot record" do
    user   = User.create!(email_address: "lbl_destroy_#{SecureRandom.hex(4)}@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    # Create a real inventory item and a loot record that snapshots it
    item     = WoodInventoryItem.create!(entity: entity, count: 5)
    loot_box = build_loot_box(user: user, entity: entity)
    loot     = LootBoxLoot.create!(
      loot_box:      loot_box,
      item_snapshot: { "type" => item.type, "count" => item.count },
      count:         item.count,
      claimed:       true
    )

    loot_id = loot.id

    # Destroying the inventory item must not raise or cascade-delete the loot record
    assert_nothing_raised { item.destroy! }

    reloaded = LootBoxLoot.find(loot_id)
    assert_equal "WoodInventoryItem", reloaded.item_snapshot["type"]
    assert_equal 5,                   reloaded.item_snapshot["count"]
  end

  test "loot_box_loot count column matches item_snapshot count" do
    loot = build_loot(loot_box: build_loot_box, type: "WoodInventoryItem", count: 8)
    loot.reload

    assert_equal loot.count, loot.item_snapshot["count"]
  end
end
