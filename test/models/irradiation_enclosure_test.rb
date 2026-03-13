require "test_helper"

class IrradiationEnclosureTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_user(email)
    user = User.create!(email_address: email, password: "password")
    user.entity.ensure_inventory_slots
    user
  end

  def clear_slots(entity)
    entity.inventory_slots.order(slot: :asc).each do |s|
      s.inventory_item = nil
      s.save!
    end
  end

  def place_item(entity, item_class, count, slot_index)
    item = item_class.create!(entity: entity, count: count)
    slot = entity.inventory_slots.order(slot: :asc).to_a[slot_index]
    slot.inventory_item = item
    slot.save!
    item
  end

  # ---------------------------------------------------------------------------
  # STI / ownership structure
  # ---------------------------------------------------------------------------

  test "IrradiationEnclosure is a subclass of PlaceableEntity" do
    assert IrradiationEnclosure < PlaceableEntity
  end

  test "PlaceableEntity is a subclass of Entity" do
    assert PlaceableEntity < Entity
  end

  test "crafted IrradiationEnclosure is stored as an Entity row with correct type" do
    user   = create_user("ie_sti_type@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    IrradiationEnclosure.craft(user, {})

    row = Entity.where(type: "IrradiationEnclosure").last
    assert_not_nil row, "Expected an entities row with type=IrradiationEnclosure"
    assert_instance_of IrradiationEnclosure, row
  end

  test "crafted IrradiationEnclosure has owner set to the user's player entity" do
    user   = create_user("ie_owner@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    IrradiationEnclosure.craft(user, {})

    enclosure = IrradiationEnclosure.last
    assert_not_nil enclosure.owner_id
    assert_equal entity.id, enclosure.owner_id
  end

  test "crafted IrradiationEnclosure has user_id nil" do
    user   = create_user("ie_no_user_id@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    IrradiationEnclosure.craft(user, {})

    enclosure = IrradiationEnclosure.last
    assert_nil enclosure.user_id
  end

  test "player Entity still has user_id set and owner_id nil after craft" do
    user   = create_user("ie_player_entity_intact@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    IrradiationEnclosure.craft(user, {})

    entity.reload
    assert_equal user.id, entity.user_id
    assert_nil entity.owner_id
  end

  test "user entity has the IrradiationEnclosure in owned_entities" do
    user   = create_user("ie_owned_entities@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    IrradiationEnclosure.craft(user, {})

    enclosure = IrradiationEnclosure.last
    assert_includes entity.owned_entities, enclosure
  end

  # ---------------------------------------------------------------------------
  # craft — success path
  # ---------------------------------------------------------------------------

  test "craft returns success: true" do
    user   = create_user("ie_success@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    result = IrradiationEnclosure.craft(user, {})

    assert result[:success], "Expected craft to succeed"
  end

  test "craft consumes exactly 100 wood and 100 iron" do
    user   = create_user("ie_consumes@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    IrradiationEnclosure.craft(user, {})

    assert_equal 0, entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    assert_equal 0, entity.inventory_items.where(type: "IronInventoryItem").sum(:count)
  end

  test "craft places an IrradiationEnclosureInventoryItem with count 1 in inventory" do
    user   = create_user("ie_inv_item@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    IrradiationEnclosure.craft(user, {})

    item = InventoryItem.where(entity: entity, type: "IrradiationEnclosureInventoryItem").first
    assert_not_nil item, "Expected an IrradiationEnclosureInventoryItem in inventory"
    assert_equal 1, item.count
  end

  test "craft links the IrradiationEnclosureInventoryItem to the created enclosure entity" do
    user   = create_user("ie_link@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    IrradiationEnclosure.craft(user, {})

    enclosure = IrradiationEnclosure.last
    item      = InventoryItem.where(entity: entity, type: "IrradiationEnclosureInventoryItem").first

    assert_not_nil enclosure
    assert_not_nil item
    assert_equal enclosure.id, item.irradiation_enclosure_id,
                 "Inventory item should reference the created IrradiationEnclosure"
  end

  test "craft returns a mutations array with at least one entry on success" do
    user   = create_user("ie_mutations@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    result = IrradiationEnclosure.craft(user, {})

    assert_kind_of Array, result[:mutations]
    assert_not_empty result[:mutations]
    assert_nil result[:reason]
  end

  test "craft with surplus materials only consumes exactly the cost" do
    user   = create_user("ie_surplus@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, WoodInventoryItem, 50,  1)
    place_item(entity, IronInventoryItem, 100, 2)

    IrradiationEnclosure.craft(user, {})

    # 150 wood total, 100 consumed → 50 remaining
    assert_equal 50, entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    assert_equal 0,  entity.inventory_items.where(type: "IronInventoryItem").sum(:count)
  end

  test "craft broadcasts inventory_mutations envelope to PlayerInventoryChannel" do
    user   = create_user("ie_broadcast@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    broadcasts = capture_broadcasts(PlayerInventoryChannel.broadcasting_for(user)) do
      IrradiationEnclosure.craft(user, {})
    end

    assert_not_empty broadcasts
    envelope = broadcasts.last
    assert_equal "inventory_mutations", envelope["action"]
    assert_kind_of Array, envelope["data"]
  end

  # ---------------------------------------------------------------------------
  # craft — insufficient materials
  # ---------------------------------------------------------------------------

  test "craft fails with insufficient_materials when wood is below cost" do
    user   = create_user("ie_low_wood@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 50, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    result = IrradiationEnclosure.craft(user, {})

    assert_equal false,                    result[:success]
    assert_equal "insufficient_materials", result[:reason]
    assert_empty result[:mutations]
  end

  test "craft fails with insufficient_materials when iron is below cost" do
    user   = create_user("ie_low_iron@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 50, 1)

    result = IrradiationEnclosure.craft(user, {})

    assert_equal false,                    result[:success]
    assert_equal "insufficient_materials", result[:reason]
    assert_empty result[:mutations]
  end

  test "craft does not consume materials when insufficient" do
    user   = create_user("ie_no_consume_fail@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 50, 0)
    place_item(entity, IronInventoryItem, 50, 1)

    wood_before = entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    iron_before = entity.inventory_items.where(type: "IronInventoryItem").sum(:count)

    IrradiationEnclosure.craft(user, {})

    assert_equal wood_before, entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    assert_equal iron_before, entity.inventory_items.where(type: "IronInventoryItem").sum(:count)
  end

  test "craft does not create an IrradiationEnclosure entity when materials are insufficient" do
    user   = create_user("ie_no_record_fail@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 10, 0)
    place_item(entity, IronInventoryItem, 10, 1)

    IrradiationEnclosure.craft(user, {})

    assert_not Entity.where(type: "IrradiationEnclosure", owner_id: entity.id).exists?,
               "Expected no IrradiationEnclosure entity row when craft fails"
  end

  test "craft does not add an IrradiationEnclosureInventoryItem when materials are insufficient" do
    user   = create_user("ie_no_item_fail@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 10, 0)
    place_item(entity, IronInventoryItem, 10, 1)

    IrradiationEnclosure.craft(user, {})

    assert_not InventoryItem.where(entity: entity, type: "IrradiationEnclosureInventoryItem").exists?
  end

  # ---------------------------------------------------------------------------
  # craft — no available inventory slot
  # ---------------------------------------------------------------------------

  test "craft fails with no_slot when all inventory slots are occupied" do
    user   = create_user("ie_no_slot@example.com")
    entity = user.entity
    clear_slots(entity)

    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each_with_index do |slot, i|
      item = if i < (slots.length / 2)
               WoodInventoryItem.create!(entity: entity, count: 100)
      else
               IronInventoryItem.create!(entity: entity, count: 100)
      end
      slot.inventory_item = item
      slot.save!
    end

    result = IrradiationEnclosure.craft(user, {})

    assert_equal false,     result[:success]
    assert_equal "no_slot", result[:reason]
    assert_empty result[:mutations]
  end

  test "craft does not create an IrradiationEnclosure entity when no slot is available" do
    user   = create_user("ie_no_slot_no_record@example.com")
    entity = user.entity
    clear_slots(entity)

    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each_with_index do |slot, i|
      item = if i < (slots.length / 2)
               WoodInventoryItem.create!(entity: entity, count: 100)
      else
               IronInventoryItem.create!(entity: entity, count: 100)
      end
      slot.inventory_item = item
      slot.save!
    end

    IrradiationEnclosure.craft(user, {})

    assert_not Entity.where(type: "IrradiationEnclosure", owner_id: entity.id).exists?
  end

  test "craft does not consume materials when no slot is available" do
    user   = create_user("ie_no_slot_no_consume@example.com")
    entity = user.entity
    clear_slots(entity)

    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each_with_index do |slot, i|
      item = if i < (slots.length / 2)
               WoodInventoryItem.create!(entity: entity, count: 100)
      else
               IronInventoryItem.create!(entity: entity, count: 100)
      end
      slot.inventory_item = item
      slot.save!
    end

    wood_before = entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    iron_before = entity.inventory_items.where(type: "IronInventoryItem").sum(:count)

    IrradiationEnclosure.craft(user, {})

    assert_equal wood_before, entity.inventory_items.where(type: "WoodInventoryItem").sum(:count)
    assert_equal iron_before, entity.inventory_items.where(type: "IronInventoryItem").sum(:count)
  end



  test "User#irradiation_enclosures association returns the user's crafted enclosures" do
    user   = create_user("ie_assoc@example.com")
    entity = user.entity
    clear_slots(entity)

    place_item(entity, WoodInventoryItem, 100, 0)
    place_item(entity, IronInventoryItem, 100, 1)

    IrradiationEnclosure.craft(user, {})

    assert_equal 1, user.irradiation_enclosures.count
    assert_instance_of IrradiationEnclosure, user.irradiation_enclosures.first
  end
end
