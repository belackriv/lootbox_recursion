class ApplyInventoryItemMutationsJob < ApplicationJob
  queue_as :default

  def perform(user, mutations)
    mutations.each do |mutation|
      InventoryItem::applyMutation(mutation)
      mutation.applied = true
      mutation.save
    end
    PlayerInventoryChannel.broadcast_to(user, mutations)
  end
end
