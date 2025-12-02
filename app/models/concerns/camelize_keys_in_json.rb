module CamelizeKeysInJson
  extend ActiveSupport::Concern

  included do
    def as_json(options = {})
      camelize_keys(super(options))
    end
  end

  def camelize_keys(hash)
    hash.deep_transform_keys { |k| k.camelize(:lower) }
  end
end
