class AddWorldCoordinateToEntities < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :world_coordinate, :integer

    # Denormalised user reference so we can enforce per-user coordinate
    # uniqueness at the DB level without a join.
    # Populated by PlaceableEntity#place! at deploy time.
    add_column :entities, :placed_by_user_id, :bigint

    add_foreign_key :entities, :users, column: :placed_by_user_id

    # Prevents two placed entities from occupying the same coordinate
    # within the same user's game world.
    # NULL coordinates (unplaced entities) are excluded from the constraint.
    add_index :entities, [ :placed_by_user_id, :world_coordinate ],
              unique: true,
              where: "world_coordinate IS NOT NULL",
              name: "index_entities_on_placed_by_user_id_and_world_coordinate_unique"
  end
end
