class AddIrradiationEnclosureIdToInventoryItems < ActiveRecord::Migration[8.1]
  def change
    # FK points at entities because IrradiationEnclosure is an STI row in that table.
    add_column :inventory_items, :irradiation_enclosure_id, :bigint, null: true
    add_index  :inventory_items, :irradiation_enclosure_id
    add_foreign_key :inventory_items, :entities, column: :irradiation_enclosure_id
  end
end
