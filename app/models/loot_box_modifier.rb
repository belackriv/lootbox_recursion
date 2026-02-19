class LootBoxModifier < ApplicationRecord
  belongs_to :loot_box

  # Base no-op implementation. Subclasses override this to mutate the loot table config.
  #
  # @param config [Hash]  the full loot table config ({ rolls: { min:, max: }, entries: [...] })
  # @return [Hash]        the (potentially mutated) config hash
  def apply(config)
    config
  end
end
