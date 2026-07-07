# frozen_string_literal: true

class NestedFavoritePlayer < FavoritePlayer
  accepts_nested_attributes_for :fanship
end
