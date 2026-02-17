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
    # Serialize mutations to camelCase using to_jbuilder before broadcasting
    mutations_payload = mutations.map { |m| m.to_jbuilder.attributes! }
    PlayerInventoryChannel.broadcast_to(user, mutations_payload)
  end
end
