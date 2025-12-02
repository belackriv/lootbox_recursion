class CreatePlayerActionStates < ActiveRecord::Migration[8.1]
  def change
    create_table :player_action_states do |t|
      t.string :player_action_name, null: false
      t.jsonb :action_state, null: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
      t.index [:player_action_name, :user_id], unique: true, name: 'unique_player_action_name_and_user_id'
    end
  end
end
