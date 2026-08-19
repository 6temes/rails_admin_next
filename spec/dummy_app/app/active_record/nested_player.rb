# frozen_string_literal: true

# Player and Draft point at each other without declaring inverse_of:, so this is the
# conventional pair whose inverse only Rails' own detection can resolve.
class NestedPlayer < Player
  accepts_nested_attributes_for :draft
end
