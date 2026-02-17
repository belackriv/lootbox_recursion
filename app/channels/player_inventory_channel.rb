class PlayerInventoryChannel < ApplicationCable::Channel

  def subscribed
    # Log when a client subscribes to help debug connection / streaming issues.
    # Include the current_user id if available to correlate server logs with client activity.
    Rails.logger.debug("[PlayerInventoryChannel] subscribed user_id=#{current_user&.id}")
    stream_for current_user
  end

  def receive(data)
    # Log incoming client messages (and broadcasts if the server receives them)
    # Use inspect so complex payloads are printed cleanly in logs.
    Rails.logger.debug("[PlayerInventoryChannel] receive payload: #{data.inspect}")

    # Preserve previous behavior for debugging convenience
    p data
  end

  def unsubscribed
    # Log unsubscribes so we can trace disconnects
    Rails.logger.debug("[PlayerInventoryChannel] unsubscribed user_id=#{current_user&.id}")
    stop_all_streams
  end
end
