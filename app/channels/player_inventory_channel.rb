class PlayerInventoryChannel < ApplicationCable::Channel

  def subscribed
    stream_for current_user
  end

  def receive(data)
    p data

  end

  def unsubscribed
    stop_all_streams
  end
end
