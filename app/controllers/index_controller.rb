class IndexController < InertiaController
  allow_unauthenticated_access only: %i[ index ]

  def index
    if authenticated?
      render inertia: 'Index/Index', props: {
        currentUser: Current.user.to_jbuilder.attributes!,
        logoutPath: session_path,
        inventory: Current.user.entity.inventory_slots.order(:slot).limit(100).map do |slot|
          slot.to_jbuilder.attributes!
        end,
        actions: Current.user.get_available_actions.map do |action|
          action.to_jbuilder.attributes!
        end
      }
    else
      render inertia: 'Index/NotLoggedIn', props: {
        currentUser: nil,
        loginPath: new_session_path
      }
    end
  end
end
