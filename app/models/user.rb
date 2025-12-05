class User < ApplicationRecord
  include CamelizeKeysInJson

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :inventory_items, dependent: :destroy
  has_many :loot_boxes, dependent: :destroy
  has_many :player_action_states, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  attr_accessor :player_actions

  def get_player_actions
    if(@player_actions.nil?)
      @player_actions = APP_DATA[:player_actions]
      @player_actions.each do |action|
          action.update(self)
        end
    end
    # load the user's player action state and update player_actions
    @player_actions.each do |action|
      player_action_state = PlayerActionState.where(user: self, player_action_name: action.name).first()
      if(player_action_state)
        action.assign_attributes(player_action_state.action_state)
      end
    end
    return @player_actions
  end

  def get_available_actions
    return get_player_actions.filter { |action| action.revealed == true }
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
    if(player_action_state.nil?)
      player_action_state = PlayerActionState.new(user: self, player_action_name: player_action.name)
    end
    player_action_state.action_state = player_action.attributes
    player_action_state.save!
  end

  def get_inventory_slot_for_type_and_count(item_type, item_count)
    stack_size =  Object.const_get(item_type)::STACK_SIZE
    inventory_item = inventory_items.where(type: item_type, count: ...(stack_size - item_count)).first()
    if inventory_item.nil?
      return get_first_empty_inventory_slot
    end
    return inventory_item.slot
  end

  def get_first_empty_inventory_slot
    last_slot_num = -1
    inventory_items.order(slot: :asc).each do |item|
      if (last_slot_num + 1) < item.slot
        return last_slot_num + 1
      end
      last_slot_num += 1
    end
    return last_slot_num + 1
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
    InventoryItem::scavenge_item(self)
  end

  def get_scavenge_range_mod
    return 10
  end

  def get_scavenge_add_mod
    return 1
  end

  def get_craft_choices
    craft_choices = [{class_name: 'LootBox', label: 'Lootbox'}]
    return craft_choices
  end

  def craft(action_data)
     Object.const_get(action_data['class_name']).craft(self, action_data)
  end

  def remove_inventory(class_name, count)
    item_count = inventory_items.where(type: class_name).sum(:count)
    if(item_count < count)
      return []
    end

    mutations = []
    inventory_items.where(type: class_name).order(slot: :desc).each do |inventory_item|
      removed = [inventory_item.count, count].min

      mutation = InventoryItemMutation.new(user: self, item_type: class_name, slot: inventory_item.slot, delta: (removed * -1))
      InventoryItem::applyMutation(mutation)
      mutation.applied = true
      mutation.save
      mutations << mutation
      count = count - removed
      if(count === 0)
        break
      end
    end
    inventory_items.where(type: class_name, count: 0).destroy_all
    return mutations
  end
end
