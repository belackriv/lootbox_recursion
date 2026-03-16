class AddPlacedAtToEntities < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :placed_at, :datetime
  end
end
