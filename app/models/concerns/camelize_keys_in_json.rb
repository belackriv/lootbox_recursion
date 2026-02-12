module CamelizeKeysInJson
  extend ActiveSupport::Concern

  included do
    # Override serializable_hash to convert keys from snake_case to camelCase.
    # This mirrors the behavior of other concerns in the app that adjust JSON output.
    #
    # Usage:
    #   model_instance.serializable_hash   # => keys are camelCased
    #
    # Accepts the same options as the default ActiveRecord#serializable_hash.
    def serializable_hash(options = {})
      result = super(options) || {}

      # If the result is not a hash (unlikely), just return it unchanged.
      return result unless result.is_a?(Hash)

      # deep_transform_keys will traverse nested hashes and convert keys.
      # We use Rails' String#camelize with :lower to produce lowerCamelCase.
      result.deep_transform_keys do |key|
        # Keep non-string keys untouched
        key_str = key.to_s
        # Avoid camelizing the special 'type' key if it's already set by other concerns,
        # but keep consistent behavior: camelize all keys by default.
        key_str.camelize(:lower)
      end
    end
  end
end
