class PlaceableEntity < Entity
  # Base class for all entities that can be placed in the world.
  # Inherits all inventory management behaviour from Entity.
  #
  # Instances are owned by a player Entity (via owner_id) rather than directly
  # by a User (user_id is null for all PlaceableEntity rows).
  #
  # Placement-specific behaviour (coordinates, place!, validations, etc.)
  # will be added here in the future.

  # Marks this entity as placed in the game world.
  # Subclasses may override this to add placement-specific behaviour
  # (e.g. persisting world coordinates, triggering events, etc.).
  #
  # @return [Boolean] true if the record was updated successfully
  def place!
    # The placed_at timestamp records when the entity entered the world.
    # Further placement attributes (x/y coordinates, region, etc.) will be
    # stored here once the world-grid system is implemented.
    touch(:placed_at)
  end
end
