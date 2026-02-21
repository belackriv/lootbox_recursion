require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Creates a user + entity with slots, crafts a loot box, and returns
  # [user, entity, loot_box] so open! tests start from a known good state.
  def create_user_with_loot_box(email:)
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

  # Returns the slot number that holds a LootBoxInventoryItem for the given entity.
  def loot_box_slot_number(entity)
    entity.inventory_slots.joins(:inventory_item)
      .where(inventory_items: { type: "LootBoxInventoryItem" })
      .first
      &.slot
  end

  # ---------------------------------------------------------------------------
  # User#use — happy path via slot_number
  # ---------------------------------------------------------------------------

  test "use opens the loot box in the specified slot and returns success" do
    user, entity, loot_box = create_user_with_loot_box(email: "use_slot@example.com")
    slot_number = loot_box_slot_number(entity)
    assert_not_nil slot_number, "Precondition: loot box must be in a slot"

    result = user.use({ "slot_number" => slot_number })

    assert result.is_a?(Hash)
    assert_equal true, result[:success], "Expected use to succeed (got: #{result.inspect})"
    assert_nil result[:reason]
    assert_kind_of Array, result[:mutations]
    assert_kind_of Array, result[:loot]
    assert_not_empty result[:loot]
  end

  test "use sets opened_at on the loot box" do
    user, entity, loot_box = create_user_with_loot_box(email: "use_opened_at@example.com")
    slot_number = loot_box_slot_number(entity)

    assert_nil loot_box.opened_at, "Precondition: loot box must not be opened yet"

    user.use({ "slot_number" => slot_number })
    loot_box.reload

    assert_not_nil loot_box.opened_at, "Expected opened_at to be stamped after use"
  end

  test "use removes the LootBoxInventoryItem from inventory" do
    user, entity, loot_box = create_user_with_loot_box(email: "use_removes@example.com")
    slot_number = loot_box_slot_number(entity)

    assert InventoryItem.where(entity: entity, type: "LootBoxInventoryItem").exists?,
           "Precondition: LootBoxInventoryItem must exist before use"

    user.use({ "slot_number" => slot_number })

    assert_not InventoryItem.where(entity: entity, type: "LootBoxInventoryItem").exists?,
               "Expected LootBoxInventoryItem to be removed after use"
  end

  test "use adds rolled items to inventory" do
    user, entity, loot_box = create_user_with_loot_box(email: "use_adds_items@example.com")
    slot_number = loot_box_slot_number(entity)

    wood_before = entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    iron_before = entity.inventory_items.where(type: "IronInventoryItem").sum(:count)

    user.use({ "slot_number" => slot_number })
    entity.reload

    wood_after = entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    iron_after = entity.inventory_items.where(type: "IronInventoryItem").sum(:count)

    assert (wood_after > wood_before) || (iron_after > iron_before),
           "Expected at least one material to increase. " \
           "Wood: #{wood_before}->#{wood_after}, Iron: #{iron_before}->#{iron_after}"
  end

  test "use creates LootBoxLoot records" do
    user, entity, loot_box = create_user_with_loot_box(email: "use_loot_records@example.com")
    slot_number = loot_box_slot_number(entity)

    user.use({ "slot_number" => slot_number })

    assert LootBoxLoot.where(loot_box: loot_box).exists?,
           "Expected LootBoxLoot records to be created"
  end

  # ---------------------------------------------------------------------------
  # User#use — recovery: loot_box_id nil on LootBoxInventoryItem
  # ---------------------------------------------------------------------------

  test "use succeeds when LootBoxInventoryItem has nil loot_box_id (legacy/corrupted data)" do
    user, entity, loot_box = create_user_with_loot_box(email: "use_nil_loot_box_id@example.com")
    slot_number = loot_box_slot_number(entity)
    assert_not_nil slot_number, "Precondition: loot box must be in a slot"

    # Simulate legacy/corrupted data by nullifying loot_box_id on the inventory item
    lb_item = InventoryItem.find_by(entity: entity, type: "LootBoxInventoryItem")
    assert_not_nil lb_item, "Precondition: LootBoxInventoryItem must exist"
    lb_item.update_column(:loot_box_id, nil)

    result = user.use({ "slot_number" => slot_number })

    assert result.is_a?(Hash)
    assert_equal true, result[:success],
                 "Expected use to succeed even when loot_box_id is nil (got: #{result.inspect})"
    assert_kind_of Array, result[:loot]
    assert_not_empty result[:loot]
  end

  test "use succeeds via fallback when LootBoxInventoryItem has nil loot_box_id and no slot_number" do
    user, entity, loot_box = create_user_with_loot_box(email: "use_nil_loot_box_id_fallback@example.com")

    # Simulate legacy/corrupted data by nullifying loot_box_id on the inventory item
    lb_item = InventoryItem.find_by(entity: entity, type: "LootBoxInventoryItem")
    lb_item.update_column(:loot_box_id, nil)

    result = user.use(nil)

    assert_equal true, result[:success],
                 "Expected use to recover without slot_number when loot_box_id is nil (got: #{result.inspect})"
  end

  # ---------------------------------------------------------------------------
  # User#use — fallback (no slot_number)
  # ---------------------------------------------------------------------------

  test "use falls back to first loot box when no slot_number is provided" do
    user, entity, loot_box = create_user_with_loot_box(email: "use_fallback@example.com")

    result = user.use(nil)

    assert result.is_a?(Hash)
    assert_equal true, result[:success],
                 "Expected use to succeed via fallback when slot_number is absent (got: #{result.inspect})"
  end

  test "use falls back to first loot box when action_data is an empty hash" do
    user, entity, loot_box = create_user_with_loot_box(email: "use_fallback_empty@example.com")

    result = user.use({})

    assert_equal true, result[:success],
                 "Expected use to succeed via fallback with empty action_data (got: #{result.inspect})"
  end

  # ---------------------------------------------------------------------------
  # User#use — guard: no loot box
  # ---------------------------------------------------------------------------

  test "use returns no_loot_box when entity has no loot box in inventory" do
    user   = User.create!(email_address: "use_no_box@example.com", password: "password")
    entity = user.entity
    entity.ensure_inventory_slots

    result = user.use({ "slot_number" => 0 })

    assert_equal false,          result[:success]
    assert_equal "no_loot_box",  result[:reason]
  end

  test "use returns no_loot_box when slot_number points to a non-loot-box item" do
    user   = User.create!(email_address: "use_wrong_slot@example.com", password: "password")
    entity = user.entity
    entity.ensure_inventory_slots

    wood = WoodInventoryItem.create!(entity: entity, count: 10)
    entity.inventory_slots.order(slot: :asc).first.update!(inventory_item: wood)

    result = user.use({ "slot_number" => 0 })

    assert_equal false,         result[:success]
    assert_equal "no_loot_box", result[:reason]
  end

  # ---------------------------------------------------------------------------
  # User#use — guard: already opened
  # ---------------------------------------------------------------------------

  test "use returns already_opened on a second call for the same loot box" do
    user, entity, loot_box = create_user_with_loot_box(email: "use_already_opened@example.com")
    slot_number = loot_box_slot_number(entity)

    first = user.use({ "slot_number" => slot_number })
    assert_equal true, first[:success], "Expected first use to succeed"

    # Reload so opened_at (set during the first open) is visible on this instance
    loot_box.reload
    second = loot_box.open!
    assert_equal false,            second[:success]
    assert_equal "already_opened", second[:reason]
  end
end
