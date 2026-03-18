class PlaceableEntity < Entity
  # Base class for all entities that can be placed in the world.
  # Inherits all inventory management behaviour from Entity.
  #
  # Instances are owned by a player Entity (via owner_id) rather than directly
  # by a User (user_id is null for all PlaceableEntity rows).
  #
  # placed_by_user_id is a denormalised reference to the User who deployed this
  # entity. It is populated at place! time and used to enforce per-user
  # coordinate uniqueness at the DB level without requiring a join.

  validates :world_coordinate,
            uniqueness: { scope: :placed_by_user_id },
            allow_nil: true

  # Marks this entity as placed at the given world coordinate.
  #
  # Guards against:
  #   - re-placing an already-placed entity
  #   - placing at a coordinate already occupied by another entity in the same
  #     user's game world
  #
  # @param coordinate [Integer] the signed 1D world coordinate to place at
  # @param user [User] the player performing the placement
  # @return [Boolean] true if the record was updated successfully
  # @raise [ArgumentError] if coordinate or user is nil
  def place!(coordinate, user)
    raise ArgumentError, "coordinate is required" if coordinate.nil?
    raise ArgumentError, "user is required" if user.nil?

    if placed_at.present?
      Rails.logger.warn(
        "PlaceableEntity#place! entity=#{id} is already placed at coordinate=#{world_coordinate} " \
        "(placed_at=#{placed_at}); ignoring"
      )
      return false
    end

    conflict = self.class
      .where(placed_by_user_id: user.id, world_coordinate: coordinate)
      .where.not(id: id)
      .where.not(placed_at: nil)
      .exists?

    if conflict
      Rails.logger.warn(
        "PlaceableEntity#place! coordinate=#{coordinate} is already occupied " \
        "(user_id=#{user.id}); ignoring"
      )
      return false
    end

    update!(world_coordinate: coordinate, placed_by_user_id: user.id, placed_at: Time.current)
  end

  # Reverses placement — clears placed_at, world_coordinate, and placed_by_user_id.
  #
  # Guards against recalling an entity that isn't currently placed.
  #
  # @return [Boolean] true if the record was updated successfully
  def recall!
    unless placed_at.present?
      Rails.logger.warn(
        "PlaceableEntity#recall! entity=#{id} is not placed; ignoring"
      )
      return false
    end

    update!(placed_at: nil, world_coordinate: nil, placed_by_user_id: nil)
  end
end
