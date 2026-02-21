require "test_helper"

class InventoryItemTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "scavenge_item broadcasts inventory channel payload with envelope format" do
    user = User.create!(email_address: "scavenge_envelope@example.com", password: "password")
    entity = user.entity
    entity.ensure_inventory_slots

    # Clear all slots for deterministic state
    entity.inventory_slots.order(slot: :asc).each do |s|
      s.inventory_item = nil
      s.save!
    end

    # Capture broadcasts to PlayerInventoryChannel
    inventory_broadcasts = capture_broadcasts(PlayerInventoryChannel.broadcasting_for(user)) do
      InventoryItem.scavenge_item(user)
    end

    assert_not_empty inventory_broadcasts, "Expected a broadcast payload from scavenge_item"

    envelope = inventory_broadcasts.last

    assert envelope.key?("action"), "Expected broadcast payload to include 'action' key"
    assert envelope.key?("data"), "Expected broadcast payload to include 'data' key"
    assert_equal "inventory_mutations", envelope["action"], "Expected action to be 'inventory_mutations'"
    assert_kind_of Array, envelope["data"], "Expected data to be an Array of mutations"
  end
end
