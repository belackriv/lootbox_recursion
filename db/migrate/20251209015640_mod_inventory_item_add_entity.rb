class ModInventoryItemAddEntity < ActiveRecord::Migration[8.1]
  def change
    add_reference :inventory_items, :entity, null: true, foreign_key: true
  end
end
