class IrradiationEnclosureInventoryItem < InventoryItem
  # Represents an Irradiation Enclosure as a carriable inventory item.
  # Non-stackable — each item corresponds to one IrradiationEnclosure entity record.
  STACK_SIZE = 1
  DISPLAY_NAME = "Irradiation Enclosure"
  TOOLTIP = "A placeable radiation chamber. Craft it and place it in the world."

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

  # Removes this item from the player's inventory and marks the associated
  # IrradiationEnclosure entity as placed in the world.
  #
  # @param user [User] the player performing the place action
  # @return [Hash] { success: Boolean, mutations: Array, reason: String|nil }
  def place!(user)
    mutations = []
    success   = false
    reason    = nil

    begin
      ActiveRecord::Base.transaction do
        enclosure = irradiation_enclosure

        if enclosure.nil?
          reason = "no_entity"
          raise ActiveRecord::Rollback
        end

        # Remove the inventory item from the slot and destroy it
        removed = user.remove_inventory(self.class.name, 1)

        if removed.empty?
          reason = "removal_failed"
          raise ActiveRecord::Rollback
        end

        mutations.concat(removed)

        # Mark the PlaceableEntity as placed
        enclosure.place!

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
      user.trigger_action_state_update
    end

    result = { success: success, mutations: mutations, reason: reason }
    Rails.logger.info("IrradiationEnclosureInventoryItem#place! result for user=#{user&.id}: #{result.inspect}")
    result
  end
end
