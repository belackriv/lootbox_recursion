class AddEntityRefToLootBoxes < ActiveRecord::Migration[8.1]
  def up
    # Add the reference initially allowing nulls so we can backfill existing rows
    add_reference :loot_boxes, :entity, foreign_key: true, null: true

    # Backfill entity_id for existing loot_boxes by joining on user_id -> entities.user_id
    execute <<-SQL.squish
      UPDATE loot_boxes
      SET entity_id = entities.id
      FROM entities
      WHERE loot_boxes.user_id = entities.user_id
    SQL

    # Ensure every loot_box now has an entity_id before making it NOT NULL
    null_count = select_value("SELECT COUNT(*) FROM loot_boxes WHERE entity_id IS NULL").to_i
    if null_count > 0
      raise ActiveRecord::IrreversibleMigration, "Cannot make loot_boxes.entity_id NOT NULL: #{null_count} rows have no matching entity"
    end

    change_column_null :loot_boxes, :entity_id, false
  end

  def down
    remove_reference :loot_boxes, :entity, foreign_key: true
  end
end
