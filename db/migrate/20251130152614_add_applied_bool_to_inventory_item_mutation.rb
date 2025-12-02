class AddAppliedBoolToInventoryItemMutation < ActiveRecord::Migration[8.1]
  def change
    add_column :inventory_item_mutations, :applied, :boolean, default: false
  end
end
