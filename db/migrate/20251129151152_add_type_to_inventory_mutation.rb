class AddTypeToInventoryMutation < ActiveRecord::Migration[8.1]
  def change
    add_column :inventory_item_mutations, :item_type, :string
  end
end
