class AddInventoryItemToLootBoxLoot < ActiveRecord::Migration[8.1]
  def change
    add_reference :loot_box_loots, :inventory_item, null: false, foreign_key: true
  end
end
