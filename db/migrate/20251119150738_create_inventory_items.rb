class CreateInventoryItems < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_items do |t|
      t.string :type
      t.integer :count
      t.integer :slot

      t.timestamps
    end
  end
end
