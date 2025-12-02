class AddUserToLootBox < ActiveRecord::Migration[8.1]
  def change
    add_reference :loot_boxes, :user, null: false, foreign_key: true
  end
end
