class Entity < ApplicationRecord
  # at some point we will add more types of entities
  # use  add_check_constraint :entity, "num_nonnulls(user_id, ...) = 1", name: "entity_only_one_foreign_key"
  # add , optional: true to line below when this is applied
  belongs_to :user
  has_many :inventory_slots, dependent: :destroy
  has_many :inventory_items, dependent: :destroy

  BASE_INVENTORY_SLOTS = 0

  def get_inventory_slot_count
    if user
      return user.get_inventory_slot_count
    end

    Entity::BASE_INVENTORY_SLOTS
  end

  def ensure_inventory_slots
    for slot_num in 0..(get_inventory_slot_count - 1)
      slot = inventory_slots.find_by(entity: self, slot: slot_num)
      if !slot
        InventorySlot.create!(entity: self, slot: slot_num, inventory_item: nil)
      end
    end
  end

  def remove_inventory(class_name, count)
    item_count = inventory_slots.joins(:inventory_item).where(inventory_item: { type: class_name }).sum("inventory_item.count")
    if item_count < count
      return []
    end

    mutations = []
    inventory_slots.joins(:inventory_item).where(inventory_item: { type: class_name }).order(slot: :desc).each do |inventory_slot|
      removed_count = [ inventory_slot.inventory_item.count, count ].min
      mutation = InventoryItemMutation.new(item_type: class_name, inventory_slot: inventory_slot, delta: (removed_count * -1))
      # can apply instantly since the item_count check was done before
      mutation.apply!
      mutations << mutation
      count = count - removed_count
      if count === 0
        break
      end
    end

    # Clear any inventory_slots that reference items with zero count before destroying those items
    zero_items = InventoryItem.where(entity: self, type: class_name, count: 0)
    zero_items.each do |it|
      if it.inventory_slot
        slot = it.inventory_slot
        slot.inventory_item = nil
        slot.save!
      end
    end
    zero_items.destroy_all

    # Trigger action state update so disabled states reflect new inventory
    trigger_action_state_update

    mutations
  end

  def add_inventory(class_name, count)
    stack_size = Object.const_get(class_name)::STACK_SIZE
    mutations = []
    inventory_slots.order(slot: :asc).each do |inventory_slot|
      added_count = 0
      if inventory_slot.inventory_item === nil
        added_count = [ stack_size, count ].min
        mutations << InventoryItemMutation.new(item_type: class_name, inventory_slot: inventory_slot, delta: added_count)
      elsif inventory_slot.inventory_item.class.name === class_name
        available_count = stack_size - inventory_slot.inventory_item.count
        added_count = [ available_count, count ].min
        mutations << InventoryItemMutation.new(item_type: class_name, inventory_slot: inventory_slot, delta: added_count)
      end
      count = count - added_count
      if count === 0
        break
      end
    end
    if count === 0
      mutations.each do |mutation|
        mutation.apply!
      end

      # Trigger action state update so disabled states reflect new inventory
      trigger_action_state_update
    end
    mutations
  end

  def trigger_action_state_update
    if user
      user.trigger_action_state_update
    end
  end
end
