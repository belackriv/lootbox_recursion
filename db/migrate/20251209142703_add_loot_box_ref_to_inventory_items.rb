class AddLootBoxRefToInventoryItems < ActiveRecord::Migration[8.1]
  def up
    # Only add the reference if it doesn't already exist to make this migration idempotent.
    unless column_exists?(:inventory_items, :loot_box_id)
      add_reference :inventory_items, :loot_box, foreign_key: true, null: true
    end
  end

  def down
    # Remove the reference only if it exists.
    if column_exists?(:inventory_items, :loot_box_id)
      remove_reference :inventory_items, :loot_box, foreign_key: true
    end
  end
end
