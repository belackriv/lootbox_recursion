module IncludeTypeInJson
  extend ActiveSupport::Concern

  included do
    def serializable_hash(options = {})
      #      Rails.logger.debug("\e[32m IncludeTypeInJson::serializable_hash \e[0m")
      result = super(options)
      result["type"] = type
      result
    end
  end
end
