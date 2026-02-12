class LootBox < ApplicationRecord
  include IncludeTypeInJson

  belongs_to :user
  belongs_to :entity
  has_one :loot_box_inventory_item, class_name: 'LootBoxInventoryItem', dependent: :destroy

  def self.craft(user, action_data)
    mutations = []
    success = false
    reason = nil

    begin
      ActiveRecord::Base.transaction do
        # Ensure we have an entity and inventory slots prepared
        entity = user.entity
        entity.ensure_inventory_slots

        # Find the first available slot:
        # - prefer an empty slot
        # - otherwise accept a LootBoxInventoryItem with available stack space
        slot = entity.inventory_slots.order(slot: :asc).detect do |s|
          if s.inventory_item.nil?
            true
          elsif s.inventory_item.class.name == 'LootBoxInventoryItem' && s.inventory_item.count < LootBoxInventoryItem::STACK_SIZE
            true
          else
            false
          end
        end

        # If there is no slot available, set reason and abort before making any destructive changes
        if slot.nil?
          reason = 'no_slot'
          raise ActiveRecord::Rollback
        end

        # Check material sufficiency without applying mutations.
        # Use a read-only count to ensure we won't apply removals unless we can complete the craft.
        wood_count = entity.inventory_slots.joins(:inventory_item).where(inventory_item: { type: 'WoodInventoryItem' }).sum('inventory_item.count')
        iron_count = entity.inventory_slots.joins(:inventory_item).where(inventory_item: { type: 'IronInventoryItem' }).sum('inventory_item.count')

        if wood_count < 50 || iron_count < 50
          reason = 'insufficient_materials'
          raise ActiveRecord::Rollback
        end

        # Now that slot is available and materials are sufficient, perform removals (these apply immediately)
        wood_mutations = user.remove_inventory('WoodInventoryItem', 50)
        iron_mutations = user.remove_inventory('IronInventoryItem', 50)
        mutations.concat(wood_mutations)
        mutations.concat(iron_mutations)

        # Double-check that removals had effect; if, for some reason, they didn't, abort.
        if wood_mutations.empty? || iron_mutations.empty?
          reason = 'insufficient_materials'
          raise ActiveRecord::Rollback
        end

        # Create the LootBox record and associate it with the entity
        loot_box = LootBox.create!(user: user, entity: entity)

        # Create an inventory mutation to add a LootBoxInventoryItem to the found slot
        mutation = InventoryItemMutation.new(item_type: 'LootBoxInventoryItem', inventory_slot: slot, delta: 1)

        # Apply it immediately so the inventory item is created & attached to the slot
        mutation.apply!

        # Ensure the created inventory item references the loot_box
        slot.reload
        item = slot.inventory_item
        if item && item.respond_to?(:loot_box=)
          item.loot_box = loot_box
          item.save!
        end

        mutations << mutation

        # mark success so we can broadcast accordingly after the transaction block
        success = true
      end
    rescue => e
      # Log errors but do not re-raise; the method will return { success: false, mutations: [...] }
      msg = "LootBox.craft failed for user=#{user&.id}: #{e.class} - #{e.message}"
      Rails.logger.error("#{msg}\n#{e.backtrace.join("\n")}")

      # Ensure mutations is cleared on failure to avoid broadcasting partially-applied mutations
      mutations = []
      reason = 'exception' if reason.nil?
    ensure
      # Broadcast the mutations we have (on failure these will typically be empty because of rollback)
      PlayerInventoryChannel.broadcast_to(user, mutations)
    end

    # Log the crafted result so tests and runtime show why craft succeeded or failed
    result = { success: success, mutations: mutations, reason: reason }
    Rails.logger.info("LootBox.craft result for user=#{user&.id}: #{result.inspect}")
    return result
  end
end
