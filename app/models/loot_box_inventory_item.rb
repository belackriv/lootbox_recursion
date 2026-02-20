class LootBoxInventoryItem < InventoryItem
  # A LootBoxInventoryItem represents a loot box as an inventory item.
  # It is associated with the LootBox record that contains the actual loot contents.
  # This item type is non-stackable (STACK_SIZE = 1).
  STACK_SIZE = 1
  DISPLAY_NAME = "Loot Box"
  TOOLTIP = "A mysterious box containing unknown rewards. Use it from your inventory to reveal its contents."

  belongs_to :loot_box, optional: true

  # Extend the JSON representation to include the loot_box reference.
  def to_jbuilder(tags = [ "default" ])
    Jbuilder.new do |jbuilder|
      if tags.include?("default")
        jbuilder.extract!(self, :id, :type, :count, :entity_id)
        jbuilder.display_name display_name
        jbuilder.tooltip tooltip
        jbuilder.loot_box_id loot_box_id
      end
    end
  end
end
