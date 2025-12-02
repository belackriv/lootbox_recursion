class LootBox < ApplicationRecord
  include IncludeTypeInJson
  include CamelizeKeysInJson

  belongs_to :user
end
