class ReplaceLootBoxLootInventoryItemWithSnapshot < ActiveRecord::Migration[8.1]
  def up
    # 1. Add the snapshot column (nullable initially so we can backfill first)
    add_column :loot_box_loots, :item_snapshot, :jsonb, null: true

    # 2. Backfill from existing FK rows — store the item type and count
    execute <<~SQL
      UPDATE loot_box_loots l
      SET    item_snapshot = jsonb_build_object(
               'type',  i.type,
               'count', l.count
             )
      FROM   inventory_items i
      WHERE  i.id = l.inventory_item_id
    SQL

    # 3. Any rows with no matching inventory_item (orphaned) get a null-safe fallback
    execute <<~SQL
      UPDATE loot_box_loots
      SET    item_snapshot = jsonb_build_object('type', null, 'count', count)
      WHERE  item_snapshot IS NULL
    SQL

    # 4. Now that every row has a snapshot, enforce non-null
    change_column_null :loot_box_loots, :item_snapshot, false

    # 5. Drop FK constraint, index, then the column itself
    remove_foreign_key :loot_box_loots, :inventory_items
    remove_index       :loot_box_loots, name: "index_loot_box_loots_on_inventory_item_id", if_exists: true
    remove_column      :loot_box_loots, :inventory_item_id
  end

  def down
    # Restore the column and FK (data in item_snapshot is not migrated back)
    add_column :loot_box_loots, :inventory_item_id, :integer, null: true
    add_index  :loot_box_loots, :inventory_item_id, name: "index_loot_box_loots_on_inventory_item_id"
    add_foreign_key :loot_box_loots, :inventory_items

    remove_column :loot_box_loots, :item_snapshot
  end
end
