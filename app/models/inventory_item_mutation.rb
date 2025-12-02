class InventoryItemMutation < ApplicationRecord
  include CamelizeKeysInJson

  belongs_to :user
end
