class CreateLootBoxLoots < ActiveRecord::Migration[8.1]
  def change
    create_table :loot_box_loots do |t|
      t.string :type
      t.integer :count
      t.boolean :claimed
      t.references :loot_box, null: false, foreign_key: true

      t.timestamps
    end
  end
end
