class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :inventory_items, dependent: :destroy
  has_many :loot_boxes, dependent: :destroy
  has_many :player_action_states, dependent: :destroy
  has_one :entity
  delegate :inventory_items, to: :entity

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  attr_accessor :player_actions

  def to_jbuilder(tags = [ "default" ])
    Jbuilder.new do |jbuilder|
      if tags.include?("default")
        jbuilder.extract!(self, :id, :email_address)
      end
    end
  end

  BASE_INVENTORY_SLOTS = 50

  def get_player_actions
    if @player_actions.nil?
      @player_actions = APP_DATA[:player_actions]
      @player_actions.each do |action|
          action.update(self)
        end
    end
    # load the user's player action state and update player_actions
    @player_actions.each do |action|
      player_action_state = PlayerActionState.where(user: self, player_action_name: action.name).first()
      if player_action_state
        action.assign_attributes(player_action_state.action_state)
      end
    end
    @player_actions
  end

  def get_available_actions
    get_player_actions.filter { |action| action.revealed == true }
  end

  def update_player_actions
    get_player_actions.each do |action|
      action.update(self)
    end
    # create the user's new player action state and save it
    @player_actions.each do |action|
      save_player_action_state(action)
    end
  end

  def save_player_action_state(player_action)
    player_action_state = PlayerActionState.where(user: self, player_action_name: player_action.name).first()
    if player_action_state.nil?
      player_action_state = PlayerActionState.new(user: self, player_action_name: player_action.name)
    end
    player_action_state.action_state = player_action.attributes
    player_action_state.save!
  end

  def get_inventory_slot_count
    User::BASE_INVENTORY_SLOTS
  end

  def get_first_empty_inventory_slot
    entity.inventory_slots.where(inventory_item: nil).order(slot: :asc).find
  end

  def perform_action(player_action_name, action_data)
    player_action = get_player_actions.find { |action| action.name == player_action_name }
    if player_action.on_cooldown_until and player_action.on_cooldown_until > Time.current
      p "Action is on cooldown"
    else
      player_action.on_cooldown_until = Time.current + player_action.cooldown
      save_player_action_state(player_action)

      PerformPlayerActionJob.set(wait: player_action.cast_time.seconds).perform_later(self, player_action_name, action_data)
    end
  end

  def scavenge(action_data)
    InventoryItem.scavenge_item(self)
  end

  def get_scavenge_range_mod
    10
  end

  def get_scavenge_add_mod
    25
  end

  def get_craft_choices
    craft_choices = [ { class_name: "LootBox", label: "Lootbox" } ]
    craft_choices
  end

  def craft(action_data)
     Object.const_get(action_data["class_name"]).craft(self, action_data)
  end

  def remove_inventory(class_name, count)
    entity.remove_inventory(class_name, count)
  end

  def add_inventory(class_name, count)
    entity.add_inventory(class_name, count)
  end

  def trigger_action_state_update
    # Recalculate all action states based on current inventory
    update_player_actions

    # Broadcast updated actions to the user's PlayerActionsChannel
    updated_actions = get_available_actions.map do |action|
      action.to_jbuilder.attributes!
    end
    PlayerActionsChannel.broadcast_to(self, updated_actions)
  end
end
