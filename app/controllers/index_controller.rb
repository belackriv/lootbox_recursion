class IndexController < InertiaController
  allow_unauthenticated_access only: %i[ index ]

  def index
    if authenticated?
      placed_entities = Entity
        .where(placed_by_user_id: Current.user.id)
        .where.not(placed_at: nil)
        .where.not(world_coordinate: nil)

      render inertia: "Index/Index", props: {
        currentUser: Current.user.to_jbuilder.attributes!,
        logoutPath: session_path,
        userEntityId: Current.user.entity.id,
        inventory: Current.user.entity.inventory_slots.order(:slot).limit(100).map do |slot|
          slot.to_jbuilder.attributes!
        end,
        actions: Current.user.get_available_actions.map do |action|
          action.to_jbuilder.attributes!
        end,
        worldCells: placed_entities.map do |entity|
          {
            coordinate: entity.world_coordinate,
            placedEntity: {
              type: entity.type,
              displayName: entity.class.const_defined?(:DISPLAY_NAME) ? entity.class::DISPLAY_NAME : entity.type,
              tooltip: entity.class.const_defined?(:TOOLTIP) ? entity.class::TOOLTIP : nil
            }
          }
        end
      }
    else
      render inertia: "Index/NotLoggedIn", props: {
        currentUser: nil,
        loginPath: new_session_path
      }
    end
  end
end
