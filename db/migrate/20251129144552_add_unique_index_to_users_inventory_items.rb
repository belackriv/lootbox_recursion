class AddUniqueIndexToUsersInventoryItems < ActiveRecord::Migration[8.1]
  def change
    add_index :inventory_items, [:slot, :user_id], unique: true, name: 'unique_inventory_items_on_slot_and_user_id'
  end
end
