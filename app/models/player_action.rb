class PlayerAction
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::AttributeAssignment

  attribute :name, :string
  attribute :label, :string
  attribute :disabled, :boolean
  attribute :revealed, :boolean
  attribute :cooldown, :integer
  attribute :on_cooldown_until, :datetime
  attribute :cast_time, :integer
  attribute :choices, ArrayType
  attribute :requirements, ArrayType
  attribute :reveal_requirements, ArrayType

  def to_jbuilder(tags = [ "default" ])
    Jbuilder.new do |jbuilder|
      if tags.include?("default")
        jbuilder.extract!(self,
          :name,
          :label,
          :disabled,
          :revealed,
          :cooldown,
          :on_cooldown_until,
          :cast_time,
          :choices,
          :requirements,
          :reveal_requirements
        )
      end
    end
  end

  def persisted?
    false
  end

  def update(user)
    update_disabled(user)
    update_revealed(user)
    update_choices(user)
  end

  def update_disabled(user)
    if name == "sort_inventory"
      on_cooldown = on_cooldown_until && on_cooldown_until > Time.current
      sort_needed = user.entity.present? && user.entity.inventory_sort_needed?
      # Rails.logger.debug("sort_needed? #{sort_needed}")
      self.disabled = on_cooldown || !sort_needed
      return
    end

    action_disabled = false
    requirements.each do |req|
      if req["for_item_type"]
        item_count = user.send(req["check"]).where(type: req["for_item_type"]).sum(:count)
        condition = check_value_by_condition(item_count, req["condition"], req["value"])
        #Rails.logger.debug("do #{req["check"]} #{req["for_item_type"]} check_value_by_condition(#{item_count}, #{req["condition"]}, #{req["value"]}) : #{condition}")
        if !condition
          action_disabled = true
        end
      end
    end
    self.disabled = action_disabled
  end

  def update_revealed(user)
    action_revealed = true
    reveal_requirements.each do |req|
      if req["for_item_type"]
        item_count = user.send(req["check"]).where(type: req["for_item_type"]).sum(:count)
        if !check_value_by_condition(item_count, req["condition"], req["value"])
          action_revealed = false
        end
      end
    end
    self.revealed = action_revealed
  end

  def update_choices(user)
    action_get_choices_method_name = "get_#{name}_choices"
    if User.method_defined?(action_get_choices_method_name)
      choices =  user.send(action_get_choices_method_name)
      self.choices = choices
    end
  end

  def check_value_by_condition(check_value, condition, compare_value)
    case condition
    when "gt"
        check_value > compare_value
    when "lt"
        check_value < compare_value
    when "eq"
        check_value == compare_value
    end
  end
end
