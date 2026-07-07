# frozen_string_literal: true

class Fan < ActiveRecord::Base
  has_and_belongs_to_many :teams

  has_many :fanships, inverse_of: :fan
  has_one :fanship, inverse_of: :fan

  validates_presence_of(:name)
end
