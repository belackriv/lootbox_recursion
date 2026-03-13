class PlaceableEntity < Entity
  # Base class for all entities that can be placed in the world.
  # Inherits all inventory management behaviour from Entity.
  #
  # Instances are owned by a player Entity (via owner_id) rather than directly
  # by a User (user_id is null for all PlaceableEntity rows).
  #
  # Placement-specific behaviour (coordinates, place!, validations, etc.)
  # will be added here in the future.
end
