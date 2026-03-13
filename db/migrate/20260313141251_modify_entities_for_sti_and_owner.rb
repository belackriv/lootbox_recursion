class ModifyEntitiesForStiAndOwner < ActiveRecord::Migration[8.1]
  def change
    # STI discriminator — nil for the base player Entity, class name for subclasses
    add_column :entities, :type, :string

    # Self-referential FK: a PlaceableEntity is owned by a player Entity.
    # Not unique — one player entity can own many placeable entities.
    add_column :entities, :owner_id, :bigint, null: true
    add_index  :entities, :owner_id
    add_foreign_key :entities, :entities, column: :owner_id

    # Make user_id nullable now that non-user entities (owner_id set) are allowed.
    # The unique index already present is kept — only one Entity may belong to each user.
    change_column_null :entities, :user_id, true

    # Enforce the invariant: exactly one of user_id or owner_id must be set.
    add_check_constraint :entities,
      "num_nonnulls(user_id, owner_id) = 1",
      name: "entity_exactly_one_owner"
  end
end
