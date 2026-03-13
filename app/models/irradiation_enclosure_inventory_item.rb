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
end
