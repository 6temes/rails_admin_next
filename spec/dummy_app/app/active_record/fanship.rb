# frozen_string_literal: true

class Fanship < ActiveRecord::Base
  self.table_name = :fans_teams
  self.primary_key = :fan_id, :team_id
  has_many :favorite_players, foreign_key: %i[fan_id team_id], inverse_of: :fanship

  belongs_to :fan, inverse_of: :fanships, optional: true
  belongs_to :team, optional: true
end
