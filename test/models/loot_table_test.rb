require "test_helper"

class LootTableTest < ActiveSupport::TestCase
  # A minimal two-entry config used by most tests.
  SIMPLE_CONFIG = {
    rolls: { min: 1, max: 1 },
    entries: [
      { item_type: "WoodInventoryItem", weight: 60, min_count: 5, max_count: 5 },
      { item_type: "IronInventoryItem", weight: 40, min_count: 3, max_count: 3 }
    ]
  }.freeze

  # Config with a single entry — every roll must pick that entry.
  SINGLE_ENTRY_CONFIG = {
    rolls: { min: 3, max: 3 },
    entries: [
      { item_type: "WoodInventoryItem", weight: 100, min_count: 10, max_count: 20 }
    ]
  }.freeze

  setup do
    LootTable.reset_cache!
  end

  # ---------------------------------------------------------------------------
  # LootTable.for
  # ---------------------------------------------------------------------------

  test "LootTable.for returns a LootTable instance" do
    loot_box = LootBox.new
    loot_box.define_singleton_method(:class) { Struct.new(:name).new("LootBox") }
    # Use a real WoodLootBox so we can check type-key lookup
    wood_box = WoodLootBox.new
    result = LootTable.for(wood_box)
    assert_instance_of LootTable, result
  end

  test "LootTable.for picks the WoodLootBox table when the box is a WoodLootBox" do
    wood_box = WoodLootBox.new
    table = LootTable.for(wood_box)
    entry_types = table.config[:entries].map { |e| e[:item_type] }
    # WoodLootBox table has WoodInventoryItem as the heavy-weight entry
    assert_includes entry_types, "WoodInventoryItem"
  end

  test "LootTable.for picks the IronLootBox table when the box is an IronLootBox" do
    iron_box = IronLootBox.new
    table = LootTable.for(iron_box)
    entry_types = table.config[:entries].map { |e| e[:item_type] }
    assert_includes entry_types, "IronInventoryItem"
  end

  test "LootTable.for falls back to default table for an unknown loot box type" do
    # Create an anonymous subclass whose STI name won't match any key in the YAML
    unknown_box = LootBox.new
    # Override class.name to something not in the YAML
    unknown_box.define_singleton_method(:class) do
      klass = Class.new
      klass.define_singleton_method(:name) { "UnknownLootBox" }
      klass
    end

    table = LootTable.for(unknown_box)
    assert_instance_of LootTable, table

    # The default table has both wood and iron entries
    entry_types = table.config[:entries].map { |e| e[:item_type] }
    assert_includes entry_types, "WoodInventoryItem"
    assert_includes entry_types, "IronInventoryItem"
  end

  # ---------------------------------------------------------------------------
  # LootTable#config
  # ---------------------------------------------------------------------------

  test "config returns deep-symbolized keys" do
    table = LootTable.new(SIMPLE_CONFIG)
    assert_kind_of Symbol, table.config.keys.first
    assert_kind_of Hash,   table.config[:rolls]
    assert_kind_of Array,  table.config[:entries]
  end

  # ---------------------------------------------------------------------------
  # LootTable#roll — return structure
  # ---------------------------------------------------------------------------

  test "roll returns an Array" do
    table  = LootTable.new(SIMPLE_CONFIG)
    result = table.roll
    assert_kind_of Array, result
  end

  test "each roll result has item_type and count keys" do
    table  = LootTable.new(SIMPLE_CONFIG)
    result = table.roll
    result.each do |item|
      assert item.key?(:item_type), "Roll result is missing :item_type"
      assert item.key?(:count),     "Roll result is missing :count"
    end
  end

  test "roll returns exactly min rolls when min == max" do
    config = {
      rolls: { min: 3, max: 3 },
      entries: SIMPLE_CONFIG[:entries]
    }
    table = LootTable.new(config)
    assert_equal 3, table.roll.length
  end

  test "roll count is within [min, max] range" do
    config = {
      rolls: { min: 2, max: 5 },
      entries: SIMPLE_CONFIG[:entries]
    }
    table = LootTable.new(config)

    # Run many times to test randomness boundaries
    100.times do
      count = table.roll.length
      assert count >= 2 && count <= 5,
             "Expected roll count between 2 and 5, got #{count}"
    end
  end

  # ---------------------------------------------------------------------------
  # LootTable#roll — weighted selection
  # ---------------------------------------------------------------------------

  test "single-entry table always picks that entry" do
    table  = LootTable.new(SINGLE_ENTRY_CONFIG)
    result = table.roll
    result.each do |item|
      assert_equal "WoodInventoryItem", item[:item_type]
    end
  end

  test "100-weight entry is always selected over zero-weight entries" do
    config = {
      rolls: { min: 1, max: 1 },
      entries: [
        { item_type: "WoodInventoryItem", weight: 100, min_count: 1, max_count: 1 },
        { item_type: "IronInventoryItem", weight: 0,   min_count: 1, max_count: 1 }
      ]
    }
    table = LootTable.new(config)
    50.times do
      result = table.roll
      assert_equal "WoodInventoryItem", result.first[:item_type]
    end
  end

  test "weighted selection produces roughly expected distribution over many rolls" do
    # 75/25 weight split; over 1_000 rolls each entry should be selected ~correctly
    config = {
      rolls: { min: 1_000, max: 1_000 },
      entries: [
        { item_type: "WoodInventoryItem", weight: 75, min_count: 1, max_count: 1 },
        { item_type: "IronInventoryItem", weight: 25, min_count: 1, max_count: 1 }
      ]
    }
    table  = LootTable.new(config)
    result = table.roll
    wood_count = result.count { |r| r[:item_type] == "WoodInventoryItem" }
    iron_count = result.count { |r| r[:item_type] == "IronInventoryItem" }

    # Allow ±10 % tolerance around expected values (750 / 250)
    assert wood_count.between?(650, 850),
           "Expected ~750 wood picks, got #{wood_count}"
    assert iron_count.between?(150, 350),
           "Expected ~250 iron picks, got #{iron_count}"
  end

  # ---------------------------------------------------------------------------
  # LootTable#roll — count range
  # ---------------------------------------------------------------------------

  test "rolled count is within entry min_count and max_count" do
    config = {
      rolls: { min: 50, max: 50 },
      entries: [
        { item_type: "WoodInventoryItem", weight: 100, min_count: 7, max_count: 13 }
      ]
    }
    table  = LootTable.new(config)
    result = table.roll
    result.each do |item|
      assert item[:count].between?(7, 13),
             "Expected count between 7 and 13, got #{item[:count]}"
    end
  end

  test "rolled count equals min_count when min_count == max_count" do
    config = {
      rolls: { min: 10, max: 10 },
      entries: [
        { item_type: "IronInventoryItem", weight: 100, min_count: 5, max_count: 5 }
      ]
    }
    table  = LootTable.new(config)
    result = table.roll
    result.each do |item|
      assert_equal 5, item[:count]
    end
  end

  # ---------------------------------------------------------------------------
  # Modifier integration (pass-through via LootTable.new)
  # ---------------------------------------------------------------------------

  test "modifier that doubles a weight changes selection distribution" do
    base_config = {
      rolls: { min: 1_000, max: 1_000 },
      entries: [
        { item_type: "WoodInventoryItem", weight: 50, min_count: 1, max_count: 1 },
        { item_type: "IronInventoryItem", weight: 50, min_count: 1, max_count: 1 }
      ]
    }

    # Simulate a modifier that doubles Iron's weight to 100 (total 150; iron ~67 %)
    modified_config = base_config.deep_dup
    modified_config[:entries][1] = modified_config[:entries][1].merge(weight: 100)

    table  = LootTable.new(modified_config)
    result = table.roll

    iron_count = result.count { |r| r[:item_type] == "IronInventoryItem" }
    wood_count = result.count { |r| r[:item_type] == "WoodInventoryItem" }

    # Iron should win significantly more often (~667 vs ~333)
    assert iron_count > wood_count,
           "Expected iron picks (#{iron_count}) to exceed wood picks (#{wood_count}) with doubled iron weight"
  end

  test "modifier that bumps max rolls increases roll count" do
    base_config = {
      rolls: { min: 2, max: 2 },
      entries: SIMPLE_CONFIG[:entries]
    }

    modified_config              = base_config.deep_dup
    modified_config[:rolls]      = { min: 2, max: 6 }

    seen_counts = Set.new
    table       = LootTable.new(modified_config)
    200.times { seen_counts << table.roll.length }

    assert seen_counts.any? { |c| c > 2 },
           "Expected some rolls to exceed 2 after bumping max to 6"
  end

  # ---------------------------------------------------------------------------
  # Cache
  # ---------------------------------------------------------------------------

  test "reset_cache! causes all_configs to reload from disk" do
    first  = LootTable.all_configs.object_id
    LootTable.reset_cache!
    second = LootTable.all_configs.object_id
    assert_not_equal first, second, "Expected a new object after cache reset"
  end

  test "all_configs is memoized between calls" do
    first  = LootTable.all_configs.object_id
    second = LootTable.all_configs.object_id
    assert_equal first, second, "Expected the same cached object on repeated calls"
  end
end
