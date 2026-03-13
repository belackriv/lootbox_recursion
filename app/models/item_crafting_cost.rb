# A plain Ruby object that encapsulates the material costs required to craft an item.
#
# Usage:
#   cost = ItemCraftingCost.new(wood: 50, iron: 50)
#   cost.wood  # => 50
#   cost.iron  # => 50
#
# Costs default to 0 so future material types can be added here without
# breaking existing callers that don't supply them.
class ItemCraftingCost
  MATERIAL_TYPES = %w[WoodInventoryItem IronInventoryItem].freeze

  attr_reader :wood, :iron

  def initialize(wood: 0, iron: 0)
    raise ArgumentError, "wood cost must be non-negative" if wood < 0
    raise ArgumentError, "iron cost must be non-negative" if iron < 0

    @wood = wood
    @iron = iron
  end

  # Returns a hash mapping InventoryItem class name → required count,
  # making it easy to iterate over all costs generically in craft logic.
  #
  #   cost.to_h  # => { "WoodInventoryItem" => 50, "IronInventoryItem" => 50 }
  def to_h
    {
      "WoodInventoryItem" => @wood,
      "IronInventoryItem" => @iron
    }
  end

  def ==(other)
    other.is_a?(ItemCraftingCost) && wood == other.wood && iron == other.iron
  end
end
