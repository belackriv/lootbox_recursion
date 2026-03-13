class IrradiationEnclosure < PlaceableEntity
  CRAFTING_COST = ItemCraftingCost.new(wood: 100, iron: 100)
  DISPLAY_NAME = "Irradiation Enclosure"

  def self.craft(user, action_data)
    Entity.craft_item(
      user,
      cost:                 CRAFTING_COST,
      inventory_item_type:  "IrradiationEnclosureInventoryItem",
      inventory_item_assoc: :irradiation_enclosure
    ) do |player_entity|
      IrradiationEnclosure.create!(owner: player_entity)
    end
  end
end
