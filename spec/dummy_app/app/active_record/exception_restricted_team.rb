# frozen_string_literal: true

class ExceptionRestrictedTeam < Team
  has_many :players, foreign_key: :team_id, dependent: :restrict_with_exception
end
