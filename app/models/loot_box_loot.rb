class LootBoxLoot < ApplicationRecord
  include CamelizeKeysInJson

  belongs_to :loot_box

  # item_snapshot is a jsonb column storing a point-in-time copy of the inventory
  # item that was awarded when the loot box was opened, e.g.:
  #   { "type" => "WoodInventoryItem", "count" => 5 }
  #
  # Using a snapshot instead of a FK means the underlying InventoryItem can be
  # freely destroyed (by sort, craft consumption, etc.) without blocking on this record.
  # Convenience reader: returns the item type string from the snapshot.
  # We store the key as "type" to mirror the inventory_items.type column name,
  # so we can't use store_accessor directly (it would look for key "item_type").
  def item_type
    item_snapshot&.dig("type")
  end

  validates :item_snapshot, presence: true

  # Returns the Ruby class constant for the item recorded in the snapshot,
  # or nil if the type is missing / not a known constant.
  def item_class
    type_name = item_snapshot&.dig("type")
    return nil if type_name.blank?

    Object.const_get(type_name)
  rescue NameError
    nil
  end
end
