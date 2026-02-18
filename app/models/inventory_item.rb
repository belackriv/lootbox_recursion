class InventoryItem < ApplicationRecord
  include IncludeTypeInJson


  belongs_to :entity
  has_one :inventory_slot

  def self.display_name
    if const_defined?(:DISPLAY_NAME)
      const_get(:DISPLAY_NAME)
    else
      name.sub(/InventoryItem\z/, "").underscore.humanize
    end
  end

  def display_name
    self.class.display_name
  end

  def to_jbuilder(tags = [ "default" ])
    Jbuilder.new do |jbuilder|
      if tags.include?("default")
        jbuilder.extract!(self, :id, :type, :count, :entity_id)
      end
    end
  end

  SCAVENGE_TYPES = [
    "IronInventoryItem",
    "WoodInventoryItem"
  ]

  def self.scavenge_item(user)
    item_type = InventoryItem::SCAVENGE_TYPES.sample
    item_count = rand(user.get_scavenge_range_mod) + user.get_scavenge_add_mod
    mutations = user.add_inventory(item_type, item_count)
    # Serialize mutations to camelCase using to_jbuilder before broadcasting
    mutations_payload = mutations.map { |mutation| mutation.to_jbuilder.attributes! }
    PlayerInventoryChannel.broadcast_to(user, { action: "inventory_mutations", data: mutations_payload })
  end
end
