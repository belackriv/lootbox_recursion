class PlayerActionsChannel < ApplicationCable::Channel

  def subscribed
    stream_for current_user
  end

  def receive(data)
    current_user.perform_action(data['playerAction']['name'], data['playerActionData'])
  end

  def unsubscribed
    stop_all_streams
  end
end
