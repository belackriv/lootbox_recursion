class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  has_many :loot_boxes, dependent: :destroy

  has_many :player_action_states, dependent: :destroy
  has_one :entity, dependent: :destroy
  has_many :irradiation_enclosures, -> { where(type: "IrradiationEnclosure") },
           through: :entity, source: :owned_entities
  delegate :inventory_items, to: :entity

  after_create :provision_entity!

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
      # Deep-copy the shared APP_DATA objects so per-user mutations (on_cooldown_until,
      # disabled, etc.) never bleed across requests or users.
      @player_actions = APP_DATA[:player_actions].map(&:dup)
    end
    # Load the user's player action state and update player_actions
    # Iterate over whatever fields are stored and apply them.
    @player_actions.each do |action|
      player_action_state = PlayerActionState.where(user: self, player_action_name: action.name).first()
      if player_action_state
        player_action_state.action_state.each do |key, value|
          action.public_send(:"#{key}=", value) if action.respond_to?(:"#{key}=")
        end
      end
    end
    # Recompute dynamic fields (disabled, revealed, choices) AFTER restoring
    # persisted state so that stale DB values never override a fresh check.
    @player_actions.each do |action|
      action.update(self)
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
    player_action_state.action_state = player_action.attributes.slice(*PlayerAction::DYNAMIC_ACTION_ATTRIBUTES)
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
      p "Action #{player_action_name} is on cooldown"
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
    craft_choices = [
      { class_name: "LootBox", label: "Lootbox" },
      { class_name: "IrradiationEnclosure", label: "Irradiation Enclosure" }
    ]
    craft_choices
  end

  def craft_irradiation_enclosure(action_data)
    IrradiationEnclosure.craft(self, action_data)
  end

  def use(action_data)
    slot_number = action_data&.dig("slot_number")

    loot_box = nil

    if slot_number.present?
      slot = entity.inventory_slots.includes(:inventory_item).find_by(slot: slot_number)
      item = slot&.inventory_item
      if item.is_a?(LootBoxInventoryItem)
        loot_box = item.loot_box

        if loot_box.nil?
          # loot_box_id is nil on this item (legacy/corrupted data). Log and attempt recovery.
          Rails.logger.warn(
            "User#use: LootBoxInventoryItem id=#{item.id} has nil loot_box_id " \
            "(user=#{id} slot_number=#{slot_number}); attempting recovery via user.loot_boxes"
          )
        end
      end
    end

    # If we still don't have a loot_box, look one up directly through the user association.
    # This is more reliable than traversing item.loot_box when loot_box_id may be nil.
    if loot_box.nil?
      loot_box = loot_boxes.where(entity: entity, opened_at: nil).first
      Rails.logger.info("User#use: resolved loot_box=#{loot_box&.id} via loot_boxes (user=#{id} slot_number=#{slot_number.inspect})")
    end

    # If the LootBox was found but its loot_box_inventory_item link is broken
    # (i.e. no inventory_item row has loot_box_id pointing back to it), repair it
    # by linking the first orphaned LootBoxInventoryItem belonging to this entity.
    if loot_box && loot_box.loot_box_inventory_item.nil?
      orphan = entity.inventory_slots
        .joins(:inventory_item)
        .where(inventory_items: { type: "LootBoxInventoryItem", loot_box_id: nil })
        .first
        &.inventory_item
      if orphan
        orphan.update!(loot_box: loot_box)
        Rails.logger.info(
          "User#use: repaired orphaned LootBoxInventoryItem id=#{orphan.id} " \
          "→ loot_box id=#{loot_box.id} (user=#{id})"
        )
      end
    end

    if loot_box.nil?
      Rails.logger.warn("User#use: no openable loot box found for user=#{id} slot_number=#{slot_number.inspect}")
      return { success: false, reason: "no_loot_box" }
    end

    loot_box.open!
  end

  def sort_inventory(action_data)
    entity.sort_and_compress_inventory!
    inventory_payload = entity.inventory_slots.order(:slot).limit(100).map { |slot| slot.to_jbuilder.attributes! }
    PlayerInventoryChannel.broadcast_to(self, { action: "inventory_snapshot", data: inventory_payload })
  end

  def craft(action_data)
     Object.const_get(action_data["class_name"]).craft(self, action_data)
  end

  def remove_inventory(class_name, count)
    entity.remove_inventory(class_name, count)
  end

  def provision_entity!
    e = Entity.create!(user: self)
    e.ensure_inventory_slots
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
