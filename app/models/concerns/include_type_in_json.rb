module IncludeTypeInJson
  extend ActiveSupport::Concern

  included do
    def as_json(options = {})
      super(options.merge(methods: [:type]))
    end
  end
end
