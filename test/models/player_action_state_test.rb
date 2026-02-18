require "test_helper"

class PlayerActionStateTest < ActiveSupport::TestCase
  test "available actions include sort_inventory with label Sort" do
    user = User.create!(email_address: "sort_action_1@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    available = user.get_available_actions
    sort_action = available.find { |a| a.name == "sort_inventory" }

    assert_not_nil sort_action, "Expected sort_inventory to be in available actions"
    assert_equal "Sort", sort_action.label
  end

  test "sort_inventory is disabled when inventory is empty" do
    user = User.create!(email_address: "sort_action_2@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    # Clear all slots
    entity.inventory_slots.order(slot: :asc).each do |s|
      s.update!(inventory_item: nil)
    end

    user.update_player_actions
    sort_action = user.get_available_actions.find { |a| a.name == "sort_inventory" }

    assert sort_action.disabled, "Sort should be disabled when inventory is empty"
  end

  test "sort_inventory is disabled when inventory is already organized" do
    user = User.create!(email_address: "sort_action_3@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    # Clear all slots
    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each { |s| s.update!(inventory_item: nil) }

    # Place items already in sorted/compressed order (Iron before Wood by display name)
    slots[0].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 50))
    slots[1].update!(inventory_item: WoodInventoryItem.create!(entity: entity, count: 50))

    user.update_player_actions
    sort_action = user.get_available_actions.find { |a| a.name == "sort_inventory" }

    assert sort_action.disabled, "Sort should be disabled when inventory is already organized"
  end

  test "sort_inventory is enabled when inventory needs organization" do
    user = User.create!(email_address: "sort_action_4@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    # Clear all slots
    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each { |s| s.update!(inventory_item: nil) }

    # Place items out of order (Wood before Iron — but Iron sorts first by display name)
    slots[0].update!(inventory_item: WoodInventoryItem.create!(entity: entity, count: 50))
    slots[1].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 50))

    user.update_player_actions
    sort_action = user.get_available_actions.find { |a| a.name == "sort_inventory" }

    assert_not sort_action.disabled, "Sort should be enabled when inventory needs organization"
  end

  test "sort_inventory is disabled during cooldown after performing sort" do
    user = User.create!(email_address: "sort_action_5@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    # Clear all slots
    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each { |s| s.update!(inventory_item: nil) }

    # Place items out of order so sort is needed
    slots[0].update!(inventory_item: WoodInventoryItem.create!(entity: entity, count: 50))
    slots[1].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 50))

    # Perform the action (which sets cooldown)
    user.perform_action("sort_inventory", {})

    # Reload action state
    user.instance_variable_set(:@player_actions, nil)
    user.update_player_actions
    sort_action = user.get_available_actions.find { |a| a.name == "sort_inventory" }

    assert sort_action.disabled, "Sort should be disabled during cooldown"
    assert_not_nil sort_action.on_cooldown_until, "Cooldown should be set after performing sort"
  end

  test "sort_inventory cooldown is approximately 1 second in the future" do
    user = User.create!(email_address: "sort_action_6@example.com", password: "password")
    entity = Entity.create!(user: user)
    entity.ensure_inventory_slots

    # Clear all slots
    slots = entity.inventory_slots.order(slot: :asc).to_a
    slots.each { |s| s.update!(inventory_item: nil) }

    # Place items out of order so sort is needed
    slots[0].update!(inventory_item: WoodInventoryItem.create!(entity: entity, count: 50))
    slots[1].update!(inventory_item: IronInventoryItem.create!(entity: entity, count: 50))

    before_time = Time.current
    user.perform_action("sort_inventory", {})
    after_time = Time.current

    # Reload action state
    user.instance_variable_set(:@player_actions, nil)
    sort_action = user.get_player_actions.find { |a| a.name == "sort_inventory" }

    assert_not_nil sort_action.on_cooldown_until
    # Cooldown is 1 second, so on_cooldown_until should be ~1 second after the action was performed
    assert_in_delta (before_time + 1.second).to_f, sort_action.on_cooldown_until.to_f, 2.0,
      "Cooldown should be approximately 1 second in the future"
  end
end
