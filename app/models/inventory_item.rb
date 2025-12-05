class InventoryItem < ApplicationRecord
  include IncludeTypeInJson
  include CamelizeKeysInJson

  belongs_to :user

  SCAVENGE_TYPES = [
    'IronInventoryItem',
    'WoodInventoryItem'
  ]

  def self.applyMutation(mutation)
    if(mutation.applied)
      return false
    end
    inventory_item = mutation.user.inventory_items.where(slot: mutation.slot).first()
    if inventory_item.nil?
      inventory_item = Object.const_get(mutation.item_type).new
      inventory_item.user = mutation.user
      inventory_item.slot = mutation.slot
      inventory_item.count = 0
    end
    inventory_item.count = inventory_item.count + mutation.delta
    inventory_item.save
    return true
  end

  def self.scavenge_item(user)
    item_type = InventoryItem::SCAVENGE_TYPES.sample;
    item_count = rand(user.get_scavenge_range_mod) + user.get_scavenge_add_mod
    item_slot = user.get_inventory_slot_for_type_and_count(item_type, item_count);

    mutation = InventoryItemMutation.new(user: user, item_type: item_type, slot: item_slot, delta: item_count)
    InventoryItem::applyMutation(mutation)
    mutation.applied = true
    mutation.save

    PlayerInventoryChannel.broadcast_to(user, [mutation])
  end
end
