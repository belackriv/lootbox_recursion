class LootBoxLoot < ApplicationRecord
  include CamelizeKeysInJson

  belongs_to :loot_box
  belongs_to :inventory_item
end
