class ApplyInventoryItemMutationsJob < ApplicationJob
  queue_as :default

  def perform(user, mutations)
    mutations.each do |mutation|
      if(!mutation.applied)
        InventoryItem::applyMutation(mutation)
        mutation.applied = true
        mutation.save
      end
    end
    PlayerInventoryChannel.broadcast_to(user, mutations)
  end
end
