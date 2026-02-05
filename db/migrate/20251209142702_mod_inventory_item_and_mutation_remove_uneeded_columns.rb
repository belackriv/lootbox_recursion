class ModInventoryItemAndMutationRemoveUneededColumns < ActiveRecord::Migration[8.1]
  def change
    change_column_null(:inventory_item_mutations, :inventory_slot_id, false)
    remove_column :inventory_items, :slot
    remove_column :inventory_item_mutations, :user_id
    remove_column :inventory_item_mutations, :entity_id
    remove_column :inventory_item_mutations, :slot
  end
end
