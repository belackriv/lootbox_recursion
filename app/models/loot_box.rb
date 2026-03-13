class LootBox < ApplicationRecord
  include IncludeTypeInJson

  belongs_to :user
  belongs_to :entity
  has_one :loot_box_inventory_item, class_name: "LootBoxInventoryItem", dependent: :destroy
  has_many :loot_box_modifiers, dependent: :destroy

  CRAFTING_COST = ItemCraftingCost.new(wood: 50, iron: 50)

  def self.craft(user, action_data)
    Entity.craft_item(
      user,
      cost:                 CRAFTING_COST,
      inventory_item_type:  "LootBoxInventoryItem",
      inventory_item_assoc: :loot_box
    ) do |player_entity|
      LootBox.create!(user: user, entity: player_entity)
    end
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
