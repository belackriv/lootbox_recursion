class IndexController < InertiaController
  allow_unauthenticated_access only: %i[ index ]

  def index
    if authenticated?
      render inertia: 'Index/Index', props: {
        currentUser: Current.user.as_json(only: [:id, :email_address]),
        logoutPath: session_path,
        inventoryItems: Current.user.inventory_items.order(:slot).limit(100).as_json(
          only: [:id, :created_at, :type, :count, :slot]
        ),
        availableActions: Current.user.get_available_actions.as_json
      }
    else
      render inertia: 'Index/NotLoggedIn', props: {
        currentUser: nil,
        loginPath: new_session_path
      }
    end
  end
end
