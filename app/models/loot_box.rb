class LootBox < ApplicationRecord
  include IncludeTypeInJson
  include CamelizeKeysInJson

  belongs_to :user

  def self.craft(user, action_data)
    p 'crafting lootbox'
    mutations = []
    mutations.concat(user.remove_inventory('WoodInventoryItem', 50))
    mutations.concat(user.remove_inventory('IronInventoryItem', 50))




    PlayerInventoryChannel.broadcast_to(user, mutations)
  end
end
