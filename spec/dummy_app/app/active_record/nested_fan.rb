# frozen_string_literal: true

class NestedFan < Fan
  accepts_nested_attributes_for :fanships
  accepts_nested_attributes_for :fanship
end
