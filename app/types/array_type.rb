class ArrayType < ActiveModel::Type::Value
  def self.type
    :array
  end

  def self.mutable?
    return true
  end

  def self.assert_valid_value(value)
    return value.kind_of?(Array)
  end

  def self.cast(value)
    Array(value) unless value.nil?
  end

  def self.serialize(value)
    value.to_json unless value.nil?
  end

  def self.deserialize(value)
    JSON.parse(value) unless value.nil?
  end
end
