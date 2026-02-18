class InventorySlot < ApplicationRecord
  belongs_to :inventory_item, optional: true
  belongs_to :entity

  def to_jbuilder(tags = [ "default" ])
    Jbuilder.new do |jbuilder|
      if tags.include?("default")
        jbuilder.extract!(self, :id, :slot, :entity_id)
        jbuilder.inventory_item inventory_item&.to_jbuilder&.attributes!
      end
    end
  end
end
