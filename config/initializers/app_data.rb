APP_DATA = {}

Rails.application.config.after_initialize do
  player_action_data = YAML.load_file('app/data/player_actions.yml')
  APP_DATA[:player_actions] = player_action_data['player_actions'].map do |data_hash|
    PlayerAction.new(data_hash)
  end
end
