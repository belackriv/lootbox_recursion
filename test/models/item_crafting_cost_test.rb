require "test_helper"

class ItemCraftingCostTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Construction & attribute readers
  # ---------------------------------------------------------------------------

  test "stores wood and iron costs provided at construction" do
    cost = ItemCraftingCost.new(wood: 50, iron: 100)
    assert_equal 50,  cost.wood
    assert_equal 100, cost.iron
  end

  test "wood defaults to 0 when not provided" do
    cost = ItemCraftingCost.new(iron: 75)
    assert_equal 0, cost.wood
  end

  test "iron defaults to 0 when not provided" do
    cost = ItemCraftingCost.new(wood: 30)
    assert_equal 0, cost.iron
  end

  test "both costs default to 0 when no arguments are given" do
    cost = ItemCraftingCost.new
    assert_equal 0, cost.wood
    assert_equal 0, cost.iron
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  test "raises ArgumentError when wood cost is negative" do
    assert_raises(ArgumentError) { ItemCraftingCost.new(wood: -1, iron: 50) }
  end

  test "raises ArgumentError when iron cost is negative" do
    assert_raises(ArgumentError) { ItemCraftingCost.new(wood: 50, iron: -1) }
  end

  test "raises ArgumentError with a descriptive message for negative wood" do
    error = assert_raises(ArgumentError) { ItemCraftingCost.new(wood: -5) }
    assert_match(/wood cost must be non-negative/, error.message)
  end

  test "raises ArgumentError with a descriptive message for negative iron" do
    error = assert_raises(ArgumentError) { ItemCraftingCost.new(iron: -5) }
    assert_match(/iron cost must be non-negative/, error.message)
  end

  test "zero is a valid cost for both wood and iron" do
    cost = assert_nothing_raised { ItemCraftingCost.new(wood: 0, iron: 0) }
    assert_equal 0, cost.wood
    assert_equal 0, cost.iron
  end

  # ---------------------------------------------------------------------------
  # to_h
  # ---------------------------------------------------------------------------

  test "to_h returns a hash keyed by InventoryItem class names" do
    cost = ItemCraftingCost.new(wood: 50, iron: 100)
    h = cost.to_h
    assert_kind_of Hash, h
    assert_equal 50,  h["WoodInventoryItem"]
    assert_equal 100, h["IronInventoryItem"]
  end

  test "to_h includes all MATERIAL_TYPES as keys" do
    cost = ItemCraftingCost.new
    ItemCraftingCost::MATERIAL_TYPES.each do |material_type|
      assert cost.to_h.key?(material_type),
             "Expected to_h to include key '#{material_type}'"
    end
  end

  test "to_h reflects default zero costs when no args given" do
    cost = ItemCraftingCost.new
    assert_equal 0, cost.to_h["WoodInventoryItem"]
    assert_equal 0, cost.to_h["IronInventoryItem"]
  end

  test "to_h returns independent hash — mutations do not affect the cost object" do
    cost = ItemCraftingCost.new(wood: 10, iron: 20)
    h = cost.to_h
    h["WoodInventoryItem"] = 999
    assert_equal 10, cost.wood, "Mutating the returned hash should not change the cost object"
  end

  # ---------------------------------------------------------------------------
  # Equality
  # ---------------------------------------------------------------------------

  test "two costs with identical values are equal" do
    a = ItemCraftingCost.new(wood: 50, iron: 50)
    b = ItemCraftingCost.new(wood: 50, iron: 50)
    assert_equal a, b
  end

  test "two costs with different wood values are not equal" do
    a = ItemCraftingCost.new(wood: 50, iron: 50)
    b = ItemCraftingCost.new(wood: 99, iron: 50)
    assert_not_equal a, b
  end

  test "two costs with different iron values are not equal" do
    a = ItemCraftingCost.new(wood: 50, iron: 50)
    b = ItemCraftingCost.new(wood: 50, iron: 99)
    assert_not_equal a, b
  end

  test "a cost is not equal to nil" do
    cost = ItemCraftingCost.new(wood: 10, iron: 10)
    assert_not_equal cost, nil
  end

  test "a cost is not equal to a plain hash with the same values" do
    cost = ItemCraftingCost.new(wood: 50, iron: 50)
    assert_not_equal cost, { wood: 50, iron: 50 }
  end

  # ---------------------------------------------------------------------------
  # MATERIAL_TYPES constant
  # ---------------------------------------------------------------------------

  test "MATERIAL_TYPES includes WoodInventoryItem" do
    assert_includes ItemCraftingCost::MATERIAL_TYPES, "WoodInventoryItem"
  end

  test "MATERIAL_TYPES includes IronInventoryItem" do
    assert_includes ItemCraftingCost::MATERIAL_TYPES, "IronInventoryItem"
  end

  test "MATERIAL_TYPES is frozen" do
    assert ItemCraftingCost::MATERIAL_TYPES.frozen?,
           "MATERIAL_TYPES should be frozen to prevent accidental mutation"
  end

  # ---------------------------------------------------------------------------
  # Integration — CRAFTING_COST constants on craftable classes
  # ---------------------------------------------------------------------------

  test "LootBox::CRAFTING_COST is an ItemCraftingCost" do
    assert_instance_of ItemCraftingCost, LootBox::CRAFTING_COST
  end

  test "LootBox::CRAFTING_COST has correct wood cost" do
    assert_equal 50, LootBox::CRAFTING_COST.wood
  end

  test "LootBox::CRAFTING_COST has correct iron cost" do
    assert_equal 50, LootBox::CRAFTING_COST.iron
  end

  test "IrradiationEnclosure::CRAFTING_COST is an ItemCraftingCost" do
    assert_instance_of ItemCraftingCost, IrradiationEnclosure::CRAFTING_COST
  end

  test "IrradiationEnclosure::CRAFTING_COST has correct wood cost" do
    assert_equal 100, IrradiationEnclosure::CRAFTING_COST.wood
  end

  test "IrradiationEnclosure::CRAFTING_COST has correct iron cost" do
    assert_equal 100, IrradiationEnclosure::CRAFTING_COST.iron
  end
end
