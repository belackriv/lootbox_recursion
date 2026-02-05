class ModInventoryItemMutationAddEntityAndSlot < ActiveRecord::Migration[8.1]
  def change
    add_reference :inventory_item_mutations, :entity, null: true, foreign_key: true
    add_reference :inventory_item_mutations, :inventory_slot, null: true, foreign_key: true
  end
end
