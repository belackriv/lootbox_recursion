class LootBox < ApplicationRecord
  include IncludeTypeInJson

  belongs_to :user
  belongs_to :entity
  has_one :loot_box_inventory_item, class_name: "LootBoxInventoryItem", dependent: :destroy
  has_many :loot_box_modifiers, dependent: :destroy

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
          elsif s.inventory_item.class.name == "LootBoxInventoryItem" && s.inventory_item.count < LootBoxInventoryItem::STACK_SIZE
            true
          else
            false
          end
        end

        # If there is no slot available, set reason and abort before making any destructive changes
        if slot.nil?
          reason = "no_slot"
          raise ActiveRecord::Rollback
        end

        # Check material sufficiency without applying mutations.
        # Use a read-only count to ensure we won't apply removals unless we can complete the craft.
        wood_count = entity.inventory_slots.joins(:inventory_item).where(inventory_item: { type: "WoodInventoryItem" }).sum("inventory_item.count")
        iron_count = entity.inventory_slots.joins(:inventory_item).where(inventory_item: { type: "IronInventoryItem" }).sum("inventory_item.count")

        if wood_count < 50 || iron_count < 50
          reason = "insufficient_materials"
          raise ActiveRecord::Rollback
        end

        # Now that slot is available and materials are sufficient, perform removals (these apply immediately)
        wood_mutations = user.remove_inventory("WoodInventoryItem", 50)
        iron_mutations = user.remove_inventory("IronInventoryItem", 50)
        mutations.concat(wood_mutations)
        mutations.concat(iron_mutations)

        # Double-check that removals had effect; if, for some reason, they didn't, abort.
        if wood_mutations.empty? || iron_mutations.empty?
          reason = "insufficient_materials"
          raise ActiveRecord::Rollback
        end

        # Create the LootBox record and associate it with the entity
        loot_box = LootBox.create!(user: user, entity: entity)

        # Create an inventory mutation to add a LootBoxInventoryItem to the found slot
        mutation = InventoryItemMutation.new(item_type: "LootBoxInventoryItem", inventory_slot: slot, delta: 1)

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
      reason = "exception" if reason.nil?
    ensure
      # Broadcast the mutations we have (on failure these will typically be empty because of rollback)
      # Serialize mutations to camelCase using to_jbuilder before broadcasting
      mutations_payload = mutations.map { |mutation| mutation.to_jbuilder.attributes! }
      PlayerInventoryChannel.broadcast_to(user, { action: "inventory_mutations", data: mutations_payload })

      # Trigger action state update so disabled state reflects new inventory
      # This ensures the craft button (and other actions) update based on final inventory state
      user.trigger_action_state_update
    end

    # Log the crafted result so tests and runtime show why craft succeeded or failed
    result = { success: success, mutations: mutations, reason: reason }
    Rails.logger.info("LootBox.craft result for user=#{user&.id}: #{result.inspect}")
    result
  end

  # Opens this loot box, rolling loot from the configured loot table (with any modifiers
  # applied), removing the LootBoxInventoryItem from the player's inventory, adding the
  # rolled items, and recording LootBoxLoot entries for each item received.
  #
  # @return [Hash] { success: Boolean, mutations: Array, loot: Array<LootBoxLoot>, reason: String|nil }
  def open!
    mutations = []
    loot      = []
    success   = false
    reason    = nil

    begin
      ActiveRecord::Base.transaction do
        # 1. Guard against re-opening
        if opened_at.present?
          reason = "already_opened"
          raise ActiveRecord::Rollback
        end

        # 2. Locate the specific LootBoxInventoryItem for this loot box and its slot
        lb_inventory_item = loot_box_inventory_item
        if lb_inventory_item.nil? || lb_inventory_item.inventory_slot.nil?
          reason = "no_inventory_item"
          raise ActiveRecord::Rollback
        end
        lb_slot = lb_inventory_item.inventory_slot

        # 3. Load the base loot table and apply the modifier chain
        base_config  = LootTable.for(self).config
        final_config = loot_box_modifiers.reduce(base_config) { |cfg, mod| mod.apply(cfg) }
        rolled       = LootTable.new(final_config).roll

        # 4. Remove the LootBoxInventoryItem from the inventory slot
        removal = InventoryItemMutation.new(
          item_type:      "LootBoxInventoryItem",
          inventory_slot: lb_slot,
          delta:          -1
        )
        removal.apply!

        # Clear the slot reference and destroy the now-empty item
        lb_slot.inventory_item = nil
        lb_slot.save!
        lb_inventory_item.destroy!

        mutations << removal

        # 5. Add each rolled item to inventory and create a LootBoxLoot record per mutation
        rolled.each do |roll|
          add_mutations = entity.add_inventory(roll[:item_type], roll[:count])

          # Guard: if add_inventory couldn't place the full count, roll back
          if add_mutations.empty? || add_mutations.sum(&:delta) < roll[:count]
            reason = "insufficient_inventory_space"
            raise ActiveRecord::Rollback
          end

          add_mutations.each do |m|
            item = m.inventory_slot.inventory_item
            loot << LootBoxLoot.create!(
              loot_box:      self,
              item_snapshot: { "type" => item.type, "count" => m.delta },
              count:         m.delta,
              claimed:       true
            )
          end

          mutations.concat(add_mutations)
        end

        # 6. Mark the loot box as opened
        update!(opened_at: Time.current)

        success = true
      end
    rescue => e
      Rails.logger.error(
        "LootBox#open! failed for loot_box=#{id}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      )
      mutations = []
      loot      = []
      reason    = "exception" if reason.nil?
    ensure
      # Always broadcast the final mutation set and refresh action states.
      # On rollback, mutations will be empty so this is a no-op on the frontend.
      mutations_payload = mutations.map { |m| m.to_jbuilder.attributes! }
      PlayerInventoryChannel.broadcast_to(user, { action: "inventory_mutations", data: mutations_payload })
      user.trigger_action_state_update
    end

    result = { success: success, mutations: mutations, loot: loot, reason: reason }
    Rails.logger.info("LootBox#open! result for loot_box=#{id}: #{result.inspect}")
    result
  end
end
