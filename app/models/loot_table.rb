class LootTable
  TABLE_DATA_PATH = Rails.root.join("app", "data", "loot_tables.yml")

  @table_data_cache = nil

  # Returns the full parsed loot_tables config hash, keyed by symbolized type name.
  # Cached after first load; call reset_cache! to force a reload (useful in tests).
  def self.all_configs
    @table_data_cache ||= YAML.load_file(TABLE_DATA_PATH).deep_symbolize_keys.fetch(:loot_tables)
  end

  def self.reset_cache!
    @table_data_cache = nil
  end

  # Returns a LootTable instance scoped to the given loot_box's STI type.
  # Falls back to the :default table when no type-specific table is found.
  def self.for(loot_box)
    type_key = loot_box.class.name.to_sym
    configs  = all_configs
    raw      = configs.key?(type_key) ? configs[type_key] : configs[:default]
    new(raw)
  end

  attr_reader :config

  def initialize(config)
    @config = config.deep_symbolize_keys
  end

  # Rolls loot based on the current config.
  #
  # 1. Draws a roll count from [rolls[:min]..rolls[:max]] (inclusive).
  # 2. For each roll, picks one entry from the weighted pool.
  # 3. For each picked entry, draws a random count from [min_count..max_count].
  #
  # @return [Array<Hash>] e.g. [{ item_type: "WoodInventoryItem", count: 14 }, ...]
  #   The same item_type may appear multiple times if selected on separate rolls.
  def roll
    rolls_config = config[:rolls]
    min_rolls    = rolls_config[:min].to_i
    max_rolls    = rolls_config[:max].to_i
    roll_count   = rand(min_rolls..max_rolls)

    entries      = config[:entries]
    total_weight = entries.sum { |e| e[:weight].to_i }

    roll_count.times.map do
      selected = weighted_pick(entries, total_weight)
      count    = rand(selected[:min_count].to_i..selected[:max_count].to_i)
      { item_type: selected[:item_type].to_s, count: count }
    end
  end

  private

  # Selects one entry using a cumulative-weight algorithm.
  #
  # @param entries [Array<Hash>] array of entry hashes with a :weight key
  # @param total_weight [Integer] pre-computed sum of all weights (avoids recomputing per roll)
  # @return [Hash] the selected entry
  def weighted_pick(entries, total_weight)
    pick       = rand(0...total_weight)
    cumulative = 0

    entries.detect do |entry|
      cumulative += entry[:weight].to_i
      pick < cumulative
    end
  end
end
