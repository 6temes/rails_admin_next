# frozen_string_literal: true

class Image < ActiveRecord::Base
  has_one_attached :file
  validates :file, presence: true
end
