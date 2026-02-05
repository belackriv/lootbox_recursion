class ModInventoryItemRemoveUser < ActiveRecord::Migration[8.1]
  def change
    change_column_null(:inventory_items, :entity_id, false)
    remove_column :inventory_items, :user_id
  end
end
