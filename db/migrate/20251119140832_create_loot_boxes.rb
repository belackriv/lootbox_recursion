class CreateLootBoxes < ActiveRecord::Migration[8.1]
  def change
    create_table :loot_boxes do |t|
      t.string :type
      t.datetime :opened_at
      t.timestamps
    end
  end
end
