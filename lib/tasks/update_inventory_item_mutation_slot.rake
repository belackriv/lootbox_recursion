namespace :update_inventory_item_mutation_slot do
  desc "Update inventory item mutations with inventory slot"
  task update: :environment do
    InventoryItemMutation.where(entity_id: nil).or(InventoryItemMutation.where(inventory_slot_id: nil)).find_each(batch_size: 100) do |mutation|
      inventory_slot = InventorySlot.find_by(slot: mutation.slot, entity: mutation.user.entity)
      mutation.inventory_slot = inventory_slot
      mutation.entity = inventory_slot.entity
      mutation.save!
    end
  end
end
