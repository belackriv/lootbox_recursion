namespace :update_inventory_item_entity do
  desc "Update inventory items with entity from user"
  task update: :environment do
    User.all.each do |user|
      InventoryItem.where(entity_id: nil, user: user).in_batches(of: 100) do |batch|
        batch.update_all(entity_id: user.entity.id)
      end
    end
  end
end
