class InventoryItemMutation < ApplicationRecord

  belongs_to :inventory_slot

  def apply
    apply
  end

  def apply!
    if(self.applied)
      return false
    end
    inventory_item = inventory_slot.inventory_item
    if inventory_item.nil?
      inventory_item = Object.const_get(item_type).new
      inventory_item.entity = inventory_slot.entity
      inventory_item.count = 0
    end
    inventory_item.count = inventory_item.count + delta
    inventory_item.save!
    if inventory_slot.inventory_item != inventory_item
      inventory_slot.inventory_item = inventory_item
      inventory_slot.save!
    end
    self.applied = true
    save!
    return true
  end
end
