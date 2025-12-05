class PerformPlayerActionJob < ApplicationJob
  queue_as :default

  def perform(user, action_name, action_data)
    user.send(action_name, action_data)
  end
end
