class InventoryItem < ApplicationRecord
  include IncludeTypeInJson


  belongs_to :entity
  has_one :inventory_slot

  def to_jbuilder(tags = ['default'])
    Jbuilder.new do |jbuilder|
      if tags.include?('default')
        jbuilder.extract!(self, :id, :type, :count, :entity_id)
      end
    end
  end

  SCAVENGE_TYPES = [
    'IronInventoryItem',
    'WoodInventoryItem'
  ]

  def self.scavenge_item(user)
    item_type = InventoryItem::SCAVENGE_TYPES.sample;
    item_count = rand(user.get_scavenge_range_mod) + user.get_scavenge_add_mod
    mutations = user.add_inventory(item_type, item_count)
    PlayerInventoryChannel.broadcast_to(user, mutations)
  end
end
