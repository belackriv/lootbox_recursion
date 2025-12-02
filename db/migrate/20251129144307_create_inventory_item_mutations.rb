class CreateInventoryItemMutations < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_item_mutations do |t|
      t.integer :delta
      t.integer :slot
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
