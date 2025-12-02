class AddUserToInventoryItem < ActiveRecord::Migration[8.1]
  def change
    add_reference :inventory_items, :user, null: false, foreign_key: true
  end
end
