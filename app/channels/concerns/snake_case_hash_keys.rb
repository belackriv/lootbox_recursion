module SnakeCaseHashKeys
  extend ActiveSupport::Concern

  def snake_case_keys(hash)
    if(!hash.is_a?(Hash))
      return nil
    end
    return hash.deep_transform_keys { |k| k.to_s.underscore }
  end
end
