class IrradiationEnclosureInventoryItem < InventoryItem
  # Represents an Irradiation Enclosure as a carriable inventory item.
  # Non-stackable — each item corresponds to one IrradiationEnclosure entity record.
  STACK_SIZE = 1
  DISPLAY_NAME = "Irradiation Enclosure"
  TOOLTIP = "A placeable radiation chamber. Craft it and place it in the world."

  def placeable?
    true
  end

  belongs_to :irradiation_enclosure, optional: true,
             class_name: "IrradiationEnclosure",
             foreign_key: :irradiation_enclosure_id

  def to_jbuilder(tags = [ "default" ])
    Jbuilder.new do |jbuilder|
      if tags.include?("default")
        jbuilder.extract!(self, :id, :type, :count, :entity_id)
        jbuilder.display_name display_name
        jbuilder.tooltip tooltip
        jbuilder.irradiation_enclosure_id irradiation_enclosure_id
      end
    end
  end

  # Removes this item from the player's inventory and places the associated
  # IrradiationEnclosure entity at the given world coordinate.
  #
  # @param user [User] the player performing the place action
  # @param coordinate [Integer] the signed 1D world coordinate to place at
  # @return [Hash] { success: Boolean, mutations: Array, reason: String|nil }
  def place!(user, coordinate)
    mutations = []
    success   = false
    reason    = nil
    placed_enclosure = nil

    begin
      ActiveRecord::Base.transaction do
        enclosure = irradiation_enclosure

        if enclosure.nil?
          reason = "no_entity"
          raise ActiveRecord::Rollback
        end

        if coordinate.nil?
          reason = "no_coordinate"
          raise ActiveRecord::Rollback
        end

        # Remove this specific inventory item from its slot directly
        slot = inventory_slot
        if slot.nil?
          reason = "removal_failed"
          raise ActiveRecord::Rollback
        end

        removal = InventoryItemMutation.new(
          item_type:      self.class.name,
          inventory_slot: slot,
          delta:          -1
        )
        removal.apply!

        slot.inventory_item = nil
        slot.save!
        destroy!

        mutations << removal

        # Mark the PlaceableEntity as placed at the given coordinate
        unless enclosure.place!(coordinate, user)
          reason = "placement_failed"
          raise ActiveRecord::Rollback
        end

        placed_enclosure = enclosure
        success = true
      end
    rescue => e
      Rails.logger.error(
        "IrradiationEnclosureInventoryItem#place! failed for user=#{user&.id}: " \
        "#{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      )
      mutations = []
      reason    = "exception" if reason.nil?
    ensure
      mutations_payload = mutations.map { |m| m.to_jbuilder.attributes! }
      PlayerInventoryChannel.broadcast_to(user, { action: "inventory_mutations", data: mutations_payload })

      if success && placed_enclosure
        PlayerInventoryChannel.broadcast_to(user, {
          action: "world_cell_update",
          data: {
            coordinate: placed_enclosure.world_coordinate,
            placed_entity: {
              type: self.class.name,
              display_name: display_name,
              tooltip: tooltip
            }
          }
        })
      end

      user.trigger_action_state_update
    end

    result = { success: success, mutations: mutations, reason: reason }
    Rails.logger.info("IrradiationEnclosureInventoryItem#place! result for user=#{user&.id}: #{result.inspect}")
    result
  end

  # Reverses deployment — recalls the IrradiationEnclosure at the given coordinate,
  # clears its placement fields, and returns a new inventory item to the player.
  #
  # @param user [User] the player performing the recall
  # @param coordinate [Integer] the world coordinate of the entity to recall
  # @return [Hash] { success: Boolean, mutations: Array, reason: String|nil }
  def self.recall!(user, coordinate)
    mutations = []
    success   = false
    reason    = nil
    recalled_coordinate = nil

    begin
      ActiveRecord::Base.transaction do
        enclosure = Entity
          .where(placed_by_user_id: user.id, world_coordinate: coordinate)
          .where.not(placed_at: nil)
          .first

        if enclosure.nil?
          reason = "no_placed_entity"
          raise ActiveRecord::Rollback
        end

        # Clear the placement fields on the entity
        unless enclosure.recall!
          reason = "recall_failed"
          raise ActiveRecord::Rollback
        end

        recalled_coordinate = coordinate

        # Return a new inventory item to the player's inventory
        added = user.add_inventory(name, 1)

        if added.empty?
          reason = "no_inventory_space"
          raise ActiveRecord::Rollback
        end

        added.each(&:apply!)
        mutations.concat(added)

        # Re-link the inventory item to the enclosure.
        # Find the mutation that actually placed into a new or previously empty slot
        # (delta > 0 and the slot didn't already hold a linked enclosure item).
        # Reload the slot so we get the live inventory_item reference after apply!.
        link_mutation = added.find { |m| m.delta > 0 && m.inventory_slot.reload && m.inventory_slot.inventory_item&.irradiation_enclosure_id.nil? }
        if link_mutation
          item = link_mutation.inventory_slot.inventory_item
          if item.respond_to?(:irradiation_enclosure=)
            item.irradiation_enclosure = enclosure
            item.save!
          end
        end

        success = true
      end
    rescue => e
      Rails.logger.error(
        "IrradiationEnclosureInventoryItem.recall! failed for user=#{user&.id}: " \
        "#{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      )
      mutations = []
      reason = "exception" if reason.nil?
    ensure
      mutations_payload = mutations.map { |m| m.to_jbuilder.attributes! }
      PlayerInventoryChannel.broadcast_to(user, { action: "inventory_mutations", data: mutations_payload })

      if success && recalled_coordinate
        PlayerInventoryChannel.broadcast_to(user, {
          action: "world_cell_update",
          data: {
            coordinate: recalled_coordinate,
            placed_entity: nil
          }
        })
      end

      user.trigger_action_state_update
    end

    result = { success: success, mutations: mutations, reason: reason }
    Rails.logger.info("IrradiationEnclosureInventoryItem.recall! result for user=#{user&.id}: #{result.inspect}")
    result
  end
end
