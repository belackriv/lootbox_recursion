
# Global Config
Rails.application.config.after_initialize do
  Jbuilder.key_format camelize: :lower
  Jbuilder.deep_format_keys true
end
