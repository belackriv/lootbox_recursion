class PlayerActionsChannel < ApplicationCable::Channel
  include SnakeCaseHashKeys

  def subscribed
    stream_for current_user
  end

  def receive(data)
    data = snake_case_keys(data)
    current_user.perform_action(data['player_action']['name'], data['player_action_data'])
  end

  def unsubscribed
    stop_all_streams
  end
end
