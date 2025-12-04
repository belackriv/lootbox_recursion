class PlayerAction
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::AttributeAssignment
  include ActiveModel::Serializers::JSON
  include CamelizeKeysInJson

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

  def persisted?
    false
  end

  def update(user)
    update_disabled(user)
    update_revealed(user)
    update_choices(user)
  end

  def update_disabled(user)
    action_disabled = false
    requirements.each do |req|
      if req['for_item_type']
        itemCount = user.send(req['check']).where(type: req['for_item_type']).sum(:count)
        if !check_value_by_condition(itemCount, req['condition'], req['value'])
          action_disabled = true
        end
      end
    end
    self.disabled = action_disabled
  end

  def update_revealed(user)
    action_revealed = true
    reveal_requirements.each do |req|
      if req['for_item_type']
        itemCount = user.send(req['check']).where(type: req['for_item_type']).sum(:count)
        if !check_value_by_condition(itemCount, req['condition'], req['value'])
          action_revealed = false
        end
      end
    end
    self.revealed = action_revealed
  end

  def update_choices(user)
    action_get_choices_method_name = 'get_' << name << '_choices'
    if(User.method_defined?(action_get_choices_method_name))
      choices =  user.send(action_get_choices_method_name)
      self.choices = choices
    end
  end

  def check_value_by_condition(check_value, condition, compare_value)
    case condition
      when 'gt'
        return check_value > compare_value
      when 'lt'
        return check_value < compare_value
      when 'eq'
        return check_value == compare_value
    end
  end
end
