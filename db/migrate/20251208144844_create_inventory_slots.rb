class CreateInventorySlots < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_slots do |t|
      t.integer :slot
      t.references :inventory_item, null: true, foreign_key: true,  index: { unique: true }
      t.references :entity, null: false, foreign_key: true

      t.timestamps
    end
    add_index :inventory_slots, [:slot, :entity_id], unique: true, name: 'unique_inventory_slot_on_slot_and_entity_id'

  end
end
