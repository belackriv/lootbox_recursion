class Entity < ApplicationRecord
  # Shared craft skeleton used by all craftable classes (LootBox, IrradiationEnclosure, etc.).
  #
  # Handles the full transaction + rescue/ensure wrapper:
  #   - ensures inventory slots exist
  #   - finds an available slot for `inventory_item_type`
  #   - checks and removes all costs specified in the ItemCraftingCost
  #   - applies the inventory item mutation
  #   - links the created record back to the inventory item via `inventory_item_assoc`
  #   - broadcasts mutations and triggers action state update
  #
  # The caller supplies a block that creates and returns the crafted record:
  #   Entity.craft_item(...) { |player_entity| MyRecord.create!(owner: player_entity) }
  #
  # @param cost [ItemCraftingCost] encapsulates all material costs for the craft
  # @return [Hash] { success: Boolean, mutations: Array, reason: String|nil }
  def self.craft_item(user, cost:, inventory_item_type:, inventory_item_assoc:)
    mutations = []
    success   = false
    reason    = nil

    begin
      ActiveRecord::Base.transaction do
        player_entity = user.entity
        player_entity.ensure_inventory_slots

        # Find the first available slot — empty preferred, otherwise a partial stack of the same type
        item_class = Object.const_get(inventory_item_type)
        slot = player_entity.inventory_slots.order(slot: :asc).detect do |s|
          if s.inventory_item.nil?
            true
          elsif s.inventory_item.class.name == inventory_item_type &&
                s.inventory_item.count < item_class::STACK_SIZE
            true
          else
            false
          end
        end

        if slot.nil?
          reason = "no_slot"
          raise ActiveRecord::Rollback
        end

        # Check all material costs are satisfied before any destructive changes
        sufficient = cost.to_h.all? do |item_type, required|
          player_entity.inventory_slots
            .joins(:inventory_item)
            .where(inventory_item: { type: item_type })
            .sum("inventory_item.count") >= required
        end

        unless sufficient
          reason = "insufficient_materials"
          raise ActiveRecord::Rollback
        end

        # Remove materials — these apply immediately inside the transaction
        cost.to_h.each do |item_type, required|
          next if required == 0
          removed = user.remove_inventory(item_type, required)
          if removed.empty?
            reason = "insufficient_materials"
            raise ActiveRecord::Rollback
          end
          mutations.concat(removed)
        end

        # Delegate record creation to the caller's block
        crafted_record = yield(player_entity)

        # Add the inventory item to the found slot
        mutation = InventoryItemMutation.new(
          item_type:      inventory_item_type,
          inventory_slot: slot,
          delta:          1
        )
        mutation.apply!

        # Link the inventory item back to the crafted record
        slot.reload
        item = slot.inventory_item
        if item && item.respond_to?(:"#{inventory_item_assoc}=")
          item.public_send(:"#{inventory_item_assoc}=", crafted_record)
          item.save!
        end

        mutations << mutation
        success = true
      end
    rescue => e
      Rails.logger.error(
        "#{name}.craft failed for user=#{user&.id}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      )
      mutations = []
      reason    = "exception" if reason.nil?
    ensure
      mutations_payload = mutations.map { |m| m.to_jbuilder.attributes! }
      PlayerInventoryChannel.broadcast_to(user, { action: "inventory_mutations", data: mutations_payload })
      user.trigger_action_state_update
    end

    result = { success: success, mutations: mutations, reason: reason }
    Rails.logger.info("#{name}.craft result for user=#{user&.id}: #{result.inspect}")
    result
  end

  # STI: subclasses (PlaceableEntity → IrradiationEnclosure, etc.) set `type`.
  # Exactly one of user_id or owner_id must be non-null (enforced by DB check constraint
  # "entity_exactly_one_owner": num_nonnulls(user_id, owner_id) = 1).
  belongs_to :user, optional: true
  belongs_to :owner, class_name: "Entity", optional: true
  has_many :owned_entities, class_name: "Entity", foreign_key: :owner_id, dependent: :destroy
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

  # Destroy InventoryItems belonging to this entity that are not referenced by any InventorySlot.
  # Returns the number of orphaned records removed.
  def cleanup_orphaned_inventory_items!
    orphans = inventory_items
      .left_joins(:inventory_slot)
      .where(inventory_slots: { id: nil })

    count = orphans.count
    if count > 0
      Rails.logger.info("[Entity#cleanup_orphaned_inventory_items!] entity=#{id} destroying #{count} orphaned InventoryItem(s)")
      orphans.destroy_all
    end
    count
  end

  # Run cleanup across every entity in the database. Useful from a console or rake task.
  def self.cleanup_all_orphaned_inventory_items!
    total = 0
    Entity.find_each do |entity|
      total += entity.cleanup_orphaned_inventory_items!
    end
    Rails.logger.info("[Entity.cleanup_all_orphaned_inventory_items!] destroyed #{total} orphaned InventoryItem(s) total")
    total
  end

  def inventory_sort_needed?
    ensure_inventory_slots

    slots = inventory_slots.includes(:inventory_item).order(slot: :asc)

    current_sequence = []
    slots.each do |inventory_slot|
      if inventory_slot.inventory_item.nil? or inventory_slot.inventory_item.count.to_i <= 0
        current_sequence << {
          type: nil,
          count: 0
        }
      else
        current_sequence << {
          type: inventory_slot.inventory_item.type,
          count: inventory_slot.inventory_item.count.to_i
        }
      end
    end

    expected_sequence = build_sorted_stacks(slots)

    current_sequence != expected_sequence
  end

  def sort_and_compress_inventory!
    ensure_inventory_slots

    slots = inventory_slots.includes(:inventory_item).order(slot: :asc)
    rebuilt_stacks = build_sorted_stacks(slots)
    Rails.logger.debug("rebuilt_stacks: #{rebuilt_stacks.inspect}")
    ApplicationRecord.transaction do
      slots.each_with_index do |inventory_slot, index|
        desired = rebuilt_stacks[index]

        if desired.nil? || desired[:type].nil?
          if inventory_slot.inventory_item
            old_item = inventory_slot.inventory_item
            inventory_slot.update!(inventory_item: nil)
            old_item.destroy! if old_item.inventory_slot.nil?
          end
          next
        end

        current_item = inventory_slot.inventory_item
        if current_item && current_item.type == desired[:type]
          current_item.update!(count: desired[:count]) if current_item.count != desired[:count]
        else
          old_item = current_item
          new_item = Object.const_get(desired[:type]).create!(entity: self, count: desired[:count])
          inventory_slot.update!(inventory_item: new_item)

          if old_item
            old_item.reload
            old_item.destroy! if old_item.inventory_slot.nil?
          end
        end
      end
    end

    cleanup_orphaned_inventory_items!
    trigger_action_state_update

    {
      item_types: rebuilt_stacks.filter_map { |s| s[:type] }.uniq.length,
      slots_used: rebuilt_stacks.count { |s| s[:type].present? }
    }
  end

  private

  def build_sorted_stacks(slots)
    totals_by_type = Hash.new(0)

    slots.each do |inventory_slot|
      next if inventory_slot.inventory_item.nil?
      next if inventory_slot.inventory_item.count.to_i <= 0

      totals_by_type[inventory_slot.inventory_item.type] += inventory_slot.inventory_item.count.to_i
    end

    sorted_types = totals_by_type.keys.sort_by do |type|
      [ Object.const_get(type).display_name.downcase, type ]
    end

    stacks = []
    sorted_types.each do |type|
      total_count = totals_by_type[type]
      stack_size = Object.const_get(type)::STACK_SIZE

      while total_count > 0
        stack_count = [ stack_size, total_count ].min
        stacks << { type: type, count: stack_count }
        total_count -= stack_count
      end
    end

    # Pad with empty-slot entries so the array length matches the total number of
    # slots. This is required for the comparison in inventory_sort_needed? to be
    # position-aware: current_sequence now includes { type: nil, count: 0 } for
    # every empty slot, so expected_sequence must do the same.
    total_slots = slots.length
    while stacks.length < total_slots
      stacks << { type: nil, count: 0 }
    end

    stacks
  end

  def trigger_action_state_update
    if user
      user.trigger_action_state_update
    elsif owner
      owner.trigger_action_state_update
    end
  end
end
