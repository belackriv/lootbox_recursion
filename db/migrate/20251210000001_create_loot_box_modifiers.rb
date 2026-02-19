class CreateLootBoxModifiers < ActiveRecord::Migration[8.1]
  def change
    create_table :loot_box_modifiers do |t|
      t.string  :type,        null: false
      t.bigint  :loot_box_id, null: false
      t.timestamps
    end

    add_index :loot_box_modifiers, :loot_box_id
    add_foreign_key :loot_box_modifiers, :loot_boxes
  end
end
